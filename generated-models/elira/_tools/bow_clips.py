# Bow clips for Elira, exec'd inside s4_anim_export.py (uses its rig/pose/apply_pose/key_all/new_action/add/sec_motion).
# Torso and legs come from world-axis euler poses; both arms are placed with an analytic two-bone IK so the left fist
# holds the bow in front of her and the right fist draws the string to the chin.
from mathutils import Vector, Matrix, Quaternion
def _upd(): bpy.context.view_layer.update()
def _set_dir(pb, d):
    """Rotate the posed bone so its head->tail axis points along d (minimal arc from its current orientation)."""
    _upd()
    M = pb.matrix.copy(); cur = M.to_3x3().normalized()
    q = (cur @ Vector((0, 1, 0))).rotation_difference(Vector(d).normalized())
    R = q.to_matrix() @ cur
    pb.matrix = Matrix.Translation(M.translation) @ R.to_4x4()
def _ik(side, wrist, pole, hand_dir):
    a = pose[FN(side+"Arm")]; f = pose[FN(side+"ForeArm")]; h = pose[FN(side+"Hand")]
    _upd()
    S = a.head.copy(); la = (a.tail-a.head).length; lb = (f.tail-f.head).length
    T = Vector(wrist); d = T-S; L = min(d.length, (la+lb)*0.995); u = d.normalized()
    ca = max(-1, min(1, (la*la+L*L-lb*lb)/(2*la*L))); along = la*ca; hgt = la*math.sqrt(max(0, 1-ca*ca))
    p = Vector(pole); v = (p-u*p.dot(u)).normalized()
    E = S+u*along+v*hgt
    _set_dir(a, E-S); _set_dir(f, S+u*L-E); _set_dir(h, hand_dir)
def _set_frame(pb, d_rest, k_rest, d_new, k_new):
    """Turn the posed bone so that rest direction d_rest goes to d_new and rest knuckle line k_rest goes to k_new."""
    _upd()
    def frame(d, k):
        d = Vector(d).normalized(); k = (Vector(k)-d*Vector(k).dot(d)).normalized(); return Matrix((d, k, d.cross(k))).transposed()
    R = frame(d_new, k_new) @ frame(d_rest, k_rest).transposed()
    M = pb.matrix.copy(); rest = pb.bone.matrix_local.to_3x3()
    pb.matrix = Matrix.Translation(M.translation) @ (R @ rest).to_4x4()
def _knuckles(side):
    b = pose[FN(side+"HandIndex1")].bone.head_local - pose[FN(side+"HandPinky1")].bone.head_local
    return b.normalized()
HAND_REST = {s: (pose[FN(s+"HandMiddle1")].bone.head_local-pose[FN(s+"Hand")].bone.head_local).normalized() for s in ("Left", "Right")}   # same as Godot: toward the middle knuckle
GRIP = {"1": 62, "2": 85, "3": 55}           # bow fist: per-joint curl, degrees
HOOK = {"1": 18, "2": 70, "3": 45}           # string hook of the drawing fingers
def fingers(P, side, curl, thumb=0.0, little_extra=0.0):
    sg = 1 if side == "Left" else -1
    for f in ("Index", "Middle", "Ring", "Pinky"):
        for k in ("1", "2", "3"):
            c = curl[k] if isinstance(curl, dict) else curl
            if f == "Pinky": c = c + little_extra
            add(P, f"{side}Hand{f}{k}", 'Y', sg*c)
    add(P, f"{side}HandThumb1", 'Z', -sg*22*thumb); add(P, f"{side}HandThumb1", 'Y', sg*15*thumb)
    add(P, f"{side}HandThumb2", 'Y', sg*35*thumb); add(P, f"{side}HandThumb3", 'Y', sg*30*thumb)
LEGS = {"Hips": {'loc': (0, 0, -0.012)}, "LeftUpLeg": {'X': -4, 'Y': 3}, "RightUpLeg": {'X': 5, 'Y': -3},
        "LeftLeg": {'X': 8}, "RightLeg": {'X': 6}, "LeftFoot": {'X': -4}, "RightFoot": {'X': -5}}
