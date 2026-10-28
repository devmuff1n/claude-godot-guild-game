import bpy, sys, json, numpy as np
from mathutils.kdtree import KDTree
def components(nv,ed):
    p=np.arange(nv)
    def find(x):
        r=x
        while p[r]!=r: r=p[r]
        while p[x]!=r: p[x],x=r,p[x]
        return r
    for a,b in ed:
        ra,rb=find(a),find(b)
        if ra!=rb: p[ra]=rb
    roots=np.array([find(i) for i in range(nv)]); u,lab=np.unique(roots,return_inverse=True); return len(u),lab
def nearest(Cother, idx_other, Cq):
    t=KDTree(len(Cother))
    for k,c in enumerate(Cother): t.insert(c,k)
    t.balance(); d=[];j=[]
    for c in Cq:
        _,k,dd=t.find(c); d.append(dd); j.append(k)
    return np.array(d), np.array(j)
argv=sys.argv[sys.argv.index("--")+1:]
blend,out=argv[0],argv[1]; frames=argv[2:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]; me=lo.data
names=[g.name for g in lo.vertex_groups]; nv=len(me.vertices)
W=np.zeros((nv,len(names)),np.float32)
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
ed=np.array([e.vertices[:] for e in me.edges])
n,lab=components(nv,ed)
sizes=np.bincount(lab)
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
sc.frame_set(0); C0=co()
rep={"islands":int(n),"sizes_sorted":sorted(sizes.tolist(),reverse=True)[:40]}
big=np.argmax(sizes)
# for every island: nearest other-island distance at rest vs posed (max over frames)
isl=[]
gap=np.zeros(n)
poses=[]
for s in frames:
    an,f=s.split(":"); rig.animation_data.action=bpy.data.actions[an]; sc.frame_set(int(f)); poses.append(co())
for i in range(n):
    if sizes[i]>4000: continue
    m=lab==i; o=~m
    d0,j0=nearest(C0[o],None,C0[m])
    # track the same neighbour pairs in pose
    oi=np.where(o)[0][j0]
    g=0
    for C in poses:
        g=max(g,float(np.percentile(np.linalg.norm(C[m]-C[oi],axis=1)-d0,90)))
    dom=np.argmax(W[m].sum(0)); ndom=np.argmax(W[oi].sum(0))
    isl.append({"i":i,"size":int(sizes[i]),"rest_gap":round(float(np.median(d0)),3),"pose_gap_growth":round(g,3),
                "dom":names[dom],"neighbour_dom":names[ndom],"z":round(float(C0[m,2].mean()),2),"x":round(float(C0[m,0].mean()),2)})
isl.sort(key=lambda r:-r["pose_gap_growth"])
rep["worst"]=isl[:30]
json.dump(rep,open(out,"w"),indent=1)
