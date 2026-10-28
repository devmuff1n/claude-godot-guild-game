import bpy,sys
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
rig=bpy.data.objects["Elira_Rig"]; rig.animation_data.action=bpy.data.actions["Bow_Aim"]; bpy.context.scene.frame_set(0)
for b in ["Hips","Spine","Spine1","Spine2","LeftShoulder","LeftArm","LeftForeArm","LeftHand","RightForeArm","RightHand","Head"]:
    p=rig.pose.bones["mixamorig:"+b].head
    print("BL",b,(round(p.x,3),round(p.z,3),round(-p.y,3)))
