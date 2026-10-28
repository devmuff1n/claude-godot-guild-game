# -*- coding: utf-8 -*-
"""Environment kit builder for Poorest Guild (Blender 4.x / 5.x).

Builds 20 environment assets (landscape, vegetation, road & defence) from the
asset-kit prompts as low/mid-poly game meshes with painted tiling textures.

Usage inside Blender (MCP or Text Editor):
    ns = {}
    exec(open(r"<this file>", encoding="utf-8").read(), ns)
    ns["run"](["oak_tree"])                  # build + export + verify + preview
    ns["run"](["oak_tree"], steps=("build",))
    ns["run"](ns["ALL_IDS"])

Conventions (SCALE_GUIDE): 1 unit = 1 m, Z up, front = -Y, origin on the
support point. glTF exporter performs the Z-up -> Y-up conversion (no manual
rotation). Collision proxies use Godot import suffix "-convcolonly".
Every asset lives in its own scene "ENV_<id>" / collection "<id>", so the
user's open scene is never modified.
"""
import bpy, bmesh, math, random, os, json, time, zlib
from mathutils import Vector, Matrix, Euler, noise

# ----------------------------------------------------------------------------- paths
PROJECT = os.environ.get("POOREST_GUILD", r"C:\Users\armor\Documents\poorest_guild")
GEN = os.path.join(PROJECT, "generated-models")
TEX = os.path.join(GEN, "_textures")
GLB_ROOT = os.path.join(PROJECT, "assets", "models", "environment")

CATEGORY = {}
for _i in ["ground_road_tile", "stream_channel", "field_rock", "fallen_tree_root", "vegetable_garden_bed"]:
    CATEGORY[_i] = "landscape"
for _i in ["oak_tree", "pine_tree", "roadside_bush", "grass_tuft", "flower_patch", "potted_plant"]:
    CATEGORY[_i] = "vegetation"
for _i in ["low_stone_wall", "wooden_garden_fence", "wooden_barricade", "checkpoint_barrier",
           "forest_defense_gate", "timber_footbridge", "toll_sign", "decorative_spear", "round_watch_shield"]:
    CATEGORY[_i] = "road_defense"
ALL_IDS = list(CATEGORY.keys())

# target bounds X,Y,Z from the MD prompts
SPEC = {
    "ground_road_tile": (6, 6, 0.2), "stream_channel": (6, 4, 0.8), "field_rock": (1.35, 1.1, 0.9),
    "fallen_tree_root": (3, 1.3, 1.0), "vegetable_garden_bed": (3.6, 2.7, 0.35),
    "oak_tree": (4, 3.6, 5.4), "pine_tree": (2.9, 2.8, 6.5), "roadside_bush": (1.4, 1.2, 1.0),
    "grass_tuft": (0.55, 0.5, 0.65), "flower_patch": (0.7, 0.6, 0.5), "potted_plant": (0.45, 0.4, 0.75),
    "low_stone_wall": (3, 0.55, 1.2), "wooden_garden_fence": (3, 0.28, 1.0), "wooden_barricade": (1.7, 0.65, 0.9),
    "checkpoint_barrier": (3.6, 0.4, 1.2), "forest_defense_gate": (2.3, 0.45, 2.8),
    "timber_footbridge": (4.2, 2.2, 1.25), "toll_sign": (0.7, 0.3, 2.1), "decorative_spear": (0.12, 0.08, 1.65),
    "round_watch_shield": (0.6, 0.1, 0.6),
}

# ----------------------------------------------------------------------------- materials
# name: (texture, roughness, metallic, uv tile size in metres, two_sided, alpha)
MATS = {
    "wood_light": ("wood_light", .85, 0, 1.0, False, None),
    "wood_mid": ("wood_mid", .85, 0, 1.0, False, None),
    "wood_dark": ("wood_dark", .85, 0, 1.0, False, None),
    "wood_raw": ("wood_raw", .9, 0, 0.6, False, None),
    "bark": ("bark", .95, 0, 1.6, False, None),
    "bark_oak": ("bark_oak", .95, 0, 1.6, False, None),
    "bark_dark": ("bark_dark", .95, 0, 1.6, False, None),
    "stone_plates": ("stone_plates", .9, 0, 0.9, False, None),
    "fern": ("fern", .8, 0, 1.0, True, None),
    "stone": ("stone", .9, 0, 1.2, False, None),
    "stone_grey": ("stone_grey", .9, 0, 1.0, False, None),
    "moss": ("moss", .95, 0, 1.0, False, None),
    "grass_ground": ("grass_ground", .95, 0, 2.0, False, None),
    "dirt": ("dirt_road", .95, 0, 2.0, False, None),
    "soil": ("soil", .95, 0, 1.5, False, None),
    "soil_dark": ("soil_dark", .95, 0, 1.0, False, None),
    "road_top": ("road_tile_top", .95, 0, 6.0, False, None),
    "leaves_oak": ("leaves_oak", .9, 0, 1.6, False, None),
    "leaves_pine": ("leaves_pine", .9, 0, 1.3, False, None),
    "leaves_bush": ("leaves_bush", .9, 0, 0.9, False, None),
    "leaf_broad": ("leaf_broad", .7, 0, 1.0, True, None),
    "leaf_bush": ("leaf_bush_card", .8, 0, 1.0, True, None),
    "grass_blade": ("grass_blade", .8, 0, 1.0, True, None),
    "flower_leaf": ("flower_leaf", .8, 0, 1.0, True, None),
    "seedling_leaf": ("seedling_leaf", .8, 0, 1.0, True, None),
    "petal_cream": ("petal_cream", .7, 0, 1.0, True, None),
    "petal_lavender": ("petal_lavender", .7, 0, 1.0, True, None),
    "iron": ("iron", .55, .6, 0.6, False, None),
    "steel": ("steel", .4, .75, 0.4, False, None),
    "brass": ("brass", .45, .65, 0.4, False, None),
    "terracotta": ("terracotta", .85, 0, 0.6, False, None),
    "rope": ("rope", .95, 0, 0.25, False, None),
    "leather": ("leather", .75, 0, 0.5, False, None),
    "water": ("water", .08, 0, 3.0, True, 0.82),
    "streambed": ("streambed", .9, 0, 1.5, False, None),
    "paint_cream": ("paint_cream", .8, 0, 1.0, False, None),
    "plaque": ("plaque", .5, .4, 1.0, False, None),
    "shield_planks": ("shield_planks", .85, 0, 1.0, False, None),
}


def get_image(tex):
    path = os.path.join(TEX, tex + ".png")
    img = bpy.data.images.load(path, check_existing=True)
    return img


def get_mat(name):
    mname = "env_" + name
    m = bpy.data.materials.get(mname)
    if m:
        return m
    tex, rough, metal, _scale, two_sided, alpha = MATS[name]
    m = bpy.data.materials.new(mname)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    ti = nt.nodes.new("ShaderNodeTexImage")
    ti.image = get_image(tex)
    ti.location = (-400, 200)
    nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    for spec in ("Specular IOR Level", "Specular"):
        if spec in bsdf.inputs:
            bsdf.inputs[spec].default_value = 0.25
            break
    if alpha is not None:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        if hasattr(m, "blend_method"):
            try:
                m.blend_method = "BLEND"
            except Exception:
                pass
    m.use_backface_culling = not two_sided
    return m


# ----------------------------------------------------------------------------- bmesh primitives
def _new():
    bm = bmesh.new()
    bm.loops.layers.uv.verify()
    return bm


def _uvl(bm):
    return bm.loops.layers.uv.verify()


def prim_box(sx, sy, sz, bevel=0.0, center=(0, 0, 0)):
    bm = _new()
    r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=r["verts"])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(sx, sy, sz) * 0.45),
                        segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def prim_tube(pts, radii, segs=8, caps=(True, True), rough=0.0, seed=0, flat_y=1.0, uvscale=1.0,
              seg_mat=None, ring_jag=None):
    """Swept tube through pts with per-point radius. radius 0 -> apex vertex.
    UV: u along length, v around (both in metres / uvscale). seg_mat(i) -> local material idx."""
    bm = _new(); uv = _uvl(bm)
    P = [Vector(p) for p in pts]
    n = len(P)
    T = []
    for i in range(n):
        a = P[max(i - 1, 0)]; b = P[min(i + 1, n - 1)]
        T.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N0 = (ref - T[0] * ref.dot(T[0])).normalized()
    frames = []
    Nn = N0
    for i in range(n):
        Nn = (Nn - T[i] * Nn.dot(T[i]))
        if Nn.length < 1e-6:
            Nn = N0
        Nn.normalize()
        frames.append((Nn.copy(), T[i].cross(Nn).normalized()))
    seglen = [0.0]
    for i in range(1, n):
        seglen.append(seglen[-1] + (P[i] - P[i - 1]).length)
    rings = []
    for i in range(n):
        r = radii[i]
        if r <= 1e-5:
            rings.append([bm.verts.new(P[i])])
            continue
        Nn, B = frames[i]
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            rr = r
            if rough:
                rr *= 1 + rough * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, seglen[i] * 2.3 + seed)))
            if ring_jag and ring_jag(i, j):
                rr *= ring_jag(i, j)
            off = Nn * math.cos(a) * rr + B * math.sin(a) * rr * flat_y
            ring.append(bm.verts.new(P[i] + off))
        rings.append(ring)
    circ = 2 * math.pi * max(radii) if max(radii) > 0 else 1.0
    for i in range(n - 1):
        A, Bv = rings[i], rings[i + 1]
        mi = seg_mat(i) if seg_mat else 0
        if len(A) == 1 and len(Bv) == 1:
            continue
        for j in range(segs):
            j2 = (j + 1) % segs
            if len(Bv) == 1:
                f = bm.faces.new((A[j], A[j2], Bv[0]))
                uvs = [(seglen[i], j / segs * circ), (seglen[i], (j + 1) / segs * circ), (seglen[i + 1], (j + .5) / segs * circ)]
            elif len(A) == 1:
                f = bm.faces.new((A[0], Bv[j2], Bv[j]))
                uvs = [(seglen[i], (j + .5) / segs * circ), (seglen[i + 1], (j + 1) / segs * circ), (seglen[i + 1], j / segs * circ)]
            else:
                f = bm.faces.new((A[j], A[j2], Bv[j2], Bv[j]))
                uvs = [(seglen[i], j / segs * circ), (seglen[i], (j + 1) / segs * circ),
                       (seglen[i + 1], (j + 1) / segs * circ), (seglen[i + 1], j / segs * circ)]
            f.material_index = mi
            for l, (u, v) in zip(f.loops, uvs):
                l[uv].uv = (u / uvscale, v / uvscale)
    for end, cap in ((0, caps[0]), (n - 1, caps[1])):
        ring = rings[end]
        if cap and len(ring) > 2:
            f = bm.faces.new(ring if end == n - 1 else list(reversed(ring)))
            f.material_index = seg_mat(min(end, n - 2)) if seg_mat else 0
            Nn, B = frames[end]
            for l in f.loops:
                d = l.vert.co - P[end]
                l[uv].uv = (d.dot(Nn) / uvscale + .5, d.dot(B) / uvscale + .5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prim_cyl(r1, r2, depth, segs=8, z0=0.0, **kw):
    return prim_tube([(0, 0, z0), (0, 0, z0 + depth)], [r1, r2], segs=segs, **kw)


def prim_ico(radius=1.0, subdiv=2):
    bm = _new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return bm


def prim_torus(R, r, segs=16, rsegs=6, uvscale=0.25):
    bm = _new(); uv = _uvl(bm)
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c = Vector((math.cos(a) * R, math.sin(a) * R, 0))
        d = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(c + d * math.cos(2 * math.pi * j / rsegs) * r + Vector((0, 0, math.sin(2 * math.pi * j / rsegs) * r)))
                      for j in range(rsegs)])
    L = 2 * math.pi * R; C = 2 * math.pi * r
    for i in range(segs):
        i2 = (i + 1) % segs
        for j in range(rsegs):
            j2 = (j + 1) % rsegs
            f = bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
            for l, (u, v) in zip(f.loops, [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]):
                l[uv].uv = (u / segs * L / uvscale, v / rsegs * C / uvscale)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prim_leaf(length, width, segs=5, curve=0.25, fold=0.18, shape="leaf", twist=0.0):
    """Leaf/blade along +X, width along Y, bending down (-Z). UV u across, v along."""
    bm = _new(); uv = _uvl(bm)
    rows = []
    for i in range(segs + 1):
        t = i / segs
        if shape == "leaf":
            w = width * (math.sin(math.pi * min(t * 1.08, 1.0)) ** 0.75) * (0.35 + 0.65 * min(1, t * 3))
        elif shape == "petal":
            w = width * (math.sin(math.pi * t) ** 0.5)
        else:  # blade
            w = width * (1 - t) ** 0.85
        w = max(w, width * (0.15 if shape != "blade" else 0.0))
        x = length * t
        z = -curve * length * t * t
        ang = twist * t
        if i == segs:
            rows.append([bm.verts.new((x, 0, z))])
            continue
        c, s = math.cos(ang), math.sin(ang)
        pts = [(-w / 2, 0), (0, fold * w), (w / 2, 0)]
        rows.append([bm.verts.new((x, py * c - pz * s, z + py * s + pz * c)) for py, pz in pts])
    for i in range(segs):
        A, B = rows[i], rows[i + 1]
        v0, v1 = i / segs, (i + 1) / segs
        if len(B) == 1:
            for k in range(2):
                f = bm.faces.new((A[k], A[k + 1], B[0]))
                for l, uvv in zip(f.loops, [(k * .5, v0), ((k + 1) * .5, v0), (.5, v1)]):
                    l[uv].uv = uvv
        else:
            for k in range(2):
                f = bm.faces.new((A[k], A[k + 1], B[k + 1], B[k]))
                for l, uvv in zip(f.loops, [(k * .5, v0), ((k + 1) * .5, v0), ((k + 1) * .5, v1), (k * .5, v1)]):
                    l[uv].uv = uvv
    for f in bm.faces:  # face up (+Z)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    return bm


