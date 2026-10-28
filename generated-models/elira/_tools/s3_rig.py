# Step 3 (Elira): build the deform skeleton (Mixamo-compatible humanoid + braid/cape/skirt chains), skin, clean weights, joint test.
import bpy, sys, os, json, math, time, bmesh, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import rigdef
from mathutils import Vector, Matrix, Quaternion
argv = sys.argv[sys.argv.index("--")+1:]
src_blend, work = argv[0], argv[1]
os.makedirs(work, exist_ok=True)
rep={}; t0=time.time()
bpy.ops.wm.open_mainfile(filepath=src_blend)
sc=bpy.context.scene
s2=json.load(open(os.path.join(os.path.dirname(os.path.dirname(src_blend)),"s2","s2_report.json")))
SH=Vector((0,0,0))  # rigdef is already in the recentred space
TEX=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(src_blend))),"textures")
for im in bpy.data.images:
    if im.filepath and "elira_" in im.filepath:
        im.filepath=os.path.join(TEX, os.path.basename(bpy.path.abspath(im.filepath))); im.reload()
lo=bpy.data.objects["Elira"]; hi=bpy.data.objects.get("Elira_High")
if hi: bpy.data.objects.remove(hi)   # high-poly lives in the bake-source file
BONES=[(rigdef.full_name(n), Vector(h)+SH, Vector(t)+SH, rigdef.full_name(p) if p else None, d) for n,h,t,p,d in rigdef.HUM+rigdef.SEC]
# --- armature
arm=bpy.data.armatures.new("Elira_Skeleton"); rig=bpy.data.objects.new("Elira_Rig", arm)
sc.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,h,t,p,d in BONES:
    eb=arm.edit_bones.new(n); eb.head=h; eb.tail=t; eb.use_deform=d
for n,h,t,p,d in BONES:
    eb=arm.edit_bones[n]
    if p:
        eb.parent=arm.edit_bones[p]
        eb.use_connect=(eb.parent.tail-eb.head).length<1e-5
    v=(eb.tail-eb.head).normalized()
    # local Z toward the front (-Y) unless the bone itself points forward/back, then Z up
    eb.align_roll(Vector((0,0,1)) if abs(v.y)>0.75 else Vector((0,-1,0)))
bpy.ops.object.mode_set(mode='OBJECT')
arm.display_type='STICK'; rig.show_in_front=True
rep["bones"]=len(arm.bones); rep["deform_bones"]=sum(1 for b in arm.bones if b.use_deform)
# --- skinning: bone heat -> rule-based clean-up; then cut welded contacts between parts that must move apart, and redo
me=lo.data
defb=[b for b in arm.bones if b.use_deform]; names=[b.name for b in defb]; B=len(defb)
idx={n:k for k,n in enumerate(names)}
H=np.array([b.head_local[:] for b in defb]); T=np.array([b.tail_local[:] for b in defb])
R=np.array([rigdef.radius(n) for n in names])
GROUP={}
for n in names:
    b=n.replace("mixamorig:","")
    GROUP[n]=("BRAID" if b.startswith("Braid") else "SKIRT" if b.startswith("Skirt") else "CAPE" if b.startswith("Cape")
              else "ARM_L" if b in ("LeftArm","LeftForeArm") or b.startswith("LeftHand") else "ARM_R" if b in ("RightArm","RightForeArm") or b.startswith("RightHand")
              else "LEG" if any(b.startswith(s+k) for s in ("Left","Right") for k in ("UpLeg","Leg","Foot","ToeBase")) else "BODY")
