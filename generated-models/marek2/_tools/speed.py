import bpy, os
W = os.path.join(os.path.dirname(__file__), '..', '_work', 'mixamo', 'Pro Sword and Shield Pack')
for fn in ('sword and shield walk', 'sword and shield walk (2)', 'sword and shield run', 'sword and shield run (2)'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(W, fn+'.fbx'))
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; act = arm.animation_data.action
    f0, f1 = [int(x) for x in act.frame_range]; h = arm.pose.bones['mixamorig:Hips']
    bpy.context.scene.frame_set(f0); a = arm.matrix_world @ h.head; z0 = arm.matrix_world @ h.bone.head_local
    bpy.context.scene.frame_set(f1); b = arm.matrix_world @ h.head
    ratio = 0.92/z0.z
    print('SPD', fn, [round(x, 2) for x in (b-a)], 'm/s marek', round((b-a).length*ratio/((f1-f0)/30), 2))