def prim_lathe(profile, segs=16, uvscale=1.0, close_bottom=True):
    """profile: list of (r, z) from bottom-centre outward/up. Revolve around Z."""
    bm = _new(); uv = _uvl(bm)
    rings = []
    for (r, z) in profile:
        rings.append([bm.verts.new((math.cos(2 * math.pi * j / segs) * r, math.sin(2 * math.pi * j / segs) * r, z)) for j in range(segs)])
    s = [0.0]
    for i in range(1, len(profile)):
        s.append(s[-1] + math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]))
    C = 2 * math.pi * max(p[0] for p in profile)
    for i in range(len(rings) - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            f = bm.faces.new((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
            for l, (u, v) in zip(f.loops, [(j, s[i]), (j + 1, s[i]), (j + 1, s[i + 1]), (j, s[i + 1])]):
                l[uv].uv = (u / segs * C / uvscale, v / uvscale)
    if close_bottom:
        f = bm.faces.new(list(reversed(rings[0])))
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / uvscale, l.vert.co.y / uvscale)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prim_prism_xz(outline, thickness):
    """Extrude a polygon given in the XZ plane along -Y (front) by thickness; back face at y=0."""
    bm = _new()
    vs = [bm.verts.new((x, 0, z)) for x, z in outline]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, -thickness, 0), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prim_pyramid(side, height, z0=0.0):
    """Square pyramid cap (axis-aligned)."""
    bm = prim_tube([(0, 0, z0), (0, 0, z0 + height)], [side / math.sqrt(2), 0], segs=4)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"), verts=bm.verts)
    return bm


# ----------------------------------------------------------------------------- UV helpers
def uv_box(bm, scale=1.0, long_axis=None, offset=(0, 0)):
    uvl = _uvl(bm)
    bm.normal_update()
    if long_axis is None:
        xs = [v.co for v in bm.verts]
        if xs:
            ext = [max(c[i] for c in xs) - min(c[i] for c in xs) for i in range(3)]
            long_axis = max(range(3), key=lambda i: ext[i])
    for f in bm.faces:
        nrm = f.normal
        ax = max(range(3), key=lambda i: abs(nrm[i]))
        others = [i for i in range(3) if i != ax]
        if long_axis in others:
            ua = long_axis; va = [o for o in others if o != long_axis][0]
        else:
            ua, va = others
        for l in f.loops:
            co = l.vert.co
            l[uvl].uv = (co[ua] / scale + offset[0], co[va] / scale + offset[1])


def uv_planar(bm, axes=(0, 2), rect=None, faces=None):
    uvl = _uvl(bm)
    fs = faces if faces is not None else bm.faces
    if rect is None:
        cs = [v.co for f in fs for v in f.verts]
        a0 = min(c[axes[0]] for c in cs); a1 = max(c[axes[0]] for c in cs)
        b0 = min(c[axes[1]] for c in cs); b1 = max(c[axes[1]] for c in cs)
        rect = (a0, b0, a1, b1)
    a0, b0, a1, b1 = rect
    for f in fs:
        for l in f.loops:
            co = l.vert.co
            l[uvl].uv = ((co[axes[0]] - a0) / max(a1 - a0, 1e-6), (co[axes[1]] - b0) / max(b1 - b0, 1e-6))


def lumpy(bm, amp=0.15, freq=1.5, seed=0.0):
    sv = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in bm.verts:
        d = v.co.normalized() if v.co.length > 1e-6 else Vector((0, 0, 1))
        v.co += d * amp * noise.noise(v.co * freq + sv)


def jitter(bm, amt, rng):
    for v in bm.verts:
        v.co += Vector((rng.uniform(-amt, amt), rng.uniform(-amt, amt), rng.uniform(-amt, amt)))


# ----------------------------------------------------------------------------- part builder
class Part:
    """Accumulates primitives into one mesh with several materials."""

    def __init__(self, name):
        self.name = name
        self.bm = _new()
        self.slots = []

    def slot(self, mat):
        if mat not in self.slots:
            self.slots.append(mat)
        return self.slots.index(mat)

    def add(self, bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), uv="keep", uvscale=None,
            long_axis=None, smooth=False, mat_fn=None, rng=None, matrix=None):
        """mat: str or list[str] (faces' material_index index this list). uv: keep|box|world."""
        mats = [mat] if isinstance(mat, str) else list(mat)
        sc = uvscale if uvscale is not None else MATS[mats[0]][3]
        if uv == "box":
            off = (rng.random(), rng.random()) if rng else (0, 0)
            uv_box(bm, sc, long_axis, off)
        M = matrix if matrix is not None else (Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4()
                                                @ Matrix.Diagonal((*scale, 1)))
        bm.transform(M)
        if any(s < 0 for s in scale):
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.normal_update()
        if uv == "world":
            uv_box(bm, sc, long_axis)
        for f in bm.faces:
            li = mat_fn(f) if mat_fn else (f.material_index if f.material_index < len(mats) else 0)
            f.material_index = self.slot(mats[li])
            if smooth is not None:
                f.smooth = smooth
        me = bpy.data.meshes.new("__tmp")
        bm.to_mesh(me)
        bm.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return self

    def build(self, coll, pivot=(0, 0, 0), parent=None, mesh_name=None):
        pv = Vector(pivot)
        bmesh.ops.translate(self.bm, vec=-pv, verts=self.bm.verts)
        me = bpy.data.meshes.new(mesh_name or self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.slots:
            me.materials.append(get_mat(m))
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        ob.location = pv - parent_pos(parent)
        if parent:
            ob.parent = parent
        return ob


def parent_pos(parent):
    """World position of a parent chain (rigs here use no rotation on parents at build time)."""
    p = Vector((0, 0, 0)); o = parent
    while o is not None:
        p += o.location; o = o.parent
    return p


def instance(mesh_obj, name, coll, loc, rot=(0, 0, 0), scale=(1, 1, 1), parent=None):
    ob = bpy.data.objects.new(name, mesh_obj.data)
    coll.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot; ob.scale = scale
    if parent:
        ob.parent = parent
    return ob


def empty(name, coll, loc, parent=None, size=0.15, kind="PLAIN_AXES", rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    coll.objects.link(e)
    e.location = Vector(loc) - parent_pos(parent); e.rotation_euler = rot
    if parent:
        e.parent = parent
    return e


def col_box(name, coll, size, center, parent=None, rot=(0, 0, 0)):
    """Simple box collision proxy (Godot: -convcolonly => StaticBody + ConvexPolygonShape, no visual)."""
    bm = prim_box(*size)
    me = bpy.data.meshes.new(name + "_col")
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name + "_col-convcolonly", me)
    coll.objects.link(ob)
    ob.location = Vector(center) - parent_pos(parent); ob.rotation_euler = rot
    ob.display_type = "WIRE"; ob.hide_render = True
    if parent:
        ob.parent = parent
    return ob


def col_mesh(name, coll, bm, parent=None):
    me = bpy.data.meshes.new(name + "_col")
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name + "_col-convcolonly", me)
    coll.objects.link(ob)
    ob.display_type = "WIRE"; ob.hide_render = True
    if parent:
        ob.parent = parent
    return ob


def col_hull(name, coll, points, parent=None):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    return col_mesh(name, coll, bm, parent)


def fit_parts(objs, spec, z_base=0.0):
    """Non-uniform fit of organic parts (all with pivot at origin) to target bounds."""
    cs = []
    for o in objs:
        for v in o.data.vertices:
            cs.append(o.matrix_world @ v.co)
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
    size = mx - mn
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    s = Vector((spec[0] / size.x, spec[1] / size.y, spec[2] / size.z))
    seen = set()
    for o in objs:
        if o.data.name in seen:
            continue
        seen.add(o.data.name)
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            w = Vector(((w.x - cx) * s.x, (w.y - cy) * s.y, (w.z - mn.z) * s.z + z_base))
            v.co = o.matrix_world.inverted() @ w
        o.data.update()
    return s


# ----------------------------------------------------------------------------- shared sub-meshes
def mesh_grass_clump(coll, name, rng, blades=9, h=(0.25, 0.45), spread=0.18, mat="grass_blade", width=0.05):
    p = Part(name)
    for i in range(blades):
        yaw = 2 * math.pi * i / blades + rng.uniform(-.3, .3)
        pitch = math.radians(rng.uniform(55, 80))
        L = rng.uniform(*h)
        bm = prim_leaf(L, width * rng.uniform(.8, 1.2), segs=4, curve=rng.uniform(.15, .35), fold=.2, shape="blade",
                       twist=rng.uniform(-.4, .4))
        b0 = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.uniform(0, spread * .3)
        p.add(bm, mat, matrix=Matrix.Translation(b0) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y"))
    return p.build(coll)


# ----------------------------------------------------------------------------- scene plumbing
def _windows():
    wm = bpy.context.window_manager
    return list(wm.windows) if wm else []


class SceneCtx:
    def __init__(self, scn):
        self.scn = scn

    def __enter__(self):
        ws = _windows()
        self.prev = None
        if ws:
            self.win = ws[0]
            self.prev = self.win.scene
            self.win.scene = self.scn
            self.ov = bpy.context.temp_override(window=self.win, scene=self.scn, view_layer=self.scn.view_layers[0])
        else:
            self.win = None
            self.ov = bpy.context.temp_override(scene=self.scn, view_layer=self.scn.view_layers[0])
        self.ov.__enter__()
        return self

    def __exit__(self, *a):
        self.ov.__exit__(*a)
        if self.win and self.prev:
            self.win.scene = self.prev


def new_asset_scene(aid):
    sname = "ENV_" + aid
    old = bpy.data.scenes.get(sname)
    if old:
        _purge_scene(old)
    scn = bpy.data.scenes.new(sname)
    scn.unit_settings.system = "METRIC"
    scn.unit_settings.scale_length = 1.0
    coll = bpy.data.collections.new(aid)
    scn.collection.children.link(coll)
    root = bpy.data.objects.new(aid, None)
    root.empty_display_type = "ARROWS"; root.empty_display_size = 0.5
    coll.objects.link(root)
    root["asset_id"] = aid
    root["target_size_m"] = list(SPEC[aid])
    return scn, coll, root


def _purge_scene(scn):
    for c in list(scn.collection.children):
        for o in list(c.all_objects):
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0:
                if isinstance(data, bpy.types.Mesh):
                    bpy.data.meshes.remove(data)
        bpy.data.collections.remove(c)
    bpy.data.scenes.remove(scn)


def is_col(o):
    return "colonly" in o.name or (o.data is not None and o.data.name.endswith("_col"))


def parts_of(root):
    return [o for o in root.children_recursive if o.type == "MESH" and not is_col(o)]


def parent_all(coll, root):
    for o in coll.objects:
        if o is not root and o.parent is None:
            o.parent = root


# ============================================================================= ASSETS
# ---------------------------------------------------------------------------- landscape
def add_fern(part, rng, loc, s=1.0, fronds=7, L=(0.28, 0.42), width=0.15, mat="fern", pitch=(25, 50)):
    base = Matrix.Translation(loc) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Diagonal((s, s, s, 1))
    for i in range(fronds):
        yaw = 2 * math.pi * i / fronds + rng.uniform(-.25, .25)
        part.add(prim_leaf(rng.uniform(*L), width * rng.uniform(.85, 1.15), segs=4, curve=rng.uniform(.35, .55), fold=.22),
                 mat, matrix=base @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-math.radians(rng.uniform(*pitch)), 4, "Y"))


