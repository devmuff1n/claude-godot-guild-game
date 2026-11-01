# One row per clip, 6 frames, q view: blender -b --python-use-system-env --python overview.py -- <blend> <out_prefix> [clips]
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from PIL import Image, ImageDraw
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
rig = bpy.data.objects['Aiden_Rig']
names = a[2].split(',') if len(a) > 2 else sorted(x.name for x in bpy.data.actions if x.name.startswith('MX_'))
setup_render((200, 260), 'BLENDER_EEVEE')
N = 8; rows = []
for nm in names:
    act = bpy.data.actions[nm]; rig.animation_data.action = act
    try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
    except Exception: pass
    L = int(act.frame_range[1]); row = Image.new('RGB', (200*N+120, 260), (40, 40, 44))
    d = ImageDraw.Draw(row); d.text((6, 90), f'{nm}\n{L+1} fr', fill=(255, 255, 255))
    for i in range(N):
        bpy.context.scene.frame_set(round(i*L/(N-1)))
        p = os.path.join(W, 'sheet', '_ov.png')
        hip = rig.matrix_world @ rig.pose.bones['mixamorig:Hips'].head; shoot(p, (hip.x, hip.y, 0.85), 2.0, (0.55, -0.8, 0.2))
        row.paste(Image.open(p), (120+200*i, 0))
    rows.append(row)
os.makedirs(os.path.join(W, 'sheet'), exist_ok=True)
for k in range(0, len(rows), 5):
    g = Image.new('RGB', (rows[0].width, 260*len(rows[k:k+5])))
    for j, r in enumerate(rows[k:k+5]): g.paste(r, (0, 260*j))
    g.save(os.path.join(W, f'{a[1]}_{k//5}.png'))
print('OV', len(rows))