GID=np.array([["BODY","BRAID","SKIRT","CAPE","ARM_L","ARM_R","LEG"].index(GROUP[n]) for n in names])
LAB=["BODY","BRAID","SKIRT","CAPE","ARM_L","ARM_R","LEG"]
# bone groups a labelled vertex must NOT use
CUT_PAIRS={frozenset(p) for p in (("ARM_L","SKIRT"),("ARM_R","SKIRT"),("ARM_L","BRAID"),("ARM_R","BRAID"),("BRAID","SKIRT"),
   ("BRAID","CAPE"),("CAPE","SKIRT"),("ARM_L","CAPE"),("ARM_R","CAPE"),("ARM_L","LEG"),("ARM_R","LEG"))}
def segdist(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1); return np.linalg.norm(P-(a+t[:,None]*ab),axis=1)
def label_allowed(labels,P):
    nv=len(labels); A=np.ones((nv,B),bool)
    bn=[n.replace("mixamorig:","") for n in names]
    def ids(pred): return np.array([pred(b) for b in bn])
    sets={
      "ARM_L": ids(lambda b: b in ("LeftArm","LeftForeArm","LeftShoulder","Spine2") or b.startswith("LeftHand")),
      "ARM_R": ids(lambda b: b in ("RightArm","RightForeArm","RightShoulder","Spine2") or b.startswith("RightHand")),
      "SKIRT": ids(lambda b: b.startswith("Skirt") or b in ("Hips","Spine")),
      "CAPE":  ids(lambda b: b.startswith("Cape") or b in ("Spine2","Neck","LeftShoulder","RightShoulder")),
      "LEG":   ids(lambda b: any(k in b for k in ("UpLeg","Leg","Foot","ToeBase")) or b=="Hips"),
      "BRAID": ids(lambda b: b.startswith("Braid") or b=="Head"),
    }
    for k,m in sets.items(): A[labels==LAB.index(k)]=m
    bm_=labels==LAB.index("BODY")
    A[bm_]=~ids(lambda b: b.startswith(("Braid","Cape","Skirt")))
    return A
def finger_override(W, P):
    """Finger skin by geometry: each vertex near a finger chain goes to that finger's phalanges, with short blends at the
    joints and a blend into the hand bone around the knuckle. Bone heat smears fingers into the hand and neighbours."""
    nv=len(P)
    for side in ("Left","Right"):
        hand=idx[f"mixamorig:{side}Hand"]
        chains=[]
        for f in ("Index","Middle","Ring","Pinky","Thumb"):
            ks=[idx[f"mixamorig:{side}Hand{f}{k}"] for k in (1,2,3)]
            pts=[H[ks[0]],H[ks[1]],H[ks[2]],T[ks[2]]]
            chains.append((f,ks,np.array(pts)))
        best_d=np.full(nv,1e9); best=np.full(nv,-1); best_s=np.zeros(nv); best_proj=np.zeros(nv)
        for ci,(f,ks,pts) in enumerate(chains):
            seglen=np.linalg.norm(np.diff(pts,axis=0),axis=1); acc=np.concatenate([[0],np.cumsum(seglen)])
            d_min=np.full(nv,1e9); s_at=np.zeros(nv)
            for j in range(3):
                a_,b_=pts[j],pts[j+1]; ab=b_-a_; t=np.clip(((P-a_)@ab)/max(ab@ab,1e-12),0,1)
                d=np.linalg.norm(P-(a_+t[:,None]*ab),axis=1); m=d<d_min; d_min[m]=d[m]; s_at[m]=acc[j]+t[m]*seglen[j]
            ab=pts[1]-pts[0]; proj=((P-pts[0])@ab)/np.linalg.norm(ab)
            m=d_min<best_d; best_d[m]=d_min[m]; best[m]=ci; best_s[m]=s_at[m]; best_proj[m]=proj[m]
        thr=np.where(best==4,0.020,0.0165)
        handzone=(np.abs(P[:,0])>0.24)&(P[:,2]<0.50)&(P[:,1]>-0.17)&(P[:,1]<0.04)
        sel=handzone&(best>=0)&(((best_d<thr)&(best_proj>-0.012))|((best_proj>0.004)&(best_d<0.03)))
        for v in np.where(sel)[0]:
            f,ks,pts=chains[best[v]]
            seglen=np.linalg.norm(np.diff(pts,axis=0),axis=1); j1=seglen[0]; j2=j1+seglen[1]; s_=best_s[v]; bw=0.005
            w=np.zeros(3)
            if s_<j1-bw: w[0]=1
            elif s_<j1+bw: t=(s_-(j1-bw))/(2*bw); w[0]=1-t; w[1]=t
            elif s_<j2-bw: w[1]=1
            elif s_<j2+bw: t=(s_-(j2-bw))/(2*bw); w[1]=1-t; w[2]=t
            else: w[2]=1
            wh=float(np.clip((0.006-best_proj[v])/0.014,0,1)) if f!="Thumb" else float(np.clip((0.004-best_proj[v])/0.02,0,1))*0.7
            W[v,:]=0; W[v,ks]=w*(1-wh); W[v,hand]=wh
    return W
