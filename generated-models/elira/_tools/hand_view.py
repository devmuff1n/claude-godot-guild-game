import bpy,sys,os,json
sys.path.insert(0,os.path.dirname(__file__))
from common import setup_render, shoot, wire_material
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); out=argv[1]; SH=json.loads(argv[2])
for o in bpy.data.objects:
    if o.type=='MESH' and not o.name.startswith("Hand"): o.hide_render=True
m=wire_material()
for o in bpy.data.objects:
    if o.name.startswith("Hand"): o.data.materials.clear(); o.data.materials.append(m)
setup_render(res=(700,700),samples=8)
for side,sg in (("L",1),("R",-1)):
    c=(sg*0.30-SH[0],-0.045-SH[1],0.44)
    for nm,d in (("out",(sg,0,0)),("in",(-sg,0,0)),("front",(0,-1,0)),("bot",(0.0,-0.3,-1))):
        shoot(os.path.join(out,f"ht{side}_{nm}.png"),c,0.15,d)
