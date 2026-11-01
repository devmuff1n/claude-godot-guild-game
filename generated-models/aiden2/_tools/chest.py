import bpy, sys
from mathutils import Vector as V
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath='../_work/'+a[0])
rig=bpy.data.objects[a[2]]
rig.animation_data.action=bpy.data.actions[a[1]]
try: rig.animation_data.action_slot=rig.animation_data.action_suitable_slots[0]
except Exception: pass
bpy.context.scene.frame_set(0)
for n in ('Hips','Spine2','Head'):
    pb=rig.pose.bones['mixamorig:'+n]; R=pb.matrix.to_3x3()@pb.bone.matrix_local.to_3x3().inverted()
    print('CH',n,[round(x,2) for x in R@V((0,-1,0))])
