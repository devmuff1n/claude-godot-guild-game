# Hollow of Neris's fists in a Mixamo frame, stored in hand-bone rest space (armature coords at rest) -> _work/fist.json
import bpy, sys, os, json
from mathutils import Vector as V
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
rig = bpy.data.objects['Neris_Rig']; body = bpy.data.objects['Neris']; M = 'mixamorig:'
out = {}
for side, clip, fr in (('Right', a[1], int(a[2])), ('Left', a[1], int(a[2]))):
    rig.animation_data.action = bpy.data.actions[clip]
    bpy.context.scene.frame_set(fr)
    dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
    gi = {g.index: g.name for g in body.vertex_groups}
    pts = []; tips = []
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if any(f in gi[g.group] for f in (side+'HandIndex', side+'HandMiddle', side+'HandRing', side+'HandPinky')))
        if w > 0.6: pts.append(me.vertices[v.index].co.copy())
    pb = rig.pose.bones[M+side+'Hand']
    D = pb.matrix @ pb.bone.matrix_local.inverted()   # posed <- rest
    Di = D.inverted()
    c = sum(pts, V())/len(pts)
    pl = [Di @ p for p in pts]
    out[side] = dict(center=list(Di @ c), n=len(pts), mn=[min(p[i] for p in pl) for i in range(3)], mx=[max(p[i] for p in pl) for i in range(3)])
    ev.to_mesh_clear()
B = {b.name: b for b in rig.data.bones}
for side in ('Left', 'Right'):
    out[side]['hand'] = list(B[M+side+'Hand'].head_local); out[side]['mid1'] = list(B[M+side+'HandMiddle1'].head_local)
    out[side]['idx1'] = list(B[M+side+'HandIndex1'].head_local); out[side]['pnk1'] = list(B[M+side+'HandPinky1'].head_local)
    out[side]['fore'] = list(B[M+side+'ForeArm'].head_local)
print('FIST', json.dumps(out))
json.dump(out, open(os.path.join(W, 'fist.json'), 'w'), indent=1)
