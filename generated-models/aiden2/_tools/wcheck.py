# Weight check: renders a posed Aiden (arms down/forward, legs apart, spine twisted) to spot pieces following the wrong limb.
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from mathutils import Matrix
W=os.path.join(os.path.dirname(__file__),'..','_work')
f=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 's1.blend'
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,f))
arm=bpy.data.objects['Aiden_Rig']; P=arm.pose.bones
for pb in P: pb.rotation_mode='QUATERNION'
def rot(n, ax, deg):
    pb=P['mixamorig:'+n]; Mr=pb.bone.matrix_local.to_3x3()
    pb.rotation_quaternion=(Mr.inverted()@Matrix.Rotation(math.radians(deg),3,ax)@Mr).to_quaternion()
rot('LeftArm','Y',70); rot('RightArm','Y',-70); rot('LeftUpLeg','X',-55); rot('RightUpLeg','X',35); rot('LeftLeg','X',60)
rot('LeftForeArm','Z',60); rot('RightForeArm','X',-70); rot('Spine1','Z',20); rot('Head','Z',35); rot('Neck','X',15); rot('LeftArm','X',-60)
setup_render((500,800),'BLENDER_EEVEE')
for n,d in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0)),('lside',(-1,0,0))]:
    shoot(os.path.join(W,f'wc_{n}.png'),(0,0,0.9),2.0,d)
from PIL import Image
g=Image.new('RGB',(2000,800))
for i,n in enumerate(('front','side','back','lside')): g.paste(Image.open(os.path.join(W,f'wc_{n}.png')),(500*i,0))
g.save(os.path.join(W,'wc_all.png'))
