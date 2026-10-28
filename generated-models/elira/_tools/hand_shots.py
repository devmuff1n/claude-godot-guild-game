import bpy,sys,os
sys.path.insert(0,os.path.dirname(__file__))
from common import setup_render, shoot
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); out=argv[1]
rig=bpy.data.objects["Elira_Rig"]; rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
setup_render(res=(700,700),samples=8)
sc=bpy.context.scene
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
for side,sg in (("L",1),("R",-1)):
    c=(sg*0.30,-0.02,0.445)
    for nm,d in (("front",(0,-1,0)),("out",(sg,0,0)),("in",(-sg,0,0)),("back",(0,1,0)),("bottom",(0,-0.01,-1))):
        shoot(os.path.join(out,f"hand{side}_{nm}.png"),c,0.2,d)
