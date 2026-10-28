# Step 4 (Elira): bow clips + role test clips (Idle/Walk/Attack/Cast/Hit/Dodge/Death), deformation stats, neris.blend + neris.glb, re-import check.
import bpy, sys, os, json, math, time, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import rigdef
from mathutils import Vector, Matrix, Quaternion, Euler
argv = sys.argv[sys.argv.index("--")+1:]
src_blend, work, out_blend, out_glb = argv[0], argv[1], argv[2], argv[3]
os.makedirs(work, exist_ok=True); os.makedirs(os.path.dirname(out_glb), exist_ok=True)
rep={}; t0=time.time()
bpy.ops.wm.open_mainfile(filepath=src_blend)
sc=bpy.context.scene; sc.render.fps=30
rig=bpy.data.objects["Elira_Rig"]; lo=bpy.data.objects["Elira"]
pose=rig.pose.bones
FN=rigdef.full_name
for pb in pose: pb.rotation_mode='QUATERNION'
REST={pb.name: pb.bone.matrix_local.to_3x3() for pb in pose}
def world_q(d):
    R=Matrix.Identity(3)
    for ax in ('X','Y','Z'):
        a=d.get(ax,0.0)
        if a: R=Matrix.Rotation(math.radians(a),3,ax) @ R
    return R
def apply_pose(P):
    for pb in pose:
        pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
    for n,d in P.items():
        b=FN(n)
        if b not in pose: continue
        pb=pose[b]; Mr=REST[b]
        pb.rotation_quaternion=(Mr.inverted() @ world_q(d) @ Mr).to_quaternion()
        if 'loc' in d: pb.location=Mr.inverted() @ Vector(d['loc'])
def key_all(f):
    for pb in pose:
        pb.keyframe_insert("rotation_quaternion", frame=f)
        if pb.name==FN("Hips"): pb.keyframe_insert("location", frame=f)
def new_action(name):
    a=bpy.data.actions.new(name); a.use_fake_user=True
    rig.animation_data_create(); rig.animation_data.action=a
    return a
def add(P, n, ax, v):
    P.setdefault(n,{}); P[n][ax]=P[n].get(ax,0)+v
def sec_motion(P, t, amp=1.0, tail=1.0, hair=1.0, cyc=1):
    w=2*math.pi*t*cyc
    for i in range(1,6):
        add(P,f"Braid_{i:02d}",'Y', hair*amp*2.0*math.sin(w-i*0.45))
        add(P,f"Braid_{i:02d}",'X', hair*amp*1.5*math.sin(w*2-i*0.4))
    for c in "BLR":
        for i in range(1,3): add(P,f"Cape_{c}_{i:02d}",'X', tail*amp*1.2*math.sin(w-i*0.4))
def smooth(x): return x*x*(3-2*x)
def lerp_pose(A,B,t):
    P={}
    for n in set(A)|set(B):
        a=A.get(n,{}); b=B.get(n,{}); d={}
        for ax in ('X','Y','Z'):
            v=a.get(ax,0)*(1-t)+b.get(ax,0)*t
            if v: d[ax]=v
        la=Vector(a.get('loc',(0,0,0))); lb=Vector(b.get('loc',(0,0,0)))
        if la.length or lb.length: d['loc']=tuple(la.lerp(lb,t))
        P[n]=d
    return P
def keyed_clip(name, keys, length, sec_amp=0.6):
    new_action(name)
    for f in range(0,length+1):
        for k in range(len(keys)-1):
            if keys[k][0]<=f<=keys[k+1][0]: break
        fa,A=keys[k]; fb,B=keys[k+1]
        t=smooth((f-fa)/max(fb-fa,1))
        P=lerp_pose(A,B,t)
        sec_motion(P, f/length, amp=sec_amp)
        apply_pose(P); key_all(f)
    return name
