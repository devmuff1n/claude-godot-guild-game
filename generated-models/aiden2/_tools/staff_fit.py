# Keep the staff out of the body, hair, robe and ground in every MX_* clip.
# Per frame: the deformed body (minus the staff hand itself) goes into a BVH; the staff is a chain of spheres in
# Staff-bone space. If any sphere touches the body/ground, try small tilts of the staff about the grip (axis in the
# bone's XZ plane) and slides along the shaft, cheapest first (tilt, slide, change from the previous frame), take
# the first clear one. Then a temporal blur (kept only where it stays clear). Keys Staff rotation/location.
# blender -b --python staff_fit.py -- <in_blend> <out_blend> [clips]   -> _work/staff_fit.json report
import bpy, sys, os, math, json, time
from mathutils import Vector as V, Quaternion as Q, Matrix
from mathutils.bvhtree import BVHTree
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
ONLY = a[2].split(',') if len(a) > 2 else None
TP = os.path.join(W, 'staff_tune.json'); TUNE = json.load(open(TP)) if os.path.exists(TP) else {}
SIDE = TUNE.get('hand', 'Left'); M = 'mixamorig:'
sc = bpy.context.scene
rig = bpy.data.objects['Aiden_Rig']; body = bpy.data.objects['Aiden']; staff = bpy.data.objects['Aiden_Staff']
pb = rig.pose.bones['Staff']; pb.rotation_mode = 'QUATERNION'
SB = rig.data.bones['Staff']; R0 = SB.matrix_local.copy()          # bone rest (armature space)
R0i = R0.inverted()
# ---- staff spheres in bone-local space (radius from the mesh cross-section + margin)
loc = [R0i @ v.co for v in staff.data.vertices]
ys = [p.y for p in loc]; y0, y1 = min(ys), max(ys)
MARGIN = TUNE.get('fit_margin', 0.012); GRIP_SKIP = 0.075
SPH = []
y = y0+0.012
while y < y1:
    band = [p for p in loc if abs(p.y-y) < 0.03]
    r = max((math.hypot(p.x, p.z) for p in band), default=0.02)+MARGIN
    if abs(y) > GRIP_SKIP: SPH.append((V((0, y, 0)), r))
    y += min(0.04, max(0.02, r*1.6))
print('SPHERES', len(SPH), round(y0, 3), round(y1, 3), [round(r, 3) for _, r in SPH][-6:])
# ---- body faces without the staff hand (fingers wrap the shaft)
gi = {g.index: g.name for g in body.vertex_groups}
HAND = {i for i, n in gi.items() if n.startswith(M+SIDE+'Hand')}
skipv = set()
for v in body.data.vertices:
    if sum(g.weight for g in v.groups if g.group in HAND) > 0.5: skipv.add(v.index)
POLYS = [list(p.vertices) for p in body.data.polygons if not any(i in skipv for i in p.vertices)]
# ---- candidates
DIRS = [math.radians(k*45) for k in range(8)]
TILTS = [0, 5, 10, 16, 23, 31, 40, 50, 62]
SLIDES = [0, 0.06, -0.06, 0.12, -0.12, 0.2, -0.2, 0.3]
CANDS = []
for t in TILTS:
    for ph in (DIRS if t else [0]):
        ax = V((math.cos(ph), 0, math.sin(ph)))
        q = Q(ax, math.radians(t))
        for s in SLIDES: CANDS.append((q, s, t))


def world_of_bone():
    return rig.matrix_world @ pb.matrix   # current pose (with current basis)


def penetration(Mb_rest_parented, q, s, bvh):
    """Mb_rest_parented = armature-space matrix of the Staff bone with identity basis."""
    Mq = Mb_rest_parented @ (Matrix.Translation(V((0, s, 0))) @ q.to_matrix().to_4x4())
    pen = 0.0
    for c, r in SPH:
        p = Mq @ c
        g = r-0.004-p.z
        if g > 0: pen += g
        hit = bvh.find_nearest(p, r)
        if hit[0] is not None: pen += r-hit[3]
    return pen


