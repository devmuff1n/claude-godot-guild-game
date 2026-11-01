# Render 4 views of a blend (rest or clip frame): blender -b --python look.py -- <blend> <out> [clip frame]
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from PIL import Image
W=os.path.join(os.path.dirname(__file__),'..','_work')
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,a[0]))
if len(a)>3:
    rig=bpy.data.objects['Aiden_Rig']; rig.animation_data.action=bpy.data.actions[a[2]]
    try: rig.animation_data.action_slot=rig.animation_data.action_suitable_slots[0]
    except Exception: pass
    bpy.context.scene.frame_set(int(a[3]))
setup_render((500,700),'BLENDER_EEVEE')
g=Image.new('RGB',(2000,700))
for i,(n,d) in enumerate([('front',(0,-1,0.05)),('side',(1,0,0.05)),('back',(0,1,0.05)),('q',(0.7,-0.7,0.25))]):
    p=os.path.join(W,'_look.png'); shoot(p,(0,0,0.88),2.0,d); g.paste(Image.open(p),(500*i,0))
g.save(os.path.join(W,a[1]))