# ---------------- neutral stance used as start/end of one-shots (relaxed arms)
NEUTRAL={"LeftForeArm":{'X':-8},"RightForeArm":{'X':-8},"LeftHand":{'X':-8},"RightHand":{'X':-8}}
CLIPS={}
# Idle 2 s loop
new_action("Idle"); L=60
for f in range(L+1):
    t=f/L; b=math.sin(2*math.pi*t)
    P=json.loads(json.dumps(NEUTRAL))
    add(P,"Spine1",'X',1.2*b); add(P,"Spine2",'X',-0.8*b); add(P,"Neck",'X',-0.6*b)
    add(P,"Head",'X',1.2*math.sin(2*math.pi*t+1.0)); add(P,"Head",'Z',1.5*math.sin(2*math.pi*t+0.3))
    add(P,"LeftArm",'Y',-1.5*b); add(P,"RightArm",'Y',1.5*b)
    add(P,"LeftForeArm",'X',-2*b); add(P,"RightForeArm",'X',-2*b)
    P.setdefault("Hips",{})['loc']=(0,0,-0.003*(1+b)/2)
    sec_motion(P,t,amp=1.0)
    apply_pose(P); key_all(f)
CLIPS["Idle"]=dict(frames=L, loop=True)
# Walk 0.8 s loop (in place)
new_action("Walk"); L=24
for f in range(L+1):
    t=f/L; p=2*math.pi*t; s=math.sin(p); c=math.cos(p)
    P={}
    thL=-24*s-3; thR=24*s-3
    knL=6+48*max(0,c)**1.5+6*max(0,-c); knR=6+48*max(0,-c)**1.5+6*max(0,c)
    add(P,"LeftUpLeg",'X',thL); add(P,"RightUpLeg",'X',thR)
    add(P,"LeftLeg",'X',knL); add(P,"RightLeg",'X',knR)
    add(P,"LeftFoot",'X',-0.75*(thL+knL)+8*max(0,-s)); add(P,"RightFoot",'X',-0.75*(thR+knR)+8*max(0,s))
    add(P,"Hips",'Z',5*s); add(P,"Hips",'Y',-2.5*s); add(P,"Hips",'X',3)
    P["Hips"]['loc']=(0,0,0.010*math.cos(2*p)-0.012)
    add(P,"Spine",'X',2); add(P,"Spine1",'Z',-3.5*s); add(P,"Spine2",'Z',-2*s)
    add(P,"Head",'Z',2*s); add(P,"Head",'X',-3)
    add(P,"LeftArm",'X',16*s); add(P,"RightArm",'X',-16*s)
    add(P,"LeftArm",'Y',8); add(P,"RightArm",'Y',-8)
    add(P,"LeftForeArm",'X',-14-10*max(0,-s)); add(P,"RightForeArm",'X',-14-10*max(0,s))
    add(P,"LeftHand",'X',-8); add(P,"RightHand",'X',-8)
    for i,(sk,th) in enumerate((("Skirt_L",thL),("Skirt_R",thR))):
        add(P,f"{sk}_01",'X',0.3*th); add(P,f"{sk}_02",'X',0.12*th)
    add(P,"Skirt_F_01",'X',-0.3*abs(s)*10); add(P,"Skirt_B_01",'X',4+3*math.cos(2*p))
    for i in range(1,8): add(P,f"Tail_{i:02d}",'Z',9*math.sin(p-i*0.55)); add(P,f"Tail_{i:02d}",'X',3*math.sin(2*p-i*0.5))
    for sd in "CLR":
        for i in range(1,5): add(P,f"Hair_Back_{sd}_{i:02d}",'X',1.5+1.8*math.sin(2*p-i*0.35))
    for sd in "LR":
        for i in range(1,4): add(P,f"Hair_Side_{sd}_{i:02d}",'X',1.5+1.8*math.sin(2*p-(i+0.5)*0.35)); add(P,f"Hair_Lock_{sd}_{i:02d}",'X',1.5+1.8*math.sin(2*p-(i+0.5)*0.35))
    apply_pose(P); key_all(f)
CLIPS["Walk"]=dict(frames=L, loop=True)
# Cast loop 1 s (both hands gathering energy in front of the chest)
CAST={"LeftArm":{'X':-52,'Y':14},"RightArm":{'X':-52,'Y':-14},"LeftForeArm":{'X':-55,'Y':-10},"RightForeArm":{'X':-55,'Y':10},
      "LeftHand":{'X':12},"RightHand":{'X':12},"Spine1":{'X':-3},"Spine2":{'X':-3},"Head":{'X':4},
      **{f"Hair_{c}_{i:02d}":{'X':4} for c in ("Back_C","Back_L","Back_R","Side_L","Side_R","Lock_L","Lock_R") for i in range(1,5)}}
