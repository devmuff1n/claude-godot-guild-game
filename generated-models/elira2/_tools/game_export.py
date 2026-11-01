# Game GLB: Elira mesh + bow/string/arrow + only the Mixamo clips (MX_*), plus MX_Shot = draw arrow + aim recoil
# glued into one attack. blender -b --python game_export.py -- <in_blend> <out_glb>
import bpy, sys, os
argv = sys.argv[sys.argv.index('--')+1:]
src, out = argv
bpy.ops.wm.open_mainfile(filepath=src)
rig = bpy.data.objects['Elira_Rig']
# glue: copy every fcurve of DrawArrow, then AimRecoil shifted to start right after it
A = bpy.data.actions['MX_DrawArrow']; B = bpy.data.actions['MX_AimRecoil']
lenA = int(round(A.frame_range[1]))
shot = A.copy(); shot.name = 'MX_Shot'; shot.use_fake_user = True
def curves(act):
    try:
        return list(act.fcurves)
    except AttributeError:   # layered actions (Blender 4.4+)
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags: out.extend(cb.fcurves)
        return out
byk = {(c.data_path, c.array_index): c for c in curves(shot)}
for c in curves(B):
    t = byk.get((c.data_path, c.array_index))
    if t is None: continue
    for kp in c.keyframe_points:
        if kp.co[0] < 1: continue   # frame 0 of the recoil repeats the last draw frame
        t.keyframe_points.insert(kp.co[0]+lenA, kp.co[1], options={'FAST'})
    t.update()
for a in list(bpy.data.actions):
    if not a.name.startswith('MX_'):
        bpy.data.actions.remove(a)
rig.animation_data.action = bpy.data.actions['MX_Idle']
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type in ('MESH', 'ARMATURE'): o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=False,
    export_skins=True, export_all_influences=False, export_def_bones=False, export_rest_position_armature=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_range=False,
    export_anim_single_armature=True, export_reset_pose_bones=True, export_optimize_animation_size=True,
    export_image_format='JPEG', export_jpeg_quality=88, export_materials='EXPORT', export_tangents=False, export_yup=True)
print('GAME', os.path.getsize(out), sorted(a.name for a in bpy.data.actions), 'shot frames', shot.frame_range[:])
