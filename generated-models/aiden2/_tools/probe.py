import bpy, os, json, sys
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
for o in bpy.data.objects:
    print('OBJ', o.name, o.type, o.parent.name if o.parent else None, [round(x,3) for x in o.location], [round(x,3) for x in o.rotation_euler], [round(x,3) for x in o.scale], [round(x,3) for x in o.dimensions])
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
info={'bones':{}}
for b in arm.data.bones:
    info['bones'][b.name]=[[round(x,4) for x in arm.matrix_world@b.head_local],[round(x,4) for x in arm.matrix_world@b.tail_local], b.parent.name if b.parent else None]
json.dump(info,open(os.path.join(W,'bones.json'),'w'),indent=1)
for o in bpy.data.objects:
    if o.type!='MESH': continue
    me=o.data
    print('MESH', o.name, len(me.polygons), len(me.vertices), len(o.vertex_groups), [m.type for m in o.modifiers], len(me.uv_layers))
    for s in o.material_slots:
        m=s.material
        for n in m.node_tree.nodes:
            if n.type=='TEX_IMAGE': print('  IMG', n.image.name, tuple(n.image.size))
    import mathutils
    pts=[o.matrix_world@v.co for v in me.vertices]
    print('  BBOX', [round(min(p[i] for p in pts),3) for i in range(3)], [round(max(p[i] for p in pts),3) for i in range(3)])
print('ANIMS', [a.name for a in bpy.data.actions])
setup_render((640,900),'BLENDER_EEVEE')
for n,d in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0)),('q',(0.7,-0.7,0.25))]:
    shoot(os.path.join(W,f'look_{n}.png'),(0,0,0.5),1.15,d)
