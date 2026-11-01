# Step 4: Mixamo longbow clips (X Bot, T-pose FBX) -> Elira. Same bone names, so each bone gets the source's world
# rotation change relative to its rest; hips travel is scaled by hip height. Bow string / arrow are added from the hand
# positions: the string follows the right hand while it is behind the bow on the arrow line, the arrow sits nocked then,
# flies off on release, and rides in the hand between the quiver and the string.
# blender -b --python mx_retarget.py -- <in_blend> <out_blend> <out_glb>
import bpy, sys, os, math, json, time
sys.path.insert(0, os.path.dirname(__file__))
import animlib as L
from mathutils import Vector as V, Matrix, Quaternion
W = os.path.join(os.path.dirname(__file__), '..', '_work')
MX = os.path.join(W, 'mixamo', 'Pro Longbow Pack')
argv = sys.argv[sys.argv.index('--')+1:]
in_blend, out_blend, out_glb = argv
CLIPS = [  # (fbx name, our name, in_place)
    ('standing idle 01', 'MX_Idle', True), ('standing idle 02 looking', 'MX_IdleLook', True),
    ('standing idle 03 examine', 'MX_IdleExamine', True), ('unarmed idle 01', 'MX_IdleUnarmed', True),
    ('standing walk forward', 'MX_Walk', True), ('standing walk back', 'MX_WalkBack', True),
    ('standing walk left', 'MX_WalkLeft', True), ('standing walk right', 'MX_WalkRight', True),
    ('standing run forward', 'MX_Run', True), ('standing run back', 'MX_RunBack', True),
    ('standing run left', 'MX_RunLeft', True), ('standing run right', 'MX_RunRight', True),
    ('standing run forward stop', 'MX_RunStop', False),
    ('standing turn 90 left', 'MX_TurnLeft', False), ('standing turn 90 right', 'MX_TurnRight', False),
    ('standing aim walk forward', 'MX_AimWalk', True), ('standing aim walk back', 'MX_AimWalkBack', True),
    ('standing aim walk left', 'MX_AimWalkLeft', True), ('standing aim walk right', 'MX_AimWalkRight', True),
    ('standing draw arrow', 'MX_DrawArrow', False), ('standing aim overdraw', 'MX_AimOverdraw', False),
    ('standing aim recoil', 'MX_AimRecoil', False), ('standing equip bow', 'MX_Equip', False),
    ('standing disarm bow', 'MX_Disarm', False), ('standing block', 'MX_Block', False),
    ('standing dodge backward', 'MX_DodgeBack', False), ('standing dodge forward', 'MX_DodgeForward', False),
    ('standing dodge left', 'MX_DodgeLeft', False), ('standing dodge right', 'MX_DodgeRight', False),
    ('standing dive forward', 'MX_Dive', False),
    ('standing react small from front', 'MX_Hit', False), ('standing react small from headshot', 'MX_HitHead', False),
    ('standing death backward 01', 'MX_Death', False), ('standing death forward 01', 'MX_DeathForward', False),
    ('fall a loop', 'MX_FallLoop', True), ('fall a land to standing idle 01', 'MX_FallLand', False),
    ('fall a land to run forward', 'MX_FallLandRun', False),
    ('standing melee kick', 'MX_Kick', False), ('standing melee punch', 'MX_Punch', False),
]
EXTRA = os.path.join(W, 'mixamo', 'extra')   # single clips downloaded separately: file name -> MX_<CamelName>
if os.path.isdir(EXTRA):
    for fn in sorted(os.listdir(EXTRA)):
        if fn.lower().endswith('.fbx'):
            base = fn[:-4]; nm = 'MX_'+''.join(w.capitalize() for w in base.replace('-', ' ').split())
            CLIPS.append((os.path.join('..', 'extra', base), nm, any(k in base.lower() for k in ('idle', 'loop', 'sprint', 'crouch walk'))))
t0 = time.time()
bpy.ops.wm.open_mainfile(filepath=in_blend)
sc = bpy.context.scene; sc.render.fps = 30
rig = bpy.data.objects['Elira_Rig']
L.init(rig, os.path.join(W, 'bow_meta.json'))
pose = rig.pose.bones
order = []
def walk(b):
    order.append(b.name)
    for c in b.children: walk(c)
