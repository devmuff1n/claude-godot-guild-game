import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from mathutils import Matrix
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
for o in list(bpy.data.objects):
    if o.name=='Icosphere': bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
P=arm.pose.bones
def rot(n, ax, deg):
    pb=P['mixamorig:'+n]; pb.rotation_mode='QUATERNION'
    Mr=pb.bone.matrix_local.to_3x3()
    pb.rotation_quaternion=(Mr.inverted()@Matrix.Rotation(math.radians(deg),3,ax)@Mr).to_quaternion() @ pb.rotation_quaternion
rot('LeftArm','Y',-60); rot('RightArm','Y',60)
rot('LeftForeArm','Z',50)
rot('LeftUpLeg','X',-45); rot('LeftLeg','X',60)
rot('Spine1','Z',25); rot('Head','X',20)
setup_render((640,900),'BLENDER_EEVEE')
for n,d in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0))]:
    shoot(os.path.join(W,f'pose_{n}.png'),(0,0,0.5),1.15,d)