def add_tuft(part, rng, loc, s=1.0, blades=10, L=(0.22, 0.4), width=0.07, mat="grass_blade"):
    base = Matrix.Translation(loc) @ Matrix.Diagonal((s, s, s, 1))
    for i in range(blades):
        yaw = 2 * math.pi * i / blades + rng.uniform(-.3, .3)
        part.add(prim_leaf(rng.uniform(*L), width * rng.uniform(.8, 1.2), segs=4, curve=rng.uniform(.25, .5), fold=.2, shape="blade",
                           twist=rng.uniform(-.4, .4)),
                 mat, matrix=base @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-math.radians(rng.uniform(50, 80)), 4, "Y"))


def build_ground_road_tile(coll, root, rng):
    W = 6.0; n = 24; T = 0.2

    def h(x, y):
        k = 2 * math.pi * x / W
        taper = min(1.0, (3.0 - abs(y)) / 0.6)
        rel = 0.03 * noise.noise(Vector((math.cos(k) * 1.3, math.sin(k) * 1.3, y * 0.9))) * taper
        road = 0.035 * max(0.0, 1 - (abs(y) / 1.55) ** 4)
        return rel - road

    bm = _new(); uv = _uvl(bm)
    grid = [[bm.verts.new((-3 + 6 * i / n, -3 + 6 * j / n, h(-3 + 6 * i / n, -3 + 6 * j / n))) for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            f.material_index = 0
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x + 3) / 6, (l.vert.co.y + 3) / 6)
    border = [grid[i][0] for i in range(n + 1)] + [grid[n][j] for j in range(1, n + 1)] + \
             [grid[i][n] for i in range(n - 1, -1, -1)] + [grid[0][j] for j in range(n - 1, 0, -1)]
    bot = [bm.verts.new((v.co.x, v.co.y, -T)) for v in border]
    for k in range(len(border)):
        k2 = (k + 1) % len(border)
        f = bm.faces.new((border[k2], border[k], bot[k], bot[k2]))
        f.material_index = 1
    fb = bm.faces.new(list(reversed(bot)))
    fb.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uvl = _uvl(bm)
    for f in bm.faces:
        if f.material_index != 1:
            continue
        f.normal_update()
        ax = 0 if abs(f.normal.x) > abs(f.normal.y) else 1
        for l in f.loops:
            co = l.vert.co
            l[uvl].uv = (co[1 - ax] / 1.5, co.z / 1.5) if abs(f.normal.z) < .5 else (co.x / 1.5, co.y / 1.5)
    for f in bm.faces:
        f.smooth = f.material_index == 0
    Part("ground_surface").add(bm, ["road_top", "soil"], smooth=None).build(coll, parent=root)
    # edge vegetation: fern fronds along both verges, one joined mesh (1 draw call), kept inside the tile
    veg = Part("edge_vegetation_cards")
    for side in (-1, 1):
        for row, (y0, y1) in enumerate(((1.95, 2.2), (2.3, 2.5), (2.55, 2.65))):
            nx = 12
            for i in range(nx):
                x = -2.55 + 5.1 * (i + 0.5 * row) / nx + rng.uniform(-.12, .12)
                if abs(x) > 2.6:
                    continue
                y = side * rng.uniform(y0, y1)
                add_fern(veg, rng, (x, y, h(x, y) - 0.01), s=rng.uniform(.75, 1.05), fronds=8, width=.17)
    veg.build(coll, parent=root)
    col_box("ground", coll, (6, 6, T), (0, 0, -T / 2), root)
    empty("snap_west", coll, (-3, 0, 0), root); empty("snap_east", coll, (3, 0, 0), root)


def build_stream_channel(coll, root, rng):
    L = 6.0; D = 0.8
    nx = 24
    yc = lambda x: 0.35 * math.sin(2 * math.pi * x / L)

    def prof(d):
        a = abs(d)
        if a < 0.55:
            return -0.5 - 0.06 * (1 - (a / 0.55) ** 2)
        if a < 1.05:
            t = (a - 0.55) / 0.5
            return -0.5 + 0.5 * (t * t * (3 - 2 * t))
        return 0.02 * noise.noise(Vector((a * 2, d, 0)))

    def block(name, ycols, mat_names, mat_fn):
        bm = _new()
        grid = []
        for i in range(nx + 1):
            x = -L / 2 + L * i / nx
            grid.append([bm.verts.new((x, y, prof(y - yc(x)) + (0.015 * noise.noise(Vector((x * 1.3, y * 1.3, 5))) if abs(y - yc(x)) > 1.05 else 0)))
                         for y in ycols(x)])
        m = len(grid[0])
        for i in range(nx):
            for j in range(m - 1):
                bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
        border = [grid[i][0] for i in range(nx + 1)] + [grid[nx][j] for j in range(1, m)] + \
                 [grid[i][m - 1] for i in range(nx - 1, -1, -1)] + [grid[0][j] for j in range(m - 2, 0, -1)]
        bot = [bm.verts.new((v.co.x, v.co.y, -D)) for v in border]
        for k in range(len(border)):
            k2 = (k + 1) % len(border)
            bm.faces.new((border[k2], border[k], bot[k], bot[k2]))
        bm.faces.new(list(reversed(bot)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            f.smooth = f.normal.z > 0.25
        Part(name).add(bm, mat_names, uv="world", mat_fn=mat_fn, smooth=None).build(coll, parent=root)

    def bank_fn(f):
        c = f.calc_center_median()
        if f.normal.z < 0.3:
            return 1
        return 0 if c.z > -0.12 else 1

    ln = lambda a, b, k: [a + (b - a) * t / k for t in range(k + 1)]
    block("left_bank", lambda x: ln(-2.0, yc(x) - 1.05, 6) + ln(yc(x) - 0.95, yc(x) - 0.55, 3), ["grass_ground", "soil"], bank_fn)
    block("right_bank", lambda x: ln(yc(x) + 0.55, yc(x) + 0.95, 3) + ln(yc(x) + 1.05, 2.0, 6), ["grass_ground", "soil"], bank_fn)
    block("streambed", lambda x: ln(yc(x) - 0.55, yc(x) + 0.55, 4), ["streambed", "soil"], lambda f: 0 if f.normal.z > 0.5 else 1)
    bm = _new(); uv = _uvl(bm)
    rows = []
    for i in range(nx + 1):
        x = -L / 2 + L * i / nx
        rows.append([bm.verts.new((x, yc(x) + d, -0.18)) for d in (-0.86, 0, 0.86)])
    for i in range(nx):
        for j in range(2):
            f = bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x + 3) / 3.0, (l.vert.co.y - yc(l.vert.co.x)) / 1.72)
    Part("water_plane").add(bm, "water", smooth=True).build(coll, parent=root)
    veg = Part("bank_vegetation")
    for side in (-1, 1):
        for row, (d0, d1) in enumerate(((1.12, 1.35), (1.45, 1.7))):
            for i in range(14):
                x = -2.65 + 5.3 * (i + 0.5 * row) / 14 + rng.uniform(-.12, .12)
                if abs(x) > 2.7:
                    continue
                y = max(-1.62, min(1.62, yc(x) + side * rng.uniform(d0, d1)))
                if rng.random() < 0.65:
                    add_fern(veg, rng, (x, y, 0.0), s=rng.uniform(.75, 1.05), fronds=9, mat="grass_blade", width=.14, L=(.24, .36), pitch=(30, 60))
                else:
                    add_tuft(veg, rng, (x, y, 0.0), s=rng.uniform(.8, 1.2), blades=11, width=.1, L=(.2, .36))
    veg.build(coll, parent=root)
    for side in (-1, 1):
        col_box("bank_%s" % ("L" if side < 0 else "R"), coll, (6, 0.9, D), (0, side * 1.55, -D / 2), root)
    col_box("streambed", coll, (6, 2.2, 0.3), (0, 0, -D + 0.15), root)
    empty("snap_west", coll, (-3, 0, 0), root); empty("snap_east", coll, (3, 0, 0), root)


def build_field_rock(coll, root, rng):
    bm = prim_ico(1.0, 4)
    sd = rng.random() * 10
    lumpy(bm, amp=0.13, freq=1.2, seed=sd)
    lumpy(bm, amp=0.05, freq=3.2, seed=sd + 4)
    for v in bm.verts:
        if v.co.z < -0.3:
            v.co.z = -0.3 + (v.co.z + 0.3) * 0.12
    seed = rng.random() * 5

    def moss_fn(f):
        c = f.calc_center_median()
        nz = noise.noise(c * 2.6 + Vector((seed, 0, 0)))
        if f.normal.z > 0.55 and nz > 0.05:
            return 1
        if c.z < -0.12 and nz > 0.25:
            return 1
        if abs(f.normal.z) < 0.5 and noise.noise(c * 5 + Vector((0, seed, 0))) > 0.45:
            return 1
        return 0

    ob = Part("stone_mesh").add(bm, ["stone_plates", "moss"], uv="world", uvscale=1.8, mat_fn=moss_fn, smooth=True).build(coll, parent=root)
    fit_parts([ob], SPEC["field_rock"])
    col_hull("stone", coll, [v.co.copy() for v in ob.data.vertices][::6], root)


def build_fallen_tree_root(coll, root, rng):
    seed = rng.random() * 10
    trunk = Part("trunk")
    pts = [(-0.7 + 2.2 * t, 0.06 * math.sin(t * 3), 0.43 - 0.06 * t) for t in [i / 11 for i in range(12)]]
    rad = [0.43 - 0.11 * (i / 11) for i in range(12)]
    tip_jag = lambda i, j: (0.7 if j % 2 else 1.05) if i == 11 else None

    def moss_fn(f):
        c = f.calc_center_median()
        if c.x > 1.45 and abs(f.normal.x) > .6:
            return 2
        return 1 if (f.normal.z > 0.3 and noise.noise(c * 2.2 + Vector((seed, 0, 0))) > -0.35) else 0
    trunk.add(prim_tube(pts, rad, segs=14, caps=(False, True), rough=0.16, seed=seed, uvscale=1.4, ring_jag=tip_jag),
              ["bark_oak", "moss", "wood_raw"], mat_fn=moss_fn, smooth=True)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-.3, .3)
        base = Vector((1.47, 0.22 * math.cos(a), 0.37 + 0.22 * math.sin(a)))
        tip = base + Vector((rng.uniform(.12, .28), 0.05 * math.cos(a), 0.05 * math.sin(a)))
        trunk.add(prim_tube([base, tip], [0.08, 0], segs=4, flat_y=.5, uvscale=.6), "wood_raw", smooth=False)
    roots = Part("root_mass")
    roots.add(prim_tube([(-0.65, 0, 0.43), (-0.8, 0, 0.44), (-0.92, 0, 0.46)], [0.44, 0.5, 0.56], segs=14, caps=(False, True), rough=.15,
                        seed=seed + 3, uvscale=1.4), ["bark_oak", "wood_raw"], mat_fn=lambda f: 1 if f.normal.x < -.7 else 0, smooth=True)
    for k in range(13):
        a = 2 * math.pi * k / 13 + rng.uniform(-.15, .15)
        ca, sa = math.cos(a), math.sin(a)
        start = Vector((-0.88, 0.36 * ca, 0.46 + 0.36 * sa))
        dirv = Vector((-0.85, 0.5 * ca, 0.55 * sa)).normalized()
        Ln = rng.uniform(.35, .6)
        mid = start + dirv * Ln * .5 + Vector((0, rng.uniform(-.05, .05), rng.uniform(-.04, .08)))
        end = start + dirv * Ln
        end.z = max(end.z, 0.05); mid.z = max(mid.z, 0.08)
        r0 = rng.uniform(.14, .2)
        roots.add(prim_tube([start, mid, end], [r0, r0 * .7, r0 * .45], segs=6, rough=.2, seed=k, flat_y=.55, uvscale=1.0,
                            caps=(False, True), ring_jag=lambda i, j: (0.6 if j % 2 else 1.0) if i == 2 else None,
                            seg_mat=lambda i: 1 if i == 1 else 0),
                  ["bark_oak", "wood_raw"], smooth=True)
    stubs = Part("branch_stubs")
    for (x, a, Ln) in ((0.1, 1.2, .55), (0.7, 2.2, .45), (-0.2, -1.0, .4), (1.0, 0.6, .38), (0.4, 1.9, .32)):
        ca, sa = math.cos(a), math.sin(a)
        base = Vector((x, 0.3 * ca, 0.40 + 0.3 * sa))
        d = Vector((0.35, ca, sa)).normalized()
        tip = base + d * Ln
        tip.z = max(tip.z, 0.08)
        stubs.add(prim_tube([base, base + d * Ln * .6, tip], [0.1, 0.07, 0.05], segs=6, caps=(False, True), rough=.1,
                            ring_jag=lambda i, j: (0.55 if j % 2 else 1.0) if i == 2 else None, uvscale=1.0,
                            seg_mat=lambda i: 1 if i == 1 else 0),
                  ["bark_oak", "wood_raw"], smooth=True)
    for k in range(30):
        x = rng.uniform(-0.6, 1.35)
        t = (x + 0.7) / 2.2
        a = rng.uniform(0.35, 2.8)
        r = (0.43 - 0.11 * t) * 0.98
        loc = Vector((x, math.cos(a) * r + 0.06 * math.sin(t * 3), (0.43 - 0.06 * t) + math.sin(a) * r))
        yaw = rng.uniform(0, 6.28)
        stubs.add(prim_leaf(.17, .11, segs=3, curve=.3, fold=.2), "leaf_broad",
                  matrix=Matrix.Translation(loc) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-0.3, 4, "Y"))
    objs = [trunk.build(coll, parent=root), roots.build(coll, parent=root), stubs.build(coll, parent=root)]
    fit_parts(objs, SPEC["fallen_tree_root"])
    col_box("log", coll, (2.4, 0.8, 0.8), (0.3, 0, 0.4), root)
    col_box("roots", coll, (0.6, 1.2, 0.95), (-1.2, 0, 0.47), root)


