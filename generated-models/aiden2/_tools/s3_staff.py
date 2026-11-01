# Step 3: low-poly mage staff for Aiden (ivory wood shaft, teal grip wrap, gold bands, gold sun ring with rays and a
# crossed ring around a glowing amber orb), skinned on a new bone 'Staff' under the staff hand (staff_tune.json 'hand'). Grip centre from
# _work/fist.json (fist hollow in rest space). Materials: Aiden_Staff (_work/aiden_staff.png swatches, staff_tex.py)
# and Aiden_Crystal (emissive). blender -b --python s3_staff.py -- <in_blend> <out_blend>
import bpy, bmesh, os, sys, math, json
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
rig = bpy.data.objects['Aiden_Rig']; M = 'mixamorig:'
F = json.load(open(os.path.join(W, 'fist.json')))
TP = os.path.join(W, 'staff_tune.json')
P = json.load(open(TP)) if os.path.exists(TP) else {}
SIDE = P.get('hand', 'Left')
for o in [o for o in bpy.data.objects if o.name.startswith('Aiden_Staff')]: bpy.data.objects.remove(o)

img = bpy.data.images.load(os.path.join(W, 'aiden_staff.png'), check_existing=True)
mat = bpy.data.materials.get('Aiden_Staff') or bpy.data.materials.new('Aiden_Staff'); mat.use_nodes = True
nt = mat.node_tree; bs = nt.nodes['Principled BSDF']
tx = [n for n in nt.nodes if n.type == 'TEX_IMAGE']; tx = tx[0] if tx else nt.nodes.new('ShaderNodeTexImage')
tx.image = img; nt.links.new(tx.outputs[0], bs.inputs['Base Color']); bs.inputs['Roughness'].default_value = 0.7
cm = bpy.data.materials.get('Aiden_Crystal') or bpy.data.materials.new('Aiden_Crystal'); cm.use_nodes = True
cb = cm.node_tree.nodes['Principled BSDF']
cb.inputs['Base Color'].default_value = (1.0, 0.62, 0.12, 1); cb.inputs['Roughness'].default_value = 0.25
cb.inputs['Emission Color'].default_value = (1.0, 0.72, 0.25, 1); cb.inputs['Emission Strength'].default_value = 1.8


def sw(i, u=0.5): return ((i*32+2+u*28)/256, 0.5)


WOOD, WOODD, GOLD, GOLDD, ROBE, CRYS, CORE, WRAP = range(8)   # WOODD = brown wood (staff foot)
BELOW, ABOVE = P.get('below', 0.70), P.get('above', 0.50)
R = 0.0165
SUN_R = P.get('sun_r', 0.085)
GR = P.get('grip_r', 0.015)


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


def torus(vert, face, c, R, r, nu, nv, U, Wn, Nrm, sw_):
    rings = []
    for i in range(nu):
        t = 2*math.pi*i/nu; rad = U*math.cos(t)+Wn*math.sin(t)
        rings.append(ringf(vert, c+rad*R, r, nv, rad, Nrm))
    for i in range(nu): bridge(face, rings[i], rings[(i+1) % nu], sw_, sw_)