for b in rig.data.bones:
    if b.parent is None: walk(b)
R0 = {n: rig.data.bones[n].matrix_local.to_3x3().normalized() for n in order}
HIPS = 'mixamorig:Hips'
M = 'mixamorig:'
clipinfo = json.load(open(os.path.join(W, 'clips.json')))

def import_src(path):
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=False)
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == 'ARMATURE'][0]
    act = arm.animation_data.action
    return arm, act, new, [a for a in bpy.data.actions if a not in acts]

def retarget(src, act, name, in_place):
    sp = src.pose.bones; mw = src.matrix_world
    S0 = {pb.name: (mw.to_3x3() @ pb.bone.matrix_local.to_3x3()).normalized() for pb in sp}
    f0, f1 = [int(round(x)) for x in act.frame_range]
    hip_s0 = mw @ sp[HIPS].bone.head_local
    ratio = rig.data.bones[HIPS].head_local.z/hip_s0.z
    a = bpy.data.actions.new(name); a.use_fake_user = True
    rig.animation_data.action = a
    frames = list(range(f0, f1+1))
    hips_off = []
    for f in frames:
        sc.frame_set(f)
        hips_off.append((mw @ sp[HIPS].head-hip_s0)*ratio)
    if in_place:   # remove the linear forward drift so loops stay on the spot
        d = hips_off[-1]-hips_off[0]
        n = max(len(hips_off)-1, 1)
        hips_off = [o-V((d.x, d.y, 0))*(i/n) for i, o in enumerate(hips_off)]
        hips_off = [o-V((hips_off[0].x, hips_off[0].y, 0)) for o in hips_off]
    # hand roll: X Bot rests palms down, Elira palms forward. C turns Elira's hand (and fingers) into the source's
    # rest roll before the source motion is applied, so the fist and the bow face the same way as on X Bot.
    C = {}
    for side in ('Left', 'Right'):
        hd = (rig.data.bones[M+side+'HandMiddle1'].head_local-rig.data.bones[M+side+'Hand'].head_local).normalized()
        def proj(k): k = V(k); return (k-hd*k.dot(hd)).normalized()
        kE = proj(rig.data.bones[M+side+'HandIndex1'].head_local-rig.data.bones[M+side+'HandPinky1'].head_local)
        kS = proj(mw @ sp[M+side+'HandIndex1'].bone.head_local-mw @ sp[M+side+'HandPinky1'].bone.head_local)
        Cs = kE.rotation_difference(kS).to_matrix()
        stack = [rig.data.bones[M+side+'Hand']]
        while stack:
            b = stack.pop(); C[b.name] = Cs; stack.extend(b.children)
    I3 = Matrix.Identity(3)
    out = []
    for i, f in enumerate(frames):
        sc.frame_set(f)
        D = {}
        for n in order:
            if n in sp:
                D[n] = (mw.to_3x3() @ sp[n].matrix.to_3x3()).normalized() @ S0[n].inverted()
            else:
                p = rig.data.bones[n].parent
                D[n] = D[p.name] if p else Matrix.Identity(3)
        for n in order:
            pb = pose[n]
            if n in ('Bow', 'BowLimbTop', 'BowLimbBot', 'BowString', 'Arrow'):
                pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1); continue
            p = rig.data.bones[n].parent
            Dp = D[p.name] if p else Matrix.Identity(3)
            Cb = C.get(n, I3); Cp = C.get(p.name, I3) if p else I3
            pb.rotation_quaternion = (R0[n].inverted() @ Cp.inverted() @ Dp.inverted() @ D[n] @ Cb @ R0[n]).to_quaternion()
            pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        pose[HIPS].location = R0[HIPS].inverted() @ hips_off[i]
        out.append(i)
        bow_extras(i)
        key_all(i)
    return len(frames)-1

