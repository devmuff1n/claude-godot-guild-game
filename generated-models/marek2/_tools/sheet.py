# Contact sheet: blender -b --python sheet.py -- <blend> <clip> [n_frames|f:a,b,c] [views] [zoom:hand]
import bpy, sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
blend, name = a[0], a[1]
FR = [int(x) for x in a[2][2:].split(',')] if len(a) > 2 and a[2].startswith('f:') else None
n = len(FR) if FR else (int(a[2]) if len(a) > 2 else 8)
views = a[3].split(',') if len(a) > 3 else ['q', 'side']
ZB = a[4] if len(a) > 4 else None   # zoom on a bone, e.g. RightHand
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, blend))
rig = bpy.data.objects['Marek_Rig']; act = bpy.data.actions[name]; rig.animation_data.action = act
try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
except Exception: pass
Lf = int(act.frame_range[1])
setup_render((300, 400), 'BLENDER_EEVEE')
D = {'q': (0.6, -0.75, 0.25), 'side': (1, 0, 0.05), 'front': (0, -1, 0.05), 'back': (-0.5, 0.8, 0.3), 'lside': (-1, 0, 0.05), 'top': (0.2, -0.3, 1)}
os.makedirs(os.path.join(W, 'sheet'), exist_ok=True)
files = []
for v in views:
    for i in range(n):
        f = FR[i] if FR else (round(i*Lf/(n-1)) if n > 1 else 0)
        bpy.context.scene.frame_set(f)
        hip = rig.matrix_world @ rig.pose.bones['mixamorig:Hips'].head
        p = os.path.join(W, 'sheet', f'{name}_{v}_{i:02d}.png'); files.append(p)
        if ZB:
            zc = rig.matrix_world @ rig.pose.bones['mixamorig:'+ZB].head
            shoot(p, tuple(zc), float(os.environ.get('ZS', '0.45')), D[v])
        else:
            shoot(p, (hip.x, hip.y, 0.95), 2.4, D[v])
from PIL import Image
ims = [Image.open(p) for p in files]
g = Image.new('RGB', (300*n, 400*len(views)))
for k, im in enumerate(ims): g.paste(im, ((k % n)*300, (k//n)*400))
g.save(os.path.join(W, f'sheet_{name}.png'))
print('SHEET', name, Lf)
