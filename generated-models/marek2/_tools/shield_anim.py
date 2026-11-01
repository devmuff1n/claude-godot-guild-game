# Per-frame shield correction: where the shield still sinks into the body, turn it about the fist (Shield bone,
# up to +-30 deg) and slide it out a few cm; smoothed over time and keyed on the Shield bone of each clip.
# blender -b --python shield_anim.py -- <in_blend> <out_blend> [clips]
import bpy, sys, os, json, math, time
from mathutils import Vector as V, Matrix, Quaternion
from mathutils.bvhtree import BVHTree
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
rig = bpy.data.objects['Marek_Rig']; body = bpy.data.objects['Marek']; shield = bpy.data.objects['Marek_Shield']
M = 'mixamorig:'
CLIPS = argv[2].split(',') if len(argv) > 2 else [a.name for a in bpy.data.actions if a.name.startswith('MX_')]
F = json.load(open(os.path.join(W, 'fist.json'))); fc = V(F['Left']['center'])
sb = rig.data.bones['Shield']; Brest = sb.matrix_local.copy()
Xs, Ys, Zs = [Brest.to_3x3().col[i].normalized() for i in range(3)]   # bone axes: Y = shield up, Z ~ out? use mesh frame below
# shield frame from the bone: s3_props aligned the bone's Y with the shield's up and its roll with the face normal
up = Ys; out = (Brest.to_3x3().col[2]).normalized(); side = up.cross(out)
# sample points: shield mesh vertices (rest) plus face centres
pts = [v.co.copy() for v in shield.data.vertices]
pts += [p.center.copy() for p in shield.data.polygons]
gi = {g.index: g.name.replace('mixamorig:', '') for g in body.vertex_groups}
def _part(poly):
    acc = {}
    for vi in poly.vertices:
        for g in body.data.vertices[vi].groups: acc[gi[g.group]] = acc.get(gi[g.group], 0)+g.weight
    return max(acc, key=acc.get) if acc else ''
SKIP = [_part(p).startswith('LeftHand') for p in body.data.polygons]
ANG = [-30, -15, 0, 15, 30]; SLIDE = [0.0, 0.03, 0.06]
CANDS = []
for a in ANG:
    for b in ANG:
        for s in SLIDE:
            R = (Matrix.Rotation(math.radians(a), 4, side) @ Matrix.Rotation(math.radians(b), 4, up))
            Mc = Matrix.Translation(fc+out*s) @ R @ Matrix.Translation(-fc)
            CANDS.append(((a, b, s), Mc, [Mc @ q for q in pts]))
hb = rig.pose.bones[M+'LeftHand']; sp = rig.pose.bones['Shield']
sp.rotation_mode = 'QUATERNION'
t0 = time.time(); report = {}


def pen_of(qs, D, bvh):
    worst = 0.0
    for q in qs:
        w = D @ q
        loc, nrm, idx, dist = bvh.find_nearest(w, 0.1)
        if loc is not None and not SKIP[idx] and (w-loc).dot(nrm) < 0 and dist > worst: worst = dist
    return worst


for c in CLIPS:
    act = bpy.data.actions[c]; rig.animation_data.action = act
    sp.rotation_quaternion = (1, 0, 0, 0); sp.location = (0, 0, 0)
    L = int(act.frame_range[1]); frames = list(range(0, L+1, 2))
    if frames[-1] != L: frames.append(L)
    chosen = []; before = []; after = []; frc = []
    for fr in frames:
        bpy.context.scene.frame_set(fr)
        dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
        bvh = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        ev.to_mesh_clear()
        D = hb.matrix @ hb.bone.matrix_local.inverted()
        frc.append((bvh, D.copy()))
        p0 = pen_of(pts, D, bvh); before.append(p0)
        if p0 < 0.004:
            chosen.append(((0.0, 0.0, 0.0), p0)); continue
        best = None
        for prm, Mc, qs in CANDS:
            pe = pen_of(qs, D, bvh)
            cost = pe*40+(abs(prm[0])+abs(prm[1]))/100+prm[2]*3
            if best is None or cost < best[0]: best = (cost, prm, pe)
        chosen.append((best[1], best[2]))
    # smooth the correction over time (gaussian over neighbours), angles and slide separately
    def corr(prm):
        a, b, s_ = prm
        R = Matrix.Rotation(math.radians(a), 4, side) @ Matrix.Rotation(math.radians(b), 4, up)
        return Matrix.Translation(fc+out*s_) @ R @ Matrix.Translation(-fc)
    raw = [c_[0] for c_ in chosen]
    sm = list(raw)
    for _ in range(2):   # smooth, then keep a frame's own best where smoothing would make it clip
        nxt = []
        for i in range(len(sm)):
            acc = [0.0, 0.0, 0.0]; ws = 0.0
            for j in range(max(0, i-3), min(len(sm), i+4)):
                w = math.exp(-((i-j)/1.6)**2); ws += w
                for t in range(3): acc[t] += sm[j][t]*w
            cand = tuple(acc[t]/ws for t in range(3))
            bvh_, D_ = frc[i]
            Mc = corr(cand)
            if pen_of([Mc @ q for q in pts], D_, bvh_) > chosen[i][1]+0.006: cand = raw[i]
            nxt.append(cand)
        sm = nxt
    fcs = [f for f in getattr(act, 'fcurves', [])] if hasattr(act, 'fcurves') else []
    for fr, (a, b, s) in zip(frames, sm):
        R = Matrix.Rotation(math.radians(a), 4, side) @ Matrix.Rotation(math.radians(b), 4, up)
        Mc = Matrix.Translation(fc+out*s) @ R @ Matrix.Translation(-fc)
        basis = Brest.inverted() @ Mc @ Brest
        loc, rot, _ = basis.decompose()
        sp.location = loc; sp.rotation_quaternion = rot
        sp.keyframe_insert('location', frame=fr); sp.keyframe_insert('rotation_quaternion', frame=fr)
    # measure the result on the same frames
    for fr in frames:
        bpy.context.scene.frame_set(fr)
        dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
        bvh = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        ev.to_mesh_clear()
        D = hb.matrix @ hb.bone.matrix_local.inverted()
        Sm = sp.matrix @ sp.bone.matrix_local.inverted()   # shield deform (includes the correction)
        after.append(pen_of([D.inverted() @ Sm @ q for q in pts], D, bvh))
    report[c] = dict(before=round(max(before)*100, 1), after=round(max(after)*100, 1),
                     frames_over_2cm_before=sum(1 for x in before if x > 0.02), frames_over_2cm_after=sum(1 for x in after if x > 0.02), n=len(frames))
    print('SA', c, report[c], round(time.time()-t0), flush=True)
json.dump(report, open(os.path.join(W, 'shield_anim_report.json'), 'w'), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, argv[1]))
