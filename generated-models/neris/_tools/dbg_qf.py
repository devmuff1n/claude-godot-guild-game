import bpy, sys, bmesh, json
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
r={}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_uv_sphere_add()
s=bpy.context.active_object
f0=len(s.data.polygons)
try:
    ret=bpy.ops.object.quadriflow_remesh(target_faces=500)
    r["sphere"]=[str(ret), f0, len(s.data.polygons)]
except Exception as e: r["sphere"]=str(e)
bpy.ops.import_scene.gltf(filepath=src)
o=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=s][0]
bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=o; o.select_set(True)
o.data.remesh_voxel_size=0.004/1.53
bpy.ops.object.voxel_remesh()
r["vox"]=len(o.data.polygons)
for tgt in (5000, 12000):
    c=o.copy(); c.data=o.data.copy(); bpy.context.scene.collection.objects.link(c)
    bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=c; c.select_set(True)
    ret=bpy.ops.object.quadriflow_remesh(target_faces=tgt, use_mesh_symmetry=False, use_preserve_sharp=False, use_preserve_boundary=False, preserve_attributes=False, smooth_normals=False)
    r[f"vox_{tgt}"]=[str(ret), len(c.data.polygons)]
for ratio in (0.2,):
    c=o.copy(); c.data=o.data.copy(); bpy.context.scene.collection.objects.link(c)
    bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=c; c.select_set(True)
    m=c.modifiers.new("d",'DECIMATE'); m.ratio=ratio; bpy.ops.object.modifier_apply(modifier="d")
    n=len(c.data.polygons)
    ret=bpy.ops.object.quadriflow_remesh(target_faces=8000)
    r[f"dec{ratio}"]=[str(ret), n, len(c.data.polygons)]
json.dump(r,open(out,"w"),indent=1); print("R",r)
