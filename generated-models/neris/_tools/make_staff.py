# Blender background: build Neris's staff and export glb. Origin = grip point, shaft along +Y (Godot up).
import bpy, bmesh, math, sys, random
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--")+1:]
out_glb, out_blend = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(7)
L = 1.00          # full length, metres
GRIP = 0.38       # grip height above the bottom
def mat(name, col, rough=0.7, metal=0.0, emit=None, es=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = es
    return m
wood = mat("Staff_Wood", (0.23, 0.13, 0.07), 0.8)
wrap = mat("Staff_Wrap", (0.45, 0.08, 0.10), 0.9)
gold = mat("Staff_Metal", (0.85, 0.62, 0.25), 0.35, 1.0)
gem  = mat("Staff_Crystal", (1.0, 0.45, 0.12), 0.15, 0.0, (1.0, 0.42, 0.08), 1.6)

def bend(z):  # gentle S-curve of the shaft
    return Vector((0.008*math.sin(z*4.5), 0.006*math.sin(z*6.5+1.0), 0))

def tube(name, z0, z1, r0, r1, segs=10, rings=24, m=wood, knots=True):
    bm = bmesh.new(); rings_v = []
    for i in range(rings+1):
        t = i/rings; z = z0+(z1-z0)*t; r = r0+(r1-r0)*t
        if knots: r *= 1 + 0.12*max(0, math.sin(t*25))**8
        c = bend(z); ring = []
        for j in range(segs):
            a = 2*math.pi*j/segs
            rr = r*(1+0.04*random.uniform(-1, 1)) if knots else r
            ring.append(bm.verts.new((c.x+rr*math.cos(a), c.y+rr*math.sin(a), z)))
        rings_v.append(ring)
    for i in range(rings):
        for j in range(segs):
            bm.faces.new([rings_v[i][j], rings_v[i][(j+1)%segs], rings_v[i+1][(j+1)%segs], rings_v[i+1][j]])
    bm.faces.new(list(reversed(rings_v[0]))); bm.faces.new(rings_v[-1])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return ob

parts = []
parts.append(tube("Shaft", 0.0, L-0.10, 0.019, 0.024))
parts.append(tube("Grip", GRIP-0.07, GRIP+0.07, 0.027, 0.027, 12, 8, wrap, False))
parts.append(tube("Ferrule", 0.0, 0.05, 0.021, 0.022, 12, 2, gold, False))
parts.append(tube("Collar", L-0.15, L-0.11, 0.030, 0.032, 12, 2, gold, False))
# three curled prongs holding the crystal
top = L-0.11
for k in range(3):
    a0 = 2*math.pi*k/3
    pts = []
    for i in range(9):
        t = i/8
        r = 0.028 + 0.055*math.sin(t*math.pi)  # bulge out, then back in
        a = a0 + t*0.6
        c = bend(top)
        pts.append((c.x + r*math.cos(a), c.y + r*math.sin(a), top + t*0.22))
    cu = bpy.data.curves.new(f"Prong{k}", 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = 0.010; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(len(pts)-1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1); sp.points[i].radius = 1.0 - 0.6*(i/8)
    ob = bpy.data.objects.new(f"Prong{k}", cu); bpy.context.collection.objects.link(ob)
    cu.materials.append(wood)
    parts.append(ob)
# crystal: elongated octahedron-ish
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.055, location=(*bend(top)[:2], top+0.11))
cr = bpy.context.active_object; cr.name = "Crystal"; cr.scale = (0.75, 0.75, 1.5)
cr.data.materials.append(gem); parts.append(cr)
# join (convert curves first)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
st = bpy.context.active_object; st.name = "NerisStaff"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# move grip point to origin
st.data.transform(Matrix.Translation((0, 0, -GRIP)))
print("TRIS", sum(len(p.vertices)-2 for p in st.data.polygons), "DIM", st.dimensions)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', export_yup=True, export_apply=True)
print("DONE")
