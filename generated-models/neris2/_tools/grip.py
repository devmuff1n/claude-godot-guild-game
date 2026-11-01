# Staff-hand fist: per finger bone, a rotation delta in armature rest space (curl toward the palm).
# D[finger] = D[hand] @ CURL[finger]  (D = world rotation change from rest, as in mx_retarget).
import math
from mathutils import Vector as V, Matrix
M = 'mixamorig:'
CURL_DEG = {'Index': (78, 88, 60), 'Middle': (82, 90, 60), 'Ring': (86, 90, 60), 'Pinky': (90, 90, 60)}
THUMB_DEG = (25, 45, 40)


def palm_frame(rig, side):
    B = rig.data.bones
    hand = B[M+side+'Hand'].head_local
    d = (B[M+side+'HandMiddle1'].head_local-hand).normalized()
    k = B[M+side+'HandIndex1'].head_local-B[M+side+'HandPinky1'].head_local
    k = (k-d*k.dot(d)).normalized()
    palm = d.cross(k) if side == 'Left' else -d.cross(k)
    return hand, d, k, palm.normalized()


def curl_map(rig, side):
    B = rig.data.bones
    hand, d, k, palm = palm_frame(rig, side)
    out = {}
    for f, degs in list(CURL_DEG.items())+[('Thumb', THUMB_DEG)]:
        acc = Matrix.Identity(3)
        for j, deg in enumerate(degs, 1):
            b = B.get(M+side+'Hand'+f+str(j))
            if b is None: continue
            fd = (acc @ (b.tail_local-b.head_local)).normalized()
            if f == 'Thumb':
                ax = fd.cross(palm+k*0.6).normalized()   # thumb wraps across the front of the fist
            else:
                ax = fd.cross(palm).normalized()
            acc = Matrix.Rotation(math.radians(deg), 3, ax) @ acc
            out[b.name] = acc.copy()
    return out
