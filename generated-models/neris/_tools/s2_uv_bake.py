# Step 2: recentre, clean, UV-unwrap the QuadriFlow mesh and bake colour / normal / roughness / metal / AO from the Tripo high-poly.
import bpy, sys, os, json, math, time, bmesh, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
src_blend, work, texdir = argv[0], argv[1], argv[2]
BC_RES=int(argv[3]) if len(argv)>3 else 2048
AUX_RES=int(argv[4]) if len(argv)>4 else 1024
UV_ANGLE=float(argv[7]) if len(argv)>7 else 80
os.makedirs(work, exist_ok=True); os.makedirs(texdir, exist_ok=True)
rep={}; t0=time.time()
bpy.ops.wm.open_mainfile(filepath=src_blend)
sc=bpy.context.scene
hi=bpy.data.objects["Neris_High"]; lo=bpy.data.objects["Neris"]
for o in list(sc.objects):
    if o.type!='MESH': bpy.data.objects.remove(o)
# --- recentre: midpoint between the feet -> origin
co=np.array([v.co[:] for v in lo.data.vertices])
f=co[co[:,2]<0.07]; mx=np.median(f[:,0])
c1=f[f[:,0]<mx].mean(0); c2=f[f[:,0]>=mx].mean(0)
shift=Vector((-(c1[0]+c2[0])/2, -(c1[1]+c2[1])/2, -co[:,2].min()))
rep["recentre_shift"]=list(shift)
for o in (hi,lo):
    o.location=shift
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# --- drop tiny islands of the low mesh
bm=bmesh.new(); bm.from_mesh(lo.data); bm.verts.ensure_lookup_table()
seen=set(); kill=[]
for v in bm.verts:
    if v.index in seen: continue
    st=[v]; comp=[]; seen.add(v.index)
    while st:
        a=st.pop(); comp.append(a)
        for e in a.link_edges:
            b=e.other_vert(a)
            if b.index not in seen: seen.add(b.index); st.append(b)
    if len(comp)<200: kill+=comp
rep["removed_island_verts"]=len(kill)
bmesh.ops.delete(bm, geom=kill, context='VERTS')
bm.to_mesh(lo.data); bm.free()
lo.name="Neris"; lo.data.name="Neris_Mesh"
for p in lo.data.polygons: p.use_smooth=True
# --- UV: smart project, then give the face more texels, then pack
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
while lo.data.uv_layers: lo.data.uv_layers.remove(lo.data.uv_layers[0])
lo.data.uv_layers.new(name="UVMap")
# region-growing charts (normal cone + size cap) -> seams -> angle-based unwrap
bm=bmesh.new(); bm.from_mesh(lo.data); bm.faces.ensure_lookup_table()
FN=[f.normal.copy() for f in bm.faces]; NF=len(bm.faces)
chart=[-1]*NF; CONE=math.cos(math.radians(UV_ANGLE)); MAXF=1800
order=sorted(range(NF), key=lambda i: -bm.faces[i].calc_center_median().z)
charts=[]
from collections import deque
for s0 in order:
    if chart[s0]>=0: continue
    k=len(charts); q=deque([s0]); chart[s0]=k; mem=[s0]; nsum=FN[s0].copy()
    while q and len(mem)<MAXF:
        i=q.popleft(); mean=nsum.normalized()
        for e in bm.faces[i].edges:
            for g in e.link_faces:
                j=g.index
                if chart[j]>=0: continue
                if FN[j].dot(mean)>CONE and FN[j].dot(FN[i])>0.5:
                    chart[j]=k; mem.append(j); nsum+=FN[j]; q.append(j)
    charts.append(mem)
# merge tiny charts into the neighbour sharing most edges
for it in range(3):
    sizes=[len(c) for c in charts]
    for k,mem in enumerate(charts):
        if not mem or len(mem)>=40: continue
        cnt={}
        for i in mem:
            for e in bm.faces[i].edges:
                for g in e.link_faces:
                    c=chart[g.index]
                    if c!=k: cnt[c]=cnt.get(c,0)+1
        if not cnt: continue
        tgt=max(cnt,key=cnt.get)
        for i in mem: chart[i]=tgt
        charts[tgt]+=mem; charts[k]=[]
