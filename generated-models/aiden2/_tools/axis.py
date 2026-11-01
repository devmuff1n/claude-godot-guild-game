import bpy, sys
from mathutils import Vector as V
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath='../_work/'+a[0])
rig=bpy.data.objects['Aiden_Rig']; M='mixamorig:'
for clip in a[1].split(','):
    rig.animation_data.action=bpy.data.actions[clip]
    try: rig.animation_data.action_slot=rig.animation_data.action_suitable_slots[0]
    except Exception: pass
    for f in [int(x) for x in a[2].split(',')]:
        bpy.context.scene.frame_set(f)
        P=rig.pose.bones
        def w(n): return rig.matrix_world@P[n].head
        s=P['Staff']; ax=(rig.matrix_world.to_3x3()@s.matrix.to_3x3()@V((0,1,0))).normalized()
        k=(w(M+'RightHandIndex1')-w(M+'RightHandPinky1')).normalized(); d=(w(M+'RightHandMiddle1')-w(M+'RightHand')).normalized()
        print('AX',clip,f,'staff',[round(x,2) for x in ax],'k',[round(x,2) for x in k],'d',[round(x,2) for x in d],'hand',[round(x,2) for x in w(M+'RightHand')])
