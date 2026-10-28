# Polish pass: blend hard weight seams that tear in the clips, keep feet above the floor, re-export elira.glb.
import bpy, sys, os, json, shutil, numpy as np
from mathutils import Vector
argv=sys.argv[sys.argv.index("--")+1:]
blend,glb,repout=argv[0],argv[1],argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Elira_Rig"]; lo=bpy.data.objects["Elira"]; me=lo.data; pose=rig.pose.bones
names=[g.name for g in lo.vertex_groups]; nv=len(me.vertices); B=len(names)
W=np.zeros((nv,B),np.float32)
for v in me.vertices:
    for g in v.groups: W[v.index,g.group]=g.weight
ed=np.array([e.vertices[:] for e in me.edges])
def co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
def rest():
    rig.animation_data.action=None
    for pb in pose: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
    sc.frame_set(0)
def write_weights(W):
    for k,n in enumerate(names):
        g=lo.vertex_groups[n]; g.remove(list(range(nv)))
        nz=np.nonzero(W[:,k])[0]
        for i in nz: g.add([int(i)], float(W[i,k]), 'REPLACE')
ACTS=[a for a in bpy.data.actions if not a.name.startswith("_")]
def scan(thr=2.2):
    rest(); C0=co(); E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1)
    bad=set(); per={}; minz={}
    for a in ACTS:
        rig.animation_data.action=a; f0,f1=map(int,a.frame_range); worst=0; mz=9
        for f in range(f0,f1+1):
            sc.frame_set(f); C=co(); E=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)
            b=np.where((E>thr*np.maximum(E0,1e-9))&(E>0.02))[0]; bad.update(b.tolist())
            strong=int(((E>3*np.maximum(E0,1e-9))&(E>0.03)).sum()); worst=max(worst,strong); mz=min(mz,float(C[:,2].min()))
        per[a.name]=worst; minz[a.name]=round(mz,3)
    rest(); return np.array(sorted(bad),int), per, minz
rep={}
bad,per,minz=scan(); rep["before"]={"long_edges":per,"min_z":minz,"seam_edges":int(len(bad))}
nbr_acc=lambda X: (np.add.at(acc:=np.zeros_like(X),ed[:,0],X[ed[:,1]]), np.add.at(acc,ed[:,1],X[ed[:,0]]), acc)[2]
cnt=np.zeros(nv); np.add.at(cnt,ed[:,0],1); np.add.at(cnt,ed[:,1],1); cnt=np.maximum(cnt,1)[:,None]
for rnd in range(3):
    if len(bad)==0: break
    band=np.zeros(nv,bool); band[ed[bad].ravel()]=True
    for r in range(3):   # grow the band a few rings
        g=band.copy(); g[ed[band[ed[:,0]],1]]=True; g[ed[band[ed[:,1]],0]]=True; band=g
    for it in range(25):
        Wn=0.5*W+0.5*nbr_acc(W)/cnt
        W[band]=Wn[band]
    W/=np.maximum(W.sum(1,keepdims=True),1e-9)
    order=np.argsort(-W,1); keep=np.zeros_like(W,bool); np.put_along_axis(keep,order[:,:4],True,1)
    W=np.where(keep&(W>0.01),W,0); W/=np.maximum(W.sum(1,keepdims=True),1e-9)
    write_weights(W)
    bad,per,minz=scan(); rep[f"round{rnd+1}"]={"long_edges":per,"band_verts":int(band.sum()),"seam_edges":int(len(bad))}
# feet / body never below the floor: lift Hips per frame by the deficit
hips=pose["mixamorig:Hips"]; Mr=hips.bone.matrix_local.to_3x3()
lift={}
for a in ACTS:
    rig.animation_data.action=a; f0,f1=map(int,a.frame_range); mx=0
    for f in range(f0,f1+1):
        sc.frame_set(f); z=float(co()[:,2].min())
        if z<0:
            d=Mr.inverted()@Vector((0,0,-z+0.002)); hips.location=hips.location+d
            hips.keyframe_insert("location",frame=f); mx=max(mx,-z)
    lift[a.name]=round(mx,3)
rest(); rep["floor_lift_m"]=lift
bad,per,minz=scan(); rep["after"]={"long_edges":per,"min_z":minz,"max_influences":int((W>0).sum(1).max())}
for a in bpy.data.actions: a.use_fake_user=True
bpy.ops.wm.save_as_mainfile(filepath=blend)
rom=bpy.data.actions.get("_ROM")
if rom: bpy.data.actions.remove(rom)
for o in list(sc.objects):
    if o not in (rig,lo): bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_apply=False,
    export_skins=True, export_all_influences=False, export_def_bones=True, export_rest_position_armature=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_range=False,
    export_anim_single_armature=True, export_reset_pose_bones=True, export_optimize_animation_size=True,
    export_image_format='AUTO', export_materials='EXPORT', export_tangents=False, export_yup=True)
rep["glb_bytes"]=os.path.getsize(glb)
json.dump(rep,open(repout,"w"),indent=1)
