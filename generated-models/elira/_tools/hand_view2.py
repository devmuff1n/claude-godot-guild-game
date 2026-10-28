import bpy,sys,os,json
sys.path.insert(0,os.path.dirname(__file__))
from common import setup_render, shoot, wire_material
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); out=argv[1]; SH=json.loads(argv[2])
for o in bpy.data.objects:
    if o.name!="Elira": o.hide_render=True
lo=bpy.data.objects["Elira"]; pass
setup_render(res=(700,700),samples=8)
for side,sg in (("L",1),("R",-1)):
    c=(sg*0.30-SH[0],-0.045-SH[1],0.45)
    for nm,d in (("out",(sg,0,0)),("in",(-sg,0,0)),("front",(0,-1,0)),("bot",(0.0,-0.3,-1))):
        shoot(os.path.join(out,f"h2{side}_{nm}.png"),c,0.16,d)