def staff_fn(vert, face):
    X, Y, Z = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
    st = [(-BELOW, 0.011, GOLDD), (-BELOW+0.035, 0.0175, GOLD), (-BELOW+0.06, 0.0135, WOODD), (-0.30, 0.0140, WOOD),
          (-0.075, 0.0145, WOOD), (-0.07, GR, WRAP), (0.07, GR, WRAP), (0.075, 0.0145, WOOD),
          (0.30, 0.0150, WOOD), (0.305, 0.0185, GOLD), (0.33, 0.0185, GOLD), (0.335, 0.0150, WOOD), (ABOVE-0.03, 0.017, WOOD),
          (ABOVE, 0.026, GOLD), (ABOVE+0.03, 0.022, GOLDD)]
    rings = [(ringf(vert, Y*y, r, 6, X, Z), s) for y, r, s in st]
    capf(face, rings[0][0], sw(GOLDD), True)
    for (a, sa), (b, sb) in zip(rings, rings[1:]): bridge(face, a, b, sw(sb, 0.3), sw(sb, 0.8))
    top = ABOVE+0.03
    capf(face, rings[-1][0], sw(GOLDD))
    RR, cy = SUN_R, top+SUN_R+0.004
    C = Y*cy
    # sun ring in the X-Y plane and a thinner crossed ring in the Z-Y plane (armillary sun)
    torus(vert, face, C, RR, 0.0105, 12, 4, X, Y, Z, sw(GOLD, 0.6))
    torus(vert, face, C, RR*0.92, 0.0065, 10, 3, Z, Y, X, sw(GOLDD, 0.6))
    # rays: 7 diamond spikes around the ring (none at the bottom where the shaft joins), long/short alternating
    for i in range(1, 8):
        t = 2*math.pi*i/8-math.pi/2; rad = X*math.cos(t)+Y*math.sin(t); tan = X*-math.sin(t)+Y*math.cos(t)
        L = 0.055 if i % 2 == 0 else 0.032
        b0 = C+rad*(RR+0.004); tip = vert(tuple(C+rad*(RR+L)))
        q = [vert(tuple(b0+tan*0.016)), vert(tuple(b0+Z*0.009)), vert(tuple(b0-tan*0.016)), vert(tuple(b0-Z*0.009))]
        for j in range(4): face([q[j], q[(j+1) % 4], tip], [sw(GOLD, 0.2), sw(GOLD, 0.5), sw(GOLD, 0.95)])
    # amber orb (8x5 lat-long sphere), emissive
    orr = 0.043; nlat, nlon = 5, 8
    pole_lo = vert(tuple(C-Y*orr)); pole_hi = vert(tuple(C+Y*orr)); lat = []
    for i in range(1, nlat):
        ph = -math.pi/2+math.pi*i/nlat
        lat.append(ringf(vert, C+Y*(orr*math.sin(ph)), orr*math.cos(ph), nlon, X, Z))
    for j in range(nlon):
        face([lat[0][(j+1) % nlon], lat[0][j], pole_lo], [sw(CRYS, 0.2)]*3, 1)
        face([lat[-1][j], lat[-1][(j+1) % nlon], pole_hi], [sw(CRYS, 0.95)]*3, 1)
    for k in range(len(lat)-1):
        u0 = sw(CRYS, 0.2+0.7*k/(len(lat)-1))
        for j in range(nlon):
            face([lat[k][j], lat[k][(j+1) % nlon], lat[k+1][(j+1) % nlon], lat[k+1][j]], [u0]*4, 1)


side = SIDE
f = F[side]; hand = V(f['hand']); d = (V(f['mid1'])-hand).normalized()
k = (V(f['idx1'])-V(f['pnk1'])); k = (k-d*k.dot(d)).normalized()
palm = (d.cross(k) if side == 'Left' else -d.cross(k)).normalized()
c = V(f['mid1'])+palm*P.get('palm', 0.026)+d*P.get('d', 0.004)+k*P.get('k', -0.012)
tilt = math.radians(P.get('tilt', 8))
Y = (k*math.cos(tilt)+d*math.sin(tilt)).normalized()    # shaft leaves the fist on the thumb side
Xs = (d-Y*d.dot(Y)).normalized(); Zs = Xs.cross(Y)
staff = build('Aiden_Staff', staff_fn, c, Xs, Y, Zs)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); eb = rig.data.edit_bones
if 'Staff' in eb: eb.remove(eb['Staff'])
b = eb.new('Staff'); b.head = c; b.tail = c+Y*0.15; b.parent = eb[M+side+'Hand']; b.align_roll(Zs)
bpy.ops.object.mode_set(mode='OBJECT')
staff.parent = rig; m = staff.modifiers.new('Armature', 'ARMATURE'); m.object = rig
staff.vertex_groups.new(name='Staff').add(list(range(len(staff.data.vertices))), 1.0, 'REPLACE')
for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, argv[1]))
print('STAFF tris', sum(len(p.vertices)-2 for p in staff.data.polygons), 'side', side, 'len', round(BELOW+ABOVE+0.03+2*SUN_R+0.06, 3))
