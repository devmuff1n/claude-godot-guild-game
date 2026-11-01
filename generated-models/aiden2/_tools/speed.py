import bpy, os
W = os.path.join(os.path.dirname(__file__), '..', '_work', 'mixamo', 'Pro Magic Pack')
HIP = 0.807   # Aiden hip height
for fn in ('Standing Walk Forward', 'Standing Run Forward'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(W, fn+'.fbx'))
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; act = arm.animation_data.action
    f0, f1 = [int(x) for x in act.frame_range]; h = arm.pose.bones['mixamorig:Hips']
    bpy.context.scene.frame_set(f0); a = arm.matrix_world @ h.head; z0 = arm.matrix_world @ h.bone.head_local
    bpy.context.scene.frame_set(f1); b = arm.matrix_world @ h.head
    print('SPD', fn, 'm/s neris', round((b-a).length*HIP/z0.z/((f1-f0)/30), 2))
