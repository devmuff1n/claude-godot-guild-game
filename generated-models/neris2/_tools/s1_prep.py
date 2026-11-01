# Step 1: import Tripo GLB, flatten, scale to 1.62 m, one mesh 'Neris' with its single 2048 texture, floor at z=0.
import bpy, os, numpy as np
from mathutils import Matrix
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
for o in list(bpy.data.objects):
    if o.name=='Icosphere': bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in [arm]+meshes:
    mw=o.matrix_world.copy(); o.parent=None; o.matrix_world=mw
for o in list(bpy.data.objects):
    if o.type=='EMPTY': bpy.data.objects.remove(o)
bpy.context.view_layer.update()
zmin=min((o.matrix_world@v.co).z for o in meshes for v in o.data.vertices)
zmax=max((o.matrix_world@v.co).z for o in meshes for v in o.data.vertices)
SCALE=1.62/(zmax-zmin)
T=Matrix.Scale(SCALE,4)@Matrix.Translation((0,0,-zmin))
for o in [arm]+meshes: o.matrix_world=T@o.matrix_world
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in [arm]+meshes: o.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
img=None
for o in meshes:
    for n in o.material_slots[0].material.node_tree.nodes:
        if n.type=='TEX_IMAGE': img=n.image
img.name='neris_atlas'
img.pack() if not img.packed_file else None
img.filepath_raw=os.path.join(W,'neris_atlas.png'); img.file_format='PNG'; img.save()
mat=bpy.data.materials.new('Neris'); mat.use_nodes=True
b=mat.node_tree.nodes['Principled BSDF']; t=mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(os.path.join(W,'neris_atlas.png'))
t.image.name='neris_atlas_png'
mat.node_tree.links.new(t.outputs[0],b.inputs['Base Color']); b.inputs['Roughness'].default_value=0.85
for o in meshes:
    o.data.materials.clear(); o.data.materials.append(mat)
if len(meshes)>1:
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join()
body=meshes[0]; body.name='Neris'; body.data.name='Neris'
body.parent=arm
mods=[m for m in body.modifiers if m.type=='ARMATURE']
for m in mods[1:]: body.modifiers.remove(m)
mods[0].object=arm
arm.name='Neris_Rig'; arm.data.name='Neris_Rig'
for i in list(bpy.data.images):
    if i.name!='neris_atlas_png': bpy.data.images.remove(i)
for m in list(bpy.data.materials):
    if m!=mat: bpy.data.materials.remove(m)
# merge duplicate verts from Tripo split (UV seams kept)
import bmesh
bm=bmesh.new(); bm.from_mesh(body.data); n0=len(bm.verts)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s1.blend'))
print('S1', SCALE, len(body.data.polygons), len(body.data.vertices), [round(v,3) for v in body.dimensions], round(min(v.co.z for v in body.data.vertices),4))
