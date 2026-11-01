import bpy, os
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
arm=bpy.data.objects['Elira_Rig']
for b in arm.data.bones:
    n=b.name.replace('mixamorig:','')
    if n.startswith('LeftHand') or n in('LeftForeArm',):
        print(n,[round(x,4) for x in b.head_local],[round(x,4) for x in b.tail_local],[round(x,3) for x in b.z_axis], [round(x,3) for x in b.x_axis])
print('BONES',len(arm.data.bones))