# ---- bow string / arrow from hand positions
QUIVER_TOP = V((-0.22, 0.12, 1.16)); QUIVER_BOT = V((-0.08, 0.10, 0.72))
state = {}
def reset_state(): state.clear(); state.update(follow=0.0, grab=None, released=None, nock0=None, d0=None, up0=None, prev_along=0)
def bow_extras(i):
    L.upd()
    Ab = (L.deform('Bow').to_3x3() @ L.META['T']).normalized()
    upb = (L.deform('Bow').to_3x3() @ L.META['up']).normalized()
    ar = L.bow_rest_point(); h = L.hook_point()
    v = h-ar; along = -v.dot(Ab); vert = abs(v.dot(upb)); lat = (v-Ab*v.dot(Ab)-upb*v.dot(upb)).length
    on = 0.07 <= along <= 0.8 and lat < 0.2 and vert < 0.25
    sd = L.deform('Spine2'); qt = sd @ QUIVER_TOP; qb = sd @ QUIVER_BOT
    if (h-qt).length < 0.25 and state['grab'] is None: state['grab'] = i
    target = 1.0 if on else 0.0
    # release: was drawn far back, now off the string
    if state['follow'] > 0.5 and not on and state['prev_along'] > 0.2:
        state['released'] = i; state['nock0'] = state['last_nock']; state['d0'] = state['last_dir']; state['up0'] = upb
        state['grab'] = None
    state['follow'] = target
    srest = L.string_rest_point()
    if on:
        L.place_string(h); L.upd()
        nk = L.pose['BowString'].head.copy(); d = (ar-nk).normalized()
        L.place_arrow(nk, d, upb, True)
        state['last_nock'] = nk; state['last_dir'] = d; state['prev_along'] = along
        state['grab'] = None
        return
    state['prev_along'] = 0
    k = i-state['released'] if state['released'] is not None else 99
    vib = 0.03*math.sin(2*math.pi*k/3.2)*math.exp(-k/3.5) if k < 14 else 0.0
    L.place_string(srest+Ab*vib); L.upd()
    if k <= 9:
        L.place_arrow(state['nock0']+state['d0']*(0.5*k), state['d0'], state['up0'], True); return
    if state['grab'] is not None:
        g = i-state['grab']; t = L.smooth(g/8)
        d = (qb-h).normalized().lerp((ar-h).normalized(), t).normalized()
        L.place_arrow(h, d, V((0, 0, 1)) if abs(d.z) < 0.9 else V((1, 0, 0)), True); return
    L.place_arrow(h, V((0, 0, -1)), V((1, 0, 0)), False)

def key_all(f):
    for pb in pose:
        pb.keyframe_insert('rotation_quaternion', frame=f)
        if pb.name in (HIPS, 'BowString', 'Arrow'): pb.keyframe_insert('location', frame=f)
        if pb.name == 'Arrow': pb.keyframe_insert('scale', frame=f)

for fbx, name, inplace in CLIPS:
    p = os.path.join(MX, fbx+'.fbx')
    if not os.path.exists(p): print('MISSING', p); continue
    src, act, new, newacts = import_src(p)
    reset_state()
    if name == 'MX_DrawArrow': state['grab'] = 0
    n = retarget(src, act, name, inplace)
    clipinfo[name] = dict(frames=n, loop=inplace, mixamo=fbx)
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    for a in newacts: bpy.data.actions.remove(a)
    for arm in [d for d in bpy.data.armatures if d.users == 0]: bpy.data.armatures.remove(arm)
    print('MX', name, n, round(time.time()-t0, 1))
rig.animation_data.action = bpy.data.actions['Idle']
json.dump(clipinfo, open(os.path.join(W, 'clips.json'), 'w'), indent=1)
for m in [m for m in bpy.data.meshes if m.users == 0]: bpy.data.meshes.remove(m)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH', 'ARMATURE'): o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', use_selection=True, export_apply=False,
    export_skins=True, export_all_influences=False, export_def_bones=False, export_rest_position_armature=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_range=False,
    export_anim_single_armature=True, export_reset_pose_bones=True, export_optimize_animation_size=True,
    export_image_format='JPEG', export_jpeg_quality=88, export_materials='EXPORT', export_tangents=False, export_yup=True)
print('DONE', os.path.getsize(out_glb), round(time.time()-t0, 1))
