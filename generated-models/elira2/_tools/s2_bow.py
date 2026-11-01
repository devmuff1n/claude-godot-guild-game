# Step 2: weight fix (quiver/cape were skinned to the right arm and left thigh), bow + string + arrow as separate skinned
# meshes on new bones: Bow (child of LeftHand), BowLimbTop/BowLimbBot (flex), BowString (nock point), Arrow (free root).
import bpy, bmesh, os, sys, math, json
from mathutils import Vector, Matrix
V = Vector
W = os.path.join(os.path.dirname(__file__), '..', '_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, 's1.blend'))
rig = bpy.data.objects['Elira_Rig']; body = bpy.data.objects['Elira']
M = 'mixamorig:'
B = {b.name: b for b in rig.data.bones}
def H(n): return B[M+n].head_local.copy()

# ---------- weights: things on the back follow the chest, not the arms / thighs
vg = {g.name: g for g in body.vertex_groups}
bad_idx = {vg[M+n].index for n in ('RightArm', 'RightForeArm', 'LeftArm', 'LeftForeArm', 'LeftUpLeg', 'RightUpLeg') if M+n in vg}
nfix = 0
for v in body.data.vertices:
    co = v.co
    if co.y > 0.035 and co.z > 0.62 and abs(co.x) < 0.34:
        ws = {g.group: g.weight for g in v.groups}
        moved = sum(w for i, w in ws.items() if i in bad_idx)
        if moved < 1e-3: continue
        if moved > 0.12:   # quiver: rigid on the upper chest
            for i in list(ws): body.vertex_groups[i].remove([v.index])
            vg[M+'Spine2'].add([v.index], 1.0, 'REPLACE')
        else:
            for i in bad_idx:
                if i in ws: body.vertex_groups[i].remove([v.index])
            vg[M+'Spine2' if co.z > 0.95 else M+'Spine1'].add([v.index], moved, 'ADD')
        nfix += 1
print('WFIX', nfix)

# ---------- bow frame at rest: grip in the left fist, up = knuckle line, T = toward the target (finger direction)
up = (H('LeftHandIndex1')-H('LeftHandPinky1')).normalized()
fd = H('LeftHandMiddle1')-H('LeftHand')
T = (fd-up*fd.dot(up)).normalized()
SIDE = up.cross(T).normalized()
palm = Vector((0, -1, 0)); palm = (palm-up*palm.dot(up)-T*palm.dot(T)).normalized()
FIST = json.load(open(os.path.join(W, 'fist.json')))['Left']   # from fist_probe.py on s1.blend
G = V(FIST['center'])+palm*0.004-T*0.024     # the grip bulges 0.024 toward the target; put the bulge in the hollow
HALF = 0.45
TIP = 0.985
def wcen(s):
    a = abs(s)
    return 0.024*(1-a)**2-0.12*a**2+0.06*max(0.0, (a-0.78)/0.22)**2
def P(s, w, v=0.0): return G+up*(s*HALF)+T*w+SIDE*v
def rad(s):
    a = abs(s); r = 0.019 if a < 0.13 else 0.019-0.011*((a-0.13)/0.87)
    return max(r, 0.0075)
def mat(name, col, rough=0.75, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m
wood = mat('Bow_Wood', (0.36, 0.17, 0.07)); wrap = mat('Bow_Wrap', (0.16, 0.33, 0.14), 0.9)
gold = mat('Bow_Gold', (0.86, 0.62, 0.24), 0.4, 0.8); strm = mat('Bow_String', (0.92, 0.88, 0.74), 0.8)
shaft_m = mat('Arrow_Shaft', (0.62, 0.42, 0.22)); head_m = mat('Arrow_Head', (0.75, 0.77, 0.8), 0.35, 0.9)
fl_m = mat('Arrow_Fletch', (0.22, 0.52, 0.2), 0.85); fl_m.use_backface_culling = False

# ---------- bones
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = rig.data.edit_bones
def nb(name, head, tail, parent, rollvec):
    b = eb.new(name); b.head = head; b.tail = tail; b.parent = eb[parent] if parent else None
    b.align_roll(rollvec); b.use_deform = True
    return b
ARROW_U = 0.035
NOCK = P(ARROW_U/HALF, wcen(TIP))
ARROW_L = 0.62
nb('Bow', G, G+up*0.10, M+'LeftHand', T)
nb('BowLimbTop', P(0.27, wcen(0.27)), P(TIP, wcen(TIP)), 'Bow', T)
nb('BowLimbBot', P(-0.27, wcen(-0.27)), P(-TIP, wcen(-TIP)), 'Bow', T)
nb('BowString', NOCK, NOCK+T*0.06, 'Bow', up)
nb('Arrow', NOCK, NOCK+T*ARROW_L, None, up)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- meshes
def obj_from_bm(name, bm, mats):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob
def sweep(bm, s0, s1, rf, mi, rings, segs=8, flat=1.5, store=None):
    R = []
    for i in range(rings+1):
        s = s0+(s1-s0)*i/rings; c = P(s, wcen(s))
        ds = 1e-3; sa = min(1.2, s+ds); sb = max(-1.2, s-ds)
        t = (P(sa, wcen(sa))-P(sb, wcen(sb))).normalized()
        n = t.cross(SIDE).normalized(); r = rf(s); ring = []
        for j in range(segs):
            a = 2*math.pi*(j+0.5)/segs
            v = bm.verts.new(c+SIDE*(r*flat*math.cos(a))+n*(r*math.sin(a))); ring.append(v)
            store[v] = s
        R.append(ring)
    for i in range(rings):
        for j in range(segs):
            f = bm.faces.new([R[i][j], R[i][(j+1) % segs], R[i+1][(j+1) % segs], R[i+1][j]]); f.material_index = mi
    f = bm.faces.new(list(reversed(R[0]))); f.material_index = mi
    f = bm.faces.new(R[-1]); f.material_index = mi
bm = bmesh.new(); S = {}
sweep(bm, -TIP-0.015, TIP+0.015, rad, 0, 44, store=S)
sweep(bm, -0.14, 0.14, lambda s: rad(s)*1.12, 1, 6, flat=1.35, store=S)
for s0 in (-0.2, 0.17):
    sweep(bm, s0, s0+0.03, lambda s: rad(s)*1.42, 2, 1, store=S)
for sg in (-1, 1):
    sweep(bm, sg*0.9, sg*(TIP+0.02), lambda s: rad(s)*1.3, 2, 4, store=S)
    s = sg*0.5; c = P(s, wcen(s)+rad(s)*0.9)
    pts = [c, c+up*(sg*0.06)+T*0.03, c+up*(sg*0.14)+T*0.012, c+up*(sg*0.07)+T*0.006]
    a = [bm.verts.new(p-SIDE*0.004) for p in pts]; b_ = [bm.verts.new(p+SIDE*0.004) for p in pts]
    for v in a+b_: S[v] = s
    f = bm.faces.new(a); f.material_index = 1
    f = bm.faces.new(list(reversed(b_))); f.material_index = 1
    for i in range(4):
        f = bm.faces.new([a[i], a[(i+1) % 4], b_[(i+1) % 4], b_[i]]); f.material_index = 1
bm.verts.index_update(); sv = [S[v] for v in bm.verts]
bow = obj_from_bm('Elira_Bow', bm, [wood, wrap, gold])
# string: 2 segments
bm = bmesh.new(); tt = P(TIP, wcen(TIP)); tb = P(-TIP, wcen(-TIP)); rings = []
for p in (tt, NOCK, tb):
    rings.append([bm.verts.new(p+SIDE*(0.0035*math.cos(2*math.pi*j/4))+T*(0.0035*math.sin(2*math.pi*j/4))) for j in range(4)])
for i in range(2):
    for j in range(4): bm.faces.new([rings[i][j], rings[i][(j+1) % 4], rings[i+1][(j+1) % 4], rings[i+1][j]])
string = obj_from_bm('Elira_String', bm, [strm])
# arrow along +T from the nock
bm = bmesh.new()
def cyl(y0, y1, r0, r1, mi, segs=6):
    A = [bm.verts.new(NOCK+T*y0+SIDE*(r0*math.cos(2*math.pi*j/segs))+up*(r0*math.sin(2*math.pi*j/segs))) for j in range(segs)]
    Bv = [bm.verts.new(NOCK+T*y1+SIDE*(r1*math.cos(2*math.pi*j/segs))+up*(r1*math.sin(2*math.pi*j/segs))) for j in range(segs)]
    for j in range(segs):
        f = bm.faces.new([A[j], Bv[j], Bv[(j+1) % segs], A[(j+1) % segs]]); f.material_index = mi
    f = bm.faces.new(list(reversed(A))); f.material_index = mi
    f = bm.faces.new(Bv); f.material_index = mi
cyl(0.0, ARROW_L-0.06, 0.0055, 0.0055, 0)
cyl(ARROW_L-0.065, ARROW_L, 0.016, 0.0006, 1, 4)
cyl(-0.008, 0.006, 0.007, 0.007, 0)
for k in range(3):
    a = 2*math.pi*k/3+math.pi/2; d = SIDE*math.cos(a)+up*math.sin(a)
    pr = [(0.005, 0.012), (0.026, 0.035), (0.022, 0.11), (0.005, 0.125)]
    f = bm.faces.new([bm.verts.new(NOCK+T*y+d*r) for r, y in pr]); f.material_index = 2
arrow = obj_from_bm('Elira_Arrow', bm, [shaft_m, head_m, fl_m])

# ---------- skinning
def skin(ob):
    ob.parent = rig; m = ob.modifiers.new('Armature', 'ARMATURE'); m.object = rig
skin(bow); skin(string); skin(arrow)
g0 = bow.vertex_groups.new(name='Bow'); gt = bow.vertex_groups.new(name='BowLimbTop'); gb = bow.vertex_groups.new(name='BowLimbBot')
for i, s in enumerate(sv):
    t = max(0.0, min(1.0, (abs(s)-0.15)/0.3))
    if t < 1: g0.add([i], 1-t, 'REPLACE')
    if t > 0: (gt if s > 0 else gb).add([i], t, 'REPLACE')
gt = string.vertex_groups.new(name='BowLimbTop'); gs = string.vertex_groups.new(name='BowString'); gb = string.vertex_groups.new(name='BowLimbBot')
gt.add(list(range(0, 4)), 1, 'REPLACE'); gs.add(list(range(4, 8)), 1, 'REPLACE'); gb.add(list(range(8, 12)), 1, 'REPLACE')
arrow.vertex_groups.new(name='Arrow').add(list(range(len(arrow.data.vertices))), 1, 'REPLACE')
meta = dict(G=list(G), up=list(up), T=list(T), SIDE=list(SIDE), NOCK=list(NOCK), HALF=HALF, ARROW_L=ARROW_L, ARROW_U=ARROW_U)
json.dump(meta, open(os.path.join(W, 'bow_meta.json'), 'w'), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, 's2.blend'))
print('S2 bow tris', sum(len(p.vertices)-2 for p in bow.data.polygons), 'arrow', sum(len(p.vertices)-2 for p in arrow.data.polygons))