def build_vegetable_garden_bed(coll, root, rng):
    W, Dp = 3.6, 2.7
    bed = Part("soil_bed")
    bm = prim_box(W - 0.2, Dp - 0.2, 0.1, bevel=0.03, center=(0, 0, 0.05))
    bed.add(bm, "soil_dark", uv="world", smooth=False)
    # raised, lumpy earth rim
    rx, ry = W / 2 - 0.12, Dp / 2 - 0.12
    ring = [(-rx, -ry), (rx, -ry), (rx, ry), (-rx, ry)]
    pts = []
    for k in range(4):
        a, b = Vector((*ring[k], 0.1)), Vector((*ring[(k + 1) % 4], 0.1))
        nseg = int((b - a).length / 0.3)
        for i in range(nseg):
            pts.append(a.lerp(b, i / nseg))
    pts.append(pts[0].copy())
    rim = prim_tube(pts, [0.13] * len(pts), segs=8, caps=(False, False), rough=.18, seed=3, uvscale=1.0)
    for v in rim.verts:
        v.co.z = max(v.co.z, 0.0)
        v.co.z = 0.04 + (v.co.z) * 0.85
    bed.add(rim, "soil", uv="world", smooth=True)
    furrows = Part("furrows")
    rows = [-0.72, 0.0, 0.72]
    for r in rows:
        bm = prim_tube([(-W / 2 + 0.32, r, 0.08), (0, r + 0.02, 0.08), (W / 2 - 0.32, r, 0.08)], [0.25, 0.26, 0.25], segs=10, rough=.12, seed=r * 7, uvscale=1.2)
        for v in bm.verts:
            v.co.z = 0.08 + max(0.0, v.co.z - 0.08) * 0.42
        furrows.add(bm, "soil", uv="world", smooth=True)
    bed.build(coll, parent=root); furrows.build(coll, parent=root)
    veg = Part("vegetable_clumps")
    for r in rows:
        for i in range(6):
            x = -1.32 + 2.64 * i / 5 + rng.uniform(-.05, .05)
            base = Matrix.Translation((x, r + rng.uniform(-.04, .04), 0.17)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z")
            s = rng.uniform(.9, 1.1)
            for k in range(5):
                yaw = 2 * math.pi * k / 5 + rng.uniform(-.2, .2)
                veg.add(prim_leaf(rng.uniform(.27, .32) * s, .18 * s, segs=4, curve=.4, fold=.28), "seedling_leaf",
                        matrix=base @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-math.radians(rng.uniform(36, 48)), 4, "Y"))
    veg.build(coll, parent=root)
    col_box("bed", coll, (W, Dp, 0.2), (0, 0, 0.1), root)


# ---------------------------------------------------------------------------- vegetation
def build_oak_tree(coll, root, rng):
    seed = rng.random() * 10
    trunk = Part("trunk_branches")
    trunk.add(prim_tube([(0, 0, 0), (0.06, 0.02, 0.6), (-0.04, 0.06, 1.3), (0.02, 0.0, 1.95)], [0.6, 0.44, 0.38, 0.34],
                        segs=12, caps=(True, False), rough=.18, seed=seed, uvscale=1.4), "bark_oak", smooth=True)
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-.3, .3)
        d = Vector((math.cos(a), math.sin(a), 0))
        trunk.add(prim_tube([d * 0.22 + Vector((0, 0, 0.5)), d * 0.55 + Vector((0, 0, 0.14)), d * 0.95 + Vector((0, 0, 0.0))],
                            [0.2, 0.12, 0.0], segs=7, rough=.1, uvscale=1.0), "bark_oak", smooth=True)
    fork = Vector((0.02, 0, 1.9))
    limbs = [((-0.95, 0.2, 3.0), 0.24, [(-1.45, 0.35, 3.6), (-0.8, -0.35, 3.9)]),
             ((0.95, -0.15, 3.0), 0.24, [(1.45, -0.2, 3.55), (0.85, 0.45, 3.95)]),
             ((0.1, 0.55, 3.3), 0.2, [(0.25, 0.95, 4.1), (-0.3, 0.3, 4.5)]),
             ((0.0, -0.5, 3.4), 0.2, [(0.15, -0.95, 4.0), (0.4, -0.2, 4.6)])]
    tips = []
    for (mid, r, subs) in limbs:
        m = Vector(mid)
        a = fork.lerp(m, 0.5) + Vector((0, 0, -0.1))
        trunk.add(prim_tube([fork, a, m], [0.3, r, r * 0.75], segs=9, rough=.12, seed=sum(mid), uvscale=1.2), "bark_oak", smooth=True)
        for s in subs:
            t = Vector(s)
            trunk.add(prim_tube([m, m.lerp(t, .5) + Vector((0, 0, .08)), t], [r * .7, r * .45, r * .2], segs=7, uvscale=1.0), "bark_oak", smooth=True)
            tips.append(t)
    tr = trunk.build(coll, parent=root)
    leaves = Part("leaf_clusters")
    centers = [(t + Vector((0, 0, 0.25)), rng.uniform(.62, .8)) for t in tips]
    centers += [(Vector((0, 0.05, 4.85)), 0.85), (Vector((-1.6, 0.0, 2.95)), 0.55), (Vector((1.6, 0.1, 2.9)), 0.55),
                (Vector((-0.6, 0.8, 3.5)), 0.55), (Vector((0.65, -0.75, 3.45)), 0.55),
                (Vector((-1.15, -0.7, 3.35)), 0.45), (Vector((1.1, 0.8, 3.4)), 0.45), (Vector((-0.4, 0.2, 4.55)), 0.55),
                (Vector((0.6, -0.1, 4.5)), 0.55), (Vector((-1.8, 0.4, 3.3)), 0.4), (Vector((1.85, -0.35, 3.3)), 0.4)]
    for i, (c, r) in enumerate(centers):
        bm = prim_ico(1.0, 2)
        lumpy(bm, amp=0.12, freq=2.8, seed=i * 1.7 + seed)
        bm.transform(Matrix.Diagonal((r * .78, r * .78, r * 0.62, 1)))
        leaves.add(bm, "leaves_oak", loc=c, uv="world", smooth=True)
        for k in range(7):  # small bumps around the top/sides -> scalloped cluster silhouette
            a = 2 * math.pi * k / 7 + rng.uniform(-.3, .3)
            el = rng.uniform(0.0, 0.9)
            d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.8))
            rb = r * rng.uniform(.38, .5)
            bb = prim_ico(1.0, 2)
            lumpy(bb, amp=0.1, freq=3.0, seed=i * 3.1 + k)
            bb.transform(Matrix.Diagonal((rb, rb, rb * .85, 1)))
            leaves.add(bb, "leaves_oak", loc=c + d * r * .62, uv="world", smooth=True)
    lv = leaves.build(coll, parent=root)
    fit_parts([tr, lv], SPEC["oak_tree"])
    col_box("trunk", coll, (0.8, 0.8, 2.2), (0, 0, 1.1), root)


def build_pine_tree(coll, root, rng):
    trunk = Part("trunk")
    trunk.add(prim_tube([(0, 0, 0), (0, 0, 0.5), (0, 0.02, 3.5), (0, 0, 6.3)], [0.32, 0.2, 0.14, 0.03], segs=10,
                        caps=(True, False), rough=.12, uvscale=1.4), "bark_dark", smooth=True)
    for k in range(4):
        a = 2 * math.pi * k / 4 + .4
        d = Vector((math.cos(a), math.sin(a), 0))
        trunk.add(prim_tube([d * .15 + Vector((0, 0, .35)), d * .5 + Vector((0, 0, 0))], [.12, 0], segs=6, uvscale=1.0), "bark_dark", smooth=True)
    tiers = Part("branch_tiers")
    nt = 9
    for t in range(nt):
        f = t / (nt - 1)
        z0 = 1.25 + f * 4.75
        R = 1.45 * (1 - f) ** 0.9 + 0.28
        nb = max(5, int(9 - 4 * f))
        rot = rng.uniform(0, 6.28)
        # core cone of the tier
        tiers.add(prim_cyl(R * 0.38, 0.02, 0.55, segs=8, z0=z0 - 0.1), "leaves_pine", uv="world", smooth=True)
        # drooping boughs radiating from the trunk
        for b in range(nb):
            a = 2 * math.pi * b / nb + rot + rng.uniform(-.2, .2)
            d = Vector((math.cos(a), math.sin(a), 0))
            Lb = R * rng.uniform(.85, 1.05)
            p0 = Vector((0, 0, z0 + 0.2)) + d * 0.08
            p1 = Vector((0, 0, z0 + 0.12)) + d * Lb * 0.5
            p2 = Vector((0, 0, z0 - 0.18 * Lb)) + d * Lb
            p2 = Vector((0, 0, z0 - 0.3 * Lb)) + d * Lb
            jag = lambda i, j: (1.0 if j % 2 == 0 else 0.55)
            tiers.add(prim_tube([p0, p1, p2], [0.28 * Lb + 0.08, 0.22 * Lb + 0.05, 0.0], segs=10, flat_y=0.42, ring_jag=jag, uvscale=1.3),
                      "leaves_pine", smooth=False)
    tiers.add(prim_cyl(0.2, 0.0, 0.7, segs=8, z0=6.0), "leaves_pine", uv="world")
    objs = [trunk.build(coll, parent=root), tiers.build(coll, parent=root)]
    fit_parts(objs, SPEC["pine_tree"])
    col_box("trunk", coll, (0.5, 0.5, 2.0), (0, 0, 1.0), root)


