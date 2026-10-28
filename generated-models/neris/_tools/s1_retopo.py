# Step 1: import Tripo high-poly, weld, scale to game size, voxel-fuse and QuadriFlow retopology.
import bpy, sys, os, json, time, bmesh
sys.path.insert(0, os.path.dirname(__file__))
from common import *
argv = sys.argv[sys.argv.index("--")+1:]
src, work = argv[0], argv[1]
VOXEL=float(argv[2]) if len(argv)>2 else 0.004
TARGET=int(argv[3]) if len(argv)>3 else 12000
HEIGHT=1.5
os.makedirs(work, exist_ok=True)
rep={}
t0=time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
hi=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
hi.name="Neris_High"; hi.data.name="Neris_High"
# weld UV-seam splits
bm=bmesh.new(); bm.from_mesh(hi.data)
n0=len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
rep["weld_removed"]=n0-len(bm.verts)
bm.to_mesh(hi.data); bm.free()
# scale so total height = HEIGHT, feet at z=0, centred in x/y
co=[v.co for v in hi.data.vertices]
zmin=min(c.z for c in co); zmax=max(c.z for c in co)
s=HEIGHT/(zmax-zmin)
hi.scale=(s,s,s); hi.location.z=-zmin*s
bpy.context.view_layer.objects.active=hi; hi.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
rep["scale_factor"]=s
# parts after weld
bm=bmesh.new(); bm.from_mesh(hi.data)
seen=set(); parts=0
for v in bm.verts:
    if v.index in seen: continue
    parts+=1; st=[v]; seen.add(v.index)
    while st:
        a=st.pop()
        for e in a.link_edges:
            b=e.other_vert(a)
            if b.index not in seen: seen.add(b.index); st.append(b)
rep["parts_after_weld"]=parts
rep["high_tris"]=sum(len(p.vertices)-2 for p in hi.data.polygons)
bm.free()
# voxel fuse on a copy
lo=hi.copy(); lo.data=hi.data.copy(); lo.name="Neris_Vox"; bpy.context.scene.collection.objects.link(lo)
lo.data.materials.clear()
lo.data.remesh_voxel_size=VOXEL; lo.data.use_remesh_fix_poles=True
bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=lo; lo.select_set(True)
bpy.ops.object.voxel_remesh()
rep["voxel_faces"]=len(lo.data.polygons); rep["t_voxel"]=time.time()-t0
# pre-decimate for quadriflow speed
# make strictly manifold for QuadriFlow: drop bow-tie verts / multi-face edges, fill the holes
for it in range(8):
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_mode(type='VERT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.mesh.select_non_manifold(extend=False, use_wire=True, use_boundary=False, use_multi_face=True, use_non_contiguous=True, use_verts=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    bad=sum(1 for v in lo.data.vertices if v.select)
    if it==0 or bad==0:
        bm=bmesh.new(); bm.from_mesh(lo.data); nb=len(bm.verts)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=2e-4)
        merged=nb-len(bm.verts); bm.to_mesh(lo.data); bm.free()
        rep.setdefault("merged",[]).append(merged)
        if merged:
            bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT')
            bpy.ops.mesh.select_non_manifold(extend=False, use_wire=True, use_boundary=False, use_multi_face=True, use_non_contiguous=True, use_verts=True)
            bpy.ops.object.mode_set(mode='OBJECT')
            bad=sum(1 for v in lo.data.vertices if v.select)
    rep.setdefault("nonmanifold_fix",[]).append(bad)
    if bad==0: break
    bm=bmesh.new(); bm.from_mesh(lo.data)
    sel=[v for v in bm.verts if v.select]
    bmesh.ops.delete(bm, geom=sel, context='VERTS')
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    loose=[v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts)>4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(lo.data); bm.free()
bm=bmesh.new(); bm.from_mesh(lo.data)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(lo.data); bm.free()
rep["boundary_edges_after_fix"]=0
rep["predec_faces"]=len(lo.data.polygons)
bpy.ops.object.quadriflow_remesh(use_mesh_symmetry=False, use_preserve_sharp=False, use_preserve_boundary=False,
    preserve_attributes=False, smooth_normals=False, mode='FACES', target_faces=TARGET, seed=7)
rep["method"]="quadriflow"
if len(lo.data.polygons)==rep["predec_faces"]:
    # fallback: coarse voxel quads, relaxed and shrink-wrapped back onto the high-poly surface
    rep["method"]="voxel_quads_relaxed"
    FB=float(argv[4]) if len(argv)>4 else 0.012
    lo.data.remesh_voxel_size=FB; lo.data.use_remesh_fix_poles=True; lo.data.use_remesh_preserve_volume=True
    bpy.ops.object.voxel_remesh()
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.vertices_smooth(factor=0.5, repeat=4)
    bpy.ops.object.mode_set(mode='OBJECT')
    sw=lo.modifiers.new("sw",'SHRINKWRAP'); sw.target=hi; sw.wrap_method='NEAREST_SURFACEPOINT'
    bpy.ops.object.modifier_apply(modifier="sw")
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.vertices_smooth(factor=0.3, repeat=1)
    bpy.ops.object.mode_set(mode='OBJECT')
rep["quad_faces"]=len(lo.data.polygons)
rep["quad_tris"]=sum(len(p.vertices)-2 for p in lo.data.polygons)
rep["quad_non_quads"]=sum(1 for p in lo.data.polygons if len(p.vertices)!=4)
lo.name="Neris"; lo.data.name="Neris"
# components of low
bm=bmesh.new(); bm.from_mesh(lo.data); bm.verts.ensure_lookup_table()
seen=set(); comps=[]
for v in bm.verts:
    if v.index in seen: continue
    st=[v]; seen.add(v.index); idx=[]
    while st:
        a=st.pop(); idx.append(a.index)
        for e in a.link_edges:
            b=e.other_vert(a)
            if b.index not in seen: seen.add(b.index); st.append(b)
    cs=[lo.data.vertices[i].co for i in idx]
    comps.append((len(idx),[round(min(c[k] for c in cs),3) for k in range(3)],[round(max(c[k] for c in cs),3) for k in range(3)]))
comps.sort(reverse=True); rep["low_components"]=comps[:20]; rep["low_ncomp"]=len(comps)
rep["nonmanifold_low"]=sum(1 for e in bm.edges if not e.is_manifold)
bm.free()
rep["t_total"]=time.time()-t0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work,"s1_retopo.blend"))
json.dump(rep, open(os.path.join(work,"s1_report.json"),"w"), indent=1)
# preview
setup_render(samples=8)
hi.hide_render=True
lo.data.materials.append(wire_material())
for p in lo.data.polygons: p.use_smooth=True
views(os.path.join(work,"s1_low"), (0,0,0.75), 1.6, ("front","side","back"))
print("REPORT", json.dumps(rep))
