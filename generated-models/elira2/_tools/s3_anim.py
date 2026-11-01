# Step 3: Elira's clips (bow handling authored with IK), saved to elira2.blend and exported to GLB.
# blender -b --python s3_anim.py -- <out_blend> <out_glb>
import bpy, sys, os, math, json, time
sys.path.insert(0, os.path.dirname(__file__))
import animlib as L, poses
from poses import build, hold_bow, on_string, solve_full
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
out_blend, out_glb = argv[0], argv[1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, 's2.blend'))
sc = bpy.context.scene; sc.render.fps = 30
rig = bpy.data.objects['Elira_Rig']
L.init(rig, os.path.join(W, 'bow_meta.json'))
t0 = time.time()
BRACE = 0.088
TORSO0 = dict(hips=0, tw=0, yaw=0, pitch=0, stance=0, knee=0, lean=0, slean=0, tilt=0, drop=0, wamp=0, wph=0, breath=0,
              feet=0.55, runlean=0, hook=0, rfist=0, string=0, flex=0, nock=0, avis=0, adir=V((0, 0, -1)), shift=V((0, 0, 0)))
def mk(**kw):
    q = dict(TORSO0); q.update(kw); return q
def nz(v): return V(v).normalized()

# ---------------- named poses
IDLE = mk(stance=3, WL=V((0.21, -0.08, 0.64)), dL=nz((0.05, -1, -0.25)), kL=nz((0.05, -0.45, 0.9)), pL=V((0.4, 1, 0)),
          WR=V((-0.2, -0.08, 0.63)), dR=nz((-0.1, -0.35, -0.93)), kR=nz((0, -1, 0.35)), pR=V((-0.3, 1, 0)), rfist=0.3)

READY = mk(hips=-25, tw=-10, yaw=35, knee=7, stance=7, lean=3, pL=V((1, 0.3, -0.4)), pR=V((-1, 0.5, -0.3)),
           WR=V((0, 0, 0)), dR=V((0, -1, 0)), kR=V((0, 0, 1)), hook=1, string=1, nock=1, avis=1)
hold_bow(READY, (0.07, -0.30, 0.86), (0.1, -0.8, -0.6), (0.5, -0.45, 0.75))
on_string(READY, BRACE)
READY_E = dict(READY); READY_E.update(WR=READY['WR']+V((-0.02, 0.03, -0.06)), hook=0.3, string=0, nock=0, avis=0)

REACH = dict(READY_E); REACH.update(hips=-10, tw=18, yaw=10, lean=-3, WR=V((-0.27, 0.10, 1.2)), dR=nz((-0.15, 0.45, -0.88)),
                                   kR=nz((-1, 0, 0)), pR=V((-1, -0.2, 0.7)), hook=0.6, avis=0)
PULL = dict(REACH); PULL.update(tw=12, yaw=15, WR=V((-0.31, 0.05, 1.34)), dR=nz((-0.2, 0.3, 0.93)), kR=nz((0, -1, 0)), hook=1,
                                avis=1, nock=0, adir=nz((0.0, 0.75, -0.65)))
OVER = dict(PULL); OVER.update(hips=-18, tw=-2, yaw=25, WR=V((-0.12, -0.22, 1.2)), dR=nz((0.2, -0.9, 0.3)), kR=V((0, 0, 1)),
                               pR=V((-1, 0.3, -0.2)), adir=nz((0.15, -0.5, 0.85)))

RAISE = mk(hips=-45, tw=-18, yaw=60, knee=5, stance=7, pL=V((1, 0.2, -0.6)), pR=V((-1, 0.4, 0.2)),
           WR=V((0, 0, 0)), dR=V((0, -1, 0)), kR=V((0, 0, 1)), hook=1, string=1, nock=1, avis=1, flex=0.4)
hold_bow(RAISE, (0.06, -0.42, 1.0), (0, -1, -0.12), (0.22, 0, 1))
RAISE['WR_guess'] = READY['WR']; on_string(RAISE, 0.26)
FULL, C_full, D_full = solve_full(mk(hips=-50, tw=-20, yaw=70, stance=7, knee=5, nock=1, avis=1), (0, -1, 0.04))
FULL.update(hook=1, string=1, nock=1, avis=1, flex=1)
SKY, C_sky, D_sky = solve_full(mk(hips=-50, tw=-20, yaw=70, stance=9, knee=7, lean=-12, pitch=-20, nock=1, avis=1), (0, -0.72, 0.69),
                               pole_r=(-1, 0.6, -0.1))
