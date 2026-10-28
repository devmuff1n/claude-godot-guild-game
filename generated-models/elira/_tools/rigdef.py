# Skeleton definition for Elira (metres, Blender Z-up, faces -Y, her left = +X).
# Coordinates are in the recentred s2 space (feet midpoint at origin), read from grid renders.
X_C = 0.0
def M(xr, y, z): return (X_C+xr, y, z)
HUM = [  # name, head, tail, parent, deform
 ("Hips",        M(0, -0.010, 0.430), M(0, -0.015, 0.500), None, True),
 ("Spine",       M(0, -0.015, 0.500), M(0, -0.020, 0.570), "Hips", True),
 ("Spine1",      M(0, -0.020, 0.570), M(0, -0.025, 0.650), "Spine", True),
 ("Spine2",      M(0, -0.025, 0.650), M(0, -0.025, 0.775), "Spine1", True),
 ("Neck",        M(0, -0.025, 0.775), M(0, -0.025, 0.860), "Spine2", True),
 ("Head",        M(0, -0.025, 0.860), M(0, -0.010, 1.330), "Neck", True),
 ("HeadTop_End", M(0, -0.010, 1.330), M(0, -0.010, 1.450), "Head", False),
]
for s, sg in (("Left", 1), ("Right", -1)):
    HUM += [
 (s+"Shoulder",  M(sg*0.030, -0.020, 0.755), M(sg*0.140, -0.005, 0.740), "Spine2", True),
 (s+"Arm",       M(sg*0.140, -0.005, 0.740), M(sg*0.235,  0.025, 0.615), s+"Shoulder", True),
 (s+"ForeArm",   M(sg*0.235,  0.025, 0.615), M(sg*0.285,  0.005, 0.500), s+"Arm", True),
 (s+"Hand",      M(sg*0.285,  0.005, 0.500), M(sg*0.310, -0.040, 0.405), s+"ForeArm", True),
 (s+"UpLeg",     M(sg*0.080, -0.010, 0.420), M(sg*0.125, -0.005, 0.265), "Hips", True),
 (s+"Leg",       M(sg*0.125, -0.005, 0.265), M(sg*0.170,  0.010, 0.095), s+"UpLeg", True),
 (s+"Foot",      M(sg*0.170,  0.010, 0.095), M(sg*0.175, -0.065, 0.030), s+"Leg", True),
 (s+"ToeBase",   M(sg*0.175, -0.065, 0.030), M(sg*0.178, -0.110, 0.022), s+"Foot", True),
 (s+"Toe_End",   M(sg*0.178, -0.110, 0.022), M(sg*0.178, -0.135, 0.022), s+"ToeBase", False),
    ]
# Fingers: knuckle -> tip lines measured on the re-meshed hands (_work/fingers/fingers.json), 3 bones each.
import json as _json, os as _os
_F = _json.load(open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", "_work", "fingers", "fingers.json")))
def _lerp(a, b, t): return tuple(a[i]+(b[i]-a[i])*t for i in range(3))
for s, sg in (("Left", 1), ("Right", -1)):
    F = _F[s]
    for fn, mx in (("Index", "Index"), ("Middle", "Middle"), ("Ring", "Ring"), ("Little", "Pinky")):
        m = F[fn]["mcp"]; t = F[fn]["tip"]
        m = (sg*m[0], m[1], m[2]); t = (sg*t[0], t[1], t[2])
        p1 = _lerp(m, t, 0.44); p2 = _lerp(m, t, 0.74); end = _lerp(m, t, 1.08)
        n = s+"Hand"+mx
        HUM += [(n+"1", m, p1, s+"Hand", True), (n+"2", p1, p2, n+"1", True), (n+"3", p2, t, n+"2", True), (n+"4", t, end, n+"3", False)]
    T = F["Thumb"]; top = T["top"]; tip = T["tip"]
    top = (sg*top[0], top[1], top[2]); tip = (sg*tip[0], tip[1], tip[2])
    cmc = (sg*0.282, -0.058, 0.468)
    d = [top[i]-tip[i] for i in range(3)]; L = sum(x*x for x in d)**0.5; d = [x/L for x in d]
    mcp = tuple(top[i]+d[i]*0.012 for i in range(3)); mid = _lerp(mcp, tip, 0.5); end = _lerp(mcp, tip, 1.15)
    n = s+"HandThumb"
    HUM += [(n+"1", cmc, mcp, s+"Hand", True), (n+"2", mcp, mid, n+"1", True), (n+"3", mid, tip, n+"2", True), (n+"4", tip, end, n+"3", False)]
def chain(name, pts, parent):
    out = []; p = parent
    for i in range(len(pts)-1):
        n = f"{name}_{i+1:02d}"; out.append((n, pts[i], pts[i+1], p, True)); p = n
    return out
SEC = []
# braid over her left shoulder, from under the hair mass down past the left elbow
SEC += chain("Braid", [M(0.150, 0.080, 0.950), M(0.200, 0.080, 0.830), M(0.240, 0.085, 0.725),
                       M(0.280, 0.110, 0.625), M(0.310, 0.135, 0.535), M(0.330, 0.150, 0.455)], "Head")
# short capelet: back + two shoulder flaps
SEC += chain("Cape_B", [M(0, 0.090, 0.820), M(0, 0.140, 0.725), M(0, 0.165, 0.640)], "Spine2")
for s, sg in (("L", 1), ("R", -1)):
    SEC += chain(f"Cape_{s}", [M(sg*0.110, 0.040, 0.820), M(sg*0.200, 0.080, 0.730), M(sg*0.245, 0.100, 0.665)], "Spine2")
    SEC += chain(f"Skirt_F{s}", [M(sg*0.090, -0.100, 0.545), M(sg*0.140, -0.120, 0.450), M(sg*0.165, -0.125, 0.370)], "Hips")
    SEC += chain(f"Skirt_{s}", [M(sg*0.185, 0.000, 0.540), M(sg*0.235, 0.015, 0.445), M(sg*0.260, 0.025, 0.375)], "Hips")
SEC += chain("Skirt_B", [M(0, 0.095, 0.530), M(0, 0.135, 0.420), M(0, 0.150, 0.320)], "Hips")
PREFIX = "mixamorig:"
def full_name(n):
    return PREFIX+n if any(n == h[0] for h in HUM) else n
# allowed-influence radius per bone (m) for the weight clean-up
def radius(n):
    b = n.replace(PREFIX, "")
    table = {"Hips": 0.17, "Spine": 0.16, "Spine1": 0.17, "Spine2": 0.19, "Neck": 0.09, "Head": 0.22}
    if b in table: return table[b]
    if "HandThumb" in b: return 0.018
    if any(k in b for k in ("HandIndex", "HandMiddle", "HandRing", "HandPinky")): return 0.0135
    for k, r in (("Shoulder", 0.09), ("ForeArm", 0.10), ("Arm", 0.10), ("Hand", 0.10), ("UpLeg", 0.10),
                 ("Leg", 0.085), ("Foot", 0.08), ("ToeBase", 0.06)):
        if b.endswith(k): return r
    if b.startswith("Braid"): return 0.08
    if b.startswith("Cape"): return 0.11
    if b.startswith("Skirt"): return 0.10
    return 0.1