new_action("Cast"); L=30
for f in range(L+1):
    t=f/L; b=math.sin(2*math.pi*t)
    P=json.loads(json.dumps(CAST))
    add(P,"LeftArm",'X',-3*b); add(P,"RightArm",'X',-3*math.sin(2*math.pi*t+0.8))
    add(P,"LeftForeArm",'Y',-4*b); add(P,"RightForeArm",'Y',4*b)
    P.setdefault("Hips",{})['loc']=(0,0,0.006*b)
    sec_motion(P,t,amp=1.6)
    apply_pose(P); key_all(f)
CLIPS["Cast"]=dict(frames=L, loop=True)
# one-shots
RELEASE={"LeftArm":{'X':-82,'Y':6},"RightArm":{'X':-82,'Y':-6},"LeftForeArm":{'X':-8},"RightForeArm":{'X':-8},
         "LeftHand":{'X':-25},"RightHand":{'X':-25},"Spine1":{'X':9},"Spine2":{'X':5},"Head":{'X':-4},"Hips":{'loc':(0,-0.02,0)},
         **{f"Hair_{c}_{i:02d}":{'X':8} for c in ("Back_C","Back_L","Back_R","Side_L","Side_R","Lock_L","Lock_R") for i in range(1,5)}, **{f"Tail_{i:02d}":{'X':-6} for i in range(1,8)}}
keyed_clip("Cast_Release",[(0,CAST),(5,RELEASE),(10,RELEASE),(18,NEUTRAL)],18); CLIPS["Cast_Release"]=dict(frames=18, loop=False)
WIND={**NEUTRAL,"RightArm":{'X':20,'Y':-25},"RightForeArm":{'X':-75},"RightHand":{'X':15},"Spine2":{'Z':12},"Spine1":{'Z':6},"Hips":{'Z':4},"LeftArm":{'X':-10},"Head":{'Z':-6}}
STRIKE={**NEUTRAL,"RightArm":{'X':-75,'Y':-10},"RightForeArm":{'X':-8},"RightHand":{'X':-20},"Spine2":{'Z':-14},"Spine1":{'Z':-6,'X':6},"Hips":{'Z':-4,'loc':(0,-0.015,0)},"LeftArm":{'X':12},"Head":{'Z':5}}
keyed_clip("Attack",[(0,NEUTRAL),(9,WIND),(13,STRIKE),(17,STRIKE),(26,NEUTRAL)],26); CLIPS["Attack"]=dict(frames=26, loop=False)
HIT={"Spine1":{'X':-12},"Spine2":{'X':-9},"Neck":{'X':-6},"Head":{'X':-12,'Z':6},"LeftArm":{'Y':-14,'X':-10},"RightArm":{'Y':14,'X':-10},
     "LeftForeArm":{'X':-30},"RightForeArm":{'X':-30},"Hips":{'loc':(0,0.025,-0.01)},"LeftUpLeg":{'X':-6},"RightUpLeg":{'X':-6},"LeftLeg":{'X':10},"RightLeg":{'X':10},
     **{f"Tail_{i:02d}":{'X':-10} for i in range(1,8)}}
keyed_clip("Hit",[(0,NEUTRAL),(4,HIT),(15,NEUTRAL)],15,sec_amp=1.2); CLIPS["Hit"]=dict(frames=15, loop=False)
DODGE={"Hips":{'loc':(0,0.09,-0.05),'X':-6},"Spine1":{'X':-10},"Spine2":{'X':-6},"Head":{'X':-6},"LeftUpLeg":{'X':-24},"RightUpLeg":{'X':-10},
       "LeftLeg":{'X':40},"RightLeg":{'X':30},"LeftFoot":{'X':-14},"RightFoot":{'X':-18},"LeftArm":{'Y':-28,'X':-12},"RightArm":{'Y':28,'X':-12},
       "LeftForeArm":{'X':-25},"RightForeArm":{'X':-25},**{f"Hair_{c}_{i:02d}":{'X':-6} for c in ("Back_C","Back_L","Back_R","Side_L","Side_R","Lock_L","Lock_R") for i in range(1,5)}}
