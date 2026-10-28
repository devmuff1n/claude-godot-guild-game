import bpy, sys, numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
out=argv[0]; acts=argv[1:]
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
sc.frame_set(0); d={"C0":co()}
me=lo.data
d["ed"]=np.array([e.vertices[:] for e in me.edges])
names=[g.name for g in lo.vertex_groups]; W=np.zeros((len(me.vertices),len(names)),np.float32)
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
d["W"]=W; d["names"]=np.array(names)
for a in acts:
    an,f=a.split(":"); rig.animation_data.action=bpy.data.actions[an]; sc.frame_set(int(f)); d[f"C_{an}_{f}"]=co()
np.savez_compressed(out,**d)
