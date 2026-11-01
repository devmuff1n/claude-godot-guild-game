# Step 3: low-poly mage staff (wood shaft, gold bands, two horn-like prongs cradling a glowing crystal), skinned on a
# new bone 'Staff' under the staff hand (default LeftHand; _work/staff_tune.json 'hand'). Grip centre from
# _work/fist.json (fist hollow in rest space). Materials: Neris_Staff (_work/neris_staff.png swatches, staff_tex.py)
# and Neris_Crystal (emissive). blender -b --python s3_staff.py -- <in_blend> <out_blend>
import bpy, bmesh, os, sys, math, json
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
rig = bpy.data.objects['Neris_Rig']; M = 'mixamorig:'
F = json.load(open(os.path.join(W, 'fist.json')))
TP = os.path.join(W, 'staff_tune.json')
P = json.load(open(TP)) if os.path.exists(TP) else {}
SIDE = P.get('hand', 'Left')
for o in [o for o in bpy.data.objects if o.name.startswith('Neris_Staff')]: bpy.data.objects.remove(o)

img = bpy.data.images.load(os.path.join(W, 'neris_staff.png'), check_existing=True)
mat = bpy.data.materials.get('Neris_Staff') or bpy.data.materials.new('Neris_Staff'); mat.use_nodes = True
nt = mat.node_tree; bs = nt.nodes['Principled BSDF']
tx = [n for n in nt.nodes if n.type == 'TEX_IMAGE']; tx = tx[0] if tx else nt.nodes.new('ShaderNodeTexImage')
tx.image = img; nt.links.new(tx.outputs[0], bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = 0.7
cm = bpy.data.materials.get('Neris_Crystal') or bpy.data.materials.new('Neris_Crystal'); cm.use_nodes = True
cb = cm.node_tree.nodes['Principled BSDF']
cb.inputs['Base Color'].default_value = (0.95, 0.18, 0.32, 1); cb.inputs['Roughness'].default_value = 0.25
cb.inputs['Emission Color'].default_value = (1.0, 0.25, 0.4, 1); cb.inputs['Emission Strength'].default_value = 1.6


def sw(i, u=0.5): return ((i*32+2+u*28)/256, 0.5)


WOOD, WOODD, GOLD, GOLDD, ROBE, CRYS, CORE, WRAP = range(8)
BELOW, ABOVE = P.get('below', 0.70), P.get('above', 0.50)
R = 0.0165


def build(name, fn, origin, X, Y, Z):
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new('UVMap'); Mx = Matrix((X, Y, Z)).transposed()
    mats = {}

    def vert(p): return bm.verts.new(V(origin)+Mx @ V(p))

    def face(vs, uvs, m=0):
        f = bm.faces.new(vs); f.material_index = m
        for l, uv in zip(f.loops, uvs): l[uvl].uv = uv
        return f
    fn(vert, face)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat); me.materials.append(cm)
    for p in me.polygons: p.use_smooth = False
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob


def ringf(vert, c, r, n, u, w):   # ring around point c in plane spanned by u,w
    return [vert(tuple(c+(u*math.cos(2*math.pi*j/n)+w*math.sin(2*math.pi*j/n))*r)) for j in range(n)]


def bridge(face, A, B, ua, ub):
    n = len(A)
    for j in range(n): face([A[j], A[(j+1) % n], B[(j+1) % n], B[j]], [ua, ua, ub, ub])


def capf(face, Rg, uv, rev=False): face(list(reversed(Rg)) if rev else Rg, [uv]*len(Rg))


