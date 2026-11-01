# Step 1: import Tripo GLB (50 parts, 50 textures), flatten, scale to 1.72 m, floor z=0, join into one mesh 'Aiden'
# with one 2048x2048 atlas (shelf packing, uniform downscale searched so everything fits).
import bpy, os, numpy as np
from mathutils import Matrix
from PIL import Image
W=os.path.join(os.path.dirname(__file__),'..','_work')
HEIGHT=1.72; AW=AH=2048; PAD=3
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
SCALE=HEIGHT/(zmax-zmin)
T=Matrix.Scale(SCALE,4)@Matrix.Translation((0,0,-zmin))
for o in [arm]+meshes: o.matrix_world=T@o.matrix_world
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in [arm]+meshes: o.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
info=[]
for o in meshes:
    m=o.material_slots[0].material; img=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE'][0]
    w,h=img.size; px=np.array(img.pixels[:],np.float32).reshape(h,w,4)
    info.append((o,px))
def pack(s):
    items=sorted(info,key=lambda t:-t[1].shape[0])
    x=y=0; rowh=0; place={}
    for o,px in items:
        h,w=px.shape[:2]; w=max(8,int(round(w*s))); h=max(8,int(round(h*s)))
        cw,ch=w+2*PAD,h+2*PAD
        if x+cw>AW: x=0; y+=rowh; rowh=0
        place[o.name]=(x,y,w,h); x+=cw; rowh=max(rowh,ch)
    return place, y+rowh
s=1.0
while True:
    place,hh=pack(s)
    if hh<=AH: break
    s-=0.01
atlas=np.zeros((AH,AW,4),np.float32); atlas[...,3]=1
for o,px in info:
    x,y,w,h=place[o.name]
    im=Image.fromarray((np.clip(px,0,1)*255).astype(np.uint8)).resize((w,h),Image.LANCZOS)
    p=np.asarray(im).astype(np.float32)/255
    p=np.pad(p,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    atlas[y:y+h+2*PAD,x:x+w+2*PAD]=p
    for d in o.data.uv_layers[0].data:
        u,v=d.uv; d.uv=((x+PAD+u*w)/AW,(y+PAD+v*h)/AH)
A=bpy.data.images.new('aiden_atlas',AW,AH,alpha=False); A.pixels=atlas.ravel()
A.filepath_raw=os.path.join(W,'aiden_atlas.png'); A.file_format='PNG'; A.save()
mat=bpy.data.materials.new('Aiden'); mat.use_nodes=True
b=mat.node_tree.nodes['Principled BSDF']; t=mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image=A
mat.node_tree.links.new(t.outputs[0],b.inputs['Base Color']); b.inputs['Roughness'].default_value=0.85
for o in meshes:
    o.data.materials.clear(); o.data.materials.append(mat)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join()
body=bpy.context.active_object; body.name='Aiden'; body.data.name='Aiden'
body.parent=arm
mods=[m for m in body.modifiers if m.type=='ARMATURE']
for m in mods[1:]: body.modifiers.remove(m)
mods[0].object=arm
arm.name='Aiden_Rig'; arm.data.name='Aiden_Rig'
for i in list(bpy.data.images):
    if i!=A: bpy.data.images.remove(i)
for m in list(bpy.data.materials):
    if m!=mat: bpy.data.materials.remove(m)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s1.blend'))
print('S1', round(SCALE,3), 'texscale', round(s,2), len(body.data.polygons), len(body.data.vertices), [round(v,3) for v in body.dimensions], round(min(v.co.z for v in body.data.vertices),4))
