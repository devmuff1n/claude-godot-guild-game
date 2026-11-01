import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
import animlib as L, poses
from mathutils import Vector as V
W = os.path.join(os.path.dirname(__file__), '..', '_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, 's2.blend'))
L.init(bpy.data.objects['Elira_Rig'], os.path.join(W, 'bow_meta.json'))
setup_render((560, 760), 'BLENDER_EEVEE')
which = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'full'
if which == 'rest':
    P = {}; L.fingers(P, 'Left', L.GRIP, thumb=1.0); L.apply_pose(P); L.upd()
    for n, d in [('front', (0, -1, 0)), ('side', (1, 0, 0)), ('q', (0.6, -0.7, 0.3))]:
        shoot(os.path.join(W, f'tr_{n}.png'), (0.6, -0.05, 0.98), 0.35, d)
    for n, d in [('wide', (0.6, -0.7, 0.3))]:
        shoot(os.path.join(W, f'tr_{n}.png'), (0.3, 0, 0.8), 1.8, d)
else:
    base = dict(hips=-50, tw=-20, yaw=70, pitch=0, stance=6, knee=4)
    q, C, D = poses.solve_full(base, (0, -1, 0.04))
    poses.build(q)
    print('FULL D', D, 'C', C, 'WL', q['WL'], 'WR', q['WR'])
    for n, d in [('front', (0, -1, 0)), ('side', (1, 0, 0)), ('top', (0.05, 0, 1)), ('q', (0.7, -0.6, 0.3)), ('back', (-0.6, 0.7, 0.3))]:
        shoot(os.path.join(W, f'tf_{n}.png'), (0, -0.15, 0.8), 1.9, d)
