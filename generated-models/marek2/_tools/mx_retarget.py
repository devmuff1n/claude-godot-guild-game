# Mixamo Sword And Shield clips (X Bot, T-pose FBX, 30 fps) -> Marek. Same bone names: each bone gets the source's
# world rotation change from rest; hips travel scaled by hip height; loops lose their forward drift. Hand roll fix:
# X Bot rests palms down, Marek palms forward, so hand + fingers are first turned into X Bot's rest roll.
# blender -b --python mx_retarget.py -- <in_blend> <out_blend>
import bpy, sys, os, json, time, re, math
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
in_blend, out_blend = argv[:2]
ONLY = argv[2].split(',') if len(argv) > 2 else None
PACK = os.path.join(W, 'mixamo', 'Pro Sword and Shield Pack')
EXTRA = os.path.join(W, 'mixamo', 'extra')
def camel(s): return ''.join(w.capitalize() for w in re.sub(r'[^a-z0-9 ]', ' ', s.lower()).split())
CLIPS = []
for d in (PACK, EXTRA):
    for fn in sorted(os.listdir(d)):
        if not fn.lower().endswith('.fbx') or fn.startswith('X Bot'): continue
        base = fn[:-4]
        nm = base.lower().replace('sword and shield ', '')
        m = re.match(r'(.*) \((\d+)\)$', nm)
        nm = camel(m.group(1))+m.group(2) if m else camel(nm)
        loop = any(k in base.lower() for k in ('idle', 'walk', 'run', 'strafe'))
        CLIPS.append((os.path.join(d, fn), 'MX_'+nm, loop))
t0 = time.time()
bpy.ops.wm.open_mainfile(filepath=in_blend)
sc = bpy.context.scene; sc.render.fps = 30
rig = bpy.data.objects['Marek_Rig']
if rig.animation_data is None: rig.animation_data_create()
pose = rig.pose.bones
for pb in pose: pb.rotation_mode = 'QUATERNION'
order = []
def walk(b):
    order.append(b.name)
    for c in b.children: walk(c)
for b in rig.data.bones:
    if b.parent is None: walk(b)
R0 = {n: rig.data.bones[n].matrix_local.to_3x3().normalized() for n in order}
HIPS = 'mixamorig:Hips'; M = 'mixamorig:'
CJ = os.path.join(W, 'clips.json')
clipinfo = json.load(open(CJ)) if os.path.exists(CJ) else {}
PROPS = ('Sword', 'Shield')
ARM_SPACE = {'Left': 14.0, 'Right': 8.0}   # degrees, like Mixamo's "Character Arm-Space"
# extra left-arm space for clips where the shield still hits the body (shield_fit.py / arm_tune.py)
_AE = os.path.join(W, 'arm_extra.json')
ARM_EXTRA = json.load(open(_AE)) if os.path.exists(_AE) else {}
ARM_EXTRA.update(json.loads(os.environ.get('ARM_EXTRA', '{}')))
ARM_TREE = {}
for side in ('Left', 'Right'):
    st = [rig.data.bones[M+side+'Arm']]; ARM_TREE[side] = []
    while st:
        b = st.pop(); ARM_TREE[side].append(b.name); st.extend(b.children)

def import_src(path):
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=False)
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == 'ARMATURE'][0]
    return arm, arm.animation_data.action, new, [a for a in bpy.data.actions if a not in acts]