SKY.update(hook=1, string=1, nock=1, avis=1, flex=1)
def shot_of(Fp):
    S = dict(Fp); A = nz(Fp['dL'])
    right = A.cross(V((0, 0, 1))).normalized()
    S.update(WR=Fp['WR']+right*0.04-A*0.13+V((0, 0, 0.03)), hook=0, string=0, flex=0, kL=nz(Fp['kL']+A*0.18))
    return S
SHOT = shot_of(FULL); SKY_SHOT = shot_of(SKY)

VICTORY = mk(lean=-6, tilt=-6, yaw=-5, stance=6, pL=V((1, 0, -0.3)), WR=V((-0.17, -0.02, 0.8)), dR=nz((0.3, -0.2, -0.9)),
             kR=nz((0, -1, 0)), pR=V((-1, 0.6, 0)), rfist=1)
hold_bow(VICTORY, (0.24, -0.08, 1.62), (0, -1, 0.1), (0.35, 0, 1))
HIT = dict(READY_E); HIT.update(lean=-14, yaw=0, tilt=10, knee=14, shift=V((0, 0.07, 0)))

# ---------------- clip machinery
def mix(A, B, t):
    out = {}
    for k in set(A) | set(B):
        a = A.get(k, B.get(k)); b = B.get(k, a)
        if isinstance(a, V): out[k] = V(a).lerp(V(b), t)
        elif isinstance(a, (int, float)): out[k] = a*(1-t)+b*t
        else: out[k] = b if t > 0.5 else a
    return out
KEYED = ['Hips', 'BowString', 'Arrow']
def key_all(f):
    for pb in L.pose:
        pb.keyframe_insert('rotation_quaternion', frame=f)
        if pb.name in (L.FN('Hips'), 'BowString', 'Arrow'): pb.keyframe_insert('location', frame=f)
        if pb.name == 'Arrow': pb.keyframe_insert('scale', frame=f)
CLIPS = {}
def clip(name, keys, length, loop=False, fx=None, post=None):
    a = bpy.data.actions.new(name); a.use_fake_user = True
    rig.animation_data_create(); rig.animation_data.action = a
    for f in range(length+1):
        for i in range(len(keys)-1):
            if keys[i][0] <= f <= keys[i+1][0]: break
        fa, A = keys[i]; fb, B = keys[i+1]
        q = mix(A, B, L.smooth((f-fa)/max(fb-fa, 1)))
        if fx: fx(f, q)
        build(q)
        if post: post(f, q)
        L.upd(); key_all(f)
    CLIPS[name] = dict(frames=length, loop=loop)
    print('CLIP', name, length, round(time.time()-t0, 1))

def breathing(L_):
    def fx(f, q): q['breath'] = math.sin(2*math.pi*f/L_)
    return fx
def release_fx(fr, Fp, speed=0.5, life=9):
    """post-build: arrow flies along the aim after frame fr; string vibrates."""
    build(Fp); L.upd()
    nock0 = L.pose['BowString'].head.copy(); d0 = (L.bow_rest_point()-nock0).normalized()
    up0 = (L.deform('Bow').to_3x3() @ L.META['up']).normalized()
    def post(f, q):
        k = f-fr
        if k < 0 or k > life+3: return
        Ab = (L.deform('Bow').to_3x3() @ L.META['T']).normalized()
        vib = 0.03*math.sin(2*math.pi*k/3.2)*math.exp(-k/3.5)
        L.place_string(L.string_rest_point()+Ab*vib); L.upd()
        L.place_arrow(nock0+d0*(speed*k), d0, up0, k <= life)
    return post

# Idle: relaxed, bow along the left side
clip('Idle', [(0, IDLE), (60, IDLE)], 60, True, breathing(60))
# Ready: combat stance, arrow nocked, bow low
clip('Ready', [(0, READY), (60, READY)], 60, True, breathing(60))
# Walk / Run with the bow carried
def walk_fx(L_, amp, run=0):
    def fx(f, q):
        ph = f/L_; q['wph'] = ph; q['wamp'] = amp; q['runlean'] = run
        s = math.sin(2*math.pi*ph)
        q['WR'] = q['WR']+V((0, 0.09*amp*s, 0.02*amp*abs(s))); q['WL'] = q['WL']+V((0, -0.04*amp*s, 0))
    return fx
