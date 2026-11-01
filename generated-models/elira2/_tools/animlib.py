# Pose helpers for Elira (new Tripo model): world-axis rotations at rest, analytic two-bone IK, hand frames,
# finger curl, bow string / arrow placement. All coordinates in armature space (= world, rig has identity transform).
import bpy, math, json, os
from mathutils import Vector, Matrix, Quaternion
M = 'mixamorig:'
V = Vector
rig = pose = REST = META = None
def init(r, meta_path):
    global rig, pose, REST, META
    rig = r; pose = r.pose.bones
    for pb in pose: pb.rotation_mode = 'QUATERNION'
    REST = {pb.name: pb.bone.matrix_local.to_3x3() for pb in pose}
    META = {k: (V(v) if isinstance(v, list) else v) for k, v in json.load(open(meta_path)).items()}
def FN(n): return n if n in pose else M+n
def upd(): bpy.context.view_layer.update()
def rest_head(n): return pose[FN(n)].bone.head_local.copy()
def head(n): return pose[FN(n)].head.copy()
def tail(n): return pose[FN(n)].tail.copy()
def smooth(x): x = max(0.0, min(1.0, x)); return x*x*(3-2*x)

PALM = V((0, -1, 0))
def world_rot(d):
    R = Matrix.Identity(3)
    for ax in ('X', 'Y', 'Z'):
        a = d.get(ax, 0.0)
        if a: R = Matrix.Rotation(math.radians(a), 3, ax) @ R
    for axis, deg in d.get('axis', []):
        R = Matrix.Rotation(math.radians(deg), 3, V(axis)) @ R
    return R
def add(P, n, ax, v):
    P.setdefault(n, {})
    if ax == 'axis': P[n].setdefault('axis', []).append(v)
    else: P[n][ax] = P[n].get(ax, 0)+v
def apply_pose(P):
    for pb in pose:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for n, d in P.items():
        b = FN(n)
        if b not in pose: continue
        pb = pose[b]; Mr = REST[b]
        pb.rotation_quaternion = (Mr.inverted() @ world_rot(d) @ Mr).to_quaternion()
        if 'loc' in d: pb.location = Mr.inverted() @ V(d['loc'])

def bone_dir(n): b = pose[FN(n)].bone; return (b.tail_local-b.head_local).normalized()
def curl_axis(n): return bone_dir(n).cross(PALM).normalized()
def fingers(P, side, curl, thumb=0.0, spread=0.0):
    """curl: {'1':deg,'2':deg,'3':deg} or number; thumb 0..1 folds the thumb over the fist."""
    for f in ('Index', 'Middle', 'Ring', 'Pinky'):
        for k in ('1', '2', '3'):
            c = curl[k] if isinstance(curl, dict) else curl
            n = f'{side}Hand{f}{k}'
            if FN(n) in pose and c: add(P, n, 'axis', (tuple(curl_axis(n)), c))
    if thumb:
        for k, a in (('1', 25), ('2', 35), ('3', 40)):
            n = f'{side}HandThumb{k}'
            add(P, n, 'axis', (tuple(curl_axis(n)), a*thumb))
        add(P, f'{side}HandThumb1', 'axis', (tuple(bone_dir(f'{side}Hand')*(1 if side == 'Left' else -1)), 28*thumb))
GRIP = {'1': 75, '2': 95, '3': 60}
HOOK = {'1': 15, '2': 80, '3': 50}
RELAX = {'1': 12, '2': 18, '3': 12}

def set_dir(pb, d):
    upd()
    Mx = pb.matrix.copy(); cur = Mx.to_3x3().normalized()
    q = (cur @ V((0, 1, 0))).rotation_difference(V(d).normalized())
    pb.matrix = Matrix.Translation(Mx.translation) @ (q.to_matrix() @ cur).to_4x4()
def arm_len(side):
    a = pose[FN(side+'Arm')].bone; f = pose[FN(side+'ForeArm')].bone
    return a.length, f.length
def ik(side, wrist, pole):
    a = pose[FN(side+'Arm')]; f = pose[FN(side+'ForeArm')]
    upd()
    S = a.head.copy(); la, lb = arm_len(side)
    d = V(wrist)-S; L = min(d.length, (la+lb)*0.999); u = d.normalized()
    ca = max(-1, min(1, (la*la+L*L-lb*lb)/(2*la*L))); along = la*ca; hgt = la*math.sqrt(max(0, 1-ca*ca))
    p = V(pole); v = (p-u*p.dot(u)).normalized()
    E = S+u*along+v*hgt
    set_dir(a, E-S); set_dir(f, S+u*L-E)
def frame(d, k):
    d = V(d).normalized(); k = (V(k)-d*V(k).dot(d)).normalized()
    return Matrix((d, k, d.cross(k))).transposed()
def hand_rest(side):
    d = (rest_head(side+'HandMiddle1')-rest_head(side+'Hand')).normalized()
    k = (rest_head(side+'HandIndex1')-rest_head(side+'HandPinky1')).normalized()
    return d, k
def hand_R(side, d_new, k_new):
    dr, kr = hand_rest(side)
    return frame(d_new, k_new) @ frame(dr, kr).transposed()
def set_hand(side, d_new, k_new):
    upd()
    pb = pose[FN(side+'Hand')]
    R = hand_R(side, d_new, k_new)
    pb.matrix = Matrix.Translation(pb.matrix.translation) @ (R @ pb.bone.matrix_local.to_3x3()).to_4x4()
def place_arm(side, wrist, pole, d_new, k_new):
    ik(side, wrist, pole); set_hand(side, d_new, k_new)

def deform(n):
    """armature-space deform matrix of a bone (posed @ rest^-1)."""
    pb = pose[FN(n)]; return pb.matrix @ pb.bone.matrix_local.inverted()
def hook_point():
    upd()
    return (head('RightHandIndex2')+head('RightHandMiddle2'))*0.5+deform('RightHand').to_3x3() @ PALM*0.006
def fist_point(side):
    upd()
    c = (head(side+'HandIndex1')+head(side+'HandPinky1'))*0.5
    return c
def bow_rest_point():   # where the arrow rests on the bow (above the fist)
    return deform('Bow') @ (META['G']+META['up']*META['ARROW_U'])
def string_rest_point():
    return deform('Bow') @ META['NOCK']
def place_string(pt):
    upd(); pb = pose['BowString']
    pb.matrix = Matrix.Translation(pt) @ pb.matrix.to_3x3().to_4x4()
def place_arrow(nock, dirv, upv, visible=True):
    pb = pose['Arrow']
    R = frame(dirv, upv) @ frame(META['T'], META['up']).transposed()
    Mx = Matrix.Translation(nock) @ (R @ pb.bone.matrix_local.to_3x3()).to_4x4()
    if not visible: Mx = Mx @ Matrix.Scale(0.001, 4)
    pb.matrix = Mx
def flex_bow(t):
    """t 0..1: limbs bend toward the archer while drawing."""
    upd()
    side = META['SIDE']
    for n, sg in (('BowLimbTop', -1), ('BowLimbBot', 1)):
        pb = pose[n]; Mr = REST[n]
        pb.rotation_quaternion = (Mr.inverted() @ Matrix.Rotation(math.radians(9*t), 3, side*sg) @ Mr).to_quaternion()