def staff_fn(vert, face):
    X, Y, Z = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
    # shaft: (y, radius, swatch) with slight knots
    st = [(-BELOW, 0.012, GOLDD), (-BELOW+0.03, 0.0185, GOLD), (-BELOW+0.06, 0.0150, WOODD), (-0.35, 0.0155, WOOD),
          (-0.07, 0.0165, WOOD), (-0.065, 0.0195, WRAP), (0.065, 0.0195, WRAP), (0.07, 0.0165, WOOD),
          (0.28, 0.017, WOOD), (0.285, 0.021, GOLD), (0.315, 0.021, GOLD), (0.32, 0.017, WOODD), (ABOVE-0.02, 0.020, WOOD),
          (ABOVE, 0.027, GOLD), (ABOVE+0.035, 0.024, GOLDD)]
    rings = [(ringf(vert, Y*y, r, 6, X, Z), s) for y, r, s in st]
    capf(face, rings[0][0], sw(GOLDD), True)
    for (a, sa), (b, sb) in zip(rings, rings[1:]): bridge(face, a, b, sw(sb, 0.3), sw(sb, 0.8))
    top = ABOVE+0.035
    capf(face, rings[-1][0], sw(GOLDD))
    # two horn prongs: from the collar, out around the crystal and curling in above it (like her ram horns)
    cy = top+0.10
    for sgn in (1, -1):
        pts = [V((sgn*0.012, top-0.004, 0))]
        for i in range(9):
            t = i/8; ang = math.radians(-80+165*t)
            rad = 0.055+0.035*math.sin(math.pi*min(1, t*1.4))*(1-0.2*t) if t < 0.72 else 0.075-0.06*(t-0.72)
            pts.append(V((sgn*rad*math.cos(ang), cy+rad*math.sin(ang), 0)))
        prev = None; n = len(pts)
        for i, c in enumerate(pts):
            dirv = (pts[min(i+1, n-1)]-pts[max(i-1, 0)]).normalized()
            u = dirv.cross(Z).normalized(); w = Z
            r = 0.0145*(1-0.7*(i/(n-1)))+0.003
            rg = ringf(vert, c, r, 5, u, w)
            if prev is None: capf(face, rg, sw(WOODD), True)
            else: bridge(face, prev, rg, sw(WOODD if i % 2 else WOOD, 0.5), sw(WOOD, 0.7))
            prev = rg
        capf(face, prev, sw(WOODD))
    # crystal: elongated hexagonal bipyramid
    h1, h2, cr = 0.07, 0.095, 0.036
    mid = ringf(vert, Y*cy, cr, 6, X, Z)
    lo = vert(tuple(Y*(cy-h1))); hi = vert(tuple(Y*(cy+h2)))
    for j in range(6):
        face([mid[j], mid[(j+1) % 6], hi], [sw(CRYS, 0.9)]*3, 1)
        face([mid[(j+1) % 6], mid[j], lo], [sw(CRYS, 0.4)]*3, 1)


side = SIDE
f = F[side]; hand = V(f['hand']); d = (V(f['mid1'])-hand).normalized()
k = (V(f['idx1'])-V(f['pnk1'])); k = (k-d*k.dot(d)).normalized()
palm = (d.cross(k) if side == 'Left' else -d.cross(k)).normalized()
c = V(f['mid1'])+palm*P.get('palm', 0.026)+d*P.get('d', 0.004)+k*P.get('k', -0.012)
tilt = math.radians(P.get('tilt', 8))
Y = (k*math.cos(tilt)+d*math.sin(tilt)).normalized()    # shaft leaves the fist on the thumb side
Xs = (d-Y*d.dot(Y)).normalized(); Zs = Xs.cross(Y)
staff = build('Neris_Staff', staff_fn, c, Xs, Y, Zs)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); eb = rig.data.edit_bones
if 'Staff' in eb: eb.remove(eb['Staff'])
b = eb.new('Staff'); b.head = c; b.tail = c+Y*0.15; b.parent = eb[M+side+'Hand']; b.align_roll(Zs)
bpy.ops.object.mode_set(mode='OBJECT')
staff.parent = rig; m = staff.modifiers.new('Armature', 'ARMATURE'); m.object = rig
staff.vertex_groups.new(name='Staff').add(list(range(len(staff.data.vertices))), 1.0, 'REPLACE')
for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, argv[1]))
print('STAFF tris', sum(len(p.vertices)-2 for p in staff.data.polygons), 'side', side, 'len', round(BELOW+ABOVE+0.035+0.13+0.10, 3))
