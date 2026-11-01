# Finds the hollow of Elira's curled fists at rest (hand bones not moved), writes _work/fist.json
import bpy, sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
import animlib as L
from mathutils import Vector as V
W = os.path.join(os.path.dirname(__file__), '..', '_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, sys.argv[sys.argv.index('--')+1]))
rig = bpy.data.objects['Elira_Rig']; body = bpy.data.objects['Elira']
L.init(rig, os.path.join(W, 'bow_meta.json')) if os.path.exists(os.path.join(W, 'bow_meta.json')) else None
if L.pose is None:
    L.rig = rig; L.pose = rig.pose.bones
    for pb in L.pose: pb.rotation_mode = 'QUATERNION'
    L.REST = {pb.name: pb.bone.matrix_local.to_3x3() for pb in L.pose}
out = {}
for side in ('Left', 'Right'):
    P = {}; L.fingers(P, side, L.GRIP, thumb=1.0); L.apply_pose(P); L.upd()
    dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
    gi = {g.index: g.name for g in body.vertex_groups}
    pts = []
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if any(f in gi[g.group] for f in (side+'HandIndex', side+'HandMiddle', side+'HandRing', side+'HandPinky')))
        if w > 0.6: pts.append(me.vertices[v.index].co.copy())
    c = sum(pts, V())/len(pts)
    mn = V([min(p[i] for p in pts) for i in range(3)]); mx = V([max(p[i] for p in pts) for i in range(3)])
    out[side] = dict(center=list(c), min=list(mn), max=list(mx), n=len(pts))
    ev.to_mesh_clear()
print('FIST', json.dumps(out))
json.dump(out, open(os.path.join(W, 'fist.json'), 'w'), indent=1)
