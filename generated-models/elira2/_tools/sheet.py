# Contact sheet: blender -b --python sheet.py -- <clip> [n_frames] [view]
import bpy, sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
name = a[0]; FR = [int(x) for x in a[1][2:].split(',')] if len(a) > 1 and a[1].startswith('f:') else None; n = len(FR) if FR else (int(a[1]) if len(a) > 1 else 8); views = a[2].split(',') if len(a) > 2 else ['q', 'side']
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, 'elira2.blend'))
rig = bpy.data.objects['Elira_Rig']; rig.animation_data.action = bpy.data.actions[name]
try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
except Exception: pass
clips = json.load(open(os.path.join(W, 'clips.json'))); Lf = clips[name]['frames']
setup_render((300, 400), 'BLENDER_EEVEE')
D = {'q': (0.6, -0.75, 0.25), 'side': (1, 0, 0.05), 'front': (0, -1, 0.05), 'back': (-0.5, 0.8, 0.3), 'lside': (-1, 0, 0.05)}
os.makedirs(os.path.join(W, 'sheet'), exist_ok=True)
files = []
for v in views:
    for i in range(n):
        f = FR[i] if FR else (round(i*Lf/(n-1)) if n > 1 else 0)
        bpy.context.scene.frame_set(f)
        p = os.path.join(W, 'sheet', f'{name}_{v}_{i:02d}.png'); files.append(p)
        shoot(p, (0, -0.05, 0.95) if FR else (0, 0, 0.78), 1.3 if FR else 2.0, D[v])
from PIL import Image
ims = [Image.open(p) for p in files]
g = Image.new('RGB', (300*n, 400*len(views)))
for k, im in enumerate(ims): g.paste(im, ((k % n)*300, (k//n)*400))
g.save(os.path.join(W, f'sheet_{name}.png'))
