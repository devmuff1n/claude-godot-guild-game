# Step 3: low-poly sword (right fist) and heater shield (left hand) as skinned meshes on new bones
# Sword (child of RightHand) and Shield (child of LeftHand). Grip from _work/fist.json (fist hollow in a Mixamo
# frame, stored in rest space); fine offsets in _work/props_tune.json. One extra material Marek_Gear with
# _work/marek_gear.png (gear_tex.py).
# blender -b --python s3_props.py -- <in_blend> <out_blend>
import bpy, bmesh, os, sys, math, json
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
rig = bpy.data.objects['Marek_Rig']; M = 'mixamorig:'
F = json.load(open(os.path.join(W, 'fist.json')))
TP = os.path.join(W, 'props_tune.json')
P = json.load(open(TP)) if os.path.exists(TP) else {}
for o in [o for o in bpy.data.objects if o.name.startswith(('Marek_Sword', 'Marek_Shield'))]:
    bpy.data.objects.remove(o)


def frame_of(side):
    f = F[side]; hand = V(f['hand']); d = (V(f['mid1'])-hand).normalized()
    k = (V(f['idx1'])-V(f['pnk1'])); k = (k-d*k.dot(d)).normalized()
    palm = d.cross(k) if side == 'Left' else -d.cross(k)
    return hand, d, k, palm.normalized()


# ---------- material
img = bpy.data.images.load(os.path.join(W, 'marek_gear.png'), check_existing=True)
mat = bpy.data.materials.get('Marek_Gear') or bpy.data.materials.new('Marek_Gear'); mat.use_nodes = True
nt = mat.node_tree; bs = nt.nodes['Principled BSDF']
tx = [n for n in nt.nodes if n.type == 'TEX_IMAGE']; tx = tx[0] if tx else nt.nodes.new('ShaderNodeTexImage')
tx.image = img; nt.links.new(tx.outputs[0], bs.inputs['Base Color'])
bs.inputs['Roughness'].default_value = 0.6; bs.inputs['Metallic'].default_value = 0.0


def sw(i, u=0.5): return ((512+i*64+4+u*56)/1024, 0.5)   # swatch uv


STEEL, STEELD, GOLD, GOLDD, LEATHER, BLUE, RED, WOOD = range(8)


def build(name, fn, origin, X, Y, Z):
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new('UVMap')
    Mx = Matrix((X, Y, Z)).transposed()

    def vert(p): return bm.verts.new(V(origin)+Mx @ V(p))

    def face(vs, uvs):
        f = bm.faces.new(vs)
        for l, uv in zip(f.loops, uvs): l[uvl].uv = uv
        return f
    fn(vert, face)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    for p in me.polygons: p.use_smooth = False
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob


def ring(vert, y, pts): return [vert((x, y, z)) for x, z in pts]


def bridge(face, A, B, uvA, uvB):
    n = len(A)
    for j in range(n):
        face([A[j], A[(j+1) % n], B[(j+1) % n], B[j]], [uvA[j], uvA[(j+1) % n], uvB[(j+1) % n], uvB[j]])


def cap(face, R, uv, rev=False): face(list(reversed(R)) if rev else R, [uv]*len(R))


def sec(r, n=6): return [(r*math.cos(2*math.pi*j/n), r*math.sin(2*math.pi*j/n)) for j in range(n)]


# ---------- sword: local Y along the blade, X = blade width (finger direction), Z = flat normal (palm)
GRIP = P.get('grip', 0.13); BL = P.get('blade', 0.70)