def build_roadside_bush(coll, root, rng):
    stems = Part("woody_stems")
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-.3, .3)
        d = Vector((math.cos(a), math.sin(a), 0))
        stems.add(prim_tube([(0, 0, 0), d * .25 + Vector((0, 0, .26)), d * .5 + Vector((0, 0, .46))], [.05, .035, .015], segs=5, uvscale=.8), "bark", smooth=True)
    masses = Part("leaf_masses")
    blobs = [((0, 0, .5), .36), ((-.38, .08, .4), .27), ((.38, -.05, .4), .28), ((.1, .3, .42), .25), ((-.12, -.3, .42), .25)]
    for i, (c, r) in enumerate(blobs):
        bm = prim_ico(1.0, 2)
        lumpy(bm, amp=.2, freq=2.5, seed=i * 2.3)
        bm.transform(Matrix.Diagonal((r, r, r * .8, 1)))
        masses.add(bm, "leaves_bush", loc=c, uv="world", smooth=True)
    cards = Part("leaf_cards")
    center = Vector((0, 0, 0.28))
    for i in range(150):
        u = rng.uniform(0, 6.28); v = rng.uniform(-0.05, 1.35)
        d = Vector((math.cos(u) * math.cos(v), math.sin(u) * math.cos(v), math.sin(v)))
        base = center + Vector((d.x * .48, d.y * .42, d.z * .38))
        yaw = math.atan2(d.y, d.x) + rng.uniform(-.5, .5)
        pitch = min(1.35, v * 0.8 + rng.uniform(0.05, 0.45))
        cards.add(prim_leaf(rng.uniform(.34, .48), .2, segs=4, curve=.45, fold=.3), "leaf_bush",
                  matrix=Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y"))
    objs = [stems.build(coll, parent=root), masses.build(coll, parent=root), cards.build(coll, parent=root)]
    fit_parts(objs, SPEC["roadside_bush"])


def _tuft(coll, root, rng, name="blade_clumps", mat="grass_blade"):
    p = Part(name)
    for i in range(22):
        yaw = 2 * math.pi * i / 22 + rng.uniform(-.2, .2)
        inner = i % 3 == 0
        pitch = math.radians(rng.uniform(72, 84) if inner else rng.uniform(48, 68))
        L = rng.uniform(.5, .66) if inner else rng.uniform(.32, .5)
        base = Vector((math.cos(yaw), math.sin(yaw), 0)) * rng.uniform(0.01, 0.05)
        p.add(prim_leaf(L, rng.uniform(.1, .13), segs=5, curve=rng.uniform(.3, .55), fold=.3, shape="leaf", twist=rng.uniform(-.4, .4)),
              mat, matrix=Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y"))
    return p.build(coll, parent=root)


def build_grass_tuft(coll, root, rng):
    ob = _tuft(coll, root, rng)
    fit_parts([ob], SPEC["grass_tuft"])


def build_flower_patch(coll, root, rng):
    leaves = Part("stems_and_leaves")
    leaves.add(prim_cyl(0.15, 0.1, 0.03, segs=10), "soil_dark", uv="world")
    for i in range(30):
        yaw = 2 * math.pi * i / 30 + rng.uniform(-.2, .2)
        tier = i % 3
        pitch = (rng.uniform(18, 32), rng.uniform(40, 55), rng.uniform(60, 75))[tier]
        leaves.add(prim_leaf(rng.uniform(.24, .32), .15, segs=4, curve=.4, fold=.3), "flower_leaf",
                   matrix=Matrix.Translation((math.cos(yaw) * .05, math.sin(yaw) * .05, .02 + .03 * tier)) @ Matrix.Rotation(yaw, 4, "Z")
                   @ Matrix.Rotation(-math.radians(pitch), 4, "Y"))
    heads = Part("flower_heads")
    for i in range(14):
        a = rng.uniform(0, 6.28); r = rng.uniform(0.03, .24)
        top = Vector((math.cos(a) * r, math.sin(a) * r * .85, rng.uniform(.3, .42)))
        leaves.add(prim_tube([(top.x * .3, top.y * .3, .03), (top.x * .8, top.y * .8, top.z * .6), top], [.009, .008, .007], segs=4, uvscale=.2),
                   "flower_leaf", smooth=True)
        if i < 11:
            mat = "petal_cream" if i % 3 == 0 else "petal_lavender"
            size = .08 if mat == "petal_cream" else .065
            tilt = Matrix.Rotation(rng.uniform(-.45, .45), 4, "X") @ Matrix.Rotation(rng.uniform(-.45, .45), 4, "Y")
            for k in range(5):
                yaw = 2 * math.pi * k / 5
                heads.add(prim_leaf(size, size * 1.0, segs=3, curve=-.12, fold=.1, shape="petal"), mat,
                          matrix=Matrix.Translation(top) @ tilt @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-0.12, 4, "Y"))
            heads.add(prim_ico(size * .25, 1), "petal_cream", loc=top + Vector((0, 0, .012)), uv="world", uvscale=10)
        else:
            bm = prim_ico(1, 1); bm.transform(Matrix.Diagonal((.02, .02, .035, 1)))
            heads.add(bm, "petal_lavender", loc=top, uv="world", uvscale=10, smooth=True)
    objs = [leaves.build(coll, parent=root), heads.build(coll, parent=root)]
    fit_parts(objs, SPEC["flower_patch"])


def build_potted_plant(coll, root, rng):
    prof = [(0.12, 0.0), (0.15, 0.03), (0.19, 0.12), (0.2, 0.2), (0.19, 0.25), (0.205, 0.26), (0.215, 0.29),
            (0.2, 0.3), (0.175, 0.29), (0.17, 0.25)]
    Part("pot").add(prim_lathe(prof, segs=20, uvscale=.6), "terracotta", smooth=True).build(coll, parent=root)
    soil = Part("soil")
    soil.add(prim_cyl(0.172, 0.172, 0.012, segs=20, z0=0.238), "soil_dark", uv="world")
    soil.build(coll, parent=root)
    plant = Part("plant")
    base = Vector((0, 0, 0.25))
    for i in range(9):
        yaw = 2 * math.pi * i / 9 + rng.uniform(-.2, .2)
        d = Vector((math.cos(yaw), math.sin(yaw), 0))
        h = rng.uniform(.12, .22) if i % 2 else rng.uniform(.26, .36)
        top = base + d * rng.uniform(.04, .07) + Vector((0, 0, h))
        plant.add(prim_tube([base + d * .01, base + d * .025 + Vector((0, 0, h * .5)), top], [.01, .009, .007], segs=5, uvscale=.3),
                  "leaf_broad", smooth=True)
        pitch = rng.uniform(-.25, .35)
        plant.add(prim_leaf(rng.uniform(.2, .24), .13, segs=5, curve=.5, fold=.25), "leaf_broad",
                  matrix=Matrix.Translation(top) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y"))
    pl = plant.build(coll, parent=root)
    sx, sy, sz = SPEC["potted_plant"]
    cs = [pl.matrix_world @ v.co for v in pl.data.vertices]
    mx = Vector((max(abs(c.x) for c in cs), max(abs(c.y) for c in cs), max(c.z for c in cs)))
    s = Vector((min(1.4, sx / 2 / mx.x), min(1.4, sy / 2 / mx.y), 1.0))  # stay inside the 0.45 x 0.40 envelope
    for v in pl.data.vertices:
        v.co.x *= s.x; v.co.y *= s.y
        if v.co.z > 0.25:
            v.co.z = 0.25 + (v.co.z - 0.25) * (sz - 0.25) / (mx.z - 0.25)
    empty("plant_insert", coll, (0, 0, 0.25), root)
    col_box("pot", coll, (0.42, 0.42, 0.3), (0, 0, 0.15), root)


# ---------------------------------------------------------------------------- road & defence
def build_low_stone_wall(coll, root, rng):
    wall = Part("wall_section"); caps = Part("cap_stones"); pillar = Part("end_pillar")
    x0, x1 = -1.5, 0.92
    courses = [(0.0, 0.3), (0.3, 0.58), (0.58, 0.84)]
    for ci, (z0, z1) in enumerate(courses):
        x = x0 + (0.0 if ci % 2 == 0 else -0.22)
        while x < x1 - 0.05:
            ln = rng.uniform(0.38, 0.6)
            a, b = max(x, x0), min(x + ln, x1)
            if b - a > 0.08:
                bm = prim_box(b - a - 0.025, 0.4, z1 - z0 - 0.025, bevel=0.045)
                jitter(bm, 0.012, rng)
                moss = ci == 0
                wall.add(bm, ["stone", "moss"], loc=((a + b) / 2, rng.uniform(-.012, .012), (z0 + z1) / 2), uv="box", rng=rng,
                         mat_fn=(lambda f, m=moss: 1 if (f.normal.z < 0.5 and f.calc_center_median().z < (0.2 if m else 0.62) and noise.noise(f.calc_center_median() * 3.5) > (-0.15 if m else 0.35)) else 0))
            x += ln
    x = x0
    while x < x1 - 0.05:
        ln = rng.uniform(0.42, 0.58)
        a, b = x, min(x + ln, x1)
        if b - a > 0.1:
            bm = prim_box(b - a - 0.02, 0.46, 0.13, bevel=0.05)
            jitter(bm, 0.01, rng)
            caps.add(bm, "stone", loc=((a + b) / 2, 0, 0.84 + 0.065), uv="box", rng=rng)
        x += ln
    # end pillar (blocks + cap)
    px = 1.5 - 0.25
    for k, (z0, z1) in enumerate([(0, 0.36), (0.36, 0.7), (0.7, 1.04)]):
        bm = prim_box(0.48, 0.48, z1 - z0 - 0.02, bevel=0.05); jitter(bm, 0.01, rng)
        pillar.add(bm, ["stone", "moss"], loc=(px, 0, (z0 + z1) / 2), uv="box", rng=rng,
                   mat_fn=(lambda f, kk=k: 1 if (kk == 0 and f.normal.z < .5 and f.calc_center_median().z < .16 and noise.noise(f.calc_center_median() * 4 + Vector((3, 0, 0))) > -.1) else 0))
    pillar.add(prim_box(0.55, 0.55, 0.1, bevel=0.03), "stone", loc=(px, 0, 1.09), uv="box", rng=rng)
    bm = prim_box(0.46, 0.46, 0.06, bevel=0.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= 0.7; v.co.y *= 0.7
    pillar.add(bm, "stone", loc=(px, 0, 1.17), uv="box", rng=rng)
    for prt in (wall, caps):
        prt.build(coll, parent=root)
    pillar.build(coll, pivot=(px, 0, 0), parent=root)
    col_box("wall", coll, (2.45, 0.46, 0.97), (-0.27, 0, 0.485), root)
    col_box("pillar", coll, (0.55, 0.55, 1.2), (px, 0, 0.6), root)
    empty("snap_west", coll, (-1.5, 0, 0), root); empty("snap_east", coll, (1.5, 0, 0), root)


def build_wooden_garden_fence(coll, root, rng):
    post = Part("post_L")
    bm = prim_box(0.26, 0.26, 1.0, bevel=0.03, center=(0, 0, 0.5)); jitter(bm, 0.008, rng)
    for v in bm.verts:  # softly chamfered, slightly uneven top
        if v.co.z > 0.95:
            v.co.z += rng.uniform(-.03, .01)
    post.add(bm, "wood_mid", uv="box", rng=rng, long_axis=2)
    for z in (0.32, 0.66):  # tenon blocks on the outer face
        post.add(prim_box(0.08, 0.12, 0.13, bevel=0.015), "wood_mid", loc=(-0.17, 0, z), uv="box", rng=rng)
    pL = post.build(coll, parent=root)
    pL.location = (-1.29, 0, 0)
    pR = instance(pL, "post_R", coll, (1.29, 0, 0), (0, 0, math.pi), parent=root)
    for nm, z in (("rail_lower", 0.32), ("rail_upper", 0.66)):
        bm = _new()
        r = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(2.6, 0.085, 0.16), verts=bm.verts)
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > 1], cuts=7, use_grid_fill=True)
        ph = rng.uniform(0, 6)
        for v in bm.verts:
            v.co.z += 0.03 * math.sin(v.co.x * 2.1 + ph)
            v.co.y += 0.012 * math.sin(v.co.x * 3.3 + ph)
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > 0.3], offset=0.02, segments=1, affect="EDGES", clamp_overlap=True)
        Part(nm).add(bm, "wood_light", loc=(0, 0, z), uv="world", long_axis=0).build(coll, parent=root)
    col_box("fence", coll, (3.0, 0.26, 1.0), (0, 0, 0.5), root)
    empty("snap_west", coll, (-1.5, 0, 0), root); empty("snap_east", coll, (1.5, 0, 0), root)


def build_wooden_barricade(coll, root, rng):
    posts = Part("posts"); beams = Part("crossbeams"); braces = Part("rear_braces"); bands = Part("iron_bands")
    for sx in (-0.62, 0.62):
        bm = prim_box(0.18, 0.18, 0.7, bevel=0.02, center=(0, 0, 0.35)); jitter(bm, .006, rng)
        posts.add(bm, "wood_mid", loc=(sx, 0, 0), uv="box", rng=rng, long_axis=2)
        posts.add(prim_pyramid(0.18, 0.2, z0=0.7), "wood_mid", loc=(sx, 0, 0), uv="box", rng=rng)
        for z in (0.24, 0.56):
            bands.add(prim_box(0.2, 0.2, 0.06), "iron", loc=(sx, 0, z), uv="box")
        # rear triangle: foot along +Y on ground and diagonal brace
        foot = prim_box(0.12, 0.54, 0.1, bevel=0.015)
        braces.add(foot, "wood_mid", loc=(sx, 0.17, 0.05), uv="box", rng=rng)
        L = math.hypot(0.4, 0.5)
        br = prim_box(0.1, L, 0.1, bevel=0.015)
        braces.add(br, "wood_mid", loc=(sx, 0.29, 0.33), rot=(math.atan2(-0.5, 0.4) + 0.0, 0, 0), uv="box", rng=rng)
    for z in (0.24, 0.56):
        bm = prim_box(1.66, 0.09, 0.17, bevel=0.025); jitter(bm, .008, rng)
        beams.add(bm, "wood_light", loc=(0, -0.12, z), uv="box", rng=rng, long_axis=0)
    for p in (posts, beams, braces, bands):
        p.build(coll, parent=root)
    col_box("barricade", coll, (1.7, 0.3, 0.9), (0, -0.05, 0.45), root)