rep["uv_charts"]=sum(1 for c in charts if c)
for e in bm.edges:
    lf=e.link_faces
    e.seam = len(lf)==2 and chart[lf[0].index]!=chart[lf[1].index]
bm.to_mesh(lo.data); bm.free()
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.unwrap(method='ANGLE_BASED', fill_holes=True, correct_aspect=True, margin=0.0)
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.average_islands_scale()
bpy.ops.object.mode_set(mode='OBJECT')
bm=bmesh.new(); bm.from_mesh(lo.data); uvl=bm.loops.layers.uv.active
bm.faces.ensure_lookup_table()
# islands = faces connected through edges whose uvs agree on both sides
fid={f.index:-1 for f in bm.faces}; isl=[]
def same(e):
    ls=e.link_loops
    if len(ls)!=2: return False
    a,b=ls
    ua1=a[uvl].uv; ua2=a.link_loop_next[uvl].uv
    ub1=b[uvl].uv; ub2=b.link_loop_next[uvl].uv
    return (ua1-ub2).length<1e-5 and (ua2-ub1).length<1e-5
for f in bm.faces:
    if fid[f.index]>=0: continue
    k=len(isl); st=[f]; fid[f.index]=k; mem=[]
    while st:
        g=st.pop(); mem.append(g)
        for e in g.edges:
            if not same(e): continue
            for h in e.link_faces:
                if fid[h.index]<0: fid[h.index]=k; st.append(h)
    isl.append(mem)
def face_zone(p):  # front of the face / eyes
    return p.z>0.80 and p.z<1.17 and p.y<-0.02 and abs(p.x)<0.19
boost=0
for mem in isl:
    cen=sum((f.calc_center_median() for f in mem), Vector())/len(mem)
    if face_zone(cen):
        s=2.0; boost+=1
        uc=sum((l[uvl].uv for f in mem for l in f.loops), Vector((0,0)))/sum(len(f.loops) for f in mem)
        for f in mem:
            for l in f.loops: l[uvl].uv=uc+(l[uvl].uv-uc)*s