def sword_fn(vert, face):
    rs = [(-GRIP/2-0.050, 0.008), (-GRIP/2-0.040, 0.024), (-GRIP/2-0.018, 0.026), (-GRIP/2-0.004, 0.014)]
    Rs = [ring(vert, y, sec(r, 8)) for y, r in rs]
    cap(face, Rs[0], sw(GOLDD), True)
    for a, b in zip(Rs, Rs[1:]): bridge(face, a, b, [sw(GOLD)]*8, [sw(GOLD)]*8)
    cap(face, Rs[-1], sw(GOLD))
    gs = [(-GRIP/2, 0.0155), (0, 0.0175), (GRIP/2, 0.0155)]
    Rg = [ring(vert, y, sec(r, 6)) for y, r in gs]
    for a, b in zip(Rg, Rg[1:]): bridge(face, a, b, [sw(LEATHER)]*6, [sw(LEATHER)]*6)
    cap(face, Rg[0], sw(LEATHER), True); cap(face, Rg[-1], sw(LEATHER))
    y0 = GRIP/2+0.004
    pts = [(-0.125, 0.022), (-0.09, 0.008), (-0.03, 0.0), (0.03, 0.0), (0.09, 0.008), (0.125, 0.022)]
    secs = []
    for x, dy in pts:
        h = 0.014 if abs(x) < 0.05 else 0.010; t = 0.020 if abs(x) < 0.05 else 0.013
        c = y0+0.016+dy
        secs.append([vert((x, c-h, -t)), vert((x, c+h, -t)), vert((x, c+h, t)), vert((x, c-h, t))])
    for a, b in zip(secs, secs[1:]): bridge(face, a, b, [sw(GOLD)]*4, [sw(GOLD)]*4)
    cap(face, secs[0], sw(GOLDD)); cap(face, secs[-1], sw(GOLDD), True)
    for s in (1, -1):   # blue gem on both faces of the guard
        g = [vert((dx, y0+0.016+dy, s*0.021)) for dx, dy in ((0.012, 0), (0, 0.014), (-0.012, 0), (0, -0.014))]
        tip = vert((0, y0+0.016, s*0.030))
        for j in range(4): face([g[j], g[(j+1) % 4], tip], [sw(BLUE)]*3)
    b0 = y0+0.030
    st = [(b0, 0.030, 0.0075), (b0+BL*0.55, 0.027, 0.0068), (b0+BL*0.86, 0.022, 0.006)]
    hi = ((512+4+0.95*56)/1024, 0.5); lo = ((512+4+0.35*56)/1024, 0.5)
    uvs = [hi, lo, hi, lo]
    Rb = [[vert((w, y, 0)), vert((0, y, t)), vert((-w, y, 0)), vert((0, y, -t))] for y, w, t in st]
    for a, b in zip(Rb, Rb[1:]): bridge(face, a, b, uvs, uvs)
    cap(face, Rb[0], sw(STEELD), True)
    tip = vert((0, b0+BL, 0))
    for j in range(4): face([Rb[-1][j], Rb[-1][(j+1) % 4], tip], [uvs[j], uvs[(j+1) % 4], sw(STEEL, 0.9)])


hand, d, k, palm = frame_of('Right')
c = V(F['Right']['center'])+palm*P.get('sword_palm', 0.004)+d*P.get('sword_d', -0.006)+k*P.get('sword_k', 0.0)
tilt = math.radians(P.get('sword_tilt', 12))
Y = (k*math.cos(tilt)+d*math.sin(tilt)).normalized()   # blade leaves the fist on the thumb side, leaning forward
Xs = (d-Y*d.dot(Y)).normalized(); Zs = Xs.cross(Y)
sword = build('Marek_Sword', sword_fn, c, Xs, Y, Zs)
SWORD_ORIGIN, SWORD_Y, SWORD_X = c, Y, Xs

# ---------- shield: local X width, Y up, Z out (face normal)
SW, SH = P.get('shield_w', 0.25), P.get('shield_h', 0.31)   # half sizes
BOW = 0.035; TH = 0.022


def half_w(y):
    t = max(0.0, min(1.0, (0.1-y)/1.1))
    return 1.0 if y > 0.1 else 1-t**2.2


def outline():
    pts = [(-1+2*i/6, 1.0) for i in range(6)]
    pts += [(1.0, 1.0), (1.0, 0.55)]
    n = 9
    for i in range(n):
        y = 0.1-1.1*i/n; pts.append((half_w(y), y))
    pts.append((0.0, -1.0))
    for i in range(n-1, -1, -1):
        y = 0.1-1.1*i/n; pts.append((-half_w(y), y))
    pts.append((-1.0, 0.55))
    return pts


