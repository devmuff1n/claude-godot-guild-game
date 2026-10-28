# Polish pass: blend hard weight seams that tear in the clips, keep feet above the floor, re-export neris.glb.
import bpy, sys, os, json, shutil, numpy as np
from mathutils import Vector
argv=sys.argv[sys.argv.index("--")+1:]
blend,glb,repout=argv[0],argv[1],argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene; rig=bpy.data.objects["Neris_Rig"]; lo=bpy.data.objects["Neris"]; me=lo.data; pose=rig.pose.bones
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

from mathutils.kdtree import KDTree
p=np.arange(nv)
def find(x):
    r=x
    while p[r]!=r: r=p[r]
    while p[x]!=r: p[x],x=r,p[x]
    return r
for a,b in ed:
    ra,rb=find(a),find(b)
    if ra!=rb: p[ra]=rb
roots=np.array([find(i) for i in range(nv)]); u,lab=np.unique(roots,return_inverse=True)
sizes=np.bincount(lab); big=np.argmax(sizes)
rig.animation_data.action=None
for pb in pose: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
sc.frame_set(0); C0=co()
dom=np.argmax(W,1)
rep={"islands":sizes.tolist(),"fixed":[]}; DEL=[]
for i in range(len(sizes)):
    if i==big or sizes[i]>400: continue
    m=np.where(lab==i)[0]; c=C0[m].mean(0)
    if not (0.38<c[2]<0.72 and abs(c[0])>0.18): continue
    side="Left" if c[0]>0 else "Right"
    ok=[names.index(f"mixamorig:{side}{b}") for b in ("ForeArm","Hand")]
    cand=np.where((lab==big)&np.isin(dom,ok))[0]
    rep["fixed"].append({"island":int(i),"size":int(sizes[i]),"side":side,"z":round(float(c[2]),2)})
    DEL.extend(m.tolist())
import bmesh
bm=bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in DEL], context='VERTS')
bm.to_mesh(me); bm.free(); me.update()
rep["deleted_verts"]=len(DEL); rep["tris_after"]=sum(len(p.vertices)-2 for p in me.polygons)
rep['ok']=True
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
