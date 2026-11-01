# Step 1: import Tripo GLB, flatten transforms, scale to 1.5 m, join 90 parts into one mesh with one texture atlas.
import bpy, os, numpy as np, json
W=os.path.join(os.path.dirname(__file__),'..','_work')
SCALE=1.5
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
for o in list(bpy.data.objects):
    if o.name=='Icosphere': bpy.data.objects.remove(o)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
meshes=[o for o in bpy.data.objects if o.type=='MESH']
# flatten hierarchy
for o in [arm]+meshes:
    mw=o.matrix_world.copy(); o.parent=None; o.matrix_world=mw
for o in list(bpy.data.objects):
    if o.type=='EMPTY': bpy.data.objects.remove(o)
arm.scale=[s*SCALE for s in arm.scale]; arm.location=arm.location*SCALE
for o in meshes:
    o.matrix_world=__import__('mathutils').Matrix.Scale(SCALE,4)@o.matrix_world
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in [arm]+meshes: o.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# ---- atlas
info=[]
for o in meshes:
    m=o.material_slots[0].material; img=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE'][0]
    info.append((o,img))
PAD=4
items=sorted(info,key=lambda t:-t[1].size[0]*1000-t[1].size[1])
AW=4096; x=y=0; rowh=0; place={}
for o,img in items:
    w,h=img.size; cw,ch=w+2*PAD,h+2*PAD
    if x+cw>AW: x=0; y+=rowh; rowh=0
    place[o.name]=(x,y,w,h); x+=cw; rowh=max(rowh,ch)
AH=y+rowh; AH2=1
while AH2<AH: AH2*=2
AH=AH2
atlas=np.zeros((AH,AW,4),np.float32); atlas[...,3]=1
for o,img in items:
    x,y,w,h=place[o.name]
    px=np.array(img.pixels[:],np.float32).reshape(h,w,4)
    px=np.pad(px,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    atlas[y:y+h+2*PAD,x:x+w+2*PAD]=px
    me=o.data
    for d in me.uv_layers[0].data:
        u,v=d.uv
        d.uv=((x+PAD+u*w)/AW,(y+PAD+v*h)/AH)
A=bpy.data.images.new('elira_atlas',AW,AH,alpha=False)
A.pixels=atlas.ravel()
A.filepath_raw=os.path.join(W,'elira_atlas.png'); A.file_format='PNG'; A.save()
mat=bpy.data.materials.new('Elira'); mat.use_nodes=True
b=mat.node_tree.nodes['Principled BSDF']; t=mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image=A
mat.node_tree.links.new(t.outputs[0],b.inputs['Base Color']); b.inputs['Roughness'].default_value=0.85
for o in meshes:
    o.data.materials.clear(); o.data.materials.append(mat)
    for s in o.material_slots: s.link='DATA'; s.material=mat
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join()
body=bpy.context.active_object; body.name='Elira'; body.data.name='Elira'
while len(body.material_slots)>1:
    body.active_material_index=1; bpy.ops.object.material_slot_remove()
body.parent=arm
mods=[m for m in body.modifiers if m.type=='ARMATURE']
for m in mods[1:]: body.modifiers.remove(m)
mods[0].object=arm
arm.name='Elira_Rig'; arm.data.name='Elira_Rig'
for img in list(bpy.data.images):
    if img!=A: bpy.data.images.remove(img)
for m in list(bpy.data.materials):
    if m!=mat: bpy.data.materials.remove(m)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s1.blend'))
print('S1', AW, AH, len(body.data.polygons), len(body.data.vertices), [round(v,3) for v in body.dimensions])
