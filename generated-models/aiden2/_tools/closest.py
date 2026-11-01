# For each clip: frame where the staff (outside the grip) comes closest to the body; close-up of that spot from 4 views.
# blender -b --python closest.py -- <blend> <clips> <out_prefix>
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
rig = bpy.data.objects['Aiden_Rig']; body = bpy.data.objects['Aiden']; staff = bpy.data.objects['Aiden_Staff']; M = 'mixamorig:'
gi = {g.index: g.name for g in body.vertex_groups}
HAND = {i for i, n in gi.items() if n.startswith(M+'RightHand')}
skip = {v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in HAND) > 0.5}
POLYS = [list(p.vertices) for p in body.data.polygons if not any(i in skip for i in p.vertices)]
sc = bpy.context.scene; setup_render((360, 360), 'BLENDER_EEVEE')
rows = []
for clip in a[1].split(','):
    act = bpy.data.actions[clip]; rig.animation_data.action = act
    try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
    except Exception: pass
    f0, f1 = [int(round(x)) for x in act.frame_range]; best = (9, 0, None)
    for f in range(f0, f1+1):
        sc.frame_set(f); dg = bpy.context.evaluated_depsgraph_get()
        me = body.evaluated_get(dg).to_mesh(); bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], POLYS); body.evaluated_get(dg).to_mesh_clear()
        sm = staff.evaluated_get(dg).to_mesh(); grip = rig.matrix_world @ rig.pose.bones['Staff'].head
        for v in sm.vertices:
            p = staff.matrix_world @ v.co
            if (p-grip).length < 0.09: continue
            h = bvh.find_nearest(p, 0.3)
            if h[0] is not None and h[3] < best[0]: best = (h[3], f, p.copy())
        staff.evaluated_get(dg).to_mesh_clear()
    d, f, p = best
    print('CLOSE', clip, 'frame', f, 'dist_cm', round(d*100, 1), flush=True)
    row = Image.new('RGB', (360*4, 380), (30, 30, 34)); ImageDraw.Draw(row).text((6, 362), f'{clip} f{f} gap {d*100:.1f} cm', fill=(255, 255, 255))
    if p is not None:
        sc.frame_set(f)
        for i, dv in enumerate([(0.6, -0.75, 0.25), (0, -1, 0.05), (1, 0, 0.05), (-0.6, 0.75, 0.25)]):
            fp = os.path.join(W, 'sheet', '_c.png'); shoot(fp, tuple(p), 0.5, dv); row.paste(Image.open(fp), (360*i, 0))
    rows.append(row)
for k in range(0, len(rows), 4):
    g = Image.new('RGB', (1440, 380*len(rows[k:k+4])))
    for j, r in enumerate(rows[k:k+4]): g.paste(r, (0, 380*j))
    g.save(os.path.join(W, f'{a[2]}_{k//4}.png'))
