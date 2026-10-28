import bpy,sys,numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
lo=bpy.data.objects["Elira"]; me=lo.data
co=np.array([v.co[:] for v in me.vertices]); ed=np.array([e.vertices[:] for e in me.edges])
names=[g.name for g in lo.vertex_groups]; W=np.zeros((len(co),len(names)),np.float32)
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
rig=bpy.data.objects["Elira_Rig"]
bones={b.name:(list(b.head_local),list(b.tail_local)) for b in rig.data.bones}
np.savez(argv[1],co=co,ed=ed,W=W,names=np.array(names))
import json; json.dump(bones,open(argv[1]+".bones.json","w"))