bm.to_mesh(lo.data); bm.free()
rep["uv_islands"]=len(isl); rep["face_islands_boosted"]=boost
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.pack_islands(rotate=True, margin_method='SCALED', margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
# UV stats
bm=bmesh.new(); bm.from_mesh(lo.data); uvl=bm.loops.layers.uv.active
r3=[];ruv=[]
for f in bm.faces:
    a3=f.calc_area()
    uv=[l[uvl].uv for l in f.loops]
    au=0.0
    for i in range(1,len(uv)-1):
        au+=abs((uv[i]-uv[0]).cross(uv[i+1]-uv[0]))/2
    r3.append(a3); ruv.append(au)
r3=np.array(r3); ruv=np.array(ruv)
rep["uv_area_used"]=float(ruv.sum())
dens=np.sqrt(ruv/np.maximum(r3,1e-12))
rep["uv_texel_density_px_per_m_median"]=float(np.median(dens)*BC_RES)
rep["uv_density_p5_p95"]=[float(np.percentile(dens,5)*BC_RES), float(np.percentile(dens,95)*BC_RES)]
bm.free()
# --- bake setup
setup_render(samples=8)
sc.cycles.samples=8
sc.render.bake.use_selected_to_active=True
sc.render.bake.cage_extrusion=float(argv[5]) if len(argv)>5 else 0.02
sc.render.bake.max_ray_distance=float(argv[6]) if len(argv)>6 else 0.05
sc.render.bake.margin=16
def img(name, res, noncolor):
    im=bpy.data.images.get(name) or bpy.data.images.new(name, res, res, alpha=False, float_buffer=False)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    return im
mat=bpy.data.materials.new("M_Neris"); mat.use_nodes=True
lo.data.materials.clear(); lo.data.materials.append(mat)
N=mat.node_tree.nodes; L=mat.node_tree.links
bake_node=N.new("ShaderNodeTexImage"); bake_node.name="BAKE"
def bake(kind, im, **kw):
    bake_node.image=im; N.active=bake_node
    bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
    t=time.time(); bpy.ops.object.bake(type=kind, **kw); rep["t_bake_"+im.name]=round(time.time()-t,1)
hmat=hi.data.materials[0]; HN=hmat.node_tree.nodes; HL=hmat.node_tree.links
hbsdf=[n for n in HN if n.type=='BSDF_PRINCIPLED'][0]
out=[n for n in HN if n.type=='OUTPUT_MATERIAL'][0]
em=HN.new("ShaderNodeEmission"); em.inputs[1].default_value=1.0
orig_surface=out.inputs[0].links[0].from_socket
mlink=hbsdf.inputs["Metallic"].links
def arr(im):
    a=np.empty(im.size[0]*im.size[1]*4,np.float32); im.pixels.foreach_get(a); return a.reshape(im.size[1],im.size[0],4)
def bake_pass(tag, ext, ray):
    sc.render.bake.cage_extrusion=ext; sc.render.bake.max_ray_distance=ray
    sc.cycles.samples=8
    r={}
    for l in list(em.inputs[0].links): HL.remove(l)
    em.inputs[0].default_value=(1,1,1,1); HL.new(em.outputs[0], out.inputs[0])
    m_lo=img(f"bake_mask{tag}",AUX_RES,True); bake("EMIT", m_lo, margin=0); r["mask"]=arr(m_lo)[...,0]
    m_hi=img(f"bake_maskhi{tag}",BC_RES,True); bake("EMIT", m_hi, margin=0); r["mask_hi"]=arr(m_hi)[...,0]
    if mlink: HL.new(mlink[0].from_socket, em.inputs[0])
    else: em.inputs[0].default_value=(hbsdf.inputs["Metallic"].default_value,)*3+(1,)
    im=img(f"bake_metal{tag}",AUX_RES,True); bake("EMIT", im); r["metal"]=arr(im)[...,0]
    HL.new(orig_surface, out.inputs[0])
    im=img(f"bake_color{tag}",BC_RES,False); bake("DIFFUSE", im, pass_filter={'COLOR'}); r["bc"]=arr(im)
    im=img(f"bake_normal{tag}",AUX_RES,True); bake("NORMAL", im, normal_space='TANGENT'); r["n"]=arr(im)
    im=img(f"bake_rough{tag}",AUX_RES,True); bake("ROUGHNESS", im); r["rough"]=arr(im)[...,0]
    sc.cycles.samples=48
    im=img(f"bake_ao{tag}",AUX_RES,True); bake("AO", im); r["ao"]=arr(im)[...,0]
    return r
A=bake_pass("A", float(argv[5]) if len(argv)>5 else 0.006, 0.03)
Bp=bake_pass("B", float(argv[6]) if len(argv)>6 else 0.025, 0.07)
# UV coverage mask (islands rasterised) via a flat white emission bake of the low mesh itself
sc.render.bake.use_selected_to_active=False
tmpm=bpy.data.materials.new("cov"); tmpm.use_nodes=True
tn=tmpm.node_tree.nodes; tl=tmpm.node_tree.links; tn.clear()
eo=tn.new("ShaderNodeOutputMaterial"); ee=tn.new("ShaderNodeEmission"); ee.inputs[0].default_value=(1,1,1,1)
tl.new(ee.outputs[0], eo.inputs[0]); ti=tn.new("ShaderNodeTexImage"); cov=img("bake_cov",AUX_RES,True); ti.image=cov; tn.active=ti
lo.data.materials[0]=tmpm
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
bpy.ops.object.bake(type='EMIT', margin=0)
covA=arr(cov)[...,0]>0.5
lo.data.materials[0]=mat; sc.render.bake.use_selected_to_active=True
def pick(a,b,m):
    mm=m if a.ndim==2 else m[...,None]
    return np.where(mm,a,b)
mA=A["mask"]>0.5; mAh=A["mask_hi"]>0.5
mB=Bp["mask"]>0.5
rep["uv_coverage"]=float(covA.mean())
rep["hit_tight_pass"]=float((mA&covA).sum()/max(covA.sum(),1))
rep["hit_any_pass"]=float(((mA|mB)&covA).sum()/max(covA.sum(),1))
ao=pick(A["ao"],Bp["ao"],mA); rough=pick(A["rough"],Bp["rough"],mA); metal=pick(A["metal"],Bp["metal"],mA)
nrm=pick(A["n"],Bp["n"],mA); bc=pick(A["bc"],Bp["bc"],mAh)
mask=covA
# --- compose final maps
def up(a,res):
    if a.shape[0]==res: return a
    k=res//a.shape[0]; return np.repeat(np.repeat(a,k,0),k,1)
ao_up=up(ao[...,None],BC_RES)[...,0]
AO_IN_ALBEDO=0.4
bcf=bc.copy(); bcf[...,:3]*= (1-AO_IN_ALBEDO+AO_IN_ALBEDO*ao_up)[...,None]
def save(name, a, fmt, res, noncolor, quality=92):
    im=bpy.data.images.new(name, res, res, alpha=False)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    a=a.copy(); a[...,3]=1.0
    im.pixels.foreach_set(a.ravel())
    ext={'JPEG':'.jpg','PNG':'.png'}[fmt]
    im.filepath_raw=os.path.join(texdir, name+ext); im.file_format=fmt
    sc.render.image_settings.quality=quality
    im.save(); return im
T_bc=save("neris_basecolor", bcf, 'JPEG', BC_RES, False)
orm=np.stack([ao,rough,metal,np.ones_like(ao)],-1)
T_orm=save("neris_orm", orm, 'PNG', AUX_RES, True)
T_n=save("neris_normal", nrm, 'PNG', AUX_RES, True)
rep["metal_mean"]=float(metal[mask].mean()); rep["rough_mean"]=float(rough[mask].mean()); rep["ao_mean"]=float(ao[mask].mean())
# reload as file-backed images
for im in (T_bc,T_orm,T_n): im.reload()
# --- final portable material (Principled + 3 image textures, glTF-compatible)
N.clear()
o=N.new("ShaderNodeOutputMaterial"); o.location=(600,0)
b=N.new("ShaderNodeBsdfPrincipled"); b.location=(250,0)
t1=N.new("ShaderNodeTexImage"); t1.image=T_bc; t1.location=(-400,300)
t2=N.new("ShaderNodeTexImage"); t2.image=T_orm; t2.location=(-400,0)
sep=N.new("ShaderNodeSeparateColor"); sep.location=(-100,0)
t3=N.new("ShaderNodeTexImage"); t3.image=T_n; t3.location=(-400,-300)
nm=N.new("ShaderNodeNormalMap"); nm.location=(-100,-300)
L.new(t1.outputs[0], b.inputs["Base Color"]); L.new(t2.outputs[0], sep.inputs[0])
L.new(sep.outputs[1], b.inputs["Roughness"]); L.new(sep.outputs[2], b.inputs["Metallic"])
L.new(t3.outputs[0], nm.inputs["Color"]); L.new(nm.outputs[0], b.inputs["Normal"])
L.new(b.outputs[0], o.inputs[0])
b.inputs["Specular IOR Level"].default_value=0.4
# remove scratch images
for im in list(bpy.data.images):
    if im.name.startswith("bake_"): bpy.data.images.remove(im)
bpy.data.materials.remove(tmpm)
for n in list(HN):
    if n==em: HN.remove(n)
hi.hide_render=True; hi.hide_set(True)
rep["low_verts"]=len(lo.data.vertices); rep["low_quads"]=len(lo.data.polygons)
rep["low_tris"]=sum(len(p.vertices)-2 for p in lo.data.polygons)
co=np.array([v.co[:] for v in lo.data.vertices]); rep["low_bounds"]=[co.min(0).round(4).tolist(), co.max(0).round(4).tolist()]
rep["t_total"]=round(time.time()-t0,1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work,"s2_baked.blend"))
json.dump(rep, open(os.path.join(work,"s2_report.json"),"w"), indent=1)
# previews (Eevee) to compare with the source
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
views(os.path.join(work,"s2_low"), (0,0,0.75), 1.6, ("front","side","back","q"))
hi.hide_render=False; lo.hide_render=True
views(os.path.join(work,"s2_high"), (0,0,0.75), 1.6, ("front","back"))
print("REPORT", json.dumps(rep))
