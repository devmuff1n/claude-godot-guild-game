import bpy, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from common import *
argv=sys.argv[sys.argv.index("--")+1:]
blend,outdir=argv[0],argv[1]; specs=argv[2:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]; me=lo.data
nv=len(me.vertices); ed=np.array([e.vertices[:] for e in me.edges])
p=np.arange(nv)
def find(x):
    r=x
    while p[r]!=r: r=p[r]
    while p[x]!=r: p[x],x=r,p[x]
    return r
for a,b in ed:
    ra,rb=find(a),find(b)
    if ra!=rb: p[ra]=rb
roots=np.array([find(i) for i in range(nv)]); u,lab=np.unique(roots,return_inverse=True)
sizes=np.bincount(lab); big=np.argmax(sizes)
pal=np.array([[1,0.1,0.1],[0.1,0.9,0.1],[0.1,0.4,1],[1,0.9,0],[1,0,1],[0,1,1],[1,0.5,0],[0.6,0.3,1],[0.3,1,0.6]])
cols=np.where((lab==big)[:,None],np.array([[0.75,0.72,0.7]]),pal[lab%len(pal)])
ca=me.color_attributes.new("isl",'FLOAT_COLOR','POINT'); ca.data.foreach_set("color",np.concatenate([cols,np.ones((nv,1))],1).astype(np.float32).ravel())
wm=bpy.data.materials.new("iv"); wm.use_nodes=True
at=wm.node_tree.nodes.new("ShaderNodeAttribute"); at.attribute_name="isl"
wm.node_tree.links.new(at.outputs[0], wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
me.materials[0]=wm
setup_render(samples=8)
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 600, 600
os.makedirs(outdir,exist_ok=True)
for s in specs:
    an,f,view=s.split(":")
    if an=="REST": rig.animation_data.action=None; [setattr(pb,"rotation_quaternion",(1,0,0,0)) for pb in rig.pose.bones]
    else: rig.animation_data.action=bpy.data.actions[an]
    sc.frame_set(int(f))
    d={"s":(1,0,0.05),"q":(0.75,-0.65,0.2),"f":(0,-1,0.05),"b":(0,1,0.05)}[view]
    shoot(os.path.join(outdir,f"isl_{an}_{f}_{view}.png"),(0,0,0.6),1.4,d)
