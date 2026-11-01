# Game GLB: Neris mesh + staff + only the Mixamo clips (MX_*). MX_Death keeps 40% of its horizontal fall so
# the body stays inside the battle frame. blender -b --python game_export.py -- <in_blend> <out_glb>
import bpy, sys, os
from mathutils import Vector as V
argv = sys.argv[sys.argv.index('--')+1:]
src, out = argv
bpy.ops.wm.open_mainfile(filepath=src)
rig = bpy.data.objects['Neris_Rig']
HIPS = 'mixamorig:Hips'
R0 = rig.data.bones[HIPS].matrix_local.to_3x3()


def curves(act):
    try:
        return list(act.fcurves)
    except AttributeError:   # layered actions (Blender 4.4+)
        res = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags: res.extend(cb.fcurves)
        return res


def damp_travel(name, keep):
    act = bpy.data.actions[name]
    loc = sorted([c for c in curves(act) if c.data_path == f'pose.bones["{HIPS}"].location'], key=lambda c: c.array_index)
    n = len(loc[0].keyframe_points)
    for i in range(n):
        lv = V([c.keyframe_points[i].co[1] for c in loc])
        w = R0 @ lv
        w.x *= keep; w.y *= keep
        lv = R0.inverted() @ w
        for c, v in zip(loc, lv): c.keyframe_points[i].co[1] = v; c.keyframe_points[i].handle_left[1] = v; c.keyframe_points[i].handle_right[1] = v
    for c in loc: c.update()


for _d in [x.name for x in bpy.data.actions if x.name.startswith('MX_Death')]: damp_travel(_d, 0.4)
import json
FJ = os.path.join(os.path.dirname(__file__), '..', '_work', 'staff_fit.json')
BAD = {k for k, v in json.load(open(FJ)).items() if v['unresolved']} if os.path.exists(FJ) else set()
print('SKIP (staff cannot clear the body)', sorted(BAD))
for a in list(bpy.data.actions):
    if not a.name.startswith('MX_') or a.name in BAD:
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
print('GAME', os.path.getsize(out), len([a for a in bpy.data.actions]))
