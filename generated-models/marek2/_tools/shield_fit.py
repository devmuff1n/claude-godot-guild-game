# Measures how deep the shield sinks into Marek's body over the game clips and searches shield placement
# (out from the back of the hand, slide along the fingers / knuckles, yaw/pitch, scale) for the least penetration.
# blender -b --python shield_fit.py -- <blend> [eval-only]
# Writes the best values into _work/props_tune.json (eval-only: just prints the current placement's numbers).
import bpy, sys, os, json, math, itertools, time
from mathutils import Vector as V, Matrix
from mathutils.bvhtree import BVHTree
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
EVAL_ONLY = len(argv) > 1
rig = bpy.data.objects['Marek_Rig']; body = bpy.data.objects['Marek']; M = 'mixamorig:'
F = json.load(open(os.path.join(W, 'fist.json')))
TP = os.path.join(W, 'props_tune.json')
P0 = json.load(open(TP)) if os.path.exists(TP) else {}
CLIPS = ['MX_Idle4', 'MX_Walk', 'MX_Run', 'MX_BlockIdle', 'MX_Block', 'MX_Slash', 'MX_Slash3', 'MX_Casting2',
         'MX_Casting', 'MX_PowerUp', 'MX_Impact2', 'MX_Impact', 'MX_StepBackward', 'MX_Death', 'MX_Victory', 'MX_Slash2']
STEP = 3
if os.environ.get('FIT_CLIPS'): CLIPS = os.environ['FIT_CLIPS'].split(',')
# hand frame at rest (same as s3_props)
f = F['Left']; hand = V(f['hand']); d = (V(f['mid1'])-hand).normalized()
k = V(f['idx1'])-V(f['pnk1']); k = (k-d*k.dot(d)).normalized()
palm = d.cross(k).normalized(); back = -palm; fc = V(f['center'])


def half_w(y):
    t = max(0.0, min(1.0, (0.1-y)/1.1))
    return 1.0 if y > 0.1 else 1-t**2.2


# sample points of the shield in its local frame (normalised x,y in [-1,1]; z front/back)
LOC = []
for i in range(-10, 11):
    for j in range(-10, 11):
        x, y = i/10, j/10
        if abs(x) <= half_w(y)+1e-6:
            for z in (0.006, -0.022):
                LOC.append((x, y, z))
for t in range(80):   # dense outline
    y = 1-2*t/79
    for s in (-1, 1):
        LOC.append((s*half_w(y), y, 0.0))


def frame_of(p):
    Z = back.copy(); Y = (k-Z*k.dot(Z)).normalized()
    Y = (Matrix.Rotation(math.radians(p.get('shield_roll', 0)), 3, Z) @ Y).normalized()
    X = Y.cross(Z)
    R = Matrix.Rotation(math.radians(p.get('shield_yaw', 0)), 3, Y) @ Matrix.Rotation(math.radians(p.get('shield_pitch', 0)), 3, X)
    X, Y, Z = R @ X, R @ Y, R @ Z
    o = fc+back*p.get('shield_out', 0.075)-d*p.get('shield_back', 0.03)+k*p.get('shield_k', 0.0)
    return o, X, Y, Z


def samples(p):
    o, X, Y, Z = frame_of(p)
    sw, sh = p.get('shield_w', 0.25), p.get('shield_h', 0.31)
    return [o+X*(x*sw)+Y*(y*sh)+Z*(z-0.035*x*x) for x, y, z in LOC]


# body part of every face (the gripping hand and forearm are allowed to touch the shield)
_gi = {g.index: g.name.replace('mixamorig:', '') for g in body.vertex_groups}
def _part(poly):
    acc = {}
    for vi in poly.vertices:
        for g in body.data.vertices[vi].groups: acc[_gi[g.group]] = acc.get(_gi[g.group], 0)+g.weight
    return max(acc, key=acc.get) if acc else ''
SKIP = [_part(p).startswith('LeftHand') for p in body.data.polygons]   # only the gripping hand
# cache per frame: body BVH (evaluated) and the hand deform matrix
cache = []
hb = rig.pose.bones[M+'LeftHand']
for c in CLIPS:
    act = bpy.data.actions[c]; rig.animation_data.action = act
    L = int(act.frame_range[1])
    for fr in list(range(0, L+1, STEP)):
        bpy.context.scene.frame_set(fr)
        dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
        bvh = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        ev.to_mesh_clear()
        D = hb.matrix @ hb.bone.matrix_local.inverted()
        cache.append((c, fr, bvh, D.copy()))
print('CACHE', len(cache), flush=True)


def penetration(p, detail=False):
    pts = samples(p); tot = 0.0; per = {}
    for c, fr, bvh, D in cache:
        worst = 0.0
        for q in pts:
            w = D @ q
            loc, nrm, idx, dist = bvh.find_nearest(w, 0.1)
            if loc is not None and not SKIP[idx] and (w-loc).dot(nrm) < 0:
                worst = max(worst, dist)
        tot += worst
        if detail: per[c] = max(per.get(c, 0.0), worst)
    return tot/len(cache), per


cur = {k_: P0.get(k_, v) for k_, v in dict(shield_out=0.075, shield_back=0.03, shield_k=0.0, shield_yaw=0.0, shield_pitch=0.0, shield_roll=0.0, shield_w=0.25, shield_h=0.31).items()}
m, per = penetration(cur, True)
print('CURRENT', json.dumps(cur), 'mean_worst', round(m, 4), {a: round(b, 3) for a, b in per.items()}, flush=True)
if EVAL_ONLY: sys.exit(0)
best = None; t0 = time.time()
grid = itertools.product([0.085, 0.1, 0.115, 0.13], [-0.06, -0.03, 0.0, 0.03, 0.06], [-0.08, -0.04, 0.0, 0.04], [-20, -10, 0, 10, 20], [-15, 0, 15], [0.21, 0.23, 0.25])
_unused = ([0.075, 0.095, 0.115, 0.135], [-0.08, -0.04, 0.0, 0.04], [-0.1, -0.05, 0.0, 0.05], [-20, -10, 0, 10, 20], [-15, 0, 15], [0.20, 0.23])
for out, bk, kk, yaw, pitch, w in grid:
    p = dict(cur, shield_out=out, shield_back=bk, shield_k=kk, shield_yaw=yaw, shield_pitch=pitch, shield_w=w, shield_h=w*1.24)
    o, X, Y, Z = frame_of(p)
    if (fc-o).dot(Z) > -0.06: continue   # the fist must stay behind the board
    pen, _ = penetration(p)
    score = pen*20+(out-0.075)*0.6+(0.25-w)*0.4+(abs(bk)+abs(kk))*0.25   # clearance first, then keep the shield close and big
    if best is None or score < best[0]: best = (score, pen, p); print('BEST', round(score, 4), round(pen, 4), json.dumps(p), round(time.time()-t0), flush=True)
m, per = penetration(best[2], True)
print('FINAL', json.dumps(best[2]), 'mean_worst', round(m, 4), {a: round(b, 3) for a, b in per.items()})
P0.update(best[2]); json.dump(P0, open(TP, 'w'), indent=1)
