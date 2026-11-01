import bpy, sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
info={'arm_obj':[list(arm.location),list(arm.rotation_euler),list(arm.scale)],'bones':{}}
for b in arm.data.bones:
    info['bones'][b.name]=[[round(x,4) for x in arm.matrix_world@b.head_local],[round(x,4) for x in arm.matrix_world@b.tail_local], b.parent.name if b.parent else None]
meshes=[o for o in bpy.data.objects if o.type=='MESH']
info['nmesh']=len(meshes)
json.dump(info,open(os.path.join(W,'bones.json'),'w'),indent=1)
setup_render((640,900),'BLENDER_EEVEE')
for n,d in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0)),('q',(0.7,-0.7,0.25))]:
    shoot(os.path.join(W,f'look_{n}.png'),(0,0,0.5),1.15,d)