def retarget(src, act, name, in_place):
    sp = src.pose.bones; mw = src.matrix_world
    S0 = {pb.name: (mw.to_3x3() @ pb.bone.matrix_local.to_3x3()).normalized() for pb in sp}
    f0, f1 = [int(round(x)) for x in act.frame_range]
    hip_s0 = mw @ sp[HIPS].bone.head_local
    ratio = rig.data.bones[HIPS].head_local.z/hip_s0.z
    old = bpy.data.actions.get(name)
    if old: bpy.data.actions.remove(old)
    a = bpy.data.actions.new(name); a.use_fake_user = True
    rig.animation_data.action = a
    frames = list(range(f0, f1+1))
    hips_off = []
    for f in frames:
        sc.frame_set(f); hips_off.append((mw @ sp[HIPS].head-hip_s0)*ratio)
    if in_place:
        d = hips_off[-1]-hips_off[0]; n = max(len(hips_off)-1, 1)
        hips_off = [o-V((d.x, d.y, 0))*(i/n) for i, o in enumerate(hips_off)]
        hips_off = [o-V((hips_off[0].x, hips_off[0].y, 0)) for o in hips_off]
    C = {}
    for side in ('Left', 'Right'):
        hd = (rig.data.bones[M+side+'HandMiddle1'].head_local-rig.data.bones[M+side+'Hand'].head_local).normalized()
        def proj(k): k = V(k); return (k-hd*k.dot(hd)).normalized()
        kE = proj(rig.data.bones[M+side+'HandIndex1'].head_local-rig.data.bones[M+side+'HandPinky1'].head_local)
        kS = proj(mw @ sp[M+side+'HandIndex1'].bone.head_local-mw @ sp[M+side+'HandPinky1'].bone.head_local)
        Cs = kE.rotation_difference(kS).to_matrix()
        stack = [rig.data.bones[M+side+'Hand']]
        while stack:
            b = stack.pop()
            if b.name not in PROPS: C[b.name] = Cs
            stack.extend(b.children)
    I3 = Matrix.Identity(3)
    for i, f in enumerate(frames):
        sc.frame_set(f)
        D = {}
        for n in order:
            if n in sp: D[n] = (mw.to_3x3() @ sp[n].matrix.to_3x3()).normalized() @ S0[n].inverted()
            else:
                p = rig.data.bones[n].parent; D[n] = D[p.name] if p else I3
        # arm space: Marek's armour is bulkier than X Bot, so both arms swing out from the chest a little
        fwd = (D['mixamorig:Spine2'] @ V((0, -1, 0))).normalized()
        for side, sg in (('Left', 1), ('Right', -1)):
            Rabd = Matrix.Rotation(math.radians(sg*(ARM_SPACE[side]+(ARM_EXTRA.get(name, 0.0) if side == 'Left' else 0.0))), 3, fwd)
            for n in ARM_TREE[side]: D[n] = Rabd @ D[n]
        for n in order:
            pb = pose[n]
            if n in PROPS:
                pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); continue
            p = rig.data.bones[n].parent
            Dp = D[p.name] if p else I3
            Cb = C.get(n, I3); Cp = C.get(p.name, I3) if p else I3
            pb.rotation_quaternion = (R0[n].inverted() @ Cp.inverted() @ Dp.inverted() @ D[n] @ Cb @ R0[n]).to_quaternion()
            pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        pose[HIPS].location = R0[HIPS].inverted() @ hips_off[i]
        for pb in pose:
            if pb.name in PROPS: continue
            pb.keyframe_insert('rotation_quaternion', frame=i)
            if pb.name == HIPS: pb.keyframe_insert('location', frame=i)
    return len(frames)-1

for path, name, loop in CLIPS:
    if ONLY and name not in ONLY: continue
    src, act, new, newacts = import_src(path)
    n = retarget(src, act, name, loop)
    clipinfo[name] = dict(frames=n, loop=loop, mixamo=os.path.basename(path)[:-4])
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    for a in newacts: bpy.data.actions.remove(a)
    for arm in [d for d in bpy.data.armatures if d.users == 0]: bpy.data.armatures.remove(arm)
    print('MX', name, n, loop, round(time.time()-t0, 1), flush=True)
json.dump(clipinfo, open(CJ, 'w'), indent=1)
for m in [m for m in bpy.data.meshes if m.users == 0]: bpy.data.meshes.remove(m)
rig.animation_data.action = bpy.data.actions.get('MX_Idle')
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print('DONE', round(time.time()-t0, 1))