clip('Walk', [(0, IDLE), (32, IDLE)], 32, True, walk_fx(32, 0.8))
RUNP = dict(IDLE); RUNP.update(lean=8, WR=IDLE['WR']+V((0, -0.06, 0.08)), WL=IDLE['WL']+V((0, -0.05, 0.06)))
clip('Run', [(0, RUNP), (20, RUNP)], 20, True, walk_fx(20, 1.3, 1))
# Draw: from the ready stance to full draw
clip('Bow_Draw', [(0, READY), (10, RAISE), (20, FULL)], 20)
# Aim: hold at full draw (loop), slight tremble and breathing
def aim_fx(f, q):
    q['breath'] = 0.5*math.sin(2*math.pi*f/40)
    q['WR'] = q['WR']+V((0, 0.004*math.sin(2*math.pi*f/40), 0))
clip('Bow_Aim', [(0, FULL), (40, FULL)], 40, True, aim_fx)
# Shoot: release, follow-through, reach to the quiver, pull an arrow, nock it, back to ready
RELOAD = [(14, REACH), (21, PULL), (28, OVER), (37, READY), (44, READY)]
clip('Bow_Shoot', [(0, FULL), (2, SHOT), (9, SHOT)]+RELOAD, 44, post=release_fx(1, FULL))
# Quick: whole cycle as one attack
clip('Bow_Quick', [(0, READY), (7, RAISE), (13, FULL), (16, FULL), (18, SHOT), (24, SHOT)]+[(f+10, p) for f, p in RELOAD],
     54, post=release_fx(17, FULL))
# Sky shot: aim high (volley / rain of arrows)
SKY_RAISE = dict(RAISE); SKY_RAISE.update(lean=-6, pitch=-10)
clip('Bow_Sky', [(0, READY), (9, SKY_RAISE), (18, SKY), (24, SKY), (26, SKY_SHOT), (34, SKY_SHOT)]+[(f+20, p) for f, p in RELOAD],
     64, post=release_fx(25, SKY))
# Hit
clip('Hit', [(0, READY_E), (4, HIT), (20, READY_E)], 20)
# Dodge: hop back
DODGE1 = dict(READY_E); DODGE1.update(knee=20, lean=10, shift=V((0, 0.04, -0.06)))
DODGE2 = dict(READY_E); DODGE2.update(knee=6, lean=-6, shift=V((0, 0.38, 0.06)))
DODGE3 = dict(READY_E); DODGE3.update(knee=18, lean=6, shift=V((0, 0.45, -0.05)))
DODGE4 = dict(READY_E); DODGE4.update(shift=V((0, 0.45, 0)))
clip('Dodge', [(0, READY_E), (4, DODGE1), (10, DODGE2), (15, DODGE3), (24, DODGE4)], 24)
# Death: stagger, knees give way, fall on the back
D1 = dict(HIT); D1.update(lean=-20, knee=25, drop=0.08)
def death_fx(f, q):
    t = L.smooth((f-12)/20)
    if t <= 0: return
    q['knee'] = q['knee']*(1-t)+10*t
    q['drop'] = q['drop']*(1-t)+0.6*t
    q['shift'] = V((0, 0.25*t, 0))
    q['WL'] = q['WL'].lerp(V((0.38, 0.25, 0.06-0.0)), t); q['WR'] = q['WR'].lerp(V((-0.38, 0.3, 0.06)), t)
    q['_fall'] = t
def death_post(f, q):
    t = q.get('_fall', 0)
    if t <= 0: return
    pb = L.pose[L.FN('Hips')]
    R = Matrix.Rotation(math.radians(-82*t), 3, 'X')
    Mr = L.REST[pb.name]
    pb.rotation_quaternion = (Mr.inverted() @ R @ Mr).to_quaternion() @ pb.rotation_quaternion
    L.upd()
    L.place_arm('Left', q['WL']+V((0, 0.25*t, 0)), q['pL'], q['dL'], q['kL'])
    L.place_arm('Right', q['WR']+V((0, 0.25*t, 0)), q['pR'], q['dR'], q['kR'])
D2 = dict(D1); D2.update(lean=-10, yaw=-20, pitch=-15)
clip('Death', [(0, READY_E), (6, D1), (14, D1), (34, D2), (50, D2)], 50, fx=death_fx, post=death_post)
# Victory: bow raised overhead
clip('Victory', [(0, READY_E), (12, VICTORY), (60, VICTORY)], 60, fx=lambda f, q: q.update(breath=math.sin(2*math.pi*f/30) if f > 12 else 0))

# ---------------- rest pose action off, save, export
rig.animation_data.action = bpy.data.actions['Idle']
json.dump(CLIPS, open(os.path.join(W, 'clips.json'), 'w'), indent=1)
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
