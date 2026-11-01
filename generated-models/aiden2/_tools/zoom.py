# Close-ups: blender -b --python zoom.py -- <blend> <clip> <frame> <out> <bone|xyz> <size> [views]
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from PIL import Image
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
rig = bpy.data.objects['Aiden_Rig']; rig.animation_data.action = bpy.data.actions[a[1]]
try: rig.animation_data.action_slot = rig.animation_data.action_suitable_slots[0]
except Exception: pass
bpy.context.scene.frame_set(int(a[2]))
if ',' in a[4]: c = tuple(float(x) for x in a[4].split(','))
else:
    pb = rig.pose.bones[a[4] if a[4] in rig.pose.bones else 'mixamorig:'+a[4]]; c = tuple(rig.matrix_world @ pb.head)
size = float(a[5]); views = a[6].split(',') if len(a) > 6 else ['q', 'front', 'side', 'back']
D = {'q': (0.6, -0.75, 0.25), 'side': (1, 0, 0.05), 'front': (0, -1, 0.05), 'back': (0, 1, 0.1), 'lside': (-1, 0, 0.05), 'top': (0.2, -0.3, 1), 'bq': (-0.6, 0.75, 0.25), 'down': (0.001, -0.01, 1), 'up': (0.001, -0.01, -1), 'fl': (0.5, -1, 0.3)}
setup_render((400, 400), 'BLENDER_EEVEE')
g = Image.new('RGB', (400*len(views), 400))
for i, v in enumerate(views):
    p = os.path.join(W, 'sheet', '_z.png'); shoot(p, c, size, D[v]); g.paste(Image.open(p), (400*i, 0))
g.save(os.path.join(W, a[3]))