def skin(labels=None):
    for g in list(lo.vertex_groups): lo.vertex_groups.remove(g)
    for m in list(lo.modifiers):
        if m.type=='ARMATURE': lo.modifiers.remove(m)
    lo.parent=None
    bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    t=time.time(); bpy.ops.object.parent_set(type='ARMATURE_AUTO'); rep.setdefault("t_heat",[]).append(round(time.time()-t,1))
    nv=len(me.vertices)
    P=np.array([v.co[:] for v in me.vertices])
    D=np.stack([segdist(P,H[i],T[i]) for i in range(B)],1)
    W=np.zeros((nv,B),np.float32)
    gi={g.name:g.index for g in lo.vertex_groups}
    col={gi[n]:k for k,n in enumerate(names) if n in gi}
    for v in me.vertices:
        for g in v.groups:
            k=col.get(g.group)
            if k is not None: W[v.index,k]=g.weight
    rep.setdefault("heat_zero_weight_verts",[]).append(int((W.sum(1)<1e-6).sum()))
    allowed=D<=R[None,:]
    head=idx["mixamorig:Head"]; neck=idx["mixamorig:Neck"]
    HC=Vector(rigdef.M(0,0.10,1.15))+SH
    e=(P-np.array(HC[:]))/np.array([0.46,0.37,0.36])
    in_head=((e**2).sum(1)<=1.0)&(P[:,2]>0.84)&~((P[:,0]>0.09)&(P[:,2]<0.93)&(P[:,1]>0.0))
    rigid=in_head|(P[:,2]>1.12)
    allowed[rigid]=False; allowed[rigid,head]=True
    allowed[in_head&(P[:,2]<0.90),neck]=True
    own={"Left":np.zeros(nv,bool),"Right":np.zeros(nv,bool)}
    for side in (("Left","Right") if labels is None else ()):
        arm_ids=[idx[f"mixamorig:{side}{b}"] for b in ("Arm","ForeArm")]+[k for k,n in enumerate(names) if n.startswith(f"mixamorig:{side}Hand")]
        near=np.argmin(D,1)
        o=np.isin(near,[idx[f"mixamorig:{side}ForeArm"]]+[k for k,n in enumerate(names) if n.startswith(f"mixamorig:{side}Hand")])&~rigid
        keep=np.zeros(B,bool); keep[arm_ids]=True
        allowed[o]=allowed[o]&keep[None,:]
        bestarm=np.array(arm_ids)[np.argmin(D[:,arm_ids],1)]
        allowed[np.where(o)[0], bestarm[o]]=True
        own[side]=o
    if labels is not None:
        LA=label_allowed(labels,P)
        allowed&=LA
    if labels is not None:
        own["Left"]=labels==LAB.index("ARM_L"); own["Right"]=labels==LAB.index("ARM_R")
    none=~allowed.any(1)
    if none.any():
        ok=label_allowed(labels,P) if labels is not None else np.ones((nv,B),bool)
        cand=np.where(ok, D/R[None,:], 1e9)
        allowed[np.where(none)[0], np.argmin(cand[none],1)]=True
    W*=allowed
    empty=W.sum(1)<1e-4
    W[empty]=np.where(allowed, np.clip(1-D/R[None,:],0,1)**2, 0)[empty]
    empty=W.sum(1)<1e-6
    if empty.any():
        cand=np.where(allowed, D/R[None,:], 1e9)
        W[np.where(empty)[0], np.argmin(cand[empty],1)]=1
    ed=np.array([e.vertices[:] for e in me.edges])
    for it in range(4):
        acc=np.zeros_like(W); cnt=np.zeros(nv)
        np.add.at(acc,ed[:,0],W[ed[:,1]]); np.add.at(acc,ed[:,1],W[ed[:,0]])
        np.add.at(cnt,ed[:,0],1); np.add.at(cnt,ed[:,1],1)
        W=0.5*W+0.5*acc/np.maximum(cnt,1)[:,None]
        W*=allowed
    if labels is not None:   # braid: blend along the chain a bit more
        hm=(labels==LAB.index("BRAID"))
        for it in range(10):
            acc=np.zeros_like(W); cnt=np.zeros(nv)
            np.add.at(acc,ed[:,0],W[ed[:,1]]); np.add.at(acc,ed[:,1],W[ed[:,0]])
            np.add.at(cnt,ed[:,0],1); np.add.at(cnt,ed[:,1],1)
            Wn=0.5*W+0.5*acc/np.maximum(cnt,1)[:,None]
            W[hm]=(Wn*allowed)[hm]
    W/=np.maximum(W.sum(1,keepdims=True),1e-9)
    W=finger_override(W,P)
    order=np.argsort(-W,1); keep=np.zeros_like(W,bool)
    np.put_along_axis(keep, order[:,:4], True, 1)
    W=np.where(keep&(W>0.01),W,0); W/=np.maximum(W.sum(1,keepdims=True),1e-9)
    return W, own, ed, P
