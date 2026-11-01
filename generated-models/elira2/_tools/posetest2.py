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
for pb in P: pb.rotation_mode='QUATERNION'
def reset():
    for pb in P: pb.rotation_quaternion=(1,0,0,0)
def rot(n, ax, deg):
    pb=P['mixamorig:'+n]
    Mr=pb.bone.matrix_local.to_3x3()
    pb.rotation_quaternion=(Mr.inverted()@Matrix.Rotation(math.radians(deg),3,ax)@Mr).to_quaternion()
setup_render((500,700),'BLENDER_EEVEE')
tests={'leg':[('LeftUpLeg','X',60),('RightLeg','X',-70)],
       'arms':[('LeftArm','Y',65),('RightArm','Y',-65),('LeftForeArm','Z',60)],
       'head':[('Neck','Z',20),('Head','Z',25),('Spine1','X',20)]}
for k,L in tests.items():
    reset()
    for t in L: rot(*t)
    bpy.context.view_layer.update()
    for n,d in [('front',(0,-1,0)),('side',(1,0,0))]:
        shoot(os.path.join(W,f't_{k}_{n}.png'),(0,0,0.5),1.15,d)
