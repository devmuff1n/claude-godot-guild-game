import bpy,sys,os
sys.path.insert(0,os.path.dirname(__file__))
from common import setup_render, shoot
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); out=argv[1]; act=argv[2]; fr=int(argv[3]); tag=argv[4]
rig=bpy.data.objects["Elira_Rig"]; rig.animation_data.action=bpy.data.actions[act]
sc=bpy.context.scene; sc.frame_set(fr); bpy.context.view_layer.update()
setup_render(res=(600,600),samples=8)
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
for side in ("Left","Right"):
    h=rig.pose.bones["mixamorig:"+side+"Hand"]; c=(rig.matrix_world@h.head)+ (rig.matrix_world.to_3x3()@(h.tail-h.head))*0.6
    sg=1 if side=="Left" else -1
    for nm,d in (("out",(sg,0,0)),("in",(-sg,-0.2,0.1)),("front",(0,-1,0.1))):
        shoot(os.path.join(out,f"{tag}_{side[0]}_{nm}.png"),tuple(c),0.18,d)
