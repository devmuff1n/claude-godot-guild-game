# Staff-carry pose for the staff arm, as rotation deltas in armature rest space relative to Spine2:
# D[n] = D[Spine2] @ CARRY[n]. Upper arm down and a little out/forward, forearm forward and slightly down,
# fist axis (pinky -> index) upright so the staff stands vertical next to the front foot.
import math
from mathutils import Vector as V, Matrix
from grip import palm_frame
M = 'mixamorig:'


def _rd(a, b): return a.normalized().rotation_difference(b.normalized()).to_matrix()


def carry_map(rig, side, P=None):
    P = P or {}
    B = rig.data.bones; sg = 1 if side == 'Left' else -1
    arm, fore, hand = B[M+side+'Arm'], B[M+side+'ForeArm'], B[M+side+'Hand']
    a_t = V((sg*P.get('carry_out', 0.30), -P.get('carry_fwd', 0.16), -1))
    Ra = _rd(arm.tail_local-arm.head_local, a_t)
    f_t = V((-sg*P.get('carry_in', 0.08), -1, -math.tan(math.radians(P.get('carry_fore_down', 22)))))
    Rf = _rd(Ra @ (fore.tail_local-fore.head_local), f_t) @ Ra
    _, d0, k0, p0 = palm_frame(rig, side)
    up = math.radians(P.get('carry_staff_fwd', 6))
    k_t = V((0, -math.sin(up), math.cos(up)))
    d_t = V((-sg*0.05, -1, -math.tan(math.radians(P.get('carry_wrist_down', 4)))))
    d_t = (d_t-k_t*d_t.dot(k_t)).normalized()
    Mr = Matrix((d0, k0, d0.cross(k0))).transposed()
    Mt = Matrix((d_t, k_t, d_t.cross(k_t))).transposed()
    Rh = Mt @ Mr.inverted()
    # move half of the wrist twist (about the forearm axis) into the forearm
    from mathutils import Quaternion
    fa = (Rf @ (fore.tail_local-fore.head_local)).normalized()
    q = (Rh @ Rf.inverted()).to_quaternion()
    xyz = V((q.x, q.y, q.z)); p = fa*xyz.dot(fa)
    tw = Quaternion((q.w, p.x, p.y, p.z)).normalized()
    ang = 2*math.atan2(V((tw.x, tw.y, tw.z)).dot(fa), tw.w)
    Rf = Quaternion(fa, ang*0.5).to_matrix() @ Rf
    return {M+side+'Shoulder': Matrix.Identity(3), M+side+'Arm': Ra, M+side+'ForeArm': Rf, M+side+'Hand': Rh}


def carry_weight(name, f, n):
    """1 = carry pose, 0 = Mixamo arm. f = frame index, n = last frame."""
    nm = name.lower(); t = f/max(n, 1)
    def ss(a, b, x):
        x = max(0.0, min(1.0, (x-a)/(b-a))); return x*x*(3-2*x)
    if any(k in nm for k in ('idle', 'walk', 'run', 'sprint', 'turn')) and 'block' not in nm: return 1.0
    if 'death' in nm: return 1-ss(0.0, 0.4, t)
    if 'small' in nm or 'large' in nm and 'block' not in nm: return 0.65
    if 'dodg' in nm or 'step' in nm: return 0.8
    e = min(8, n/4)
    edge = max(1-ss(0, e, f), ss(n-e, n, f))
    lo = 0.7 if ('1h' in nm or 'victory' in nm) else 0.0
    return lo+(1-lo)*edge