# ---- named poses after the video references (_work/ref): every value is interpolated between keyframes
V = Vector
POSES = {
    # ref 3/4: bow held across the belly with both fists, string toward her
    "READY": dict(tw=-8, head=6, lean=3, WL=V((0.045, -0.143, 0.536)), dL=V((-0.1, -0.6, -0.8)), kL=V((-1, 0, 0)), pL=V((0.8, 0.4, -0.5)),
                  WR=V((-0.07, -0.140, 0.536)), dR=V((0.1, -0.6, -0.8)), kR=V((1, 0, 0)), pR=V((-0.8, 0.4, -0.5)), hook=0.0, rfist=1.0),
    # ref 1, beat 2: bow raised upright toward the target, right fingers on the string
    "RAISE": dict(tw=-45, head=20, lean=0, WL=V((0.05, -0.37, 0.77)), dL=V((-0.05, -1, 0.1)), kL=V((0, 0, 1)), pL=V((0.6, 0.2, -0.8)),
                  WR=V((0.02, -0.30, 0.78)), dR=V((0.2, -1, 0.0)), kR=V((0, 0, 1)), pR=V((-0.8, 0.3, -0.5)), hook=1.0, rfist=0.0),
    # ref 1, full draw: side-on, bow arm to the target, string to the right cheek, elbow high
    "FULL": dict(tw=-75, head=42, lean=-2, WL=V((0.03, -0.405, 0.785)), dL=V((-0.03, -1, 0.08)), kL=V((0, 0, 1)), pL=V((0.6, 0.2, -0.8)),
                 WR=V((0.0, -0.10, 0.84)), dR=V((0.25, -0.95, 0.05)), kR=V((0, 0, 1)), pR=V((-0.6, 0.7, 0.45)), hook=1.0, rfist=0.0),
    # ref 1, release: string hand flies back past the ear, fingers open
    "SHOT": dict(tw=-75, head=42, lean=-3, WL=V((0.03, -0.395, 0.79)), dL=V((-0.03, -1, 0.1)), kL=V((0, 0, 1)), pL=V((0.6, 0.2, -0.8)),
                 WR=V((-0.07, -0.02, 0.87)), dR=V((0.1, -0.6, 0.6)), kR=V((0, 0, 1)), pR=V((-0.6, 0.7, 0.45)), hook=0.0, rfist=0.0),
    # ref 2: walking carry, bow along the left leg (only the left arm is used by the game)
    "CARRY": dict(tw=0, head=0, lean=0, WL=V((0.262, -0.045, 0.505)), dL=V((0.0, -1, -0.3)), kL=V((-0.12, 0.25, 1)), pL=V((0.6, 0.5, -0.3)),
                  WR=V((-0.27, -0.01, 0.50)), dR=V((0.05, -0.4, -1)), kR=V((-0.2, -1, 0)), pR=V((-0.8, 0.3, -0.5)), hook=0.0, rfist=0.3),
}
def _mix(A, B, t):
    out = {}
    for k in A:
        a, b = A[k], B[k]
        out[k] = a.lerp(b, t) if isinstance(a, Vector) else a*(1-t)+b*t
    return out
def bow_pose2(Q, breath=0.0):
    P = json.loads(json.dumps(LEGS))
    tw = Q["tw"]
    add(P, "Spine", 'Z', tw*0.25); add(P, "Spine1", 'Z', tw*0.35); add(P, "Spine2", 'Z', tw*0.40)
    add(P, "Spine1", 'X', 1.0*breath+Q["lean"]); add(P, "Spine2", 'X', -0.6*breath)
    add(P, "Neck", 'Z', Q["head"]*0.45); add(P, "Head", 'Z', Q["head"]*0.55)
    add(P, "Head", 'X', -2-1.0*breath*0.5)
    sec_motion(P, breath*0.25, amp=0.4)
    fingers(P, "Left", GRIP, thumb=1.0)
    hk = Q["hook"]; rf = Q["rfist"]
    curl = {j: 8+(HOOK[j]-8)*hk+(GRIP[j]-8)*rf for j in HOOK}
    fingers(P, "Right", curl, thumb=0.6*hk+rf, little_extra=35*hk)
    apply_pose(P); _upd()
    br = Vector((0, 0, 0.003*breath))
    _ik("Left", Q["WL"]+br, Q["pL"], Q["dL"])
    _set_frame(pose[FN("LeftHand")], HAND_REST["Left"], _knuckles("Left"), Q["dL"], Q["kL"])
    _ik("Right", Q["WR"]+br, Q["pR"], Q["dR"])
    _set_frame(pose[FN("RightHand")], HAND_REST["Right"], _knuckles("Right"), Q["dR"], Q["kR"])
def bow_clip2(name, keys, length, loop=False):
    """keys: [(frame, pose name)], smooth interpolation between named poses."""
    new_action(name)
    for f in range(0, length+1):
        for i in range(len(keys)-1):
            if keys[i][0] <= f <= keys[i+1][0]: break
        fa, A = keys[i]; fb, B = keys[i+1]
        t = smooth((f-fa)/max(fb-fa, 1))
        Q = _mix(POSES[A], POSES[B], t)
        bow_pose2(Q, math.sin(2*math.pi*f/length) if loop else 0.0); key_all(f)
    CLIPS[name] = dict(frames=length, loop=loop)
# ref 1 timing (24 fps video, 4 s): raise ~0.5 s, draw ~0.4 s, hold, release, follow-through
bow_clip2("Bow_Draw", [(0, "READY"), (12, "RAISE"), (24, "FULL")], 24)
bow_clip2("Bow_Aim", [(0, "FULL"), (40, "FULL")], 40, loop=True)
bow_clip2("Bow_Shoot", [(0, "FULL"), (2, "SHOT"), (12, "SHOT"), (30, "READY")], 30)
bow_clip2("Bow_Quick", [(0, "READY"), (7, "RAISE"), (13, "FULL"), (16, "FULL"), (18, "SHOT"), (26, "SHOT"), (40, "READY")], 40)
bow_clip2("Pose_Ready", [(0, "READY"), (40, "READY")], 40, loop=True)
bow_clip2("Pose_Carry", [(0, "CARRY"), (2, "CARRY")], 2)
new_action("Fist")
for f in range(0, 21):
    t = smooth(min(1.0, f/10)) if f <= 10 else smooth((20-f)/10)
    P = {}
    fingers(P, "Left", {k: v*t for k, v in GRIP.items()}, thumb=t)
    fingers(P, "Right", {k: v*t for k, v in GRIP.items()}, thumb=t)
    apply_pose(P); key_all(f)
CLIPS["Fist"] = dict(frames=20, loop=False)