keyed_clip("Dodge",[(0,NEUTRAL),(6,DODGE),(10,DODGE),(18,NEUTRAL)],18); CLIPS["Dodge"]=dict(frames=18, loop=False)
D1={"Spine1":{'X':-10},"Head":{'X':-10},"Hips":{'loc':(0,0.03,0)},"LeftArm":{'Y':-10},"RightArm":{'Y':10},"LeftForeArm":{'X':-20},"RightForeArm":{'X':-20}}
D2={"Hips":{'loc':(0,0.03,-0.12),'X':5},"LeftUpLeg":{'X':-30},"RightUpLeg":{'X':-24},"LeftLeg":{'X':60},"RightLeg":{'X':52},"LeftFoot":{'X':-25},"RightFoot":{'X':-22},
    "Spine":{'X':12},"Spine1":{'X':8},"Head":{'X':14},"LeftArm":{'X':-20,'Y':6},"RightArm":{'X':-20,'Y':-6},"LeftForeArm":{'X':-40},"RightForeArm":{'X':-40}}
D3={"Hips":{'loc':(0,0.04,-0.20),'X':10,'Y':-4},"Skirt_F_01":{'X':-45},"Skirt_B_01":{'X':45},"Skirt_L_01":{'Y':-35},"Skirt_R_01":{'Y':35},"Skirt_L_02":{'Y':-15},"Skirt_R_02":{'Y':15},"LeftUpLeg":{'X':-10},"RightUpLeg":{'X':-6},"LeftLeg":{'X':92},"RightLeg":{'X':88},"LeftFoot":{'X':-8},"RightFoot":{'X':-8},
    "Spine":{'X':6},"Spine1":{'X':5},"Spine2":{'X':3},"Neck":{'X':6},"Head":{'X':14,'Z':-12},"LeftArm":{'X':-6,'Y':10},"RightArm":{'X':-8,'Y':-8},
    "LeftForeArm":{'X':-20},"RightForeArm":{'X':-15},"LeftHand":{'X':10},"RightHand":{'X':10},
    **{f"Hair_{c}_{i:02d}":{'X':-10 if i==1 else -3} for c in ("Back_C","Back_L","Back_R","Side_L","Side_R","Lock_L","Lock_R") for i in range(1,5)}, **{f"Tail_{i:02d}":{'X':4,'Z':5} for i in range(1,8)}}
keyed_clip("Death",[(0,NEUTRAL),(8,D1),(20,D2),(34,D3),(45,D3)],45,sec_amp=0.4); CLIPS["Death"]=dict(frames=45, loop=False)
exec(open(os.path.join(os.path.dirname(__file__),"bow_clips.py"),encoding="utf-8").read())
# rest pose for the file
apply_pose({}); rig.animation_data.action=None
for pb in pose: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
# ---------------- deformation stats (triangle area / edge stretch vs bind pose)
me=lo.data; me.calc_loop_triangles()
tri=np.array([t.vertices[:] for t in me.loop_triangles])
ed=np.array([e.vertices[:] for e in me.edges])
def eval_co():
    dg=bpy.context.evaluated_depsgraph_get(); ev=lo.evaluated_get(dg); m=ev.to_mesh()
    a=np.empty(len(m.vertices)*3,np.float32); m.vertices.foreach_get("co",a); ev.to_mesh_clear(); return a.reshape(-1,3)
def areas(C):
    return 0.5*np.linalg.norm(np.cross(C[tri[:,1]]-C[tri[:,0]],C[tri[:,2]]-C[tri[:,0]]),axis=1)
