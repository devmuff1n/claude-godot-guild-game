import bpy, os, sys
W = os.path.join(os.path.dirname(__file__), '..', '_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, 'neris2.blend'))
rig = bpy.data.objects['Neris_Rig']; h = rig.pose.bones['mixamorig:Hips']
for a in sorted(bpy.data.actions, key=lambda a: a.name):
    rig.animation_data.action = a
    L = int(a.frame_range[1]); pts = []
    for f in range(0, L+1, 2):
        bpy.context.scene.frame_set(f); pts.append(h.head.copy())
    mx = max(((p-pts[0]).xy.length for p in pts))
    print('TR', a.name, L+1, 'end', [round(x, 2) for x in (pts[-1]-pts[0])], 'max', round(mx, 2))