def build_checkpoint_barrier(coll, root, rng):
    posts = Part("fixed_posts")
    xl, xr = -1.6, 1.6
    bm = prim_box(0.36, 0.36, 1.2, bevel=0.03, center=(0, 0, 0.6)); jitter(bm, .008, rng)
    posts.add(bm, "wood_mid", loc=(xl, 0, 0), uv="box", rng=rng, long_axis=2)
    bm = prim_box(0.36, 0.36, 0.72, bevel=0.03, center=(0, 0, 0.36)); jitter(bm, .008, rng)
    posts.add(bm, "wood_mid", loc=(xr, 0, 0), uv="box", rng=rng, long_axis=2)
    iron = Part("iron_fittings")
    for (x, z) in ((xl, 0.12), (xl, 0.62), (xl, 1.08), (xr, 0.12), (xr, 0.6)):
        iron.add(prim_box(0.39, 0.39, 0.11), "iron", loc=(x, 0, z), uv="box")
        iron.add(prim_pyramid(0.05, 0.025), "iron", loc=(x, -0.195, z), rot=(math.pi / 2, 0, 0), uv="box")
    # stop support: U cradle on the right post
    stop = Part("stop_support")
    stop.add(prim_box(0.3, 0.38, 0.04), "iron", loc=(xr, 0, 0.74), uv="box")
    for sy in (-0.15, 0.15):
        stop.add(prim_box(0.26, 0.04, 0.2), "iron", loc=(xr, sy, 0.84), uv="box")
    # hinge leaf on the left post (fixed) + crossbar with hinge barrel (moving)
    hinge_x, hinge_z = xl + 0.24, 0.85
    hinge = Part("iron_hinge")
    hinge.add(prim_box(0.06, 0.3, 0.26), "iron", loc=(xl + 0.2, 0, hinge_z), uv="box")
    hinge.add(prim_tube([(hinge_x, -0.17, hinge_z), (hinge_x, 0.17, hinge_z)], [0.05, 0.05], segs=8, uvscale=.3), "iron", smooth=True)
    bar = Part("crossbar")
    n = 13
    xs = [hinge_x + 0.02 + (xr + 0.17 - hinge_x - 0.02) * i / (n - 1) for i in range(n)]
    bar.add(prim_tube([(x, 0, hinge_z) for x in xs], [0.085] * n, segs=10, uvscale=1.0,
                      seg_mat=lambda i: 1 if (i % 3 == 1 and 1 <= i <= n - 3) else 0),
            ["wood_mid", "paint_cream"], smooth=True)
    bar.add(prim_box(0.16, 0.2, 0.18), "iron", loc=(hinge_x + 0.1, 0, hinge_z), uv="box")  # strap at hinge
    for p in (posts, iron, stop, hinge):
        p.build(coll, parent=root)
    cb = bar.build(coll, pivot=(hinge_x, 0, hinge_z), parent=root)
    cb["pivot_axis"] = "local Y (lift)"
    col_box("posts_L", coll, (0.36, 0.36, 1.2), (xl, 0, 0.6), root)
    col_box("posts_R", coll, (0.36, 0.36, 0.9), (xr, 0, 0.45), root)
    col_box("crossbar", coll, (xr + 0.17 - hinge_x, 0.17, 0.17), (hinge_x + (xr + 0.17 - hinge_x) / 2, 0, hinge_z), cb)


def build_forest_defense_gate(coll, root, rng):
    posts = Part("side_posts")
    for sx in (-0.92, 0.92):
        bm = prim_box(0.4, 0.4, 2.0, bevel=0.025, center=(0, 0, 1.0)); jitter(bm, .006, rng)
        posts.add(bm, "wood_dark", loc=(sx, 0, 0), uv="box", rng=rng, long_axis=2)
        posts.add(prim_box(0.18, 0.03, 1.7, bevel=0.008), "wood_light", loc=(sx, -0.213, 0.95), uv="box", rng=rng, long_axis=2)
        posts.add(prim_box(0.44, 0.44, 0.12, bevel=0.02), "wood_dark", loc=(sx, 0, 2.06), uv="box", rng=rng)
        posts.add(prim_pyramid(0.34, 0.18, z0=2.12), "wood_dark", loc=(sx, 0, 0), uv="box", rng=rng)
    posts.build(coll, parent=root)
    hx = -0.7
    leaf = Part("gate_leaf")
    nplank = 6; w = 1.4 / nplank
    for i in range(nplank):
        x = hx + w * (i + 0.5)
        bm = prim_box(w - 0.012, 0.09, 2.66, bevel=0.012, center=(0, 0, 1.33)); jitter(bm, .004, rng)
        leaf.add(bm, "wood_light", loc=(x, 0, 0), uv="box", rng=rng, long_axis=2)
    for sx in (hx + 0.04, hx + 1.4 - 0.04):  # dark frame stiles
        leaf.add(prim_box(0.08, 0.13, 2.8, bevel=0.01, center=(0, 0, 1.4)), "wood_dark", loc=(sx, 0, 0), uv="box", rng=rng, long_axis=2)
    leaf.add(prim_box(1.4, 0.13, 0.1, bevel=0.01), "wood_dark", loc=(hx + 0.7, 0, 2.75), uv="box", rng=rng)
    gl = leaf.build(coll, pivot=(hx, 0, 0), parent=root)
    gl["pivot_axis"] = "local Z (hinge on left stile)"
    braces = Part("cross_braces"); fit = Part("metal_fittings")
    for z in (0.62, 2.05):
        braces.add(prim_box(1.34, 0.06, 0.14, bevel=0.01), "wood_dark", loc=(hx + 0.7, -0.075, z), uv="box", rng=rng, long_axis=0)
        for sx in (hx + 0.12, hx + 1.28):
            fit.add(prim_box(0.14, 0.03, 0.18), "iron", loc=(sx, -0.115, z), uv="box")
            fit.add(prim_pyramid(0.05, 0.02), "iron", loc=(sx, -0.13, z), rot=(math.pi / 2, 0, 0), uv="box")
    # hinge straps on the left (fixed to leaf)
    for z in (0.4, 2.35):
        fit.add(prim_box(0.36, 0.03, 0.08), "iron", loc=(hx + 0.18, -0.075, z), uv="box")
    braces.build(coll, pivot=(hx, 0, 0), parent=gl); fit.build(coll, pivot=(hx, 0, 0), parent=gl)
    plq = Part("shield_plaque")
    outline = [(-0.14, 0.2), (0.14, 0.2), (0.14, -0.02), (0.0, -0.2), (-0.14, -0.02)]
    bm = prim_prism_xz(outline, 0.03)
    uv_planar(bm, axes=(0, 2))
    plq.add(bm, "plaque", loc=(hx + 0.7, -0.045, 1.55))
    plq.build(coll, pivot=(hx, 0, 0), parent=gl)
    # existing damage / fire effect anchors
    for i, (x, z) in enumerate(((0.35, 1.0), (-0.3, 1.9), (0.1, 2.5))):
        empty("vfx_damage_%d" % i, coll, (x, -0.12, z), gl)
    for i, (x, z) in enumerate(((-0.3, 0.3), (0.35, 0.25))):
        empty("vfx_fire_%d" % i, coll, (x, -0.12, z), gl)
    for sx in (-0.92, 0.92):
        col_box("post_%s" % ("L" if sx < 0 else "R"), coll, (0.44, 0.44, 2.3), (sx, 0, 1.15), root)
    col_box("gate_leaf", coll, (1.4, 0.15, 2.8), (0.0, 0, 1.4), gl)


def build_timber_footbridge(coll, root, rng):
    beams = Part("beams"); deck = Part("deck_boards"); posts = Part("posts"); rails = Part("rails"); rope = Part("rope_lashings")
    for sy in (-0.72, 0.72):
        bm = prim_box(4.2, 0.2, 0.22, bevel=0.02, center=(0, 0, 0.11)); jitter(bm, .006, rng)
        beams.add(bm, "wood_mid", loc=(0, sy, 0), uv="box", rng=rng, long_axis=0)
    for x in (-1.8, -0.9, 0, 0.9, 1.8):
        bm = prim_box(0.16, 2.2, 0.12, bevel=0.015, center=(0, 0, 0.28)); jitter(bm, .006, rng)
        beams.add(bm, "wood_mid", loc=(x, 0, 0), uv="box", rng=rng, long_axis=1)
    nb = 8; bw = 1.84 / nb
    for i in range(nb):
        y = -0.92 + bw * (i + 0.5)
        ln = rng.uniform(3.6, 3.85)
        bm = prim_box(ln, bw - 0.018, 0.06, bevel=0.012, center=(0, 0, 0.37)); jitter(bm, .008, rng)
        deck.add(bm, "wood_light", loc=(rng.uniform(-.06, .06), y, rng.uniform(-.006, .006)), rot=(rng.uniform(-.01, .01), 0, rng.uniform(-.004, .004)),
                 uv="box", rng=rng, long_axis=0)
    for x in (-1.88, 1.88):
        for y in (-0.97, 0.97):
            bm = prim_box(0.17, 0.17, 1.08, bevel=0.02, center=(0, 0, 0.54)); jitter(bm, .006, rng)
            posts.add(bm, "wood_mid", loc=(x, y, 0), uv="box", rng=rng, long_axis=2)
            posts.add(prim_pyramid(0.17, 0.17, z0=1.08), "wood_mid", loc=(x, y, 0), uv="box", rng=rng)
            for z in (0.5, 0.98):
                rope.add(prim_torus(0.112, 0.022, segs=10, rsegs=5), "rope", loc=(x, y, z))
                rope.add(prim_torus(0.112, 0.022, segs=10, rsegs=5), "rope", loc=(x, y, z - 0.045))
    for y in (-0.97, 0.97):
        rails.add(prim_tube([(-1.88, y, 0.98), (0, y, 0.995), (1.88, y, 0.98)], [0.055, 0.06, 0.055], segs=8, rough=.06, uvscale=1.0), "wood_mid", smooth=True)
        rails.add(prim_tube([(-1.88, y, 0.52), (1.88, y, 0.52)], [0.045, 0.045], segs=8, rough=.06, uvscale=1.0), "wood_mid", smooth=True)
        rails.add(prim_tube([(-1.88, y, 0.62), (-1.35, y, 0.96)], [0.04, 0.04], segs=6, uvscale=1.0), "wood_mid", smooth=True)
        rails.add(prim_tube([(1.88, y, 0.62), (1.35, y, 0.96)], [0.04, 0.04], segs=6, uvscale=1.0), "wood_mid", smooth=True)
    for p in (beams, deck, posts, rails, rope):
        p.build(coll, parent=root)
    col_box("deck", coll, (4.2, 1.9, 0.4), (0, 0, 0.2), root)
    for y in (-0.97, 0.97):
        col_box("rail_%s" % ("L" if y < 0 else "R"), coll, (3.94, 0.17, 0.85), (0, y, 0.82), root)
    empty("deck_start", coll, (-2.1, 0, 0.4), root); empty("deck_end", coll, (2.1, 0, 0.4), root)


