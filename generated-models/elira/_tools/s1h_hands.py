# Step 1h: replace the hands of the game mesh (fingers fused into mittens by the coarse retopology) with the hands of
# a 4x denser QuadriFlow pass of the same body (s1 with voxel 2.2 mm, 120k faces), where every finger is its own tube.
# The seam sits inside the glove cuff, a few millimetres of overlap hide it.
import bpy, bmesh, sys, json
argv = sys.argv[sys.argv.index("--")+1:]
src, dense, out, SH = argv[0], argv[1], argv[2], json.loads(argv[3])
CUT_Z = float(argv[4]) if len(argv) > 4 else 0.478     # s2 space
OVER = 0.009
bpy.ops.wm.open_mainfile(filepath=src)
lo = bpy.data.objects["Elira"]
with bpy.data.libraries.load(dense) as (s, d):
    d.objects = ["Elira"]
dn = d.objects[0]; dn.name = "Dense"; bpy.context.scene.collection.objects.link(dn)
rep = {}
def s2(c): return (c[0]+SH[0], c[1]+SH[1], c[2]+SH[2])
def hand_zone(c, ztop):
    x, y, z = s2(c)
    for sg in (1, -1):
        if sg*x > 0.24 and sg*x < 0.37 and -0.16 < y < 0.05 and 0.36 < z < ztop and not (sg*x < 0.272 and y > -0.02 and z < 0.45):
            return True
    return False
# hands from the dense mesh: faces whose centre is in the zone
bm = bmesh.new(); bm.from_mesh(dn.data)
keep = {f for f in bm.faces if hand_zone(f.calc_center_median(), CUT_Z+OVER)}
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# drop crumbs (skirt / braid bits caught by the box): keep the two biggest pieces
bm.verts.ensure_lookup_table(); seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; seen.add(v.index); c = []
    while st:
        a = st.pop(); c.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in seen: seen.add(b.index); st.append(b)
    comps.append(c)
comps.sort(key=len, reverse=True)
rep["dense_pieces"] = [len(c) for c in comps[:6]]
bmesh.ops.delete(bm, geom=[v for c in comps[2:] for v in c], context='VERTS')
bm.to_mesh(dn.data); bm.free()
dn.data.materials.clear()
rep["hand_faces"] = len(dn.data.polygons)
# cut the old hands out of the game mesh
bm = bmesh.new(); bm.from_mesh(lo.data)
kill = [f for f in bm.faces if hand_zone(f.calc_center_median(), CUT_Z)]
rep["low_faces_removed"] = len(kill)
bmesh.ops.delete(bm, geom=kill, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(lo.data); bm.free()
bpy.ops.object.select_all(action='DESELECT')
dn.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
bpy.ops.object.join()
rep["low_faces"] = len(lo.data.polygons); rep["low_tris"] = sum(len(p.vertices)-2 for p in lo.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=out)
print("REPORT", json.dumps(rep))
