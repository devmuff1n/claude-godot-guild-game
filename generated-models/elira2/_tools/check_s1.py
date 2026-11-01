import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
from mathutils import Matrix
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
arm=bpy.data.objects['Elira_Rig']; P=arm.pose.bones
print('MW', arm.matrix_world)
for pb in P: pb.rotation_mode='QUATERNION'
def rot(n, ax, deg):
    pb=P['mixamorig:'+n]; Mr=pb.bone.matrix_local.to_3x3()
    pb.rotation_quaternion=(Mr.inverted()@Matrix.Rotation(math.radians(deg),3,ax)@Mr).to_quaternion()
rot('LeftArm','Y',65); rot('RightArm','Y',-65); rot('LeftUpLeg','X',-50)
setup_render((500,700),'BLENDER_EEVEE')
for n,d in [('front',(0,-1,0)),('side',(1,0,0))]:
    shoot(os.path.join(W,f's1_{n}.png'),(0,0,0.75),1.7,d)