def build_toll_sign(coll, root, rng):
    post = Part("post")
    post.add(prim_tube([(0, 0, 0), (0.005, 0, 1.0), (0, 0.004, 2.08)], [0.085, 0.08, 0.075], segs=8, rough=.06, uvscale=1.0), "wood_mid", smooth=True)
    post.add(prim_pyramid(0.12, 0.04, z0=2.06), "wood_mid", uv="box")
    br = Part("bracket")
    br.add(prim_box(0.62, 0.09, 0.09, bevel=0.012), "wood_mid", loc=(0.3, 0, 1.86), uv="box", rng=rng, long_axis=0)
    L = math.hypot(0.3, 0.33)
    br.add(prim_box(L, 0.07, 0.07, bevel=0.01), "wood_mid", loc=(0.16, 0, 1.67), rot=(0, -math.atan2(0.33, 0.3), 0), uv="box", rng=rng, long_axis=0)
    for z in (1.86, 0.7):
        br.add(prim_torus(0.095, 0.02, segs=10, rsegs=5), "rope", loc=(0, 0, z))
        br.add(prim_torus(0.095, 0.02, segs=10, rsegs=5), "rope", loc=(0, 0, z - 0.04))
    post.build(coll, parent=root); br.build(coll, parent=root)
    hinge = Vector((0.37, 0, 1.815))
    sign = Part("round_sign")
    disk = prim_cyl(0.2, 0.2, 0.045, segs=20, z0=-0.0225)
    disk.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    uv_planar(disk, axes=(0, 2))
    sign.add(disk, "wood_light", loc=(0.37, 0, 1.47))
    rim = prim_torus(0.2, 0.025, segs=20, rsegs=6)
    sign.add(rim, "wood_dark", loc=(0.37, 0, 1.47), rot=(math.pi / 2, 0, 0))
    for dx in (-0.08, 0.08):  # hanging loops
        ring = prim_torus(0.03, 0.007, segs=8, rsegs=4, uvscale=.1)
        sign.add(ring, "iron", loc=(0.37 + dx, 0, 1.69), rot=(math.pi / 2, 0, 0))
        ring = prim_torus(0.03, 0.007, segs=8, rsegs=4, uvscale=.1)
        sign.add(ring, "iron", loc=(0.37 + dx, 0, 1.77), rot=(0, math.pi / 2, 0))
    so = sign.build(coll, pivot=hinge, parent=root)
    so["pivot_axis"] = "local X (swing)"
    coins = Part("coin_emblem")  # raised emblem: a stack of three coins plus two beside it
    for (dx, k) in ((-0.055, 0), (-0.055, 1), (-0.055, 2), (0.06, 0), (0.06, 1)):
        c = prim_cyl(0.055, 0.055, 0.028, segs=16, z0=0.0)
        coins.add(c, "brass", loc=(0.37 + dx, -0.06, 1.39 + k * 0.03), smooth=None)
    coins.build(coll, pivot=hinge, parent=so)
    col_box("post", coll, (0.18, 0.18, 2.1), (0, 0, 1.05), root)


