import bpy,sys,json,numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
sc=bpy.context.scene; rig=bpy.data.objects["Elira_Rig"]; lo=bpy.data.objects["Elira"]; me=lo.data
names=[g.name for g in lo.vertex_groups]; nv=len(me.vertices)
W=np.zeros((nv,len(names)))
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
ed=np.array([e.vertices[:] for e in me.edges])
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
rig.animation_data.action=bpy.data.actions[argv[1]]; sc.frame_set(0); C0=co(); sc.frame_set(int(argv[2])); C=co()
E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1); E=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)
bad=np.where((E>2.5*np.maximum(E0,1e-9))&(E>0.012))[0]
vs=np.unique(ed[bad].ravel())
out=[]
for v in vs[:400]:
    if abs(C0[v,0])<0.24: continue
    top=np.argsort(-W[v])[:3]
    out.append([np.round(C0[v],3).tolist(), [(names[k].replace("mixamorig:",""),round(float(W[v,k]),2)) for k in top if W[v,k]>0]])
print("N",len(bad))
for o in out[:60]: print(o)