sc.frame_set(0); C0=eval_co(); A0=areas(C0); E0=np.linalg.norm(C0[ed[:,0]]-C0[ed[:,1]],axis=1)
stats={}
acts=["_ROM"]+list(CLIPS)
for an in acts:
    act=bpy.data.actions.get(an)
    if not act: continue
    rig.animation_data.action=act
    fr=act.frame_range; worst=dict(stretch=1.0,shrink=1.0,bad_tris=0,frame=0)
    for f in range(int(fr[0]),int(fr[1])+1,2):
        sc.frame_set(f); C=eval_co(); A=areas(C); E=np.linalg.norm(C[ed[:,0]]-C[ed[:,1]],axis=1)
        r=E/np.maximum(E0,1e-9); r[E0<2e-3]=1; ar=A/np.maximum(A0,1e-12); ar[A0<2e-6]=1
        bad=int(((ar<0.25)|(ar>3.0)).sum()); long=int(((r>3)&(E>0.03)).sum())
        if r.max()>worst["stretch"] or bad>worst["bad_tris"]:
            worst=dict(stretch=round(float(r.max()),2),shrink=round(float(r.min()),2),bad_tris=bad,frame=f,
                       p99_stretch=round(float(np.percentile(r,99.9)),2),min_z=round(float(C[:,2].min()),3),long_edges=long)
    stats[an]=worst
rep["deformation"]=stats
rig.animation_data.action=None; sc.frame_set(0)
for pb in pose: pb.rotation_quaternion=(1,0,0,0); pb.location=(0,0,0)
rep["clips"]=CLIPS
# ---------------- save neris.blend (keeps _ROM)
for a in bpy.data.actions:
    a.use_fake_user=True
rig.data.pose_position='POSE'
for m in bpy.data.materials:
    if m.name=='M_Elira': m.use_backface_culling=False
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
# ---------------- export GLB (role clips only, deform bones only)
rom=bpy.data.actions.get("_ROM")
if rom: bpy.data.actions.remove(rom)
for o in list(sc.objects):
    if o not in (rig,lo): bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', use_selection=True, export_apply=False,
    export_skins=True, export_all_influences=False, export_def_bones=True, export_rest_position_armature=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_range=False,
    export_anim_single_armature=True, export_reset_pose_bones=True, export_optimize_animation_size=True,
    export_image_format='AUTO', export_materials='EXPORT', export_tangents=False, export_yup=True)
rep["glb_bytes"]=os.path.getsize(out_glb)
# ---------------- re-import check
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=out_glb)
objs=bpy.context.scene.objects
arms=[o for o in objs if o.type=='ARMATURE']; meshes=[o for o in objs if o.type=='MESH']
chk={"armatures":len(arms),"meshes":len(meshes)}
if arms:
    a=arms[0]; chk["bones"]=len(a.data.bones); chk["root_bones"]=[b.name for b in a.data.bones if not b.parent]
if meshes:
    m=meshes[0]; dg=bpy.context.evaluated_depsgraph_get(); ev=m.evaluated_get(dg); mm=ev.to_mesh()
    co=np.array([(m.matrix_world@v.co)[:] for v in mm.vertices]); ev.to_mesh_clear()
    chk["tris"]=sum(len(p.vertices)-2 for p in m.data.polygons); chk["bounds"]=[co.min(0).round(4).tolist(), co.max(0).round(4).tolist()]
    chk["materials"]=[s.material.name for s in m.material_slots]; chk["vgroups"]=len(m.vertex_groups)
    chk["max_influences"]=max(len(v.groups) for v in m.data.vertices)
chk["images"]=[(i.name,list(i.size)) for i in bpy.data.images]
chk["actions"]={a.name:[round(a.frame_range[0]),round(a.frame_range[1])] for a in bpy.data.actions}
rep["reimport"]=chk
rep["t_total"]=round(time.time()-t0,1)
json.dump(rep, open(os.path.join(work,"s4_report.json"),"w"), indent=1)
# ---------------- preview sheets of the clips (re-open the saved blend)
bpy.ops.wm.open_mainfile(filepath=out_blend)
sc=bpy.context.scene; rig=bpy.data.objects["Elira_Rig"]
setup_render(samples=8)
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 384, 512
for an,info in json.load(open(os.path.join(work,"s4_report.json")))["clips"].items():
    rig.animation_data.action=bpy.data.actions[an]
    n=info["frames"]
    for k,f in enumerate([0,n//4,n//2,3*n//4] if info["loop"] else [n//3,n//2,2*n//3,n]):
        sc.frame_set(f)
        shoot(os.path.join(work,f"clip_{an}_{k}_q.png"),(0,0,0.7),1.7,(0.75,-0.65,0.2))
        shoot(os.path.join(work,f"clip_{an}_{k}_s.png"),(0,0,0.7),1.7,(1,0,0.05))
print("REPORT", json.dumps(rep)[:4000])
