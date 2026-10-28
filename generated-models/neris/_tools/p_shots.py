import bpy, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from common import *
argv=sys.argv[sys.argv.index("--")+1:]
blend,outdir=argv[0],argv[1]; specs=argv[2:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]
setup_render(samples=8)
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 512, 512
# floor plane
bpy.ops.mesh.primitive_plane_add(size=3); fl=bpy.context.object
m=bpy.data.materials.new("fl"); m.use_nodes=True; m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.5,0.5,0.52,1); fl.data.materials.append(m)
os.makedirs(outdir,exist_ok=True)
info={}
for s in specs:
    an,f,view=s.split(":")
    rig.animation_data.action=bpy.data.actions[an]; sc.frame_set(int(f))
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); mm=ev.to_mesh()
    C=np.array([v.co[:] for v in mm.vertices]); ev.to_mesh_clear()
    info[s]=[round(float(C[:,2].min()),3)]
    d={"s":(1,0,0.05),"q":(0.75,-0.65,0.2),"f":(0,-1,0.05)}[view]
    shoot(os.path.join(outdir,f"{an}_{f}_{view}.png"),(0,0,0.65),1.6,d)
print("INFO",info)