def make_labels(W,own,ed,P):
    nv=len(P)
    gw=np.stack([W[:,GID==g].sum(1) for g in range(len(LAB))],1)
    gw[:,0]*=0.6
    lab=np.argmax(gw,1)
    HC=Vector(rigdef.M(0,0.10,1.15))+SH
    ein=((((P-np.array(HC[:]))/np.array([0.46,0.37,0.36]))**2).sum(1)<=1.0)&(P[:,2]>0.84)&~((P[:,0]>0.09)&(P[:,2]<0.93)&(P[:,1]>0.0))
    lab[own["Left"]]=LAB.index("ARM_L"); lab[own["Right"]]=LAB.index("ARM_R")
    lab[(lab==0)&(P[:,2]<0.30)]=LAB.index("LEG")
    # tabard / skirt panels that the heat solver gave to the legs: nearest bone decides
    legb=[k for k,n in enumerate(names) if GROUP[n]=="LEG" and "Hips" not in n]
    skb=[k for k,n in enumerate(names) if GROUP[n]=="SKIRT"]
    armb={s_:[idx[f"mixamorig:{s_}ForeArm"]]+[k for k,n in enumerate(names) if n.startswith(f"mixamorig:{s_}Hand")] for s_ in ("Left","Right")}
    Dl=np.stack([segdist(P,H[k],T[k]) for k in legb],1).min(1); Ds=np.stack([segdist(P,H[k],T[k]) for k in skb],1).min(1)
    lab[(lab==LAB.index("LEG"))&(Ds<Dl)&(Dl>0.05)]=LAB.index("SKIRT")
    # bracer / glove hugging the forearm/hand belongs to the arm even if the braid touches it
    for s_,L_ in (("Left","ARM_L"),("Right","ARM_R")):
        Da=np.stack([segdist(P,H[k],T[k]) for k in armb[s_]],1).min(1)
        lab[(Da<0.06)&~ein]=LAB.index(L_)
    lab[ein]=0
    for it in range(4):
        votes=np.zeros((nv,len(LAB))); np.add.at(votes,(ed[:,0],lab[ed[:,1]]),1); np.add.at(votes,(ed[:,1],lab[ed[:,0]]),1)
        votes[np.arange(nv),lab]+=1.5
        lab=np.argmax(votes,1)
    return lab