def build_decorative_spear(coll, root, rng):
    shaft = Part("wooden_shaft")
    shaft.add(prim_tube([(0, 0, 0.04), (0, 0, 1.42)], [0.017, 0.016], segs=8, uvscale=1.0), "wood_dark", smooth=True)
    head = Part("iron_spearhead")
    head.add(prim_tube([(0, 0, 1.38), (0, 0, 1.43)], [0.022, 0.022], segs=8, uvscale=.2), "steel", smooth=False)
    head.add(prim_tube([(0, 0, 1.43), (0, 0, 1.475)], [0.02, 0.011], segs=8, uvscale=.2), "steel", smooth=False)
    bm = _new()
    rows = []
    prof = [(1.47, 0.012), (1.5, 0.045), (1.53, 0.058), (1.57, 0.045), (1.61, 0.022), (1.65, 0.0)]
    for z, w in prof:
        if w == 0:
            rows.append([bm.verts.new((0, 0, z))])
        else:
            t = 0.012 * (w / 0.058) + 0.004
            rows.append([bm.verts.new(p) for p in ((-w, 0, z), (0, -t, z), (w, 0, z), (0, t, z))])
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        for k in range(4):
            if len(B) == 1:
                bm.faces.new((A[k], A[(k + 1) % 4], B[0]))
            else:
                bm.faces.new((A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k]))
    bm.faces.new(list(reversed(rows[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    head.add(bm, "steel", uv="world", uvscale=.2)
    head.add(prim_tube([(0, 0, 0.0), (0, 0, 0.045)], [0.0, 0.019], segs=8, uvscale=.2), "steel")  # butt spike
    shaft.build(coll, parent=root); head.build(coll, parent=root)
    empty("rack_socket", coll, (0, 0, 0.825), root)


def build_round_watch_shield(coll, root, rng):
    R = 0.27
    disk = Part("wooden_shield_disk")
    bm = prim_cyl(R, R, 0.035, segs=28, z0=-0.0175)
    bm.transform(Matrix.Rotation(math.pi / 2, 4, "X"))  # axis Z -> -Y : front faces -Y
    uv_planar(bm, axes=(0, 2), rect=(-R, -R, R, R))
    disk.add(bm, "shield_planks")
    rim = Part("metal_rim")
    prof = [(R - 0.012, -0.028), (R + 0.03, -0.024), (R + 0.03, 0.024), (R - 0.012, 0.028)]
    bmr = prim_lathe(prof, segs=32, uvscale=.4, close_bottom=False)
    bmr.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    rim.add(bmr, "iron", smooth=False)
    for k in range(16):
        a = 2 * math.pi * k / 16
        rim.add(prim_ico(0.011, 1), "iron", loc=(math.cos(a) * (R + 0.009), -0.03, math.sin(a) * (R + 0.009)), uv="world", uvscale=.1, smooth=True)
    boss = Part("central_boss")
    bmb = prim_ico(1.0, 2)
    for v in bmb.verts:
        if v.co.z < 0:
            v.co.z = 0
    bmb.transform(Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Diagonal((0.075, 0.075, 0.04, 1)))
    boss.add(bmb, "steel", loc=(0, -0.0175, 0), uv="world", uvscale=.2, smooth=True)
    fl = prim_cyl(0.1, 0.1, 0.008, segs=20, z0=0)
    fl.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    boss.add(fl, "iron", loc=(0, -0.0175, 0), uv="world", uvscale=.2)
    for k in range(6):
        a = 2 * math.pi * k / 6
        boss.add(prim_ico(0.009, 1), "iron", loc=(math.cos(a) * 0.088, -0.027, math.sin(a) * 0.088), uv="world", uvscale=.1, smooth=True)
    grip = Part("rear_grip_and_straps")
    grip.add(prim_tube([(-0.11, 0.03, 0), (0.0, 0.04, 0), (0.11, 0.03, 0)], [0.013, 0.013, 0.013], segs=6, uvscale=.3), "leather", smooth=True)
    for x in (-0.11, 0.11):
        grip.add(prim_box(0.03, 0.025, 0.05), "iron", loc=(x, 0.03, 0), uv="world", uvscale=.2)
    # arm strap loop on the rear, reaching toward the left edge (seen at the rim in the PNG)
    pts = [(-0.2, 0.019, 0.1), (-0.27, 0.04, 0.06), (-0.285, 0.045, -0.02), (-0.27, 0.04, -0.09), (-0.2, 0.019, -0.13)]
    grip.add(prim_tube(pts, [0.008] * 5, segs=6, flat_y=0.35, uvscale=.3), "leather", smooth=True)
    for z in (0.1, -0.13):
        grip.add(prim_box(0.035, 0.012, 0.045), "iron", loc=(-0.2, 0.022, z), uv="world", uvscale=.2)
    for p in (disk, rim, boss, grip):
        p.build(coll, parent=root)
    empty("grip_socket", coll, (0, 0.05, 0), root)
    empty("arm_strap_socket", coll, (-0.25, 0.04, -0.015), root)


BUILDERS = {k: globals()["build_" + k] for k in ALL_IDS}


# ============================================================================= pipeline
def mesh_stats(objs):
    tris = 0; mats = set(); meshes = set()
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        meshes.add(me.name)
        for m in me.materials:
            if m:
                mats.add(m.name)
    return tris, sorted(mats), sorted(meshes)


def world_bounds(objs):
    cs = []
    for o in objs:
        mw = o.matrix_world
        for v in o.data.vertices:
            cs.append(mw @ v.co)
    if not cs:
        return None
    mn = [min(c[i] for c in cs) for i in range(3)]
    mx = [max(c[i] for c in cs) for i in range(3)]
    return mn, mx


def sanity(objs):
    issues = []
    for o in objs:
        if any(s < 0 for s in o.scale):
            issues.append("negative scale: " + o.name)
        bm = bmesh.new(); bm.from_mesh(o.data)
        degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
        loose = sum(1 for v in bm.verts if not v.link_faces)
        if degenerate:
            issues.append("%s: %d degenerate faces" % (o.name, degenerate))
        if loose:
            issues.append("%s: %d loose verts" % (o.name, loose))
        bm.free()
    return issues


def motion_test(coll):
    out = []
    for o in coll.objects:
        ax = o.get("pivot_axis")
        if not ax:
            continue
        idx = {"X": 0, "Y": 1, "Z": 2}[ax.split()[1]]
        before = world_bounds([o])
        rot0 = o.rotation_euler.copy()
        r = list(rot0); r[idx] += math.radians(-60 if idx == 1 else 60)
        o.rotation_euler = r
        bpy.context.view_layer.update() if bpy.context.view_layer else None
        o.matrix_world  # noqa
        after = world_bounds([o])
        o.rotation_euler = rot0
        if bpy.context.view_layer:
            bpy.context.view_layer.update()
        moved = before and after and any(abs(a - b) > 0.02 for a, b in zip(before[1] + before[0], after[1] + after[0]))
        out.append({"part": o.name, "axis": ax, "pivot": [round(c, 3) for c in o.matrix_world.translation], "moves": bool(moved),
                    "max_z_before": round(before[1][2], 3), "max_z_after": round(after[1][2], 3)})
    return out


def build(aid):
    rng = random.Random(zlib.crc32(aid.encode()))
    scn, coll, root = new_asset_scene(aid)
    with SceneCtx(scn):
        BUILDERS[aid](coll, root, rng)
        parent_all(coll, root)
        for o in list(coll.objects):
            if o is root:
                continue
            if not o.name.startswith(aid + "_"):
                o.name = aid + "_" + o.name
            if o.data is not None and not o.data.name.startswith(aid + "_"):
                o.data.name = aid + "_" + o.data.name
        scn.view_layers[0].update()
    return scn


def export(aid):
    scn = bpy.data.scenes["ENV_" + aid]
    coll = bpy.data.collections[aid]
    cat = CATEGORY[aid]
    out_dir = os.path.join(GEN, aid)
    glb_dir = os.path.join(GLB_ROOT, cat)
    os.makedirs(out_dir, exist_ok=True); os.makedirs(glb_dir, exist_ok=True)
    glb = os.path.join(glb_dir, aid + ".glb")
    with SceneCtx(scn):
        scn.view_layers[0].update()
        kw = dict(filepath=glb, export_format="GLB", use_active_scene=True, export_apply=True, export_yup=True,
                  export_extras=True, export_cameras=False, export_lights=False)
        try:
            bpy.ops.export_scene.gltf(**kw)
        except TypeError:
            for k in ("export_cameras", "export_lights", "use_active_scene"):
                kw.pop(k, None)
            bpy.ops.export_scene.gltf(**kw)
        # editable .blend containing only this asset's scene (textures packed)
        for img in {n.image for m in bpy.data.materials if m.name.startswith("env_") and m.use_nodes for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}:
            if not img.packed_file:
                img.pack()
        blend = os.path.join(out_dir, aid + ".blend")
        bpy.data.libraries.write(blend, {scn}, fake_user=False, compress=True)
    return glb, blend


def glb_json(path):
    import struct
    with open(path, "rb") as fh:
        b = fh.read()
    ln = struct.unpack("<I", b[12:16])[0]
    return json.loads(b[20:20 + ln])


def verify(aid):
    """Re-import the GLB into a throwaway scene and compare against the source."""
    scn = bpy.data.scenes["ENV_" + aid]
    coll = bpy.data.collections[aid]
    root = bpy.data.objects[aid]
    cat = CATEGORY[aid]
    glb = os.path.join(GLB_ROOT, cat, aid + ".glb")
    src_vis = [o for o in coll.all_objects if o.type == "MESH" and not is_col(o)]
    src_col = [o for o in coll.all_objects if o.type == "MESH" and is_col(o)]
    tris, mats, meshes = mesh_stats(src_vis)
    with SceneCtx(scn):
        scn.view_layers[0].update()
        sb = world_bounds(src_vis)
        motion = motion_test(coll)
        issues = sanity(src_vis)
    vs = bpy.data.scenes.new("ENV__verify")
    before_ids = {"o": set(bpy.data.objects), "m": set(bpy.data.meshes), "mat": set(bpy.data.materials), "img": set(bpy.data.images)}
    with SceneCtx(vs):
        bpy.ops.import_scene.gltf(filepath=glb)
        vs.view_layers[0].update()
        imp = [o for o in vs.objects]
        iscol = lambda o: is_col(o) or o.data.name.endswith("_col")
        iv = [o for o in imp if o.type == "MESH" and not is_col(o)]
        ic = [o for o in imp if o.type == "MESH" and is_col(o)]
        ib = world_bounds(iv)
        itris, imats, imeshes = mesh_stats(iv)
        empties = sorted(o.name for o in imp if o.type == "EMPTY")
        neg = [o.name for o in imp if any(s < 0 for s in o.matrix_world.to_scale())]
    new_o = set(bpy.data.objects) - before_ids["o"]
    for o in new_o:
        bpy.data.objects.remove(o, do_unlink=True)
    for m in set(bpy.data.meshes) - before_ids["m"]:
        bpy.data.meshes.remove(m)
    for m in set(bpy.data.materials) - before_ids["mat"]:
        bpy.data.materials.remove(m)
    for i in set(bpy.data.images) - before_ids["img"]:
        bpy.data.images.remove(i)
    bpy.data.scenes.remove(vs)
    gj = glb_json(glb)
    size = [round(ib[1][i] - ib[0][i], 3) for i in range(3)]
    spec = SPEC[aid]
    dev = [round(size[i] / spec[i] - 1, 3) for i in range(3)]
    rep = {
        "id": aid, "category": cat,
        "glb": glb, "blend": os.path.join(GEN, aid, aid + ".blend"),
        "target_size_m": list(spec), "glb_size_m": size, "size_deviation": dev,
        "bounds_min": [round(c, 3) for c in ib[0]], "bounds_max": [round(c, 3) for c in ib[1]],
        "source_vs_glb_bounds_match": all(abs(a - b) < 1e-3 for a, b in zip(sb[0] + sb[1], ib[0] + ib[1])),
        "triangles": itris, "source_triangles": tris,
        "visual_mesh_nodes": len(iv), "unique_meshes": len(imeshes), "materials": [m.split(".")[0] for m in imats],
        "collision_nodes": [n["name"] for n in gj["nodes"] if "colonly" in n.get("name", "")],
        "glb_nodes": len(gj["nodes"]), "glb_kb": os.path.getsize(glb) // 1024,
        "glb_materials": [(m["name"], m.get("alphaMode", "OPAQUE"), bool(m.get("doubleSided"))) for m in gj.get("materials", [])],
        "glb_images": len(gj.get("images", [])), "empties": empties, "negative_scale_nodes": neg,
        "mesh_issues": issues, "motion_test": motion,
        "parts": sorted(o.name for o in src_vis),
        "built_with": "Blender %s, procedural geometry from PNG + MD prompt (no Tripo high-poly)" % bpy.app.version_string,
        "time": time.strftime("%Y-%m-%d %H:%M"),
    }
    with open(os.path.join(GEN, aid, aid + "_report.json"), "w", encoding="utf-8") as fh:
        json.dump(rep, fh, ensure_ascii=False, indent=2)
    return rep


def preview(aid, res=640):
    """Workbench render of the asset (textured) to generated-models/<id>/<id>_preview.png."""
    coll = bpy.data.collections[aid]
    ps = bpy.data.scenes.get("ENV__preview") or bpy.data.scenes.new("ENV__preview")
    for o in list(ps.collection.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    inst = bpy.data.objects.new("inst", None)
    inst.instance_type = "COLLECTION"; inst.instance_collection = coll
    ps.collection.objects.link(inst)
    vis = [o for o in coll.all_objects if o.type == "MESH" and not is_col(o)]
    mn, mx = world_bounds(vis)
    c = Vector([(a + b) / 2 for a, b in zip(mn, mx)])
    size = max(b - a for a, b in zip(mn, mx))
    cam_d = bpy.data.cameras.new("pcam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 1.35
    cam = bpy.data.objects.new("pcam", cam_d); ps.collection.objects.link(cam)
    d = Vector((-0.55, -1.0, 0.62)).normalized()
    cam.location = c + d * size * 3
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam_d.clip_end = size * 10
    ps.camera = cam
    r = ps.render
    r.engine = "BLENDER_WORKBENCH"
    r.resolution_x = r.resolution_y = res; r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
    sh = ps.display.shading
    sh.light = "STUDIO"; sh.color_type = "TEXTURE"
    sh.show_cavity = True; sh.cavity_type = "WORLD"
    sh.show_object_outline = True; sh.object_outline_color = (0.08, 0.06, 0.05)
    sh.show_shadows = False
    try:
        ps.display_settings.display_device = "sRGB"; ps.view_settings.view_transform = "Standard"
        ps.view_settings.exposure = 0.35
    except Exception:
        pass
    out = os.path.join(GEN, aid, aid + "_preview.png")
    r.filepath = out
    with SceneCtx(ps):
        bpy.ops.render.render(write_still=True, scene=ps.name)
    for o in (inst, cam):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.cameras.remove(cam_d)
    return out


def run(ids, steps=("build", "export", "verify", "preview")):
    res = {}
    for aid in ids:
        t = time.time(); r = {}
        try:
            if "build" in steps:
                build(aid)
            if "export" in steps:
                r["files"] = export(aid)
            if "verify" in steps:
                rep = verify(aid)
                r.update({k: rep[k] for k in ("glb_size_m", "target_size_m", "triangles", "materials", "unique_meshes",
                                              "visual_mesh_nodes", "collision_nodes", "glb_kb", "glb_materials", "mesh_issues", "motion_test",
                                              "source_vs_glb_bounds_match", "negative_scale_nodes")})
            if "preview" in steps:
                r["preview"] = preview(aid)
        except Exception as e:
            import traceback
            r["error"] = traceback.format_exc()[-1500:]
        r["sec"] = round(time.time() - t, 1)
        res[aid] = r
    return res


# ============================================================================= demo level
LAYOUT = [
    ('ground_road_tile', -9, 0, 0, 1),
    ('ground_road_tile', -3, 0, 0, 1),
    ('ground_road_tile', 7, 0, 0, 1),
    ('ground_road_tile', 13, 0, 0, 1),
    ('stream_channel', 2, 0, 90, 1),
    ('stream_channel', 2, 6, 90, 1),
    ('stream_channel', 2, -6, 90, 1),
    ('timber_footbridge', 2, 0, 0, 1),
    ('checkpoint_barrier', -6, 0, 90, 1),
    ('toll_sign', -6.9, -2.45, 0, 1),
    ('forest_defense_gate', 10, 0, 90, 1),
    ('low_stone_wall', 10, 2.65, 90, 1),
    ('low_stone_wall', 10, -2.65, -90, 1),
    ('wooden_barricade', 12.3, 1.7, 90, 1),
    ('wooden_barricade', 12.3, -1.7, 90, 1),
    ('decorative_spear', 9.25, -1.5, 0, 1),
    ('round_watch_shield', 10.32, 2.6, 90, 1),
    ('potted_plant', 8.9, -3.4, 0, 1),
    ('wooden_garden_fence', -10.5, 4.6, 0, 1),
    ('wooden_garden_fence', -7.5, 4.6, 0, 1),
    ('wooden_garden_fence', -4.5, 4.6, 0, 1),
    ('vegetable_garden_bed', -7.5, 7.4, 0, 1),
    ('oak_tree', -2.5, 7.0, 30, 1),
    ('oak_tree', 15.5, -6.6, 120, 0.9),
    ('pine_tree', -12.5, -5.6, 0, 1),
    ('pine_tree', -9.5, -7.4, 60, 0.85),
    ('pine_tree', 6.2, 6.6, 20, 1.1),
    ('pine_tree', 16.5, 5.9, 80, 0.9),
    ('pine_tree', -1.6, -7.6, 40, 0.9),
    ('roadside_bush', -4.8, -3.9, 0, 1),
    ('roadside_bush', 5.4, -4.2, 70, 1),
    ('roadside_bush', 13.6, 3.9, 140, 1),
    ('roadside_bush', -1.0, 4.1, 200, 0.9),
    ('field_rock', -0.4, -4.5, 20, 1),
    ('field_rock', 8.4, 4.5, 150, 0.8),
    ('field_rock', -13.6, 2.2, 0, 1.2),
    ('fallen_tree_root', -12.8, 6.4, 25, 1),
    ('flower_patch', -3.6, -3.6, 0, 1),
    ('flower_patch', -11.8, -3.6, 40, 1),
    ('flower_patch', 7.8, 3.6, 90, 1),
    ('flower_patch', 15.0, -3.7, 10, 1),
    ('grass_tuft', -5.6, -3.4, 0, 1),
    ('grass_tuft', -8.3, -3.8, 50, 1.1),
    ('grass_tuft', -10.2, -3.3, 100, 0.9),
    ('grass_tuft', -0.2, 3.5, 20, 1),
    ('grass_tuft', 6.4, 3.5, 70, 1),
    ('grass_tuft', 11.8, 4.2, 30, 1.2),
    ('grass_tuft', 14.6, -4.4, 150, 1),
    ('grass_tuft', 4.6, -3.4, 10, 0.9),
    ('grass_tuft', -13.0, -3.9, 80, 1),
]


def build_demo(res=(1600, 900), render=True):
    """Assemble a road / creek / outpost stretch from the kit (collection instances) and render it."""
    old = bpy.data.scenes.get("ENV_demo_level")
    if old:
        for o in list(old.collection.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    scn = bpy.data.scenes.new("ENV_demo_level")
    for aid in {r[0] for r in LAYOUT}:
        if not bpy.data.collections.get(aid):
            build(aid)
    # ground below the tiles, with an opening for the creek (x 0..4, y -9..9)
    for k, (x0, x1, y0, y1) in enumerate(((-20.5, 0, -15, 15), (4, 23.5, -15, 15), (0, 4, 9, 15), (0, 4, -15, -9))):
        bm = prim_box(x1 - x0, y1 - y0, 0.04, center=((x0 + x1) / 2, (y0 + y1) / 2, -0.1))
        uv_box(bm, 2.0, 0)
        me = bpy.data.meshes.new("demo_ground_%d" % k); bm.to_mesh(me); bm.free()
        me.materials.append(get_mat("grass_ground"))
        g = bpy.data.objects.new("demo_ground_%d" % k, me); scn.collection.objects.link(g)
    for i, (aid, x, y, rz, s) in enumerate(LAYOUT):
        e = bpy.data.objects.new("%02d_%s" % (i, aid), None)
        e.instance_type = "COLLECTION"; e.instance_collection = bpy.data.collections[aid]
        e.location = (x, y, 0.7 if aid == "round_watch_shield" else 0.0)
        e.rotation_euler = (0, 0, math.radians(rz)); e.scale = (s, s, s)
        scn.collection.objects.link(e)
    cam_d = bpy.data.cameras.new("demo_cam"); cam_d.lens = 38; cam_d.clip_end = 200
    cam = bpy.data.objects.new("demo_cam", cam_d); scn.collection.objects.link(cam)
    target = Vector((1.5, -0.5, 0.0))
    cam.location = target + Vector((-6.0, -21.0, 15.0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    sun_d = bpy.data.lights.new("demo_sun", "SUN"); sun_d.energy = 3.2; sun_d.angle = math.radians(3)
    sun = bpy.data.objects.new("demo_sun", sun_d); sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scn.collection.objects.link(sun)
    w = bpy.data.worlds.get("demo_world") or bpy.data.worlds.new("demo_world")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.62, 0.74, 0.86, 1); bg.inputs[1].default_value = 0.9
    scn.world = w
    r = scn.render
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            r.engine = eng
            break
        except TypeError:
            continue
    r.resolution_x, r.resolution_y = res; r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    try:
        scn.view_settings.view_transform = "Standard"
    except Exception:
        pass
    if hasattr(scn, "eevee"):
        for k, v in (("taa_render_samples", 16), ("use_shadows", True)):
            if hasattr(scn.eevee, k):
                setattr(scn.eevee, k, v)
    out_dir = os.path.join(GEN, "_demo"); os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "demo_level.png")
    r.filepath = out
    if render:
        with SceneCtx(scn):
            bpy.ops.render.render(write_still=True, scene=scn.name)
    return out


def save_kit_blend():
    """One editable .blend with every asset scene + the demo scene (textures packed)."""
    scenes = {s for s in bpy.data.scenes if s.name.startswith("ENV_") and s.name not in ("ENV__preview", "ENV__verify")}
    for img in {n.image for m in bpy.data.materials if m.name.startswith("env_") and m.use_nodes for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}:
        if not img.packed_file:
            img.pack()
    path = os.path.join(GEN, "environment_kit.blend")
    bpy.data.libraries.write(path, scenes, fake_user=False, compress=True)
    return path
