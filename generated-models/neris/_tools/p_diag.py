# Diagnose torn / stretched edges per clip: which bone pairs and parts they sit on.
import bpy, sys, os, json, numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
blend,out=argv[0],argv[1]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]; me=lo.data
names=[g.name for g in lo.vertex_groups]
W=np.zeros((len(me.vertices),len(names)),np.float32)
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
dom=np.argmax(W,1)
part=None
if "part" in me.attributes:
    part=np.zeros(len(me.vertices),np.int32); me.attributes["part"].data.foreach_get("value",part)
LAB=["BODY","HAIR","SKIRT","TAIL","ARM_L","ARM_R","LEG"]
ed=np.array([e.vertices[:] for e in me.edges])
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
rig.animation_data_create(); rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
sc.frame_set(0); C0=co(); E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1)
rep={"has_part":part is not None,"nv":len(me.vertices)}
for a in bpy.data.actions:
    if a.name.startswith("_"): continue
    rig.animation_data.action=a
    f0,f1=map(int,a.frame_range); worst=None
    for f in range(f0,f1+1):
        sc.frame_set(f); C=co(); E=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)
        bad=np.where((E>3*np.maximum(E0,1e-9))&(E>0.03))[0]
        if worst is None or len(bad)>worst[1]: worst=(f,len(bad),bad,C)
    f,n,bad,C=worst
    pairs={}; parts={}
    for e in bad:
        a_,b_=ed[e]
        k=" | ".join(sorted((names[dom[a_]].replace("mixamorig:",""),names[dom[b_]].replace("mixamorig:",""))))
        pairs[k]=pairs.get(k,0)+1
        if part is not None:
            kp=" | ".join(sorted((LAB[part[a_]],LAB[part[b_]]))); parts[kp]=parts.get(kp,0)+1
    # are bad edges between verts with nearly disjoint weights?
    ov=[float(np.minimum(W[ed[e,0]],W[ed[e,1]]).sum()) for e in bad]
    rep[a.name]={"frame":f,"n":n,"pairs":dict(sorted(pairs.items(),key=lambda x:-x[1])[:10]),"parts":parts,
                 "weight_overlap_median":round(float(np.median(ov)),3) if ov else None,
                 "min_z":round(float(C[:,2].min()),3),"bad_z":[round(float(C0[ed[bad,0],2].min()),2),round(float(C0[ed[bad,0],2].max()),2)] if n else None}
rig.animation_data.action=None
json.dump(rep,open(out,"w"),indent=1)