def must_cut(la,lb,z):
    if frozenset((la,lb)) in CUT_PAIRS: return True
    if z<0.70 and {la,lb} in ({"ARM_L","BODY"},{"ARM_R","BODY"}): return True
    if z<0.86 and {la,lb}=={"BRAID","BODY"}: return True
    return False
def cut_and_cap(lab):
    bm=bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    FL=bm.faces.layers.int.new("flab")
    for f in bm.faces:
        cnt={}
        for v in f.verts: cnt[int(lab[v.index])]=cnt.get(int(lab[v.index]),0)+1
        f[FL]=max(cnt,key=cnt.get)
    # smooth face labels (majority of edge neighbours) to avoid ragged seams
    for it in range(2):
        new={}
        for f in bm.faces:
            cnt={f[FL]:1.5}
            for e in f.edges:
                for g in e.link_faces:
                    if g is not f: cnt[g[FL]]=cnt.get(g[FL],0)+1
            new[f]=max(cnt,key=cnt.get)
        for f,v in new.items(): f[FL]=v
    cut=[]
    for e in bm.edges:
        lf=e.link_faces
        if len(lf)==2 and lf[0][FL]!=lf[1][FL] and must_cut(LAB[lf[0][FL]],LAB[lf[1][FL]],(e.verts[0].co.z+e.verts[1].co.z)/2):
            cut.append(e)
    n=len(cut)
    if cut:
        bmesh.ops.split_edges(bm, edges=cut)
        uvl=bm.loops.layers.uv.active
        before=set(bm.faces)
        bnd=[e for e in bm.edges if e.is_boundary]
        # group boundary edges into loops; only cap loops that border a single part (a slit between two parts stays open)
        par={}
        def fd(x):
            while par.get(x,x)!=x: x=par[x]
            return x
        for e in bnd:
            a,b=fd(e.verts[0].index),fd(e.verts[1].index)
            if a!=b: par[a]=b
        loops={}
        for e in bnd: loops.setdefault(fd(e.verts[0].index),[]).append(e)
        fill=[]; slits=0
        for es in loops.values():
            labs={e.link_faces[0][FL] for e in es if e.link_faces}
            if len(labs)==1: fill+=es
            else: slits+=1
        rep.setdefault("open_slits",[]).append(slits)
        bmesh.ops.holes_fill(bm, edges=fill, sides=0)
        caps=[f for f in bm.faces if f not in before]
        for f in caps:
            f.smooth=True
            # cap takes the label and UVs of the faces around its rim
            cnt={}
            for l in f.loops:
                for g in l.vert.link_faces:
                    if g not in caps: cnt[g[FL]]=cnt.get(g[FL],0)+1
            if cnt: f[FL]=max(cnt,key=cnt.get)
            for l in f.loops:
                src=[m for g in l.vert.link_faces if g not in caps for m in g.loops if m.vert is l.vert]
                if src: l[uvl].uv=src[0][uvl].uv
        res=bmesh.ops.triangulate(bm, faces=caps)
        rep.setdefault("cap_faces",[]).append(len(res["faces"]))
    bm.verts.index_update()
    lab2=np.zeros(len(bm.verts),int)
    for v in bm.verts:
        cnt={}
        for f in v.link_faces: cnt[f[FL]]=cnt.get(f[FL],0)+1
        lab2[v.index]=max(cnt,key=cnt.get) if cnt else 0
    rep["open_boundary_edges_after_caps"]=sum(1 for e in bm.edges if e.is_boundary)
    bm.faces.layers.int.remove(FL)
    bm.to_mesh(me); bm.free()
    return lab2, n
