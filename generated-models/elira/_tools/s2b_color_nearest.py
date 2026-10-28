# Step 2b: re-bake the base colour by nearest-surface transfer (no rays), so thin layered clothing
# (strap, belt, cape edge) does not pick colour from the wrong layer. Normal/ORM from s2 stay.
import bpy, sys, os, json, time, numpy as np
from mathutils.bvhtree import BVHTree
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
blend, texdir = argv[0], argv[1]
RES = int(argv[2]) if len(argv) > 2 else 2048
AO_IN_ALBEDO = 0.4
t0 = time.time(); rep = {}
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
hi = bpy.data.objects["Elira_High"]; lo = bpy.data.objects["Elira"]
hi.hide_set(False)
# --- position bake of the low mesh into its UV layout
sc.render.engine = 'CYCLES'; sc.cycles.samples = 1; sc.render.bake.use_selected_to_active = False
pm = bpy.data.materials.new("posbake"); pm.use_nodes = True
N = pm.node_tree.nodes; L = pm.node_tree.links; N.clear()
o = N.new("ShaderNodeOutputMaterial"); e = N.new("ShaderNodeEmission"); g = N.new("ShaderNodeNewGeometry")
L.new(g.outputs["Position"], e.inputs[0]); L.new(e.outputs[0], o.inputs[0])
ti = N.new("ShaderNodeTexImage")
pos = bpy.data.images.new("pos", RES, RES, alpha=True, float_buffer=True); pos.colorspace_settings.name = 'Non-Color'
ti.image = pos; N.active = ti
orig = lo.data.materials[0]; lo.data.materials[0] = pm
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active = lo
pos.pixels.foreach_set(np.zeros(RES*RES*4, np.float32))
bpy.ops.object.bake(type='EMIT', margin=0)
P = np.empty(RES*RES*4, np.float32); pos.pixels.foreach_get(P); P = P.reshape(RES, RES, 4)
lo.data.materials[0] = orig
# coverage: alpha of baked texels
cov = np.abs(P[..., :3]).sum(2) > 1e-7
rep["cov"] = float(cov.mean())
# --- high mesh BVH + uv per triangle
dg = bpy.context.evaluated_depsgraph_get()
hm = hi.data
hm.calc_loop_triangles()
nt = len(hm.loop_triangles)
tv = np.empty(nt*3, np.int64); hm.loop_triangles.foreach_get("vertices", tv); tv = tv.reshape(-1, 3)
tl = np.empty(nt*3, np.int64); hm.loop_triangles.foreach_get("loops", tl); tl = tl.reshape(-1, 3)
co = np.empty(len(hm.vertices)*3, np.float32); hm.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
uv = np.empty(len(hm.loops)*2, np.float32); hm.uv_layers[0].data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
mw = hi.matrix_world
assert all(abs(mw[i][j] - (1 if i == j else 0)) < 1e-6 for i in range(4) for j in range(4))
bvh = BVHTree.FromPolygons(co.tolist(), tv.tolist(), all_triangles=True)
rep["t_bvh"] = round(time.time()-t0, 1)
ys, xs = np.nonzero(cov)
pts = P[ys, xs, :3]
fi = np.empty(len(pts), np.int64); hit = np.empty((len(pts), 3), np.float32); dist = np.empty(len(pts), np.float32)
fn = bvh.find_nearest
for i, p in enumerate(pts):
    r = fn(Vector(p))
    hit[i] = r[0]; fi[i] = r[2]; dist[i] = r[3]
rep["t_query"] = round(time.time()-t0, 1)
rep["dist_p50_p99_max"] = [float(np.percentile(dist, 50)), float(np.percentile(dist, 99)), float(dist.max())]
# barycentric
a = co[tv[fi, 0]]; b = co[tv[fi, 1]]; c = co[tv[fi, 2]]
v0 = b-a; v1 = c-a; v2 = hit-a
d00 = (v0*v0).sum(1); d01 = (v0*v1).sum(1); d11 = (v1*v1).sum(1); d20 = (v2*v0).sum(1); d21 = (v2*v1).sum(1)
den = np.maximum(d00*d11-d01*d01, 1e-20)
w1 = (d11*d20-d01*d21)/den; w2 = (d00*d21-d01*d20)/den; w0 = 1-w1-w2
U = uv[tl[fi, 0]]*w0[:, None]+uv[tl[fi, 1]]*w1[:, None]+uv[tl[fi, 2]]*w2[:, None]
# sample the high base colour (bilinear)
src = [i for i in bpy.data.images if 'basecolor' in i.name and i.size[0] >= 4096][0]
W, H = src.size
S = np.empty(W*H*4, np.float32); src.pixels.foreach_get(S); S = S.reshape(H, W, 4)
x = (U[:, 0] % 1)*W-0.5; y = (U[:, 1] % 1)*H-0.5
x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int); fx = (x-x0)[:, None]; fy = (y-y0)[:, None]
def px(xx, yy): return S[np.clip(yy, 0, H-1), np.clip(xx, 0, W-1), :3]
col = (px(x0, y0)*(1-fx)*(1-fy)+px(x0+1, y0)*fx*(1-fy)+px(x0, y0+1)*(1-fx)*fy+px(x0+1, y0+1)*fx*fy)
out = np.zeros((RES, RES, 3), np.float32); out[ys, xs] = col
# --- dilate 16 px into the gutters
m = cov.copy()
for it in range(16):
    acc = np.zeros_like(out); n = np.zeros((RES, RES), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sm = np.roll(m, (dy, dx), (0, 1)); so = np.roll(out, (dy, dx), (0, 1))
        acc += so*sm[..., None]; n += sm
    grow = (~m) & (n > 0)
    out[grow] = acc[grow]/n[grow][:, None]; m |= grow
# --- AO from the s2 ORM map
orm = bpy.data.images.load(os.path.join(texdir, "elira_orm.png"))
R = orm.size[0]; A = np.empty(R*R*4, np.float32); orm.pixels.foreach_get(A); A = A.reshape(R, R, 4)[..., 0]
k = RES//R; ao = np.repeat(np.repeat(A, k, 0), k, 1)
out *= (1-AO_IN_ALBEDO+AO_IN_ALBEDO*ao)[..., None]
img = bpy.data.images.new("elira_basecolor_n", RES, RES, alpha=False)
img.pixels.foreach_set(np.concatenate([out, np.ones((RES, RES, 1), np.float32)], 2).ravel())
img.filepath_raw = os.path.join(texdir, "elira_basecolor.jpg"); img.file_format = 'JPEG'
sc.render.image_settings.quality = 92
img.save()
for im in bpy.data.images:
    if im.filepath and os.path.basename(bpy.path.abspath(im.filepath)) == "elira_basecolor.jpg" and im is not img: im.reload()
bpy.data.images.remove(pos); bpy.data.materials.remove(pm)
hi.hide_set(True)
bpy.ops.wm.save_mainfile()
rep["t_total"] = round(time.time()-t0, 1)
print("REPORT", json.dumps(rep))
# preview
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, views
setup_render(samples=8)
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
hi.hide_render = True; lo.hide_render = False
views(os.path.join(os.path.dirname(blend), "s2b_low"), (0, 0, 0.75), 1.6, ("front", "back", "q", "side"))
