# Skeleton definition for Neris (metres, Blender Z-up, character faces -Y, her left = +X).
# Coordinates are in the ORIGINAL (pre-recentre) space measured from mesh slices; X_C is the body midline there.
X_C=-0.037
def M(xr,y,z): return (X_C+xr, y, z)
HUM=[ # name, head, tail, parent, deform
 ("Hips",        M(0,-0.100,0.450), M(0,-0.105,0.520), None, True),
 ("Spine",       M(0,-0.105,0.520), M(0,-0.105,0.585), "Hips", True),
 ("Spine1",      M(0,-0.105,0.585), M(0,-0.098,0.650), "Spine", True),
 ("Spine2",      M(0,-0.098,0.650), M(0,-0.075,0.740), "Spine1", True),
 ("Neck",        M(0,-0.075,0.740), M(0,-0.062,0.810), "Spine2", True),
 ("Head",        M(0,-0.062,0.810), M(0,-0.050,1.250), "Neck", True),
 ("HeadTop_End", M(0,-0.050,1.250), M(0,-0.050,1.320), "Head", False),
]
for s,sg in (("Left",1),("Right",-1)):
    HUM+=[
 (s+"Shoulder",  M(sg*0.025,-0.085,0.710), M(sg*0.120,-0.090,0.685), "Spine2", True),
 (s+"Arm",       M(sg*0.120,-0.090,0.685), M(sg*0.190,-0.085,0.575), s+"Shoulder", True),
 (s+"ForeArm",   M(sg*0.190,-0.085,0.575), M(sg*0.265,-0.120,0.470), s+"Arm", True),
 (s+"Hand",      M(sg*0.265,-0.120,0.470), M(sg*0.330,-0.148,0.395), s+"ForeArm", True),
 (s+"UpLeg",     M(sg*0.070,-0.120,0.430), M(sg*0.123,-0.110,0.240), "Hips", True),
 (s+"Leg",       M(sg*0.123,-0.110,0.240), M(sg*0.147,-0.075,0.095), s+"UpLeg", True),
 (s+"Foot",      M(sg*0.147,-0.075,0.095), M(sg*0.170,-0.130,0.030), s+"Leg", True),
 (s+"ToeBase",   M(sg*0.170,-0.130,0.030), M(sg*0.190,-0.185,0.022), s+"Foot", True),
 (s+"Toe_End",   M(sg*0.190,-0.185,0.022), M(sg*0.198,-0.215,0.022), s+"ToeBase", False),
    ]
def chain(name, pts, parent):
    out=[]; p=parent
    for i in range(len(pts)-1):
        n=f"{name}_{i+1:02d}"; out.append((n, pts[i], pts[i+1], p, True)); p=n
    return out
SEC=[]
SEC+=chain("Tail", [(0.105,0.323,0.48),(0.155,0.313,0.38),(0.205,0.298,0.29),(0.29,0.25,0.195),(0.40,0.185,0.18),(0.49,0.125,0.25),(0.505,0.115,0.36),(0.50,0.115,0.43)], "Hips")
SEC+=chain("Hair_Back_C", [M(0,0.25,0.97),M(0,0.30,0.78),M(0,0.31,0.60),M(0,0.28,0.43),M(0,0.22,0.29)], "Head")
for s,sg in (("L",1),("R",-1)):
    SEC+=chain(f"Hair_Back_{s}", [M(sg*0.17,0.22,0.96),M(sg*0.24,0.26,0.78),M(sg*0.27,0.25,0.59),M(sg*0.28,0.20,0.43),M(sg*0.28,0.15,0.31)], "Head")
    SEC+=chain(f"Hair_Side_{s}", [M(sg*0.27,0.04,0.96),M(sg*0.38,0.04,0.78),M(sg*0.43,0.05,0.60),M(sg*0.46,0.06,0.42)], "Head")
    SEC+=chain(f"Hair_Lock_{s}", [M(sg*0.22,-0.05,0.90),M(sg*0.28,-0.045,0.74),M(sg*0.30,-0.035,0.58),M(sg*0.32,-0.02,0.45)], "Head")
    SEC+=chain(f"Skirt_{s}", [M(sg*0.10,-0.08,0.44),M(sg*0.20,-0.07,0.30),M(sg*0.27,-0.065,0.16),M(sg*0.29,-0.065,0.09)], "Hips")
SEC+=chain("Skirt_F", [M(0,-0.18,0.44),M(0,-0.20,0.28),M(0,-0.20,0.12)], "Hips")
SEC+=chain("Skirt_B", [M(0,0.00,0.44),M(0,0.05,0.28),M(0,0.07,0.12)], "Hips")
PREFIX="mixamorig:"
def full_name(n):
    return PREFIX+n if any(n==h[0] for h in HUM) else n
# allowed-influence radius per bone (m) for the weight clean-up
def radius(n):
    b=n.replace(PREFIX,"")
    table={"Hips":0.17,"Spine":0.16,"Spine1":0.17,"Spine2":0.18,"Neck":0.09,"Head":0.42}
    if b in table: return table[b]
    for k,r in (("Shoulder",0.09),("ForeArm",0.16),("Arm",0.10),("Hand",0.12),("UpLeg",0.09),("Leg",0.075),("Foot",0.075),("ToeBase",0.055)):
        if b.endswith(k): return r
    if b.startswith("Tail_"):
        return 0.04 if int(b[-2:])<=4 else 0.065
    if b.startswith("Hair"): return 0.20
    if b.startswith("Skirt"): return 0.11
    return 0.1