W,own,ed,P=skin(None)
lab2=None
for it in range(3):
    lab=make_labels(W,own,ed,P)
    if lab2 is not None:   # keep earlier part assignment where it exists
        lab=np.where(lab2!=0, lab2, lab)
    lab2,n=cut_and_cap(lab)
    rep.setdefault("cut_edges",[]).append(n)
    W,own,ed,P=skin(lab2)
    if n==0: break
nv=len(me.vertices)
rep["label_counts"]={LAB[i]:int((lab2==i).sum()) for i in range(len(LAB))}
rep["max_influences"]=int((W>0).sum(1).max()); rep["unweighted_after"]=int((W.sum(1)<0.99).sum())
for g in list(lo.vertex_groups): lo.vertex_groups.remove(g)
for k,n in enumerate(names):
    g=lo.vertex_groups.new(name=n)
    nz=np.nonzero(W[:,k])[0]
    for i in nz: g.add([int(i)], float(W[i,k]), 'REPLACE')
rep["bone_vertex_counts"]={n:int((W[:,k]>0.05).sum()) for k,n in enumerate(names)}
rep["low_verts_after_cut"]=nv; rep["low_tris_after_cut"]=sum(len(p.vertices)-2 for p in me.polygons)
np.save(os.path.join(work,"weights.npy"),W)
# --- joint range-of-motion test clip
def rot_world(pb, axis, deg):
    Mr=pb.bone.matrix_local.to_3x3()
    q=Quaternion(Vector(axis), math.radians(deg))
    ql=(Mr.inverted() @ q.to_matrix() @ Mr).to_quaternion()
    pb.rotation_mode='QUATERNION'; pb.rotation_quaternion=ql
pose=rig.pose.bones
def PB(n): return pose[rigdef.full_name(n)]
act=bpy.data.actions.new("_ROM"); rig.animation_data_create(); rig.animation_data.action=act
POSES={
 0:{},
 10:{"LeftForeArm":((1,0,0),-100),"RightForeArm":((1,0,0),-100),"LeftArm":((1,0,0),-20),"RightArm":((1,0,0),-20)},
 20:{"LeftUpLeg":((1,0,0),-70),"RightUpLeg":((1,0,0),-70),"LeftLeg":((1,0,0),110),"RightLeg":((1,0,0),110)},
 30:{"LeftArm":((0,1,0),-60),"RightArm":((0,1,0),60),"LeftForeArm":((0,1,0),-20),"RightForeArm":((0,1,0),20)},
 40:{"Spine":((1,0,0),15),"Spine1":((1,0,0),15),"Spine2":((0,0,1),20),"LeftUpLeg":((1,0,0),-25),"RightUpLeg":((1,0,0),35),"RightLeg":((1,0,0),45)},
 50:{"Neck":((0,0,1),25),"Head":((0,0,1),30),"LeftHand":((1,0,0),-50),"RightHand":((0,1,0),40)},
 60:{**{f"Braid_{i:02d}":((0,1,0),-15) for i in range(1,6)}, **{f"Cape_{c}_{i:02d}":((1,0,0),15) for c in "BLR" for i in range(1,3)}},
 70:{**{f"Skirt_{s}_{i:02d}":((1,0,0),-20) for s in ("FL","FR","L","R") for i in range(1,3)}, **{f"Skirt_B_{i:02d}":((1,0,0),20) for i in range(1,3)}},
 80:{**{f"{sd}Hand{f}{k}":((0,1,0),(55 if sd=="Left" else -55)) for sd in ("Left","Right") for f in ("Index","Middle","Ring","Pinky") for k in (1,2,3)},
     **{f"{sd}HandThumb{k}":((0,0,1),(-30 if sd=="Left" else 30)) for sd in ("Left","Right") for k in (1,2,3)}},
}
for f,pd in POSES.items():
    for pb in pose:
        pb.rotation_mode='QUATERNION'; pb.rotation_quaternion=(1,0,0,0)
    for n,(ax,deg) in pd.items():
        if rigdef.full_name(n) in pose: rot_world(PB(n), ax, deg)
    for pb in pose: pb.keyframe_insert("rotation_quaternion", frame=f)
