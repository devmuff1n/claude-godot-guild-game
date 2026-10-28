# Blender background: Elira's recurve bow + arrow, exported as two glb files.
# Bow: origin = middle of the grip, limbs along +Y (Godot up), belly (back of the bow) toward +Z (Godot: where the
# arrow flies), string side toward -Z. Tip markers "TipTop" / "TipBottom" are empties at the string nocks.
# Arrow: nock at origin, flies along +Z, length ARROW_L.
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--")+1:]
out_bow, out_arrow, out_blend = argv[0], argv[1], argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
HALF = 0.37        # half length of the bow along Y (Blender Z before the y-up export)
ARROW_L = 0.34
def mat(name, col, rough=0.7, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m
wood = mat("Bow_Wood", (0.30, 0.15, 0.06), 0.65)
wrap = mat("Bow_Wrap", (0.13, 0.30, 0.12), 0.9)      # green leather like her capelet
gold = mat("Bow_Metal", (0.85, 0.62, 0.25), 0.35, 1.0)
shaft_m = mat("Arrow_Shaft", (0.55, 0.38, 0.20), 0.7)
head_m = mat("Arrow_Head", (0.62, 0.64, 0.66), 0.3, 1.0)
fletch_m = mat("Arrow_Fletch", (0.20, 0.45, 0.18), 0.8)
# Work in Blender coords with the bow axis on Z (becomes Godot +Y) and the belly toward -Y (becomes Godot +Z).
def limb_center(s):   # s in [-1, 1] along the bow; returns (y, z)
    a = abs(s)
    back = -0.020*(1-a)**2                         # grip bulges toward the target
    bend = 0.085*a**2                              # limbs sweep toward the archer (+Y in Blender)
    recurve = -0.045*max(0.0, (a-0.78)/0.22)**2    # tips flip back toward the target
    return back+bend+recurve, s*HALF
def limb_r(s):
    a = abs(s)
    w = 0.016 if a < 0.12 else 0.016-0.010*((a-0.12)/0.88)   # thickness
    return max(w, 0.0055)
def sweep(name, s0, s1, rad, m, rings=48, segs=10, flat=1.6):
    bm = bmesh.new(); R = []
    for i in range(rings+1):
        s = s0+(s1-s0)*i/rings
        y, z = limb_center(s)
        ds = 1e-3; y2, z2 = limb_center(min(1, s+ds)); y1, z1 = limb_center(max(-1, s-ds))
        tng = Vector((0, y2-y1, z2-z1)).normalized(); side = Vector((1, 0, 0)); nrm = tng.cross(side).normalized()
        r = rad(s); ring = []
        for j in range(segs):
            a = 2*math.pi*j/segs
            p = Vector((0, y, z))+side*(r*flat*math.cos(a))+nrm*(r*math.sin(a))
            ring.append(bm.verts.new(p))
        R.append(ring)
    for i in range(rings):
        for j in range(segs):
            bm.faces.new([R[i][j], R[i][(j+1) % segs], R[i+1][(j+1) % segs], R[i+1][j]])
    bm.faces.new(list(reversed(R[0]))); bm.faces.new(R[-1])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob); me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return ob
parts = [sweep("Limbs", -1, 1, limb_r, wood, rings=80)]
parts.append(sweep("Grip", -0.13, 0.13, lambda s: limb_r(s)*1.35, wrap, rings=10, segs=12))
for s0 in (-0.17, 0.15):
    parts.append(sweep(f"Ring{s0}", s0, s0+0.02, lambda s: limb_r(s)*1.5, gold, rings=2, segs=12))
for sg in (-1, 1):
    parts.append(sweep(f"Tip{sg}", sg*0.93 if sg < 0 else 0.93, -1 if sg < 0 else 1, lambda s: limb_r(s)*1.25, gold, rings=6, segs=10))
    # small leaf ornament on each limb, on the belly side
    y, z = limb_center(sg*0.45)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.022, location=(0, y-0.012, z))
    lf = bpy.context.active_object; lf.scale = (0.45, 0.25, 1.6); lf.rotation_euler = (sg*0.35, 0, 0)
    lf.data.materials.append(wrap); parts.append(lf)
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join(); bow = bpy.context.active_object; bow.name = "EliraBow"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ty, tz = limb_center(0.985)
for nm, zz in (("TipTop", tz), ("TipBottom", -tz)):
    e = bpy.data.objects.new(nm, None); e.location = (0, ty, zz); bpy.context.collection.objects.link(e); e.parent = bow
print("BOW_TRIS", sum(len(p.vertices)-2 for p in bow.data.polygons), "DIM", tuple(round(v, 3) for v in bow.dimensions), "TIP", (round(ty, 3), round(tz, 3)))
# ---- arrow (separate collection/object), shaft along -Y in Blender = +Z in Godot
def cyl(name, y0, y1, r0, r1, m, segs=8):
    bm = bmesh.new(); A = []; B = []
    for j in range(segs):
        a = 2*math.pi*j/segs
        A.append(bm.verts.new((r0*math.cos(a), y0, r0*math.sin(a)))); B.append(bm.verts.new((r1*math.cos(a), y1, r1*math.sin(a))))
    for j in range(segs):
        bm.faces.new([A[j], B[j], B[(j+1) % segs], A[(j+1) % segs]])
    bm.faces.new(A); bm.faces.new(list(reversed(B)))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob); me.materials.append(m)
    return ob
ap = [cyl("Shaft", 0, -(ARROW_L-0.045), 0.0042, 0.0042, shaft_m),
      cyl("Head", -(ARROW_L-0.045), -ARROW_L, 0.011, 0.0005, head_m, 4),
      cyl("Nock", 0.006, 0, 0.0055, 0.0055, gold)]
for k in range(3):
    bm = bmesh.new(); a = 2*math.pi*k/3; c, s_ = math.cos(a), math.sin(a)
    pts = [(0.004, -0.012), (0.020, -0.030), (0.016, -0.075), (0.004, -0.085)]
    vs = [bm.verts.new((r*c, y, r*s_)) for r, y in pts]
    bm.faces.new(vs)
    me = bpy.data.meshes.new(f"Fl{k}"); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(f"Fl{k}", me); bpy.context.collection.objects.link(ob); me.materials.append(fletch_m); ap.append(ob)
fletch_m.use_backface_culling = False
bpy.ops.object.select_all(action='DESELECT')
for o in ap: o.select_set(True)
bpy.context.view_layer.objects.active = ap[0]
bpy.ops.object.join(); arrow = bpy.context.active_object; arrow.name = "EliraArrow"
arrow.location = (0.3, 0, 0)
print("ARROW_TRIS", sum(len(p.vertices)-2 for p in arrow.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.object.select_all(action='DESELECT'); bow.select_set(True)
for c in bow.children: c.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_bow, export_format='GLB', export_yup=True, export_apply=True, use_selection=True)
bpy.ops.object.select_all(action='DESELECT'); arrow.select_set(True)
loc = arrow.location.copy(); arrow.location = (0, 0, 0)
bpy.ops.export_scene.gltf(filepath=out_arrow, export_format='GLB', export_yup=True, export_apply=True, use_selection=True)
arrow.location = loc
# preview render
sys.path.insert(0, __import__("os").path.dirname(__file__))
from common import setup_render, shoot
setup_render(res=(768, 768), samples=16)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
import os
base = os.path.splitext(out_blend)[0]
shoot(base+"_side.png", (0.15, 0, 0), 0.9, (1, 0, 0.0))
shoot(base+"_q.png", (0.15, 0, 0), 0.9, (0.6, -0.7, 0.3))
