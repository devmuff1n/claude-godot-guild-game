import bpy, sys, bmesh, json, os
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=o; o.select_set(True)
o.data.remesh_voxel_size=0.004/1.53; o.data.use_remesh_fix_poles=True
bpy.ops.object.voxel_remesh()
r={}
def stats(tag):
    bm=bmesh.new(); bm.from_mesh(o.data)
    e_bad=sum(1 for e in bm.edges if len(e.link_faces)!=2)
    e_wind=0
    for e in bm.edges:
        if len(e.link_loops)==2:
            l1,l2=e.link_loops
            if l1.vert==l2.vert: e_wind+=1
    v_bad=sum(1 for v in bm.verts if not v.is_manifold)
    degen=sum(1 for f in bm.faces if f.calc_area()<1e-12)
    dupv=sum(1 for f in bm.faces if len(set(f.verts))!=len(f.verts))
    r[tag]=dict(faces=len(bm.faces),e_bad=e_bad,e_wind=e_wind,v_bad=v_bad,degen=degen,dupv=dupv,ngon=sum(1 for f in bm.faces if len(f.verts)>4))
    bm.free()
stats("voxel")
bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(o.data); bm.free()
stats("recalc")
json.dump(r,open(out,"w"),indent=1); print(r)