def bone_identity_matrix():
    pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    return pb.matrix.copy()


def solve_clip(act, loop):
    rig.animation_data.action = act
    try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
    except Exception: pass
    f0, f1 = [int(round(x)) for x in act.frame_range]
    frames = list(range(f0, f1+1))
    data = []
    for f in frames:
        sc.frame_set(f)
        Mb = bone_identity_matrix()
        dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
        bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], POLYS)
        ev.to_mesh_clear()
        data.append((Mb, bvh))
    def run(prev):
        out = []
        for Mb, bvh in data:
            p0 = penetration(Mb, Q(), 0, bvh)
            if p0 == 0 and prev[2] == 0 and prev[1] == 0:
                out.append((Q(), 0.0, 0, 0.0)); prev = out[-1]; continue
            best = None
            order = sorted(CANDS, key=lambda c: c[2]*1.0+abs(c[1])*90+math.degrees(c[0].rotation_difference(prev[0]).angle)*0.7+abs(c[1]-prev[1])*60)
            for q, s, t in order:
                if penetration(Mb, q, s, bvh) == 0: best = (q, s, t, 0.0); break
            if best is None:
                sc_ = [(penetration(Mb, q, s, bvh), q, s, t) for q, s, t in CANDS]
                pmin, q, s, t = min(sc_, key=lambda x: x[0]+x[3]*0.0005)
                best = (q, s, t, pmin)
            out.append(best); prev = best
        return out
    raw = run((Q(), 0.0, 0, 0.0))
    if loop: raw = run(raw[-1])
    # temporal blur (gaussian-ish 1-4-6-4-1), keep where still clear
    n = len(raw); K = [1, 4, 6, 4, 1]
    sm = []
    for i in range(n):
        acc_q = None; acc_s = 0; wsum = 0
        for j, k in enumerate(K):
            ii = i+j-2
            if loop: ii %= n
            else: ii = max(0, min(n-1, ii))
            q = raw[ii][0]
            if acc_q is None: acc_q = q.copy(); wsum = k; acc_s = raw[ii][1]*k; continue
            wsum += k; acc_q = acc_q.slerp(q, k/wsum); acc_s += raw[ii][1]*k
        sm.append((acc_q, acc_s/sum(K)))
    final = []; bad = 0; worst = 0
    for i, (Mb, bvh) in enumerate(data):
        q, s = sm[i]
        p = penetration(Mb, q, s, bvh)
        if p > 0 and raw[i][3] < p: q, s = raw[i][0], raw[i][1]; p = raw[i][3]
        if p > 0: bad += 1; worst = max(worst, p)
        final.append((q, s))
    # key
    for i, f in enumerate(frames):
        q, s = final[i]
        pb.rotation_quaternion = q; pb.location = (0, s, 0)
        pb.keyframe_insert('rotation_quaternion', frame=f); pb.keyframe_insert('location', frame=f)
    tilts = [math.degrees(q.angle) for q, s in final]
    return dict(frames=n, fixed=sum(1 for t in tilts if t > 0.5), max_tilt=round(max(tilts), 1),
                max_slide=round(max(abs(s) for q, s in final), 3), unresolved=bad, worst=round(worst, 4))


CJ = os.path.join(W, 'clips.json'); clips = json.load(open(CJ)) if os.path.exists(CJ) else {}
rep = {}; t0 = time.time()
for act in sorted([x for x in bpy.data.actions if x.name.startswith('MX_')], key=lambda x: x.name):
    if ONLY and act.name not in ONLY: continue
    r = solve_clip(act, clips.get(act.name, {}).get('loop', False))
    rep[act.name] = r; print('FIT', act.name, r, round(time.time()-t0, 1), flush=True)
RJ = os.path.join(W, 'staff_fit.json'); old = json.load(open(RJ)) if os.path.exists(RJ) else {}
old.update(rep); json.dump(old, open(RJ, 'w'), indent=1)
pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
rig.animation_data.action = bpy.data.actions.get('MX_Idle')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, a[1]))
