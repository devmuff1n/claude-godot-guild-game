import bpy, sys, json, numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
sc=bpy.context.scene; rig=bpy.data.objects["Elira_Rig"]; lo=bpy.data.objects["Elira"]; me=lo.data
names=[g.name for g in lo.vertex_groups]; nv=len(me.vertices)
W=np.zeros((nv,len(names)))
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
dom=W.argmax(1); ed=np.array([e.vertices[:] for e in me.edges])
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
sc.frame_set(0); C0=co(); E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1)
out={}
for an,f in [x.split(":") for x in argv[1].split(",")]:
    rig.animation_data.action=bpy.data.actions[an]; sc.frame_set(int(f)); C=co()
    E=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)
    b=np.where((E>3*np.maximum(E0,1e-9))&(E>0.03))[0]
    out[f"{an}:{f}"]=[(names[dom[ed[i,0]]],names[dom[ed[i,1]]],[round(float(x),3) for x in C0[ed[i,0]]],round(float(E[i]),3)) for i in b]
print("DIAG",json.dumps(out))