dom=np.argmax(W,1)
def eval_co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
sc.frame_set(0); C0=eval_co(); E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1)
diag={}
for f in sorted(POSES):
    if f==0: continue
    sc.frame_set(f); C=eval_co(); r=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)/np.maximum(E0,1e-9); r[E0<2e-3]=1.0
    bad=np.where(r>2.5)[0]
    pairs={}
    for e in bad:
        a,b=names[dom[ed[e,0]]],names[dom[ed[e,1]]]
        k=" | ".join(sorted((a.replace("mixamorig:",""),b.replace("mixamorig:",""))))
        pairs[k]=pairs.get(k,0)+1
    diag[f]={"max":round(float(r.max()),2),"edges>2.5":int(len(bad)),"pairs":dict(sorted(pairs.items(),key=lambda x:-x[1])[:8]),
             "bad_z":[round(float(C0[ed[bad,0],2].min()),2),round(float(C0[ed[bad,0],2].max()),2)] if len(bad) else None}
rep["rom_stretch"]=diag
mov={}
for f in (40,60):
    sc.frame_set(f); C=eval_co(); dsp=np.linalg.norm(C-C0,axis=1)
    m=np.where((C0[:,2]<0.2)&(dsp>0.12))[0]
    cnt={}
    for i in m: cnt[names[dom[i]]]=cnt.get(names[dom[i]],0)+1
    mov[f]={"n":int(len(m)),"bones":cnt,"lab":{LAB[k]:int((lab2[m]==k).sum()) for k in range(len(LAB))} if len(m) else {},
            "pos":C0[m].mean(0).round(3).tolist() if len(m) else None}
rep["low_movers"]=mov
sc.frame_set(0)
for pb in pose:
    pb.rotation_quaternion=(1,0,0,0)
rep["t_total"]=round(time.time()-t0,1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work,"s3_rigged.blend"))
json.dump(rep, open(os.path.join(work,"s3_report.json"),"w"), indent=1)
# --- previews: weights (dominant bone colour) and ROM poses
setup_render(samples=8)
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 512, 683
labpal=np.array([[0.8,0.8,0.8],[0.55,0.2,0.75],[0.2,0.7,0.3],[1.0,0.45,0.1],[0.2,0.5,1.0],[0.1,0.9,0.9],[0.9,0.9,0.2]])
cols=np.concatenate([labpal[lab2],np.ones((nv,1))],1).astype(np.float32)
pa=me.attributes.new("part",'INT','POINT'); pa.data.foreach_set("value",lab2.astype(np.int32))
ca=me.color_attributes.new("wdom",'FLOAT_COLOR','POINT'); ca.data.foreach_set("color",cols.ravel())
wm=bpy.data.materials.new("wview"); wm.use_nodes=True
at=wm.node_tree.nodes.new("ShaderNodeAttribute"); at.attribute_name="wdom"
wm.node_tree.links.new(at.outputs[0], wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
orig=me.materials[0]; me.materials[0]=wm
sc.frame_set(0)
views(os.path.join(work,"s3_w"), (0,0,0.75), 1.6, ("front","back","side","lside","q"))
me.materials[0]=orig
for f in (10,20,30,40,50,60,70,80):
    sc.frame_set(f)
    views(os.path.join(work,f"s3_rom{f:02d}"), (0,0,0.75), 1.6, ("front","side","q"))
print("REPORT", json.dumps(rep)[:3000])
