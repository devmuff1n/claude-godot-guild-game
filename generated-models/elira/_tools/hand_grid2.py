import bpy,sys,os
sys.path.insert(0,os.path.dirname(__file__))
from common import setup_render, shoot
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); out=argv[1]
rig=None

lo=bpy.data.objects["Elira"]
# hide everything that is not hand/forearm: delete faces far from the hands in an evaluated copy is costly; use a clip box via mask modifier on a vertex group
import numpy as np
me=lo.data
vg=lo.vertex_groups.new(name="_handzone")
ids=[v.index for v in me.vertices if abs(v.co.x)>0.24 and v.co.z<0.56 and v.co.z>0.36 and v.co.y>-0.16 and v.co.y<0.06 and not (abs(v.co.x)<0.27 and v.co.y>0.0 and v.co.z<0.45)]
vg.add(ids,1.0,'REPLACE')
mk=lo.modifiers.new("mask",'MASK'); mk.vertex_group="_handzone"
setup_render(res=(800,800),samples=8)
sc=bpy.context.scene
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
S=0.16
for side,sg in (("L",1),("R",-1)):
    c=(sg*0.30,-0.045,0.44)
    for nm,d in (("front",(0,-1,0)),("out",(sg,0,0)),("in",(-sg,0,0))):
        shoot(os.path.join(out,f"g{side}_{nm}.png"),c,S,d)
print("CENTERS done")