def shield_fn(vert, face):
    O = outline(); n = len(O)
    def zf(x): return -BOW*x*x
    def uvf(x, y): return ((x+1)/2*0.5, (y+1)/2)
    rings = []
    for s, lift in ((1.0, 0.006), (0.86, 0.004), (0.5, 0.0)):
        R = []; U = []
        for x, y in O:
            xx, yy = x*s, (y-0.03)*s+0.03
            R.append(vert((xx*SW, yy*SH, zf(xx)+lift))); U.append(uvf(xx, yy))
        rings.append((R, U))
    ctr = vert((0, 0.03*SH, 0.0))
    for (A, UA), (B, UB) in zip(rings, rings[1:]): bridge(face, A, B, UA, UB)
    A, UA = rings[-1]
    for j in range(n): face([A[j], A[(j+1) % n], ctr], [UA[j], UA[(j+1) % n], uvf(0, 0.03)])
    Bk = [vert((x*SW, y*SH, zf(x)-TH)) for x, y in O]
    bridge(face, rings[0][0], Bk, [sw(GOLD)]*n, [sw(GOLDD)]*n)
    cb = vert((0, 0.03*SH, -TH-0.004))
    for j in range(n): face([Bk[(j+1) % n], Bk[j], cb], [sw(WOOD)]*3)
    # leather grip bar through the fist (along the knuckles), two straps down to the back board
    fx, fy, fz = FIST_L; gw = 0.011; zb = -TH-0.004
    kx, ky = Xsh.dot(k), Ysh.dot(k); nk = math.hypot(kx, ky) or 1.0; kx, ky = kx/nk, ky/nk
    px, py = -ky, kx
    ends = [(fx+kx*s, fy+ky*s) for s in (-0.07, 0.07)]
    bar = [[vert((ex+px*dp, ey+py*dp, fz+dz)) for dp, dz in ((-gw, -gw), (gw, -gw), (gw, gw), (-gw, gw))] for ex, ey in ends]
    bridge(face, bar[0], bar[1], [sw(LEATHER)]*4, [sw(LEATHER)]*4)
    for ex, ey in ends:   # straps from the bar ends to the board
        st = [[vert((ex+px*dp+kx*dk, ey+py*dp+ky*dk, z)) for dp, dk in ((-gw, -gw), (gw, -gw), (gw, gw), (-gw, gw))] for z in (fz, zb)]
        bridge(face, st[0], st[1], [sw(LEATHER)]*4, [sw(LEATHER)]*4)


hand, d, k, palm = frame_of('Left')
back = -palm
fc = V(F['Left']['center'])
Zsh = back; Ysh = (k-Zsh*k.dot(Zsh)).normalized()
Ysh = (Matrix.Rotation(math.radians(P.get('shield_roll', 0)), 3, Zsh) @ Ysh).normalized()
Xsh = Ysh.cross(Zsh)
# yaw / pitch from shield_fit.py: turn the shield away from the chest, head and pauldron
Rt = Matrix.Rotation(math.radians(P.get('shield_yaw', 0)), 3, Ysh) @ Matrix.Rotation(math.radians(P.get('shield_pitch', 0)), 3, Xsh)
Xsh, Ysh, Zsh = Rt @ Xsh, Rt @ Ysh, Rt @ Zsh
sc_ = fc+back*P.get('shield_out', 0.075)-d*P.get('shield_back', 0.03)+k*P.get('shield_k', 0.0)
# the fist in shield space: the grip bar on the back goes there (the hand holds the shield off-centre)
Msh = Matrix((Xsh, Ysh, Zsh))
FIST_L = Msh @ (fc-sc_)
shield = build('Marek_Shield', shield_fn, sc_, Xsh, Ysh, Zsh)

# ---------- bones + skin
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); eb = rig.data.edit_bones
for n in ('Sword', 'Shield'):
    if n in eb: eb.remove(eb[n])
b = eb.new('Sword'); b.head = SWORD_ORIGIN; b.tail = SWORD_ORIGIN+SWORD_Y*0.12; b.parent = eb[M+'RightHand']; b.align_roll(SWORD_X)
b = eb.new('Shield'); b.head = sc_; b.tail = sc_+Ysh*0.12; b.parent = eb[M+'LeftHand']; b.align_roll(Zsh)
bpy.ops.object.mode_set(mode='OBJECT')
for ob, bn in ((sword, 'Sword'), (shield, 'Shield')):
    ob.parent = rig; m = ob.modifiers.new('Armature', 'ARMATURE'); m.object = rig
    ob.vertex_groups.new(name=bn).add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, argv[1]))
def tri(o): return sum(len(p.vertices)-2 for p in o.data.polygons)
print('PROPS sword tris', tri(sword), 'shield tris', tri(shield))
