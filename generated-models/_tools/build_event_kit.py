"""Route-event dioramas for The Kingdom's Poorest Guild (Blender, procedural).

Extends build_environment_kit.py (same primitives, materials and pipeline).
Usage inside Blender:
    ns = {}; exec(open(r"...\\generated-models\\_tools\\build_event_kit.py", encoding="utf-8").read(), ns)
    ns["run"](["ev01_spring"])

Conventions: Z-up, 1 unit = 1 m, front = -Y (the road / camera side), origin = road edge point
in front of the scene. Common props go to assets/models/events/common/, dioramas to
assets/models/events/dioramas/.
"""
import os, math, random
from mathutils import Vector, Matrix, Euler

_PROJECT = os.environ.get("POOREST_GUILD", r"C:\Users\armor\Documents\poorest_guild")
exec(open(os.path.join(_PROJECT, "generated-models", "_tools", "build_environment_kit.py"), encoding="utf-8").read(), globals())

# exported GLBs: assets/models/<CATEGORY>/<id>.glb
GLB_ROOT = os.path.join(PROJECT, "assets", "models")
for _k in list(CATEGORY):
    if not CATEGORY[_k].startswith("environment"):
        CATEGORY[_k] = "environment/" + CATEGORY[_k]

EV_COMMON = ["ev_peasant", "ev_old_tree", "ev_crate", "ev_barrel", "ev_sack", "ev_cart"]
EV_SCENES = ["ev01_spring", "ev02_peddler", "ev03_toll", "ev04_smithy", "ev05_captive", "ev06_cage", "ev07_barn",
             "ev08_tower", "ev09_cache", "ev10_turncoat", "ev11_idol", "ev12_corpse", "ev13_chapel", "ev14_dice",
             "ev15_hive", "ev16_ditch"]
for _k in EV_COMMON:
    CATEGORY[_k] = "events/common"
for _k in EV_SCENES:
    CATEGORY[_k] = "events/dioramas"
EV_IDS = EV_COMMON + EV_SCENES

SPEC.update({
    "ev_peasant": (0.62, 0.55, 1.3), "ev_old_tree": (6.0, 5.5, 7.2), "ev_crate": (0.7, 0.7, 0.7),
    "ev_barrel": (0.62, 0.62, 0.8), "ev_sack": (0.5, 0.45, 0.6),
    "ev01_spring": (6.5, 8.0, 7.5), "ev02_peddler": (6.5, 6.5, 7.5), "ev03_toll": (5.0, 3.6, 3.6),
    "ev_cart": (1.3, 3.2, 1.3),
    "ev04_smithy": (6.5, 6.0, 5.0), "ev05_captive": (6.5, 6.0, 7.0), "ev06_cage": (6.5, 6.0, 5.0),
    "ev07_barn": (7.0, 7.0, 6.0), "ev08_tower": (6.5, 6.0, 8.0), "ev09_cache": (6.5, 6.0, 6.0),
    "ev10_turncoat": (6.0, 5.0, 4.0), "ev11_idol": (6.5, 6.0, 5.0), "ev12_corpse": (6.5, 6.0, 7.0),
    "ev13_chapel": (6.5, 6.5, 6.0), "ev14_dice": (6.5, 6.0, 5.0), "ev15_hive": (6.5, 6.0, 7.0),
    "ev16_ditch": (6.5, 6.0, 6.0),
})

for _n, _r in (("cloth_cream", .9), ("cloth_brown", .9), ("cloth_green", .9), ("cloth_red", .9), ("cloth_blue", .85),
               ("cloth_purple", .9), ("bandage", .9), ("burlap", .95), ("skin", .7), ("leather_dark", .7), ("bone", .7),
               ("bread", .8), ("smoke", 1.0), ("mud_dark", .95), ("cork", .9), ("eye", .3), ("eye_white", .3),
               ("wound", .8), ("hair_blond", .8), ("hair_dark", .8), ("hair_brown", .8)):
    MATS[_n] = (_n, _r, 0, 0.5, False, None)
MATS["roof_blue"] = ("roof_blue", .8, 0, 1.0, False, None)
MATS["glass_blue"] = ("glass_blue", .15, 0, 0.3, False, None)
MATS["glass_green"] = ("glass_green", .15, 0, 0.3, False, None)
MATS["glass_red"] = ("glass_red", .15, 0, 0.3, False, None)
MATS["lantern_glow"] = ("lantern_glow", .5, 0, 0.3, False, None)
MATS["pennant"] = ("cloth_blue", .9, 0, 0.6, True, None)
MATS["water_fall"] = ("water", .08, 0, 1.0, True, 0.75)
for _n, _r in (("honey", .35), ("gold", .3), ("copper", .4), ("apple", .5), ("fur_dark", .9), ("fur_white", .9),
               ("coal_glow", .8), ("fire", .8), ("feather", .8), ("pink", .7), ("horn", .6), ("cloth_orange", .9),
               ("cloth_grey", .9), ("cloth_white", .9), ("cloth_tent", .9), ("cow_hide", .85), ("chainmail", .5),
               ("skin_dark", .7)):
    MATS[_n] = (_n, _r, 0, 0.5, False, None)
MATS["roof_slate"] = ("roof_slate", .8, 0, 1.0, False, None)
MATS["thatch"] = ("thatch", .95, 0, 1.0, False, None)
MATS["honeycomb"] = ("honeycomb", .5, 0, 0.25, False, None)
EMISSIVE = {"lantern_glow": 3.0, "fire": 1.6, "coal_glow": 1.5}

_base_get_mat = get_mat


def get_mat(name):
    fresh = bpy.data.materials.get("env_" + name) is None
    m = _base_get_mat(name)
    if fresh and name in EMISSIVE:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        tex = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
        key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs[key])
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = EMISSIVE[name]
    return m


# ============================================================================= helpers
def W(at=(0, 0, 0), yaw=0.0, s=1.0):
    return Matrix.Translation(Vector(at)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((s, s, s, 1))


def T(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def R(rx=0, ry=0, rz=0):
    return Euler((rx, ry, rz)).to_matrix().to_4x4()


def S(x, y=None, z=None):
    return Matrix.Diagonal((x, x if y is None else y, x if z is None else z, 1))


def blob(r, sx=1, sy=1, sz=1, amp=0.0, freq=2.5, seed=0, subdiv=2):
    bm = prim_ico(1.0, subdiv)
    if amp:
        lumpy(bm, amp, freq, seed)
    bm.transform(S(r * sx, r * sy, r * sz))
    return bm


def seg_tube(a, b, ra, rb, segs=8, **kw):
    return prim_tube([a, b], [ra, rb], segs=segs, **kw)


def rock(part, rng, M, r=0.45, moss=True, flat=0.7, mat="stone_grey"):
    seed = rng.random() * 50
    bm = blob(r, 1.0, 0.85, flat, amp=0.18, freq=2.2, seed=seed)
    part.add(bm, mat, matrix=M @ T(0, 0, r * flat * 0.55), uv="world", smooth=True)
    if moss:
        mb = blob(r * 0.86, 1.0, 0.8, flat * 0.55, amp=0.2, freq=2.6, seed=seed + 3)
        part.add(mb, "moss", matrix=M @ T(0, 0, r * flat * 0.55 + r * flat * 0.5), uv="world", smooth=True)


def ground_patch(part, M, rx, ry, mat="soil", seed=0, z=0.012):
    """Flat irregular decal disc lying on the ground."""
    bm = _new()
    n = 18
    c = bm.verts.new((0, 0, z))
    ring = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + 0.18 * noise.noise(Vector((math.cos(a) * 1.3 + seed, math.sin(a) * 1.3, seed)))
        ring.append(bm.verts.new((math.cos(a) * rx * k, math.sin(a) * ry * k, z)))
    for i in range(n):
        bm.faces.new((c, ring[i], ring[(i + 1) % n]))
    part.add(bm, mat, matrix=M, uv="world")


def footpath(part, pts, width=0.9, mat="dirt", seed=0, z=0.01):
    """Ribbon decal through (x, y) points with wobbly edges."""
    bm = _new()
    P = [Vector((p[0], p[1], z)) for p in pts]
    rows = []
    for i, p in enumerate(P):
        a = P[max(i - 1, 0)]; b = P[min(i + 1, len(P) - 1)]
        d = (b - a).normalized(); nrm = Vector((-d.y, d.x, 0))
        w = width * (0.5 + 0.12 * noise.noise(Vector((i * 0.7 + seed, seed, 0))))
        w2 = width * (0.5 + 0.12 * noise.noise(Vector((i * 0.7 + seed, seed + 5, 0))))
        rows.append((bm.verts.new(p + nrm * w), bm.verts.new(p), bm.verts.new(p - nrm * w2)))
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        for k in range(2):
            bm.faces.new((A[k], A[k + 1], B[k + 1], B[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    part.add(bm, mat, uv="world")


def plants(part, rng, spots, ferns=True):
    for (x, y, s) in spots:
        if ferns and rng.random() < 0.6:
            add_fern(part, rng, Vector((x, y, 0)), s=s, fronds=rng.randint(6, 9))
        else:
            add_tuft(part, rng, Vector((x, y, 0)), s=s, blades=rng.randint(8, 12))


# ============================================================================= common props
def crate(part, M, sz=0.62):
    h = sz / 2
    part.add(prim_box(sz * .94, sz * .94, sz * .94, bevel=.01), "wood_light", matrix=M @ T(0, 0, h), uv="box", long_axis=0)
    b = sz * 0.12
    for sx in (-1, 1):  # vertical corner posts
        for sy in (-1, 1):
            part.add(prim_box(b, b, sz, bevel=.01), "wood_mid", matrix=M @ T(sx * (h - b / 2 + .01), sy * (h - b / 2 + .01), h), uv="box", long_axis=2)
    for z in (b / 2, sz - b / 2):  # top/bottom rims
        for sy in (-1, 1):
            part.add(prim_box(sz, b * .8, b, bevel=.008), "wood_mid", matrix=M @ T(0, sy * (h - b * .3), z), uv="box", long_axis=0)
        for sx in (-1, 1):
            part.add(prim_box(b * .8, sz, b, bevel=.008), "wood_mid", matrix=M @ T(sx * (h - b * .3), 0, z), uv="box", long_axis=1)
    L = math.hypot(sz - 2 * b, sz - 2 * b)
    for (yy, ry) in ((-h - .005, 1), (h + .005, -1)):  # diagonal braces front/back
        part.add(prim_box(L, b * .6, b * .8, bevel=.006), "wood_mid", matrix=M @ T(0, yy, h) @ R(0, ry * math.pi / 4, 0), uv="box", long_axis=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (b / 2, sz - b / 2):
                part.add(prim_box(.035, .035, .035), "iron", matrix=M @ T(sx * (h + .005), sy * (h + .005), z))


def barrel(part, M, h=0.78, r=0.29):
    prof = [(r * .82, 0), (r * .93, h * .2), (r, h * .5), (r * .93, h * .8), (r * .82, h)]
    part.add(prim_lathe(prof, segs=16, uvscale=.6), "wood_mid", matrix=M, smooth=True)
    lid = prim_cyl(r * .78, r * .78, .02, segs=16, z0=h - .04)
    part.add(lid, "wood_dark", matrix=M, uv="box")
    for z, rr in ((h * .22, .955), (h * .78, .955)):
        part.add(prim_torus(r * rr + .008, .014, segs=16, rsegs=4), "iron", matrix=M @ T(0, 0, z) @ S(1, 1, 2.6))


def sack(part, M, s=1.0, seed=0, mat="burlap"):
    bm = blob(0.24 * s, 1.0, 0.9, 1.05, amp=.05, freq=3, seed=seed)
    for v in bm.verts:  # pear shape: wide bottom, narrow top
        t = (v.co.z / (0.24 * s * 1.05) + 1) / 2
        k = 1.12 - 0.45 * t * t
        v.co.x *= k; v.co.y *= k
        if v.co.z < -0.17 * s:
            v.co.z = -0.17 * s - (v.co.z + 0.17 * s) * 0.15
    part.add(bm, mat, matrix=M @ T(0, 0, .19 * s), uv="world", smooth=True)
    part.add(prim_torus(.07 * s, .018 * s, segs=10, rsegs=4), "rope", matrix=M @ T(0, 0, .43 * s))
    neck = blob(.085 * s, 1, 1, .9, amp=.25, freq=6, seed=seed + 2, subdiv=1)
    part.add(neck, mat, matrix=M @ T(0, 0, .5 * s), uv="world", smooth=True)


def bottle(part, M, mat, h=0.22, r=0.07):
    prof = [(r * .7, 0), (r, h * .08), (r, h * .55), (r * .45, h * .72), (r * .3, h * .8), (r * .3, h * .9)]
    part.add(prim_lathe(prof, segs=10, uvscale=.3), mat, matrix=M, smooth=True)
    part.add(prim_cyl(r * .33, r * .3, h * .14, segs=8, z0=h * .88), "cork", matrix=M)


def old_tree(bark, leaves, rng, M, claw=False, crown=1.0):
    """Huge old broadleaf tree with flaring roots (≈6 m tall). Pivot = trunk base."""
    seed = rng.random() * 10
    bark.add(prim_tube([(0, 0, -0.1), (0.08, 0, 1.0), (-0.05, 0.05, 2.0), (0.02, 0, 3.0)], [1.25, 0.82, 0.66, 0.58],
                       segs=14, caps=(True, False), rough=.22, seed=seed, uvscale=1.6), "bark_oak", matrix=M, smooth=True)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-.25, .25)
        d = Vector((math.cos(a), math.sin(a), 0))
        L = rng.uniform(1.7, 2.2)
        bark.add(prim_tube([d * .55 + Vector((0, 0, .85)), d * 1.05 + Vector((0, 0, .32)), d * L * .78 + Vector((0, 0, .08)),
                            d * L + Vector((0, 0, -.03))], [.42, .3, .15, .02], segs=8, rough=.15, seed=k, uvscale=1.2, flat_y=.75),
                 "bark_oak", matrix=M, smooth=True)
    fork = Vector((0.02, 0, 2.9))
    tips = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4 + rng.uniform(-.2, .2)
        d = Vector((math.cos(a), math.sin(a), 0))
        mid = fork + d * 1.3 + Vector((0, 0, 1.2))
        bark.add(prim_tube([fork, fork.lerp(mid, .5) + Vector((0, 0, -.15)), mid], [.42, .3, .2], segs=9, rough=.1, uvscale=1.2),
                 "bark_oak", matrix=M, smooth=True)
        tip = mid + d * 0.9 + Vector((0, 0, .6))
        bark.add(prim_tube([mid, tip], [.2, .08], segs=7), "bark_oak", matrix=M, smooth=True)
        tips.append(tip)
    if claw:  # three diagonal gashes facing the road
        for i in range(3):
            g = prim_box(0.08, 0.3, 0.75, bevel=.02)
            for v in g.verts:  # pointed ends
                t = abs(v.co.z) / 0.375
                v.co.x *= max(0.15, 1 - t * t)
            bark.add(g, "wound", matrix=M @ T(-0.2 + i * 0.17, -0.74, 1.6 - i * 0.05) @ R(0, -0.45, 0))
    centers = [(t + Vector((0, 0, .2)), rng.uniform(1.0, 1.25)) for t in tips]
    centers += [(Vector((0, 0, 6.0)), 1.35), (Vector((.4, -.6, 5.2)), 1.0), (Vector((-.6, .5, 5.4)), 1.0)]
    for i, (c, r) in enumerate(centers):
        r *= crown
        bm = blob(1.0, amp=.12, freq=2.8, seed=i * 1.7 + seed)
        bm.transform(S(r * .8, r * .8, r * .62))
        leaves.add(bm, "leaves_oak", matrix=M @ T(*c), uv="world", smooth=True)
        for k in range(7):
            a = 2 * math.pi * k / 7 + rng.uniform(-.3, .3)
            el = rng.uniform(0.0, 0.9)
            d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * .8))
            rb = r * rng.uniform(.38, .5)
            bb = blob(rb, 1, 1, .85, amp=.1, freq=3.0, seed=i * 3.1 + k)
            leaves.add(bb, "leaves_oak", matrix=M @ T(*(c + d * r * .62)), uv="world", smooth=True)


# ----------------------------------------------------------------------------- chibi people
LOOKS = {
    "peasant": dict(shirt="cloth_cream", pants="cloth_brown", hair="hair_blond", boots="leather_dark"),
    "keeper": dict(shirt="cloth_cream", pants="cloth_brown", hair="hair_brown", boots="leather_dark", vest="cloth_green",
                   cap="cloth_green", mustache=True),
    "bandit_a": dict(shirt="cloth_brown", pants="cloth_brown", hair="hair_blond", boots="leather_dark", mask="cloth_red"),
    "bandit_b": dict(shirt="cloth_purple", pants="cloth_brown", hair="hair_dark", boots="leather_dark", mask="cloth_red"),
    "smith": dict(shirt="cloth_cream", pants="cloth_brown", hair="hair_dark", boots="leather_dark", apron="leather",
                  beard=True, sleeves_up=True, bulk=1.12),
    "driver": dict(shirt="cloth_cream", pants="cloth_brown", hair="hair_blond", boots="leather_dark", vest="cloth_brown"),
    "driver_b": dict(shirt="cloth_white", pants="cloth_grey", hair="hair_brown", boots="leather_dark"),
    "guard_bandit": dict(shirt="cloth_brown", pants="cloth_grey", hair="hair_dark", boots="leather_dark", vest="leather_dark",
                         mask="cloth_grey", headband="cloth_red"),
    "farm_woman": dict(shirt="cloth_green", pants="cloth_brown", hair="hair_brown", boots="leather_dark", skirt="cloth_green",
                       apron="cloth_white", scarf="cloth_white"),
    "caretaker": dict(shirt="cloth_tent", pants="cloth_brown", hair="fur_white", boots="leather_dark", skirt="cloth_tent",
                      apron="cloth_white", bun=True, hair_style="short"),
    "guard": dict(shirt="cloth_white", pants="cloth_brown", hair="hair_brown", boots="leather_dark", vest="leather",
                  cap="leather", cloak="cloth_green"),
    "guard_b": dict(shirt="cloth_white", pants="cloth_brown", hair="hair_blond", boots="leather_dark", vest="leather",
                    cloak="cloth_green"),
    "guard_c": dict(shirt="cloth_white", pants="cloth_brown", hair="hair_dark", boots="leather_dark", vest="leather",
                    cloak="cloth_green", skin="skin_dark"),
    "turncoat": dict(shirt="cloth_cream", pants="cloth_brown", hair="hair_blond", boots="leather_dark", bandana="cloth_red",
                     patches="cloth_brown", back_sack=True),
    "mercenary": dict(shirt="chainmail", pants="cloth_brown", hair="hair_dark", boots="leather_dark", helmet="steel",
                      cloak="cloth_blue", vest="chainmail"),
}

_STAND = [(0, 0, .42), (0, -.01, .25), (0, 0, .11)]
POSES = {
    #  drop / tilt move the upper body; legs = hip, knee, ankle; arms = shoulder, elbow, hand (left; right mirrors if None)
    "stand": dict(drop=0, tilt=0, legs=_STAND, foot=(0, -1, 0),
                  arm_l=[(-.15, 0, .68), (-.22, .01, .56), (-.26, -.02, .44)], arm_r=None),
    "sit": dict(drop=-.3, tilt=-.18, legs=[(0, -.02, .14), (0, -.24, .24), (0, -.42, .1)], foot=(0, -.4, 1),
                arm_l=[(-.15, 0, .68), (-.26, -.12, .62), (-.15, -.22, .87)],
                arm_r=[(.15, 0, .68), (.22, -.12, .5), (.18, -.32, .44)]),
    "offer": dict(drop=0, tilt=0, legs=_STAND, foot=(0, -1, 0),
                  arm_l=[(-.15, 0, .68), (-.22, .01, .56), (-.2, -.08, .47)],
                  arm_r=[(.15, 0, .68), (.24, -.12, .58), (.27, -.3, .62)]),
    "peek": dict(drop=0, tilt=.12, legs=_STAND, foot=(0, -1, 0),
                 arm_l=[(-.15, 0, .68), (-.23, -.1, .62), (-.22, -.22, .72)],
                 arm_r=[(.15, 0, .68), (.22, -.06, .56), (.24, -.1, .46)]),
    "hammer": dict(drop=0, tilt=.1, legs=[(0, .02, .42), (0, -.03, .25), (0, 0, .11)], foot=(0, -1, 0),
                   arm_l=[(-.15, 0, .68), (-.18, -.2, .58), (-.08, -.36, .52)],
                   arm_r=[(.15, 0, .68), (.27, -.04, .84), (.22, -.12, 1.02)]),
    "tied": dict(drop=0, tilt=0, legs=_STAND, foot=(0, -1, 0),
                 arm_l=[(-.15, 0, .68), (-.19, .1, .55), (-.09, .17, .45)], arm_r=None),
    "hands_up": dict(drop=0, tilt=-.05, legs=[(0, 0, .42), (0, -.04, .25), (0, -.02, .11)], foot=(0, -1, 0),
                     arm_l=[(-.15, 0, .68), (-.29, -.04, .8), (-.31, -.08, 1.0)], arm_r=None),
    "cry": dict(drop=0, tilt=.08, legs=_STAND, foot=(0, -1, 0),
                arm_l=[(-.15, 0, .68), (-.22, -.15, .66), (-.12, -.24, .9)], arm_r=None),
    "sweep": dict(drop=0, tilt=.15, legs=[(0, .02, .42), (0, -.03, .25), (0, 0, .11)], foot=(0, -1, 0),
                  arm_l=[(-.15, 0, .68), (-.06, -.2, .6), (.07, -.27, .6)],
                  arm_r=[(.15, 0, .68), (.22, -.15, .52), (.15, -.28, .44)]),
    "sit_log": dict(drop=0, tilt=0, legs=[(0, -.02, .42), (0, -.27, .42), (0, -.3, .1)], foot=(0, -1, 0),
                    arm_l=[(-.15, 0, .68), (-.2, -.16, .55), (-.13, -.3, .5)],
                    arm_r=[(.15, 0, .68), (.22, -.18, .6), (.16, -.36, .62)]),
    "sit_hold": dict(drop=-.3, tilt=0, legs=[(0, -.02, .14), (0, -.2, .3), (0, -.32, .1)], foot=(0, -1, .3),
                     arm_l=[(-.15, 0, .68), (-.2, -.16, .72), (-.12, -.3, .86)], arm_r=None),
    "slump": dict(drop=-.3, tilt=-.4, legs=[(0, -.02, .14), (0, -.3, .14), (0, -.5, .1)], foot=(0, -.2, 1),
                  arm_l=[(-.15, 0, .68), (-.3, -.02, .5), (-.38, -.08, .3)], arm_r=None),
}


def chibi(parts, rng, M, look="peasant", pose="stand", bandage=False, eyes="open"):
    """Stylised chibi villager (≈1.3 m). parts: dict with Part 'body'. Returns hand matrices for props."""
    L = LOOKS[look]; P = POSES[pose]
    p = parts["body"]
    skin = L.get("skin", "skin")
    seed = rng.random() * 40
    bulk = L.get("bulk", 1.0)
    M = M @ S(bulk, bulk, 1.0)
    # --- legs + boots
    for sx in (-1, 1):
        pts = [Vector((sx * .1 + a[0], a[1], a[2])) for a in P["legs"]]
        p.add(prim_tube(pts, [.078, .085, .075], segs=10), L["pants"], matrix=M, smooth=True)
        fd = Vector(P["foot"]).normalized()
        ank = pts[-1]
        boot = blob(.075, 1.0, 1.55, .8, subdiv=2)
        q = fd.to_track_quat("Y", "Z").to_matrix().to_4x4()
        p.add(boot, L["boots"], matrix=M @ Matrix.Translation(ank + fd * .05 + Vector((0, 0, -.04))) @ q, uv="world", smooth=True)
        legdir = (pts[-1] - pts[-2]).normalized()
        cq = legdir.to_track_quat("Z", "Y").to_matrix().to_4x4()
        p.add(prim_torus(.08, .025, segs=12, rsegs=5), L["boots"], matrix=M @ Matrix.Translation(ank - legdir * .03) @ cq, smooth=True)
        if bandage and sx == 1:
            mid = pts[1].lerp(pts[2], .5)
            dd = (pts[2] - pts[1]).normalized()
            p.add(prim_tube([mid - dd * .07, mid + dd * .07], [.092, .092], segs=10), "bandage", matrix=M, smooth=True)
        if L.get("patches") and sx == -1:
            p.add(prim_box(.07, .02, .07), L["patches"], matrix=M @ Matrix.Translation(pts[1] + Vector((0, -.08, -.02))))
    # --- upper body (dropped + tilted around the hips)
    U = M @ T(0, 0, P["drop"]) @ T(0, 0, .42) @ R(P["tilt"], 0, 0) @ T(0, 0, -.42)
    if L.get("skirt"):
        sk = prim_lathe([(.0, .12 - P["drop"] * 0), (.24, .14), (.2, .3), (.17, .46)], segs=16, uvscale=.4)
        if P["drop"] < 0:  # sitting: skirt spreads forward over the legs
            sk.transform(S(1.15, 1.6, .55))
            p.add(sk, L["skirt"], matrix=M @ T(0, -.12, .02), smooth=True)
        else:
            p.add(sk, L["skirt"], matrix=M, smooth=True)
    prof = [(.0, .36), (.175, .37), (.165, .46), (.15, .56), (.15, .64), (.12, .71), (.07, .75)]
    torso = prim_lathe(prof, segs=14, uvscale=.4, close_bottom=False)
    torso.transform(S(1, .82, 1))
    p.add(torso, L["shirt"], matrix=U, smooth=True)
    if L.get("vest"):
        vp = [(.0, .45), (.158, .45), (.155, .56), (.155, .64), (.125, .70), (.0, .70)]
        vest = prim_lathe(vp, segs=14, uvscale=.4, close_bottom=False)
        vest.transform(S(1, .84, 1))
        p.add(vest, L["vest"], matrix=U @ T(0, .006, 0) @ S(1.02, 1.02, 1), smooth=True)
    if L.get("apron"):
        ap = prim_prism_xz([(-.14, .66), (.14, .66), (.17, .2 if not L.get("skirt") else .14), (-.17, .2 if not L.get("skirt") else .14)], .02)
        p.add(ap, L["apron"], matrix=U @ T(0, -.12, 0) @ R(-.08, 0, 0), uv="box")
    if L.get("cloak"):
        ck = prim_prism_xz([(-.17, .72), (.17, .72), (.22, .3), (.1, .34), (0, .28), (-.1, .34), (-.22, .3)], .025)
        p.add(ck, L["cloak"], matrix=U @ T(0, .175, 0) @ R(.12, 0, 0), uv="box")
        p.add(prim_torus(.13, .03, segs=12, rsegs=4), L["cloak"], matrix=U @ T(0, .02, .72) @ S(1, .85, 1), smooth=True)
    if L.get("patches"):
        p.add(prim_box(.06, .02, .06), L["patches"], matrix=U @ T(-.07, -.13, .6))
        p.add(prim_box(.05, .02, .05), L["patches"], matrix=U @ T(.08, -.13, .52))
    p.add(prim_torus(.158, .025, segs=14, rsegs=5), L.get("belt", "leather_dark"), matrix=U @ T(0, 0, .46) @ S(1, .84, 1), smooth=True)
    p.add(prim_box(.05, .02, .07, bevel=.008), "brass" if look in ("guard", "guard_b", "guard_c") else "leather_dark", matrix=U @ T(.03, -.14, .44))
    p.add(prim_cyl(.05, .05, .08, segs=8, z0=.72), skin, matrix=U, smooth=True)
    if L.get("bandana"):
        p.add(prim_torus(.075, .035, segs=12, rsegs=5), L["bandana"], matrix=U @ T(0, -.01, .76), smooth=True)
        p.add(prim_prism_xz([(-.06, 0), (.06, 0), (0, -.09)], .02), L["bandana"], matrix=U @ T(0, -.075, .76) @ R(-.3, 0, 0))
    if L.get("back_sack"):
        sack(p, U @ T(0, .24, .42) @ R(.25, 0, 0) @ S(.95), seed=seed)
        for k in range(2):
            p.add(prim_tube([(-.04 + k * .07, 0, 0), (-.06 + k * .09, 0, .2)], [.035, .03], segs=8), "bread",
                  matrix=U @ T(0, .26, .82) @ R(.35, 0, 0), smooth=True)
    # --- arms
    arm_l = P["arm_l"]
    arm_r = P["arm_r"] or [(-a[0], a[1], a[2]) for a in arm_l]
    hands = []
    for arm in (arm_l, arm_r):
        a = [Vector(x) for x in arm]
        sl = skin if L.get("sleeves_up") else L["shirt"]
        p.add(prim_tube([a[0], a[1]], [.058 * (1.1 if L.get("sleeves_up") else 1), .052], segs=8), L["shirt"] if not L.get("sleeves_up") else L["shirt"], matrix=U, smooth=True)
        p.add(prim_tube([a[1], a[1].lerp(a[2], .8)], [.052, .05], segs=8), sl, matrix=U, smooth=True)
        p.add(blob(.048, 1, 1, 1.1, subdiv=1), skin, matrix=U @ Matrix.Translation(a[2]), smooth=True)
        d = (a[2] - a[1]).normalized()
        hands.append(U @ Matrix.Translation(a[2]) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4())
    # --- head
    hc = Vector((0, 0, 1.0))
    H = U @ Matrix.Translation(hc)
    p.add(blob(.245, 1.0, .95, .93), skin, matrix=H, smooth=True)
    for sx in (-1, 1):
        p.add(blob(.05, .6, .8, 1), skin, matrix=H @ T(sx * .24, .02, -.02), smooth=True)
        if L.get("helmet"):
            continue
        if eyes == "closed":  # happy / crying arcs
            p.add(prim_tube([(-.035, 0, -.01), (0, 0, .012), (.035, 0, -.01)], [.009, .011, .009], segs=5), "eye",
                  matrix=H @ T(sx * .085, -.232, -.04), smooth=True)
        else:
            p.add(blob(.042, .78, .3, 1.15, subdiv=1), "eye", matrix=H @ T(sx * .085, -.215, -.04), smooth=True)
            p.add(blob(.012, 1, .5, 1, subdiv=1), "eye_white", matrix=H @ T(sx * .085 + .012, -.228, -.015), smooth=True)
    if eyes == "closed" and not L.get("mask"):
        p.add(blob(.04, 1.2, .4, .7, subdiv=1), "wound", matrix=H @ T(0, -.228, -.13), smooth=True)  # open mouth
    if L.get("mustache"):
        for sx in (-1, 1):
            p.add(prim_tube([(sx * .01, -.23, -.08), (sx * .07, -.225, -.09), (sx * .12, -.19, -.06)], [.03, .026, .008], segs=7),
                  L["hair"], matrix=H, smooth=True)
    if L.get("beard"):
        bd = blob(.2, 1.05, .7, .7, amp=.08, freq=8, seed=seed)
        bd = bd
        cutb = [f for f in bd.faces if f.calc_center_median().y > .02]
        bmesh.ops.delete(bd, geom=cutb, context="FACES")
        p.add(bd, L["hair"], matrix=H @ T(0, -.07, -.12), uv="world", smooth=True)
    if L.get("mask"):
        mk = prim_lathe([(.252, -.17), (.257, -.12), (.256, -.06), (.24, -.03)], segs=16, uvscale=.3, close_bottom=False)
        mk.transform(S(1, .97, 1))
        p.add(mk, L["mask"], matrix=H, smooth=True)
    if L.get("helmet"):
        hm = prim_lathe([(.27, -.2), (.285, -.05), (.28, .08), (.22, .2), (.12, .27), (.0, .29)], segs=18, uvscale=.3, close_bottom=False)
        p.add(hm, L["helmet"], matrix=H, smooth=True)
        p.add(prim_box(.3, .05, .035), "eye", matrix=H @ T(0, -.27, -.02))
        p.add(prim_box(.04, .04, .3), L["helmet"], matrix=H @ T(0, -.285, .0))
        return {"U": U, "hand_l": hands[0], "hand_r": hands[1], "head": H}
    # --- hair: shell over top/back + locks
    shell = blob(.282, 1.04, 1.0, .97, amp=.05, freq=6, seed=seed)
    cut = []
    for f in shell.faces:
        c = f.calc_center_median()
        if c.y < -.05 and c.z < .07 and abs(c.x) < .2:
            cut.append(f)
        elif c.z < -.12 and c.y < .1:
            cut.append(f)
    bmesh.ops.delete(shell, geom=cut, context="FACES")
    shell.normal_update()
    p.add(shell, L["hair"], matrix=H @ T(0, .025, .035), uv="world", smooth=True)
    short = L.get("hair_style") == "short" or L.get("scarf")
    for i in range(22 if not short else 10):
        a = 2 * math.pi * i / (22 if not short else 10) + rng.uniform(-.12, .12)
        el = rng.uniform(-.25, .75) if not short else rng.uniform(-.2, .2)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        if d.y < -.35 and el < .5:
            continue
        base = hc + Vector((0, .03, .05)) + d * .21
        ln = .15 if not short else .08
        tip = base + (d * ln + Vector((0, 0, -.09))) * rng.uniform(.8, 1.2)
        p.add(prim_tube([base, base.lerp(tip, .5) + d * .02 + Vector((0, 0, .02)), tip], [.085, .06, 0], segs=6, flat_y=.5),
              L["hair"], matrix=U, smooth=True)
    for i in range(6):
        x = -.16 + i * .064
        base = hc + Vector((x * .8, -.16, .2))
        tip = hc + Vector((x * 1.2 + rng.uniform(-.025, .025), -.265, .05 + rng.uniform(-.03, .02) + (.04 if short else 0)))
        p.add(prim_tube([base, base.lerp(tip, .5) + Vector((0, -.03, .02)), tip], [.06, .045, 0], segs=6, flat_y=.55),
              L["hair"], matrix=U, smooth=True)
    if L.get("bun"):
        p.add(blob(.11, amp=.05, freq=8, seed=seed), L["hair"], matrix=H @ T(0, .12, .27), uv="world", smooth=True)
    if L.get("scarf"):
        sc = prim_lathe([(.0, .31), (.17, .28), (.27, .17), (.3, .02), (.29, -.1)], segs=18, uvscale=.3, close_bottom=False)
        cuts = [f for f in sc.faces if f.calc_center_median().y < -.12 and f.calc_center_median().z < .2]
        bmesh.ops.delete(sc, geom=cuts, context="FACES")
        p.add(sc, L["scarf"], matrix=H @ T(0, .03, 0), smooth=True)
        p.add(blob(.06, 1.2, .8, .8, subdiv=1), L["scarf"], matrix=H @ T(0, .26, -.12), smooth=True)
    if L.get("headband"):
        p.add(prim_torus(.27, .025, segs=18, rsegs=4), L["headband"], matrix=H @ T(0, .02, .12) @ R(-.12, 0, 0) @ S(1, .98, 1), smooth=True)
        p.add(prim_tube([(0, .28, .1), (.06, .38, .02), (.1, .42, -.06)], [.03, .025, .01], segs=5, flat_y=.4), L["headband"], matrix=H)
    if L.get("cap"):
        cp = prim_lathe([(.0, 0), (.28, 0), (.27, .06), (.2, .12), (.0, .14)], segs=16, uvscale=.3)
        p.add(cp, L["cap"], matrix=H @ T(0, 0, .15) @ R(-.15, 0, 0) @ S(1, 1.05, 1), smooth=True)
        brim = prim_cyl(.16, .16, .025, segs=12)
        brim.transform(S(1.3, 1, 1))
        p.add(brim, L["cap"], matrix=H @ T(0, -.25, .12) @ R(-.25, 0, 0) @ S(1, .7, 1), smooth=True)
    elif not L.get("scarf") and not L.get("bun"):
        p.add(prim_tube([hc + Vector((0, 0, .27)), hc + Vector((.03, -.02, .36)), hc + Vector((-.01, -.06, .4))], [.04, .025, 0], segs=6),
              L["hair"], matrix=U, smooth=True)
    return {"U": U, "hand_l": hands[0], "hand_r": hands[1], "head": H}


# ============================================================================= common asset builders
def build_ev_peasant(coll, root, rng):
    parts = {"body": Part("peasant")}
    chibi(parts, rng, W(), "peasant", "stand")
    parts["body"].build(coll, parent=root)
    col_box("body", coll, (.5, .4, 1.25), (0, 0, .62), root)


def build_ev_old_tree(coll, root, rng):
    bark, leaves = Part("trunk_roots"), Part("crown")
    old_tree(bark, leaves, rng, W())
    bark.build(coll, parent=root); leaves.build(coll, parent=root)
    col_box("trunk", coll, (1.6, 1.6, 3.0), (0, 0, 1.5), root)


def build_ev_crate(coll, root, rng):
    p = Part("crate"); crate(p, W(), .66); p.build(coll, parent=root)
    col_box("crate", coll, (.66, .66, .66), (0, 0, .33), root)


def build_ev_barrel(coll, root, rng):
    p = Part("barrel"); barrel(p, W()); p.build(coll, parent=root)
    col_box("barrel", coll, (.56, .56, .78), (0, 0, .39), root)


def build_ev_sack(coll, root, rng):
    p = Part("sack"); sack(p, W()); p.build(coll, parent=root)


# ============================================================================= event dioramas
def build_ev01_spring(coll, root, rng):
    """Forest spring at the roots of an old tree, 4 m off the road, reached by a footpath;
    wolf tracks and a gnawed bone beside the path (the hidden danger)."""
    bark, leaves = Part("tree_trunk"), Part("tree_crown")
    old_tree(bark, leaves, rng, W((0.5, 6.9, 0), 0.3))
    stone, water, deco, plants_p = Part("spring_stones"), Part("spring_water"), Part("ground_details"), Part("plants")
    bc = Vector((0.3, 4.1, 0))  # basin centre
    n = 10
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0))
        h = rng.uniform(.38, .48)
        M = Matrix.Translation(bc + d * 1.15) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")
        blk = prim_box(.75, .36, h, bevel=.06)
        lumpy(blk, .025, 4, i)
        stone.add(blk, "stone_grey", matrix=M @ T(0, 0, h / 2), uv="world")
        mb = prim_box(.66, .3, .05, bevel=.02)
        lumpy(mb, .03, 5, i + 9)
        stone.add(mb, "moss", matrix=M @ T(0, 0, h + .01), uv="world")
    stone.add(prim_cyl(1.1, 1.1, .06, segs=16, z0=.02), "streambed", matrix=Matrix.Translation(bc), uv="world")
    water.add(prim_cyl(1.05, 1.05, .02, segs=20, z0=.3), "water", matrix=Matrix.Translation(bc), uv="world")
    # rock pile at the back with a wooden spout
    for (dx, dy, r) in ((-.7, 1.2, .6), (.05, 1.45, .75), (.8, 1.2, .58), (1.2, .6, .45), (-1.2, .6, .42)):
        rock(stone, rng, Matrix.Translation(bc + Vector((dx, dy, 0))), r=r, flat=1.15 if r > .45 else .9)
    sp = bc + Vector((0.02, .9, 1.05))
    stone.add(prim_box(.14, .5, .08, bevel=.015), "wood_dark", matrix=Matrix.Translation(sp) @ R(.18, 0, 0), uv="box", long_axis=1)
    for sx in (-1, 1):
        stone.add(prim_box(.025, .5, .06), "wood_dark", matrix=Matrix.Translation(sp + Vector((sx * .07, 0, .04))) @ R(.18, 0, 0), uv="box")
    fall = prim_tube([sp + Vector((0, -.25, .03)), sp + Vector((0, -.38, -.12)), sp + Vector((0, -.45, -.45)), bc + Vector((0, .42, .31))],
                     [.06, .065, .07, .09], segs=8, flat_y=.45, caps=(False, False))
    water.add(fall, "water_fall", uvscale=.5)
    for k in range(5):  # splash
        a = 2 * math.pi * k / 5
        water.add(blob(.06, 1, 1, .6, subdiv=1), "smoke", matrix=Matrix.Translation(bc + Vector((math.cos(a) * .14, .42 + math.sin(a) * .1, .33))))
    # footpath from the road edge to the basin
    footpath(deco, [(-.6, -.4), (-.2, .6), (-.45, 1.5), (-.1, 2.3), (.15, 2.9)], width=1.0, seed=1)
    # wolf tracks + bone (left of the path)
    tc = Vector((-2.15, 1.8, 0))
    ground_patch(deco, Matrix.Translation(tc) @ Matrix.Rotation(.3, 4, "Z"), 1.05, .75, "soil", seed=2, z=.014)
    for j, (px, py, rot) in enumerate(((-.45, -.25, .5), (.1, .1, .3), (.5, -.35, .6), (-.2, .45, .2))):
        Mp = Matrix.Translation(tc + Vector((px, py, .018))) @ Matrix.Rotation(rot, 4, "Z")
        deco.add(prim_cyl(.085, .085, .006, segs=10), "mud_dark", matrix=Mp @ S(1, .85, 1))
        for t in range(4):
            a = math.radians(-50 + t * 33)
            deco.add(prim_cyl(.032, .032, .006, segs=8), "mud_dark", matrix=Mp @ T(math.sin(a) * .13, math.cos(a) * .13 + .02, 0))
    bm = Matrix.Translation(tc + Vector((.35, .55, .05))) @ Matrix.Rotation(.8, 4, "Z")
    deco.add(prim_tube([(-.2, 0, 0), (.2, 0, 0)], [.035, .035], segs=8), "bone", matrix=bm, smooth=True)
    for ex in (-.22, .22):
        for ey in (-.04, .04):
            deco.add(blob(.045, subdiv=1), "bone", matrix=bm @ T(ex, ey, 0), smooth=True)
    for (x, y, r) in ((-2.6, 3.4, .45), (2.2, 2.2, .55), (-.9, .7, .22), (1.1, 1.1, .18)):
        rock(deco, rng, Matrix.Translation((x, y, 0)), r=r, moss=r > .3)
    plants(plants_p, rng, [(-1.1, 1.3, 1.1), (.9, .4, 1.0), (1.4, 3.3, 1.3), (-.9, 3.7, 1.2), (-2.4, 1.6, 1.0), (2.6, 3.4, 1.2),
                           (-1.9, 4.6, 1.3), (1.9, 4.7, 1.1), (-.7, 2.2, .8), (.95, 2.3, .9), (-2.8, .5, 1.0), (2.7, .9, 1.0)])
    for p in (bark, leaves, stone, water, deco, plants_p):
        p.build(coll, parent=root)
    col_box("tree", coll, (2.0, 2.0, 3.0), (.5, 6.9, 1.5), root)
    col_box("basin", coll, (2.7, 2.5, .5), (bc.x, bc.y, .25), root)
    empty("cam_focus", coll, (bc.x, bc.y - .6, .6), root, .3, "SPHERE")


def build_ev02_peddler(coll, root, rng):
    """Wounded peddler resting against a signpost at the roadside, his pack open; claw marks on the
    tree behind him hint at what attacked him."""
    bark, leaves = Part("tree_trunk"), Part("tree_crown")
    old_tree(bark, leaves, rng, W((1.9, 3.4, 0), -.2), claw=True, crown=.9)
    post, pack, goods, people, deco = Part("signpost"), Part("pack"), Part("goods"), {"body": Part("peddler")}, Part("ground_details")
    # signpost
    pc = Vector((-.3, 1.55, 0))
    post.add(prim_box(.2, .2, 2.4, bevel=.02), "wood_mid", matrix=Matrix.Translation(pc + Vector((0, 0, 1.2))), uv="box", long_axis=2)
    post.add(prim_pyramid(.2, .1, z0=2.4), "wood_mid", matrix=Matrix.Translation(pc), uv="box")
    for (z, sx, ln) in ((1.95, -1, 1.15), (1.55, 1, 1.25)):
        outline = [(0, -.13), (ln - .2, -.13), (ln, 0), (ln - .2, .13), (0, .13)]
        bm = prim_prism_xz(outline, .06)
        uv_box(bm, 1.0, 0)
        post.add(bm, "wood_light", matrix=Matrix.Translation(pc + Vector((sx * .08, -.1, z))) @ S(sx, 1, 1))
        post.add(prim_cyl(.03, .03, .03, segs=8), "iron", matrix=Matrix.Translation(pc + Vector((0, -.17, z))) @ R(math.pi / 2, 0, 0))
    rock(post, rng, Matrix.Translation(pc + Vector((-.2, .1, 0))), r=.18, moss=False)
    # peddler sitting against the post, bandaged right leg, hand on his head
    chibi(people, rng, W(pc + Vector((.05, -.25, 0)), .15), "peasant", "sit", bandage=True)
    # open pack-chest
    kc = Matrix.Translation((-1.35, 1.25, 0)) @ Matrix.Rotation(.25, 4, "Z")
    pack.add(prim_box(.8, .5, .5, bevel=.03), "wood_mid", matrix=kc @ T(0, 0, .25), uv="box", long_axis=0)
    pack.add(prim_box(.82, .48, .06, bevel=.02), "wood_mid", matrix=kc @ T(0, .38, .68) @ R(-1.2, 0, 0), uv="box", long_axis=0)
    for sx in (-.22, .22):
        pack.add(prim_box(.07, .54, .02), "leather", matrix=kc @ T(sx, 0, .505))
        pack.add(prim_box(.07, .02, .5), "leather", matrix=kc @ T(sx, -.26, .25))
        pack.add(prim_box(.06, .03, .06), "brass", matrix=kc @ T(sx, -.275, .3))
        pack.add(prim_tube([(sx, .26, .45), (sx, .42, .3), (sx, .36, .05)], [.025, .025, .025], segs=6, flat_y=.4), "leather", matrix=kc)
    pack.add(prim_box(.74, .44, .02), "wood_dark", matrix=kc @ T(0, 0, .47))
    goods.add(prim_tube([(-.32, -.05, .55), (-.2, -.08, .6), (-.08, -.05, .56)], [.07, .09, .07], segs=10), "bread", matrix=kc, smooth=True)
    for (x, y, m, h) in ((.0, .05, "glass_blue", .26), (.1, -.06, "glass_red", .22), (-.08, .1, "glass_green", .24)):
        bottle(goods, kc @ T(x, y, .46), m, h=h)
    sack(goods, kc @ T(.26, .02, .4) @ S(.6), seed=3)
    goods.add(blob(.12, 1.2, 1, .8, amp=.1, freq=5, seed=4), "cloth_purple", matrix=kc @ T(.17, .12, .55), smooth=True)
    for (x, m) in ((-.05, "cloth_red"), (.08, "cloth_blue")):
        rb = prim_prism_xz([(-.04, 0), (.04, 0), (.04, -.3), (0, -.26), (-.04, -.3)], .01)
        goods.add(rb, m, matrix=kc @ T(x, -.26, .5))
    for (x, y, r) in ((-2.4, 2.3, .4), (.9, .7, .2), (-2.0, .5, .16), (3.0, 1.6, .5)):
        rock(deco, rng, Matrix.Translation((x, y, 0)), r=r, moss=r > .3)
    ground_patch(deco, Matrix.Translation((-.6, 1.2, 0)), 1.6, .9, "soil", seed=5)
    pl = Part("plants")
    plants(pl, rng, [(.6, 1.9, 1.0), (-2.2, 1.3, 1.1), (-1.8, 2.6, 1.3), (.9, 2.8, 1.0), (2.7, 2.4, 1.2), (-.9, 2.4, .9),
                     (1.4, 1.2, .8), (-2.9, .9, 1.0), (3.1, .6, 1.0), (.0, 3.2, 1.1), (-1.0, 3.6, 1.2)])
    for p in (bark, leaves, post, pack, goods, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_box("tree", coll, (1.6, 1.6, 3.0), (1.9, 3.4, 1.5), root)
    col_box("post", coll, (.25, .25, 2.4), (pc.x, pc.y, 1.2), root)
    empty("cam_focus", coll, (-.5, 1.1, .7), root, .3, "SPHERE")


def build_ev03_toll(coll, root, rng):
    """Toll booth by the bridge: keeper with a mug for coins, two masked friends peeking from behind
    the booth. The bridge itself is the level's timber_footbridge."""
    booth, roof, pole, props, people = Part("booth"), Part("roof"), Part("pole"), Part("props"), {"body": Part("people")}
    B = Matrix.Translation((-.6, 1.9, 0)) @ Matrix.Rotation(.12, 4, "Z")
    w, d, h = 1.6, 1.3, 1.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            booth.add(prim_box(.14, .14, h + (.25 if sx > 0 else 0), bevel=.015), "wood_mid",
                      matrix=B @ T(sx * w / 2, sy * d / 2, (h + (.25 if sx > 0 else 0)) / 2), uv="box", long_axis=2)
    # walls: planks (vertical) — back, sides, front with a window
    def planks(x0, x1, y, z0, z1, axis="x"):
        n = max(1, int(round(abs(x1 - x0) / .2)))
        for i in range(n):
            c = x0 + (i + .5) * (x1 - x0) / n
            hh = z1 - z0 + rng.uniform(-.03, .03)
            if axis == "x":
                booth.add(prim_box(abs(x1 - x0) / n - .01, .05, hh, bevel=.008), "wood_light", matrix=B @ T(c, y, z0 + hh / 2), uv="box", long_axis=2, rng=rng)
            else:
                booth.add(prim_box(.05, abs(x1 - x0) / n - .01, hh, bevel=.008), "wood_light", matrix=B @ T(y, c, z0 + hh / 2), uv="box", long_axis=2, rng=rng)
    top = lambda x: h + .25 * (x + w / 2) / w
    planks(-w / 2, w / 2, d / 2, 0, h, "x")
    planks(-d / 2, d / 2, -w / 2, 0, h, "y")
    planks(-d / 2, d / 2, w / 2, 0, h + .2, "y")
    planks(-w / 2, w / 2, -d / 2, 0, .9, "x")           # front below the counter
    planks(-w / 2, -.45, -d / 2, .9, h, "x")            # front left of window
    planks(.45, w / 2, -d / 2, .9, h + .1, "x")         # front right
    booth.add(prim_box(.9, .05, .35, bevel=.008), "wood_light", matrix=B @ T(0, -d / 2, 1.82), uv="box", long_axis=0)
    for z in (.3, 1.5):
        booth.add(prim_box(w + .1, .07, .1, bevel=.01), "wood_mid", matrix=B @ T(0, -d / 2 - .04, z if z < 1 else 1.6), uv="box", long_axis=0)
    booth.add(prim_box(1.1, .35, .06, bevel=.01), "wood_mid", matrix=B @ T(0, -d / 2 - .12, .92), uv="box", long_axis=0)
    for sx in (-.45, .45):
        booth.add(prim_box(.05, .3, .05), "wood_mid", matrix=B @ T(sx, -d / 2 - .12, .78) @ R(.7, 0, 0))
    booth.add(prim_box(1.2, .55, .04, bevel=.008), "wood_mid", matrix=B @ T(0, -d / 2 - .3, 1.72) @ R(-.35, 0, 0), uv="box", long_axis=0)
    booth.add(prim_box(.9, .8, .05), "wood_dark", matrix=B @ T(0, 0, .03), uv="box")  # floor
    booth.add(prim_box(.6, .4, .05), "wood_dark", matrix=B @ T(0, -.2, 1.0))  # inner shelf (dark window)
    booth.add(prim_box(1.3, 1.1, .04), "wood_dark", matrix=B @ T(0, .02, 1.25))   # dark interior ceiling
    # gable roof (ridge along X) with blue tiles
    rz = h + .45
    for sy in (-1, 1):
        ang = -sy * math.radians(32)
        sl = (d / 2 + .35) / math.cos(math.radians(32))
        Mr = B @ T(0, sy * (d / 2 + .35) / 2, rz - .5 * (d / 2 + .35) * math.tan(math.radians(32))) @ R(ang, 0, 0)
        roof.add(prim_box(w + .5, sl, .06), "wood_dark", matrix=Mr, uv="box", long_axis=0)
        rows = 5
        for r_ in range(rows):
            yy = -sl / 2 + (r_ + .5) * sl / rows
            n = 7
            for c in range(n + (r_ % 2)):
                xx = -(w + .5) / 2 + (c + (0 if r_ % 2 else .5)) * (w + .5) / n
                if abs(xx) > (w + .5) / 2 - .05:
                    continue
                tl = prim_box((w + .5) / n - .02, sl / rows + .06, .05, bevel=.012)
                roof.add(tl, "roof_blue", matrix=Mr @ T(xx, yy, .055 + .012 * (rows - r_)),
                         uv="box", long_axis=0, uvscale=.4)
    roof.add(prim_box(w + .55, .14, .14, bevel=.02), "wood_mid", matrix=B @ T(0, 0, rz + .02), uv="box", long_axis=0)
    for sx in (-1, 1):  # gable boards
        for sy in (-1, 1):
            L = (d / 2 + .38) / math.cos(math.radians(32))
            roof.add(prim_box(.08, L, .12), "wood_mid",
                     matrix=B @ T(sx * (w / 2 + .27), sy * L * math.cos(math.radians(32)) / 2, rz - L * math.sin(math.radians(32)) / 2) @ R(-sy * math.radians(32), 0, 0))
    # chimney + smoke
    ch = B @ T(-.45, .35, rz - .3)
    roof.add(prim_box(.26, .26, .85, bevel=.02), "stone_grey", matrix=ch @ T(0, 0, .42), uv="world")
    roof.add(prim_box(.34, .34, .08, bevel=.015), "stone_grey", matrix=ch @ T(0, 0, .88), uv="world")
    for k, (dx, dz, r) in enumerate(((0, 1.05, .1), (.05, 1.22, .13), (-.04, 1.38, .12), (.1, 1.5, .15), (.02, 1.68, .13), (.16, 1.75, .1))):
        roof.add(blob(r, amp=.2, freq=6, seed=k, subdiv=2), "smoke", matrix=ch @ T(dx, -.02 * k, dz), smooth=True)
    # barrel + leaning plank + club
    barrel(props, Matrix.Translation((-1.75, 1.35, 0)))
    props.add(prim_box(.22, .05, .75, bevel=.01), "wood_light", matrix=Matrix.Translation((.3, 1.15, .35)) @ R(.25, 0, .3), uv="box", long_axis=2)
    props.add(prim_tube([(0, 0, 0), (0, 0, .35), (0, 0, .6), (0, 0, .7)], [.04, .05, .09, .0], segs=8), "wood_mid",
              matrix=Matrix.Translation((-1.45, 1.0, .02)) @ R(.35, .3, 0), smooth=True)
    props.add(prim_torus(.045, .015, segs=8, rsegs=4), "leather", matrix=Matrix.Translation((-1.45, 1.0, .02)) @ R(.35, .3, 0) @ T(0, 0, .2))
    # pole with pennant and lantern
    pp = Vector((.9, 1.25, 0))
    pole.add(prim_box(.16, .16, 3.3, bevel=.02), "wood_mid", matrix=Matrix.Translation(pp + Vector((0, 0, 1.65))), uv="box", long_axis=2)
    pole.add(prim_box(1.1, .12, .12, bevel=.015), "wood_mid", matrix=Matrix.Translation(pp + Vector((.5, 0, 3.0))), uv="box", long_axis=0)
    pole.add(prim_box(.6, .07, .07), "wood_mid", matrix=Matrix.Translation(pp + Vector((.2, 0, 2.75))) @ R(0, .75, 0), uv="box", long_axis=0)
    for x in (0, .3, .95):
        pole.add(prim_torus(.09, .022, segs=10, rsegs=4), "rope", matrix=Matrix.Translation(pp + Vector((x, 0, 3.0))) @ R(0, math.pi / 2, 0))
    pen = _new()
    cols = 8
    for i in range(cols + 1):
        t = i / cols
        x = .1 + t * .95
        hh = .55 * (1 - .35 * t)
        wave = .05 * math.sin(t * 6)
        pen.verts.new((x, wave, 0)); pen.verts.new((x, wave, -hh if i < cols else -hh * .4))
    pen.verts.ensure_lookup_table()
    for i in range(cols):
        a, b, c, e = pen.verts[2 * i], pen.verts[2 * i + 2], pen.verts[2 * i + 3], pen.verts[2 * i + 1]
        pen.faces.new((a, b, c, e))
    for i in range(cols - 2, cols):  # torn notch at the tail
        for v in (pen.verts[2 * i + 1],):
            v.co.z += .15
    uv_planar(pen, axes=(0, 2))
    pole.add(pen, "pennant", matrix=Matrix.Translation(pp + Vector((0, 0, 2.97))))
    lc = pp + Vector((.42, 0, 2.3))
    pole.add(prim_tube([lc + Vector((0, 0, .7)), lc + Vector((0, 0, .32))], [.008, .008], segs=4), "iron")
    pole.add(prim_torus(.04, .01, segs=8, rsegs=4), "iron", matrix=Matrix.Translation(lc + Vector((0, 0, .32))) @ R(math.pi / 2, 0, 0))
    pole.add(prim_box(.16, .16, .2), "lantern_glow", matrix=Matrix.Translation(lc + Vector((0, 0, .08))))
    pole.add(prim_pyramid(.22, .1, z0=.18), "iron", matrix=Matrix.Translation(lc))
    pole.add(prim_box(.2, .2, .04), "iron", matrix=Matrix.Translation(lc + Vector((0, 0, -.04))))
    for sx in (-1, 1):
        for sy in (-1, 1):
            pole.add(prim_box(.025, .025, .22), "iron", matrix=Matrix.Translation(lc + Vector((sx * .085, sy * .085, .08))))
    # people: keeper in front, offering a mug; two masked "friends" peeking behind the booth
    chibi(people, rng, W((.35, .65, 0), -.25), "keeper", "offer")
    mug = Matrix.Translation((.35, .65, 0)) @ Matrix.Rotation(-.25, 4, "Z") @ T(.27, -.36, .58)
    people["body"].add(prim_cyl(.06, .055, .12, segs=12), "steel", matrix=mug, smooth=True)
    people["body"].add(prim_torus(.035, .012, segs=8, rsegs=4), "steel", matrix=mug @ T(.065, 0, .06) @ R(math.pi / 2, 0, 0))
    chibi(people, rng, W((-1.55, 2.55, 0), .5, .95), "bandit_a", "peek")
    chibi(people, rng, W((-1.35, 3.05, 0), .3, .98), "bandit_b", "peek")
    deco, pl = Part("ground_details"), Part("plants")
    ground_patch(deco, Matrix.Translation((-.3, 1.4, 0)), 1.9, 1.3, "dirt", seed=7)
    for (x, y, r) in ((-2.3, 2.2, .35), (1.6, 2.3, .4), (2.2, .8, .2)):
        rock(deco, rng, Matrix.Translation((x, y, 0)), r=r, moss=r > .3)
    plants(pl, rng, [(-2.0, .8, 1.0), (1.4, .5, .8), (1.8, 1.6, 1.1), (-2.2, 3.0, 1.2), (.6, 3.0, 1.2), (-.4, 3.2, 1.0),
                     (-2.4, 1.6, .9), (2.3, 2.9, 1.0)])
    for p in (booth, roof, pole, props, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_hull("booth", coll, [(B @ Vector((sx * (w / 2 + .1), sy * (d / 2 + .1), z))) for sx in (-1, 1) for sy in (-1, 1) for z in (0, h + .3)], root)
    col_box("pole", coll, (.2, .2, 3.3), (pp.x, pp.y, 1.65), root)
    empty("cam_focus", coll, (.0, .9, .9), root, .3, "SPHERE")
    empty("coin_point", coll, (.6, .2, .6), root, .15)


# ============================================================================= props for events 4–16
def plank_wall(part, M, w, h, mat="wood_light", rng=None, plank=.2, t=.05):
    """Vertical planks across width w (local X, centred), height h from z=0, at y=0."""
    n = max(1, int(round(w / plank)))
    for i in range(n):
        c = -w / 2 + (i + .5) * w / n
        hh = h + (rng.uniform(-.03, .03) if rng else 0)
        part.add(prim_box(w / n - .01, t, hh, bevel=.008), mat, matrix=M @ T(c, 0, hh / 2), uv="box", long_axis=2, rng=rng)


def wheel(part, M, r=.42, spokes=8, mat="wood_mid"):
    """Spoked wheel, hub at M, axle along local X."""
    A = M @ R(0, math.pi / 2, 0)
    part.add(prim_torus(r - .035, .04, segs=20, rsegs=6, uvscale=.4), mat, matrix=A @ S(1, 1, 1.6), smooth=True)
    part.add(prim_torus(r, .016, segs=20, rsegs=4), "iron", matrix=A @ S(1, 1, 2.6))
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        d = Vector((0, math.cos(a), math.sin(a)))
        part.add(prim_tube([d * .06, d * (r - .05)], [.022, .018], segs=6), mat, matrix=M)
    part.add(prim_cyl(.075, .075, .14, segs=10, z0=-.07), "iron", matrix=A)


def cart(part, M, cage=False, shafts=True):
    """Two-wheel peasant cart along local Y (shafts toward -Y). Bed floor at z 0.5."""
    z0 = .5
    part.add(prim_box(1.0, 1.7, .06, bevel=.01), "wood_mid", matrix=M @ T(0, 0, z0), uv="box", long_axis=1)
    for sx in (-1, 1):
        for z in (z0 + .14, z0 + .32):
            part.add(prim_box(.06, 1.75, .16, bevel=.01), "wood_light", matrix=M @ T(sx * .5, 0, z), uv="box", long_axis=1)
        for y in (-.8, 0, .8):
            part.add(prim_box(.08, .08, .5, bevel=.01), "wood_mid", matrix=M @ T(sx * .53, y, z0 + .2), uv="box", long_axis=2)
            part.add(prim_box(.09, .09, .06), "iron", matrix=M @ T(sx * .535, y, z0 + .36))
    for sy in (-1, 1):
        part.add(prim_box(1.0, .06, .34, bevel=.01), "wood_light", matrix=M @ T(0, sy * .86, z0 + .2), uv="box", long_axis=0)
    part.add(prim_cyl(.05, .05, 1.3, segs=8, z0=-.65), "wood_dark", matrix=M @ T(0, 0, .42) @ R(0, math.pi / 2, 0))
    for sx in (-1, 1):
        wheel(part, M @ T(sx * .64, 0, .42))
    if shafts:
        for sx in (-1, 1):
            part.add(prim_box(.07, 2.7, .07, bevel=.01), "wood_mid", matrix=M @ T(sx * .32, -.6, .43) @ R(.08, 0, 0), uv="box", long_axis=1)
            part.add(prim_box(.09, .1, .09), "iron", matrix=M @ T(sx * .32, -1.93, .33))
    if cage:
        for sx in (-1, 1):
            for i in range(8):
                part.add(prim_box(.07, .07, .8, bevel=.01), "wood_mid", matrix=M @ T(sx * .5, -.8 + i * 1.6 / 7, z0 + .75), uv="box", long_axis=2)
        for sy in (-1, 1):
            for i in range(5):
                part.add(prim_box(.07, .07, .8, bevel=.01), "wood_mid", matrix=M @ T(-.4 + i * .2, sy * .83, z0 + .75), uv="box", long_axis=2)
        for z in (z0 + .55, z0 + 1.15):
            for sx in (-1, 1):
                part.add(prim_box(.09, 1.8, .09, bevel=.01), "wood_dark", matrix=M @ T(sx * .5, 0, z), uv="box", long_axis=1)
            for sy in (-1, 1):
                part.add(prim_box(1.08, .09, .09, bevel=.01), "wood_dark", matrix=M @ T(0, sy * .83, z), uv="box", long_axis=0)
        for i in range(5):
            part.add(prim_box(1.05, .12, .05), "wood_mid", matrix=M @ T(0, -.8 + i * .4, z0 + 1.2), uv="box", long_axis=0)
        for z in (z0 + .55, z0 + 1.15):
            for sx in (-1, 1):
                for sy in (-1, 1):
                    part.add(prim_box(.11, .11, .11), "iron", matrix=M @ T(sx * .5, sy * .83, z))


def campfire(part, rng, M, lit=True, r=.38):
    for i in range(9):
        a = 2 * math.pi * i / 9
        part.add(blob(.1, 1.2, 1, .8, amp=.2, freq=4, seed=i), "stone_grey", matrix=M @ T(math.cos(a) * r, math.sin(a) * r, .06), uv="world", smooth=True)
    for k in range(4):
        a = k * math.pi / 4 + .3
        d = Vector((math.cos(a), math.sin(a), 0))
        part.add(prim_tube([-d * .28 + Vector((0, 0, .06)), d * .28 + Vector((0, 0, .12))], [.045, .04], segs=7), "wood_dark", matrix=M, smooth=True)
    if lit:
        part.add(blob(.2, 1, 1, .35, amp=.2, freq=5), "coal_glow", matrix=M @ T(0, 0, .06), smooth=True)
        for k, (dx, dy, h, rr) in enumerate(((0, 0, .55, .14), (.09, .05, .38, .09), (-.08, -.04, .42, .1), (.03, -.09, .3, .07))):
            part.add(prim_tube([(dx, dy, .08), (dx * 1.2, dy * 1.2, .08 + h * .5), (dx * .5 + .03, dy * .5, .08 + h)], [rr, rr * .7, 0], segs=7),
                     "fire", matrix=M, smooth=True)


def tripod_pot(part, M):
    for k in range(3):
        a = 2 * math.pi * k / 3 + .5
        part.add(prim_tube([(math.cos(a) * .5, math.sin(a) * .5, 0), (0, 0, 1.15)], [.03, .025], segs=6), "wood_mid", matrix=M)
    part.add(prim_torus(.05, .02, segs=8, rsegs=4), "rope", matrix=M @ T(0, 0, 1.1))
    part.add(prim_tube([(0, 0, 1.1), (0, 0, .78)], [.008, .008], segs=4), "iron", matrix=M)
    part.add(prim_lathe([(.0, .5), (.12, .52), (.17, .6), (.16, .72), (.13, .76)], segs=14, uvscale=.3), "iron", matrix=M, smooth=True)
    part.add(prim_torus(.13, .012, segs=12, rsegs=4), "iron", matrix=M @ T(0, 0, .76) @ R(0, math.pi / 2, 0) @ S(1, 1, 1))


def bucket(part, M, water=False):
    part.add(prim_lathe([(.0, 0), (.12, 0), (.15, .26)], segs=12, uvscale=.4), "wood_mid", matrix=M, smooth=True)
    for z in (.05, .2):
        part.add(prim_torus(.125 + z * .12, .01, segs=12, rsegs=4), "iron", matrix=M @ T(0, 0, z) @ S(1, 1, 2))
    part.add(prim_torus(.15, .008, segs=12, rsegs=4), "iron", matrix=M @ T(0, 0, .26) @ R(math.pi / 2, 0, 0) @ S(1, 1, 1))
    if water:
        part.add(prim_cyl(.14, .14, .01, segs=12, z0=.21), "water", matrix=M)


def coins(part, M, stacks=((0, 0, 5),), mat="gold", r=.04):
    for (x, y, n) in stacks:
        for k in range(n):
            part.add(prim_cyl(r, r, .012, segs=10, z0=k * .013), mat, matrix=M @ T(x + (k % 2) * .003, y, 0))


def coin_heap(part, rng, M, n=26, r=.15, mat="copper"):
    for k in range(n):
        a = rng.uniform(0, 6.28); d = rng.uniform(0, r) * (1 - k / n * .5)
        part.add(prim_cyl(.032, .032, .01, segs=8), mat, matrix=M @ T(math.cos(a) * d, math.sin(a) * d, k / n * r * .7) @ R(rng.uniform(-.5, .5), rng.uniform(-.5, .5), 0))


def mug(part, M, mat="steel"):
    part.add(prim_cyl(.05, .046, .11, segs=12), mat, matrix=M, smooth=True)
    part.add(prim_torus(.03, .01, segs=8, rsegs=4), mat, matrix=M @ T(.055, 0, .055) @ R(math.pi / 2, 0, 0))


def knife(part, M):
    part.add(prim_prism_xz([(0, -.02), (.2, -.015), (.24, .01), (0, .02)], .008), "steel", matrix=M @ T(0, .004, 0) @ R(math.pi / 2, 0, 0))
    part.add(prim_tube([(-.12, 0, 0), (0, 0, 0)], [.018, .02], segs=6), "wood_dark", matrix=M)
    part.add(prim_box(.02, .06, .02), "brass", matrix=M)


def fence(part, M, length, gate_at=None, open_gate=0.0, mat="wood_mid"):
    """Rail fence along local X from 0 to length; optional gate gap of 1 m starting at gate_at."""
    n = int(round(length))
    for i in range(n + 1):
        x = i * length / n
        part.add(prim_tube([(x, 0, 0), (x, 0, 1.0)], [.06, .05], segs=6), mat, matrix=M, uv="box")
    for i in range(n):
        x0, x1 = i * length / n, (i + 1) * length / n
        if gate_at is not None and x0 >= gate_at - 1e-3 and x1 <= gate_at + 1.0 + 1e-3:
            G = M @ T(x0, 0, 0) @ R(0, 0, -open_gate)
            for z in (.3, .75):
                part.add(prim_box(x1 - x0 - .08, .05, .1, bevel=.01), mat, matrix=G @ T((x1 - x0) / 2, 0, z), uv="box", long_axis=0)
            part.add(prim_box(math.hypot(x1 - x0, .45), .05, .08), mat, matrix=G @ T((x1 - x0) / 2, 0, .52) @ R(0, -math.atan2(.45, x1 - x0), 0), uv="box", long_axis=0)
            continue
        for z in (.4, .78):
            part.add(prim_box(x1 - x0 + .08, .06, .09, bevel=.01), mat, matrix=M @ T((x0 + x1) / 2, 0, z), uv="box", long_axis=0)


def bush(part, rng, M, r=.7, mat="leaves_bush"):
    seed = rng.random() * 30
    part.add(blob(r, 1.1, 1, .8, amp=.15, freq=2.5, seed=seed), mat, matrix=M @ T(0, 0, r * .55), uv="world", smooth=True)
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-.3, .3)
        d = Vector((math.cos(a), math.sin(a), .5))
        part.add(blob(r * .5, amp=.12, freq=3, seed=seed + k), mat, matrix=M @ T(*(Vector((0, 0, r * .6)) + d * r * .6)), uv="world", smooth=True)


def arrow(part, M, length=.7):
    """Arrow along local +Z from z=0 (tip) backwards; tip buried at M."""
    part.add(prim_tube([(0, 0, 0), (0, 0, length)], [.012, .012], segs=5), "wood_light", matrix=M)
    part.add(prim_pyramid(.04, .08, z0=-.08), "steel", matrix=M @ R(math.pi, 0, 0) @ T(0, 0, 0))
    for k in range(3):
        part.add(prim_prism_xz([(0, 0), (.05, .03), (.05, .14), (0, .16)], .004), "cloth_white",
                 matrix=M @ T(0, 0, length - .17) @ R(0, 0, k * 2.094))


def pine(trunk, leaves, rng, M, h=6.5, rope=False):
    trunk.add(prim_tube([(0, 0, -.05), (0, 0, h * .45), (0, 0, h * .9)], [.36, .26, .1], segs=12, rough=.12, seed=rng.random() * 9, uvscale=1.3),
              "bark", matrix=M, smooth=True)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-.2, .2)
        d = Vector((math.cos(a), math.sin(a), 0))
        trunk.add(prim_tube([d * .2 + Vector((0, 0, .3)), d * .7 + Vector((0, 0, .02))], [.16, .03], segs=6), "bark", matrix=M, smooth=True)
    tiers = 5
    for i in range(tiers):
        z = h * .35 + i * h * .13
        rr = 1.6 * (1 - i / tiers * .75)
        bm = prim_tube([(0, 0, z), (0, 0, z + h * .26)], [rr, 0], segs=9)
        for v in bm.verts:
            if v.co.z < z + .01:
                v.co.z -= .25 * (1 + math.sin(math.atan2(v.co.y, v.co.x) * 9))
        leaves.add(bm, "leaves_pine", matrix=M, uv="world", smooth=False)
    if rope:
        for k in range(4):
            trunk.add(prim_torus(.32, .03, segs=16, rsegs=5), "rope", matrix=M @ T(0, 0, .75 + k * .06) @ R(.06 * (k % 2), 0, 0))


def chest(part, M, open_=False, sz=(.6, .4, .32)):
    w, d, h = sz
    part.add(prim_box(w, d, h, bevel=.015), "wood_mid", matrix=M @ T(0, 0, h / 2), uv="box", long_axis=0)
    part.add(prim_box(w - .06, d - .06, .02), "eye", matrix=M @ T(0, 0, h - .005))
    for x in (-w * .32, w * .32):
        part.add(prim_box(.05, d + .02, h + .01), "iron", matrix=M @ T(x, 0, h / 2))
    lid = Matrix.Translation((0, d / 2, h)) @ R(-1.9 if open_ else 0, 0, 0) @ T(0, -d / 2, 0)
    bm = prim_cyl(d / 2, d / 2, w, segs=10, z0=-w / 2)
    for v in bm.verts:
        if v.co.x < 0:
            v.co.x = 0
    part.add(bm, "wood_mid", matrix=M @ lid @ R(0, math.pi / 2, 0) @ S(1, 1, 1), uv="box")
    for x in (-w * .32, w * .32):
        part.add(prim_box(.05, d + .02, .05), "iron", matrix=M @ lid @ T(x, 0, d / 2 - .02))
    part.add(prim_box(.08, .02, .1), "iron", matrix=M @ T(0, -d / 2 - .01, h - .05))


def bear_trap(part, M):
    part.add(prim_torus(.3, .02, segs=20, rsegs=4), "iron", matrix=M @ T(0, 0, .03) @ S(1, 1, 1.5))
    for k in range(14):
        a = 2 * math.pi * k / 14
        part.add(prim_pyramid(.045, .07, z0=.04), "iron", matrix=M @ T(math.cos(a) * .3, math.sin(a) * .3, 0))
    part.add(prim_cyl(.08, .08, .02, segs=10, z0=.02), "iron", matrix=M)
    for sx in (-1, 1):
        part.add(prim_tube([(sx * .3, 0, .03), (sx * .5, 0, .03)], [.025, .025], segs=6), "iron", matrix=M)


def crow(part, M, flying=False):
    part.add(blob(.09, .8, 1.4, .8), "feather", matrix=M @ T(0, 0, .12) @ R(.3, 0, 0), smooth=True)
    part.add(blob(.06), "feather", matrix=M @ T(0, -.12, .2), smooth=True)
    part.add(prim_pyramid(.04, .08), "iron", matrix=M @ T(0, -.17, .2) @ R(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        part.add(blob(.012, subdiv=1), "eye_white", matrix=M @ T(sx * .03, -.16, .22))
    part.add(prim_prism_xz([(-.05, 0), (.05, 0), (.07, -.15), (-.07, -.15)], .015), "feather", matrix=M @ T(0, .16, .14) @ R(-1.2, 0, 0))
    if flying:
        for sx in (-1, 1):
            part.add(prim_prism_xz([(0, 0), (sx * .3, .12), (sx * .35, .02), (sx * .25, -.06)], .015), "feather", matrix=M @ T(0, 0, .14))
    else:
        for sx in (-1, 1):
            part.add(blob(.07, .4, 1.1, .6), "feather", matrix=M @ T(sx * .06, .03, .12), smooth=True)
            part.add(prim_tube([(sx * .03, 0, .06), (sx * .03, 0, 0)], [.006, .006], segs=4), "iron", matrix=M)


def cow(part, M):
    part.add(blob(.42, 1.0, 1.7, .9, amp=.03), "cow_hide", matrix=M @ T(0, 0, .75), uv="world", smooth=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            part.add(prim_tube([(sx * .2, sy * .45, .6), (sx * .2, sy * .45, .05)], [.09, .08], segs=8), "cow_hide", matrix=M, uv="world", smooth=True)
            part.add(prim_cyl(.085, .085, .08, segs=8), "fur_dark", matrix=M @ T(sx * .2, sy * .45, 0))
    H = M @ T(0, -.8, 1.0)
    part.add(blob(.26, 1.0, 1.0, .95), "fur_white", matrix=H, smooth=True)
    part.add(blob(.2, 1.1, .8, .7), "pink", matrix=H @ T(0, -.2, -.1), smooth=True)
    for sx in (-1, 1):
        part.add(blob(.035, .8, .3, 1.1, subdiv=1), "eye", matrix=H @ T(sx * .11, -.22, .07))
        part.add(prim_tube([(sx * .15, 0, .2), (sx * .27, .02, .3)], [.035, .01], segs=6), "horn", matrix=H)
        part.add(blob(.09, 1.4, .4, .7), "fur_dark", matrix=H @ T(sx * .3, .05, .1) @ R(0, sx * .4, 0), smooth=True)
        part.add(blob(.025, subdiv=1), "eye", matrix=H @ T(sx * .06, -.36, -.1))
    part.add(blob(.12, 1, .5, 1), "fur_dark", matrix=H @ T(.1, -.03, .16), smooth=True)
    part.add(prim_tube([(0, .75, .95), (0, .85, .6), (0, .82, .4)], [.02, .015, .03], segs=5), "fur_dark", matrix=M)


def badger(part, M):
    part.add(blob(.34, 1.05, .9, 1.0, amp=.04), "fur_dark", matrix=M @ T(0, .05, .34), uv="world", smooth=True)
    part.add(blob(.28, 1.0, .7, .95), "fur_white", matrix=M @ T(0, -.12, .32), smooth=True)
    H = M @ T(0, -.05, .8)
    part.add(blob(.2, 1.1, .95, .9), "fur_dark", matrix=H, smooth=True)
    part.add(blob(.13, .9, .9, 1.25), "fur_white", matrix=H @ T(0, -.1, .02), smooth=True)
    part.add(blob(.08, 1.2, .9, .75), "fur_white", matrix=H @ T(0, -.18, -.08), smooth=True)
    part.add(blob(.03, subdiv=1), "eye", matrix=H @ T(0, -.27, -.05))
    for sx in (-1, 1):
        part.add(blob(.06, 1, .5, 1), "fur_dark", matrix=H @ T(sx * .16, .02, .15), smooth=True)
        part.add(prim_tube([(-.03, 0, -.01), (0, 0, .012), (.03, 0, -.01)], [.008, .01, .008], segs=5), "eye", matrix=H @ T(sx * .085, -.2, .02))
        part.add(blob(.1, .9, 1.3, .7), "fur_dark", matrix=M @ T(sx * .2, -.25, .07), smooth=True)  # feet
        part.add(blob(.04, 1, .5, 1), "pink", matrix=M @ T(sx * .2, -.36, .09), smooth=True)
        part.add(prim_tube([(sx * .3, -.02, .55), (sx * .22, -.25, .42), (sx * .08, -.3, .45)], [.07, .065, .06], segs=8), "fur_dark", matrix=M, smooth=True)
    part.add(blob(.12, 1.3, .8, .6, amp=.2, freq=7), "honey", matrix=M @ T(0, -.3, .45), smooth=True)
    for k, (x, z) in enumerate(((-.08, .3), (.07, .24), (.0, .36))):
        part.add(prim_tube([(x, -.36, .42), (x, -.38, z)], [.02, .012], segs=5), "honey", matrix=M, smooth=True)


def bee(part, M):
    part.add(blob(.035, 1, 1.4, 1, subdiv=1), "honey", matrix=M, smooth=True)
    part.add(prim_torus(.032, .008, segs=8, rsegs=3), "eye", matrix=M @ R(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        part.add(blob(.03, 1, .6, .15, subdiv=1), "eye_white", matrix=M @ T(sx * .03, 0, .03) @ R(0, sx * .5, 0))


def ribbon(part, M, mat):
    part.add(prim_prism_xz([(-.025, 0), (.025, 0), (.03, -.4), (0, -.35), (-.025, -.42)], .008), mat, matrix=M)


def honey_drips(part, M, n=4, rng=None):
    for k in range(n):
        x = -.12 + k * .08
        ln = .2 + (rng.uniform(0, .35) if rng else k * .07)
        part.add(prim_tube([(x, 0, 0), (x, -.01, -ln * .6), (x, -.012, -ln)], [.03, .022, .03], segs=6), "honey", matrix=M, smooth=True)
        part.add(blob(.032, subdiv=1), "honey", matrix=M @ T(x, -.012, -ln), smooth=True)


def apple(part, M):
    part.add(blob(.05, 1, 1, .9), "apple", matrix=M @ T(0, 0, .045), smooth=True)
    part.add(prim_tube([(0, 0, .09), (.005, 0, .12)], [.006, .004], segs=4), "wood_dark", matrix=M)


def flower(part, M, mat="petal_cream"):
    for k in range(6):
        part.add(prim_leaf(.06, .04, segs=3, curve=.1, shape="petal"), mat, matrix=M @ T(0, 0, .05) @ R(0, 0, k * 1.047) @ R(0, -.3, 0))
    part.add(blob(.018, subdiv=1), "honey", matrix=M @ T(0, 0, .06))


def logs_pile(part, M):
    for (x, z) in ((-.16, .14), (.16, .14), (0, .4)):
        part.add(prim_tube([(-.45, 0, 0), (.45, 0, 0)], [.14, .14], segs=10), "bark", matrix=M @ T(0, x, z), smooth=True)
        for ex in (-.45, .45):
            part.add(prim_cyl(.13, .13, .01, segs=10), "wood_raw", matrix=M @ T(ex, x, z) @ R(0, math.pi / 2, 0))


# ============================================================================= event dioramas 4–16
def build_ev04_smithy(coll, root, rng):
    """Open lean-to smithy at the roadside: forge with coals, bellows, anvil, smith hammering."""
    shed, forge, tools, people, deco, pl = Part("shed"), Part("forge"), Part("tools"), {"body": Part("smith")}, Part("ground_details"), Part("plants")
    w, y0, y1, zf, zb = 4.2, 1.2, 3.4, 2.6, 2.05
    for sx in (-1, 1):
        for (y, h) in ((y0, zf), (y1, zb)):
            shed.add(prim_box(.2, .2, h, bevel=.02), "wood_mid", matrix=T(sx * w / 2, y, h / 2), uv="box", long_axis=2)
        shed.add(prim_box(.12, .9, .12, bevel=.01), "wood_mid", matrix=T(sx * w / 2, y0 + .45, zf - .4) @ R(-.75, 0, 0), uv="box", long_axis=1)
    shed.add(prim_box(w + .5, .2, .22, bevel=.02), "wood_mid", matrix=T(0, y0, zf), uv="box", long_axis=0)
    shed.add(prim_box(w + .5, .2, .22, bevel=.02), "wood_mid", matrix=T(0, y1, zb), uv="box", long_axis=0)
    for sx in (-1, 1):
        shed.add(prim_box(.14, .5, .12), "wood_mid", matrix=T(sx * (w / 2 - .3), y0 + .2, zf - .3) @ R(0, sx * .7, 0))
    ang = math.atan2(zf - zb, y1 - y0)
    L = math.hypot(zf - zb, y1 - y0) + .7
    n = 11
    for i in range(n):
        x = -(w + .6) / 2 + (i + .5) * (w + .6) / n
        shed.add(prim_box((w + .6) / n - .02, L, .08, bevel=.01), "wood_light",
                 matrix=T(x, (y0 + y1) / 2, (zf + zb) / 2 + .16 + rng.uniform(-.01, .01)) @ R(-ang, 0, 0), uv="box", long_axis=1, rng=rng)
    plank_wall(shed, T(0, y1 + .05, 0), w, zb, "wood_mid", rng)
    for sx in (-1, 1):
        plank_wall(shed, T(sx * w / 2, (y0 + y1) / 2 + .55, 0) @ R(0, 0, math.pi / 2), 1.1, .9, "wood_mid", rng)
    # forge: stone blocks around a glowing hearth, chimney through the roof
    fc = Vector((1.0, 2.75, 0))
    forge.add(prim_box(1.2, 1.0, .85, bevel=.04), "stone_grey", matrix=Matrix.Translation(fc) @ T(0, 0, .42), uv="world")
    for row in range(3):
        for k in range(4 - (row % 2)):
            x = -.45 + k * .3 + (row % 2) * .15
            if row == 1 and abs(x) < .25:
                continue
            blk = prim_box(.27, .12, .26, bevel=.03)
            lumpy(blk, .01, 5, row * 7 + k)
            forge.add(blk, "stone_grey", matrix=Matrix.Translation(fc) @ T(x, -.52, .15 + row * .28), uv="world")
    forge.add(prim_box(.42, .1, .3), "mud_dark", matrix=Matrix.Translation(fc) @ T(0, -.5, .45))
    forge.add(blob(.18, 1.1, .5, .35, amp=.25, freq=6), "coal_glow", matrix=Matrix.Translation(fc) @ T(0, -.52, .34), smooth=True)
    for k in range(3):
        forge.add(prim_tube([(-.1 + k * .1, -.55, .33), (-.08 + k * .1, -.56, .45 + .07 * (k % 2)), (-.1 + k * .1, -.57, .55)], [.06, .04, 0], segs=6), "fire",
                  matrix=Matrix.Translation(fc), smooth=True)
    for k, (wdt, h) in enumerate(((.95, .5), (.75, .5), (.55, .55), (.45, .6))):
        z = .85 + sum(x[1] for x in ((.95, .5), (.75, .5), (.55, .55), (.45, .6))[:k])
        blk = prim_box(wdt, wdt * .85, h, bevel=.04)
        lumpy(blk, .015, 4, k)
        forge.add(blk, "stone_grey", matrix=Matrix.Translation(fc) @ T(0, .05, z + h / 2), uv="world")
    # bellows on a frame
    bc = Matrix.Translation((1.95, 2.45, 0)) @ R(0, 0, .5)
    for sx in (-1, 1):
        tools.add(prim_box(.06, .06, .5), "wood_mid", matrix=bc @ T(sx * .2, 0, .25))
    tools.add(prim_box(.5, .5, .06), "wood_mid", matrix=bc @ T(0, 0, .5))
    tools.add(prim_tube([(0, .35, .7), (0, 0, .72), (0, -.45, .66)], [.04, .26, .06], segs=10, flat_y=.45), "leather", matrix=bc @ R(0, math.pi / 2, 0) @ R(0, -math.pi / 2, 0), smooth=True)
    tools.add(prim_box(.5, .9, .04), "wood_mid", matrix=bc @ T(0, -.05, .84) @ R(.08, 0, 0), uv="box")
    tools.add(prim_tube([(0, .45, .82), (0, .7, .9)], [.025, .025], segs=6), "wood_dark", matrix=bc)
    # anvil on a stump, smith hammering
    ac = Matrix.Translation((-.1, 1.85, 0))
    tools.add(prim_cyl(.3, .27, .45, segs=12), "bark", matrix=ac, smooth=True)
    tools.add(prim_cyl(.26, .26, .01, segs=12, z0=.45), "wood_raw", matrix=ac)
    tools.add(prim_box(.24, .18, .1), "steel", matrix=ac @ T(0, 0, .5))
    tools.add(prim_box(.12, .1, .12), "steel", matrix=ac @ T(0, 0, .6))
    tools.add(prim_box(.4, .18, .1, bevel=.01), "steel", matrix=ac @ T(.03, 0, .71))
    tools.add(prim_tube([(-.17, 0, .72), (-.36, 0, .74)], [.06, 0], segs=8), "steel", matrix=ac)
    tools.add(prim_box(.12, .05, .03), "coal_glow", matrix=ac @ T(.05, 0, .78))
    hand = chibi(people, rng, W((-.65, 1.45, 0), 1.05), "smith", "hammer")
    hr = hand["hand_r"]
    people["body"].add(prim_tube([(0, 0, -.05), (0, 0, .32)], [.018, .018], segs=6), "wood_dark", matrix=hr @ R(1.4, 0, 0))
    people["body"].add(prim_box(.07, .16, .07), "steel", matrix=hr @ R(1.4, 0, 0) @ T(0, 0, .32))
    for k in range(6):  # sparks
        a = k * 1.05
        tools.add(blob(.018, subdiv=1), "coal_glow", matrix=ac @ T(math.cos(a) * (.15 + k * .03), math.sin(a) * .1 - .05, .85 + k * .04))
    # quench barrel, buckets, wall rack with horseshoes and rims, crate with cloth, leaning wheel
    barrel(tools, Matrix.Translation((-1.3, 2.4, 0)), h=.7, r=.32)
    tools.add(prim_cyl(.27, .27, .01, segs=14, z0=.64), "water", matrix=Matrix.Translation((-1.3, 2.4, 0)))
    bucket(tools, Matrix.Translation((-.75, 2.3, 0)), water=True)
    bucket(tools, Matrix.Translation((.55, 2.25, 0)))
    for k in range(4):
        hs = prim_tube([(-.07, 0, 0), (-.08, 0, .09), (0, 0, .14), (.08, 0, .09), (.07, 0, 0)], [.014] * 5, segs=5, flat_y=.6)
        tools.add(hs, "iron", matrix=T(-.9 + k * .22, y1 - .02, 1.55))
        tools.add(prim_cyl(.012, .012, .05, segs=4), "iron", matrix=T(-.9 + k * .22, y1 - .02, 1.67) @ R(math.pi / 2, 0, 0))
    for k in range(2):
        wheel(tools, T(.15 + k * .5, y1 - .06, 1.55) @ R(0, 0, math.pi / 2), r=.2, spokes=6, mat="iron")
    for k in range(3):
        tools.add(prim_tube([(0, 0, 0), (0, 0, .4)], [.012, .012], segs=4), "iron", matrix=T(-1.6 + k * .12, y1 - .03, 1.2) @ R(0, .12 * (k - 1), 0))
        tools.add(prim_box(.04, .03, .1), "iron", matrix=T(-1.6 + k * .12, y1 - .03, 1.15))
    crate(tools, Matrix.Translation((-1.75, 1.6, 0)) @ R(0, 0, .2), .6)
    tools.add(blob(.32, 1, .9, .18, amp=.2, freq=5), "burlap", matrix=T(-1.75, 1.6, .64) @ R(0, 0, .2), smooth=True)
    wheel(tools, T(-2.15, 1.05, .42) @ R(0, -.3, .2) @ R(0, 0, math.pi / 2 - .3), r=.42)
    logs_pile(tools, T(2.55, 2.9, 0) @ R(0, 0, math.pi / 2) @ S(.8))
    crate(tools, Matrix.Translation((1.75, 3.05, 0)), .5)
    # ground: dirt floor with stepping stones, fence stubs, plants
    ground_patch(deco, T(0, 2.3, 0), 2.6, 1.5, "dirt", seed=4)
    for k in range(7):
        deco.add(blob(.12, 1.3, 1, .15, amp=.2, freq=5, seed=k), "stone_grey", matrix=T(-1.2 + k * .38, .7 + (k % 2) * .15, .01), smooth=True)
    fence(deco, T(-4.2, 1.6, 0), 1.9)
    fence(deco, T(2.4, 1.6, 0), 1.9)
    for (x, y, r) in ((-3.0, .9, .4), (3.4, 3.2, .5)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-3.2, 2.6, 1.1), (3.1, 1.0, 1.0), (-2.6, .4, .9), (2.8, .3, .9), (.2, .3, .8), (-3.6, 3.6, 1.2), (3.7, 2.2, 1.0)])
    for p in (shed, forge, tools, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_box("shed", coll, (w + .4, 2.4, 2.6), (0, 2.3, 1.3), root)
    empty("cam_focus", coll, (.2, 1.8, .9), root, .3, "SPHERE")
    empty("light_forge", coll, (1.0, 2.1, .6), root, .2)


def build_ev05_captive(coll, root, rng):
    """A wagon driver tied to a lone pine in a clearing 6 m off the road; arrows poke out of the bushes."""
    trunk, needles, props, people, bushes, deco, pl = Part("pine_trunk"), Part("pine_needles"), Part("props"), {"body": Part("captive")}, Part("bushes"), Part("ground_details"), Part("plants")
    tc = Vector((.2, 6.4, 0))
    pine(trunk, needles, rng, Matrix.Translation(tc), h=6.8)
    chibi(people, rng, W(tc + Vector((0, -.42, 0)), 0), "driver", "tied")
    for k in range(4):
        trunk.add(prim_torus(.42, .028, segs=18, rsegs=5), "rope", matrix=Matrix.Translation(tc) @ T(0, -.12, .5 + k * .08) @ S(1, 1.15, 1) @ R(.05 * (k % 2), 0, 0))
    # overturned wheelbarrow and spilled sacks
    wb = Matrix.Translation(tc + Vector((1.35, -.7, 0))) @ R(0, 0, .6) @ T(0, 0, .32) @ R(1.9, 0, 0)
    props.add(prim_box(.7, .9, .05, bevel=.01), "wood_mid", matrix=wb, uv="box", long_axis=1)
    for sx in (-1, 1):
        props.add(prim_box(.05, .9, .3, bevel=.01), "wood_light", matrix=wb @ T(sx * .35, 0, .15), uv="box", long_axis=1)
        props.add(prim_box(.05, 1.0, .05), "wood_mid", matrix=wb @ T(sx * .25, .85, -.05), uv="box", long_axis=1)
        props.add(prim_box(.05, .05, .25), "wood_mid", matrix=wb @ T(sx * .25, .3, -.15))
    props.add(prim_box(.7, .05, .3, bevel=.01), "wood_light", matrix=wb @ T(0, -.45, .15), uv="box")
    wheel(props, wb @ T(0, -.6, -.05), r=.2, spokes=6)
    sack(props, Matrix.Translation(tc + Vector((.85, -.95, 0))) @ R(1.4, 0, .4) @ T(0, 0, -.15) @ S(.8), seed=2)
    sack(props, Matrix.Translation(tc + Vector((.55, -1.25, 0))) @ S(.75), seed=5)
    # bushes ring the clearing; arrows and a bow tip stick out
    spots = [(-1.9, 1.5, .95, 2), (2.1, 1.8, .85, 1), (-2.8, 4.4, .9, 1), (2.9, 4.6, .9, 0), (-1.8, 6.6, .8, 0), (2.4, 7.0, .9, 0), (-3.2, 2.9, .7, 0)]
    for (x, y, r, n) in spots:
        bush(bushes, rng, T(x, y, 0), r=r)
        for k in range(n):
            arrow(bushes, T(x + (k - .5) * .35, y - r * .3, r * 1.0) @ R(-.6 + k * .3, .3 - k * .5, 0) @ R(math.pi, 0, 0) @ T(0, 0, -.7))
    bow = [(-1.6 + .02 * k, .9 + .01 * k * k, 1.0 + .07 * k) for k in range(8)]
    bushes.add(prim_tube(bow, [.02] * 8, segs=5), "wood_dark", smooth=True)
    footpath(deco, [(-.3, -.4), (.1, 1.2), (-.2, 2.6), (.1, 4.0), (.15, 5.2)], width=1.0, seed=3)
    ground_patch(deco, Matrix.Translation(tc + Vector((0, -.9, 0))), 2.0, 1.4, "grass_ground", seed=9, z=.008)
    for (x, y, r) in ((-1.0, 5.4, .3), (1.7, 6.0, .35), (-.8, .9, .2)):
        rock(deco, rng, T(x, y, 0), r=r, moss=r > .25)
    plants(pl, rng, [(-1.0, 3.0, .9), (1.2, 3.3, .9), (-2.3, 5.6, 1.0), (2.3, 5.8, 1.0), (.9, .7, .8), (-2.6, .5, .9), (2.8, .6, .9)])
    for p in (trunk, needles, props, people["body"], bushes, deco, pl):
        p.build(coll, parent=root)
    col_box("pine", coll, (.8, .8, 3.0), (tc.x, tc.y, 1.5), root)
    empty("cam_focus", coll, (tc.x, tc.y - 1.0, .8), root, .3, "SPHERE")


def build_ev06_cage(coll, root, rng):
    """Bandit stop by the road: cage cart with two drivers, campfire with a pot, guard counting coins."""
    cartp, camp, people, deco, pl = Part("cage_cart"), Part("camp"), {"body": Part("people")}, Part("ground_details"), Part("plants")
    cm = Matrix.Translation((-1.9, 2.3, 0)) @ R(0, 0, -math.pi / 2 + .12)
    cart(cartp, cm, cage=True)
    chibi(people, rng, cm @ T(-.15, -.35, .53) @ R(0, 0, math.pi / 2 - .12) @ S(.85), "driver", "sit_hold")
    chibi(people, rng, cm @ T(.12, .35, .53) @ R(0, 0, math.pi / 2 - .12) @ S(.85), "driver_b", "sit_hold")
    fc = Matrix.Translation((.15, 2.3, 0))
    campfire(camp, rng, fc)
    tripod_pot(camp, fc)
    bt = Matrix.Translation((1.05, 1.75, 0))
    barrel(camp, bt, h=.72, r=.3)
    coins(camp, bt @ T(0, 0, .72), stacks=((-.06, 0, 7), (.07, .04, 4), (.05, -.08, 2)))
    lg = Matrix.Translation((1.75, 2.05, 0))
    camp.add(prim_tube([(-.55, 0, .26), (.55, 0, .26)], [.2, .2], segs=12), "bark", matrix=lg, smooth=True)
    for ex in (-.55, .55):
        camp.add(prim_cyl(.19, .19, .01, segs=12), "wood_raw", matrix=lg @ T(ex, 0, .26) @ R(0, math.pi / 2, 0))
        camp.add(prim_box(.08, .3, .1), "wood_mid", matrix=lg @ T(ex * .7, 0, .05))
    g = chibi(people, rng, lg @ T(.1, .02, .03) @ R(0, 0, .35), "guard_bandit", "sit_log")
    kr = g["U"] @ T(.14, -.12, .4)
    people["body"].add(prim_torus(.05, .008, segs=10, rsegs=4), "steel", matrix=kr @ R(math.pi / 2, 0, 0))
    for k in range(3):
        people["body"].add(prim_box(.012, .012, .1), "steel", matrix=kr @ T(-.02 + k * .02, -.01, -.08) @ R(0, (k - 1) * .25, 0))
    coins(people["body"], g["hand_r"] @ T(0, 0, .02), stacks=((0, 0, 1),))
    # awning, lantern, barrels, crates behind
    for (x, y, h) in ((-.5, 3.4, 2.0), (2.5, 3.4, 2.0), (-.5, 2.75, 1.7), (2.5, 2.75, 1.7)):
        camp.add(prim_tube([(x, y, 0), (x, y, h)], [.05, .045], segs=6), "wood_mid")
        camp.add(prim_torus(.06, .02, segs=8, rsegs=4), "rope", matrix=T(x, y, h - .1))
    camp.add(prim_box(3.2, 1.0, .03), "cloth_tent", matrix=T(1.0, 3.05, 1.88) @ R(-.35, 0, 0))
    for k in range(6):
        camp.add(prim_prism_xz([(0, 0), (.25, 0), (.125, -.18)], .01), "cloth_tent", matrix=T(-.4 + k * .52, 2.58, 1.72))
    lt = Vector((2.5, 2.7, 1.45))
    camp.add(prim_box(.14, .14, .18), "lantern_glow", matrix=Matrix.Translation(lt))
    camp.add(prim_pyramid(.2, .09, z0=.09), "iron", matrix=Matrix.Translation(lt))
    camp.add(prim_box(.18, .18, .03), "iron", matrix=Matrix.Translation(lt) @ T(0, 0, -.1))
    for (x, y) in ((.4, 3.6), (1.0, 3.75)):
        barrel(camp, T(x, y, 0))
    crate(camp, T(1.9, 3.6, 0), .55)
    crate(camp, T(2.55, 2.3, 0) @ R(0, 0, .3), .5)
    fence(deco, T(3.0, .9, 0) @ R(0, 0, .5), 1.8)
    ground_patch(deco, T(.3, 2.4, 0), 2.6, 1.4, "dirt", seed=6)
    for (x, y, r) in ((-3.3, 3.4, .5), (3.4, 2.6, .4), (-.9, .9, .2)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-3.1, 1.6, 1.0), (3.3, 3.8, 1.1), (-.8, 4.0, 1.0), (.6, .8, .8), (-3.4, .6, .9), (2.2, .8, .9)])
    for p in (cartp, camp, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_box("cart", coll, (2.2, 1.4, 1.8), (-1.9, 2.3, .9), root)
    empty("cam_focus", coll, (.2, 2.0, .8), root, .3, "SPHERE")
    empty("light_fire", coll, (.15, 2.3, .6), root, .2)


def build_ev07_barn(coll, root, rng):
    """Village barn on fire at night, a well, a crying farm woman at the gate, a cow in the doorway."""
    barn, roof, fire, props, people, deco, pl = Part("barn"), Part("roof"), Part("fire"), Part("props"), {"body": Part("people")}, Part("ground_details"), Part("plants")
    bc = Vector((.9, 4.4, 0))
    w, d, h = 3.4, 3.0, 2.0
    B = Matrix.Translation(bc)
    for sx in (-1, 1):
        for sy in (-1, 1):
            barn.add(prim_box(.18, .18, h, bevel=.02), "wood_mid", matrix=B @ T(sx * w / 2, sy * d / 2, h / 2), uv="box", long_axis=2)
    plank_wall(barn, B @ T(0, d / 2, 0), w, h, "wood_light", rng, plank=.28)
    for sx in (-1, 1):
        plank_wall(barn, B @ T(sx * w / 2, 0, 0) @ R(0, 0, math.pi / 2), d, h, "wood_light", rng, plank=.28)
    for sx in (-1, 1):  # front wall beside the doors
        plank_wall(barn, B @ T(sx * (w / 2 - .3), -d / 2, 0), .6, h, "wood_light", rng, plank=.3)
    gable = prim_prism_xz([(-w / 2, 0), (w / 2, 0), (0, 1.25)], .06)
    for yy in (-d / 2, d / 2 + .06):
        barn.add(gable, "wood_light", matrix=B @ T(0, yy, h), uv="box") if yy < 0 else barn.add(prim_prism_xz([(-w / 2, 0), (w / 2, 0), (0, 1.25)], .06), "wood_light", matrix=B @ T(0, yy, h), uv="box")
    barn.add(prim_box(.3, .05, .35), "eye", matrix=B @ T(0, -d / 2 - .04, h + .45))
    barn.add(prim_box(w + .2, .14, .14), "wood_mid", matrix=B @ T(0, -d / 2 - .05, h), uv="box", long_axis=0)
    barn.add(prim_box(2.0, .1, 1.7), "eye", matrix=B @ T(0, -d / 2 + .05, .85))
    for sx, opn in ((-1, .25), (1, 1.2)):  # double doors, the right one swung open
        D = B @ T(sx * 1.0, -d / 2 - .03, 0) @ R(0, 0, sx * opn) @ T(-sx * .5, 0, 0)
        barn.add(prim_box(1.0, .06, 1.7, bevel=.01), "wood_mid", matrix=D @ T(0, 0, .85), uv="box", long_axis=2)
        barn.add(prim_box(1.15, .04, .1), "wood_dark", matrix=D @ T(0, -.04, .85) @ R(0, sx * .95, 0))
        for z in (.2, 1.5):
            barn.add(prim_box(.95, .04, .1), "wood_dark", matrix=D @ T(0, -.04, z))
    cow(props, B @ T(.1, -.6, 0) @ R(0, 0, .15) @ S(.75))
    # thatch roof (ridge along Y) with the crossed gable poles
    pitch = math.atan2(1.25, w / 2)
    sl = math.hypot(1.25, w / 2) + .45
    for sx in (-1, 1):
        Mr = B @ T(sx * (w / 4 + .12), 0, h + .62 - .12) @ R(0, sx * pitch, 0)
        roof.add(prim_box(sl, d + .7, .22, bevel=.05), "thatch", matrix=Mr, uv="box", long_axis=1)
        for k in range(3):
            roof.add(prim_box(.1, d + .75, .16, bevel=.04), "thatch", matrix=Mr @ T(-sl / 2 + .2 + k * sl / 3 * sx * sx, 0, .14), uv="box", long_axis=1)
    for yy in (-d / 2 - .35, d / 2 + .35):
        for sx in (-1, 1):
            roof.add(prim_tube([(0, yy, h + 1.25), (sx * .45, yy, h + 1.75)], [.06, .05], segs=6), "wood_dark", matrix=B)
    # fire on the roof + dark smoke
    for k in range(14):
        sx = rng.choice((-1, 1)); t = rng.uniform(.1, .9); y = rng.uniform(-d / 2, d / 2)
        base = Vector((sx * (w / 2 + .3) * (1 - t), y, h + .1 + 1.25 * t + .2))
        hh = rng.uniform(.5, 1.2)
        fire.add(prim_tube([base, base + Vector((rng.uniform(-.1, .1), 0, hh * .5)), base + Vector((rng.uniform(-.2, .2), 0, hh))],
                           [rng.uniform(.18, .3), .14, 0], segs=7), "fire", matrix=B, smooth=True)
    for k in range(3):
        fire.add(blob(.32 + k * .08, amp=.25, freq=3, seed=k), "smoke", matrix=B @ T(.25 * math.sin(k), .3 + .15 * k, h + 2.3 + k * .4), smooth=True)
    fire.add(blob(.3, 1.6, .2, .9, amp=.2, freq=4), "fire", matrix=B @ T(w / 2 + .02, -.3, 1.2), smooth=True)
    # hay, crates, wheel
    for (x, y, z) in ((-w / 2 - .35, -.6, .2), (-w / 2 - .35, .2, .2), (-w / 2 - .35, -.2, .58)):
        props.add(prim_box(.5, .75, .38, bevel=.06), "thatch", matrix=B @ T(x, y, z), uv="box", long_axis=1)
    wheel(props, B @ T(w / 2 + .3, -.9, .42) @ R(0, .25, 0), r=.42)
    crate(props, B @ T(w / 2 + .4, .4, 0), .5)
    # well with buckets
    wc = Matrix.Translation((-1.9, 2.0, 0))
    for i in range(10):
        a = 2 * math.pi * i / 10
        blk = prim_box(.36, .2, .6, bevel=.03)
        props.add(blk, "stone_grey", matrix=wc @ T(math.cos(a) * .55, math.sin(a) * .55, .3) @ R(0, 0, a + math.pi / 2), uv="world")
    props.add(prim_cyl(.5, .5, .02, segs=14, z0=.4), "eye", matrix=wc)
    for sx in (-1, 1):
        props.add(prim_box(.1, .1, 1.5), "wood_mid", matrix=wc @ T(sx * .65, 0, .9), uv="box", long_axis=2)
    props.add(prim_cyl(.07, .07, 1.4, segs=8, z0=-.7), "wood_dark", matrix=wc @ T(0, 0, 1.3) @ R(0, math.pi / 2, 0))
    props.add(prim_torus(.09, .03, segs=10, rsegs=4), "rope", matrix=wc @ T(0, 0, 1.3) @ R(0, math.pi / 2, 0))
    props.add(prim_tube([(0, -.05, 1.25), (0, -.05, .95)], [.01, .01], segs=4), "rope", matrix=wc)
    bucket(props, wc @ T(0, -.05, .7))
    for sx in (-1, 1):
        props.add(prim_box(.8, 1.0, .05), "wood_mid", matrix=wc @ T(0, sx * .35, 1.75) @ R(sx * .7, 0, 0), uv="box")
    bucket(props, Matrix.Translation((-1.2, 1.55, 0)), water=True)
    bucket(props, Matrix.Translation((-1.0, 1.85, 0)) @ R(1.4, 0, .4) @ T(0, 0, -.12))
    # crying farm woman at the open gate
    chibi(people, rng, W((-2.85, 1.25, 0), .25), "farm_woman", "cry", eyes="closed")
    fence(deco, T(-4.3, .7, 0), 3.2, gate_at=1.0, open_gate=1.2)
    fence(deco, T(-1.0, .7, 0), 1.0)
    fence(deco, T(3.0, 2.4, 0) @ R(0, 0, math.pi / 2), 3.0)
    ground_patch(deco, T(-.4, 2.6, 0), 2.8, 1.8, "soil", seed=11)
    for (x, y, r) in ((-3.6, 3.6, .45), (3.5, 1.2, .35)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-3.4, 2.2, 1.0), (2.4, 1.2, .9), (-.2, 1.0, .8), (3.6, 5.6, 1.1), (-3.0, 5.2, 1.1)], ferns=False)
    for p in (barn, roof, fire, props, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_box("barn", coll, (w + .4, d + .4, 2.4), (bc.x, bc.y, 1.2), root)
    col_box("well", coll, (1.3, 1.3, .7), (-1.9, 2.0, .35), root)
    empty("cam_focus", coll, (-.6, 2.4, 1.0), root, .3, "SPHERE")
    empty("light_fire", coll, (bc.x, bc.y - .5, 3.2), root, .2)


def build_ev08_tower(coll, root, rng):
    """Old hunting tower on four log posts; ladder with a broken rung, quiver and torn cloak up top."""
    tower, gear, deco, pl, bushes = Part("tower"), Part("gear"), Part("ground_details"), Part("plants"), Part("bushes")
    c = Vector((.2, 2.7, 0))
    Mc = Matrix.Translation(c)
    hp, s = 3.3, .8
    for sx in (-1, 1):
        for sy in (-1, 1):
            tower.add(prim_tube([(sx * (s + .08), sy * (s + .08), -.02), (sx * s, sy * s, hp + .1)], [.17, .14], segs=10, rough=.08, seed=sx + sy * 3, uvscale=1.2),
                      "wood_mid", matrix=Mc, smooth=True)
    for sy in (-1, 1):  # X braces
        for k in (-1, 1):
            tower.add(prim_tube([(-s, sy * s, 1.0 + (k + 1) * .5), (s, sy * s, 2.0 - (k + 1) * .5 + 1.0)], [.06, .06], segs=6), "wood_mid", matrix=Mc)
    for sx in (-1, 1):
        tower.add(prim_tube([(sx * s, -s, 1.2), (sx * s, s, 2.6)], [.06, .06], segs=6), "wood_mid", matrix=Mc)
    for k in range(9):
        tower.add(prim_box(.24, 2.1, .1, bevel=.01), "wood_light", matrix=Mc @ T(-.96 + k * .24, 0, hp + .05), uv="box", long_axis=1, rng=rng)
    for sy in (-1, 1):
        tower.add(prim_box(2.15, .16, .16, bevel=.02), "wood_mid", matrix=Mc @ T(0, sy * s, hp - .08), uv="box", long_axis=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tower.add(prim_box(.12, .12, .95, bevel=.015), "wood_mid", matrix=Mc @ T(sx * .95, sy * .95, hp + .55), uv="box", long_axis=2)
    for z in (hp + .5, hp + .95):
        for sy in (-1, 1):
            tower.add(prim_box(2.0, .08, .1, bevel=.01), "wood_mid", matrix=Mc @ T(0, sy * .95, z), uv="box", long_axis=0)
        for sx in (-1, 1):
            tower.add(prim_box(.08, 2.0, .1, bevel=.01), "wood_mid", matrix=Mc @ T(sx * .95, 0, z), uv="box", long_axis=1)
    for k in range(3):  # notches on the front-left post
        tower.add(prim_box(.08, .06, .03), "mud_dark", matrix=Mc @ T(-s - .02, -s - .14, 1.3 + k * .12) @ R(0, .3, 0))
    # ladder leaning against the front with a broken rung
    a0, a1 = Vector((.3, -2.0, 0)), Vector((.3, -s - .1, hp + .1))
    for sx in (-1, 1):
        tower.add(prim_tube([a0 + Vector((sx * .26, 0, 0)), a1 + Vector((sx * .26, 0, 0))], [.05, .045], segs=6), "wood_light", matrix=Mc, smooth=True)
    n = 9
    for k in range(n):
        t = (k + .6) / (n + .4)
        p = a0.lerp(a1, t)
        if k == 3:
            for sx in (-1, 1):
                tower.add(prim_tube([p + Vector((sx * .26, 0, 0)), p + Vector((sx * .12, 0, -.05 * sx))], [.03, .02], segs=5), "wood_light", matrix=Mc)
            continue
        tower.add(prim_tube([p + Vector((-.26, 0, 0)), p + Vector((.26, 0, 0))], [.03, .03], segs=5), "wood_light", matrix=Mc)
    # quiver on the rear-left post, torn cloak over the front rail
    q = Mc @ T(-.95, -.8, hp + .6) @ R(.15, 0, 0)
    gear.add(prim_cyl(.09, .1, .5, segs=10), "leather", matrix=q, smooth=True)
    for z in (.08, .4):
        gear.add(prim_torus(.1, .014, segs=10, rsegs=4), "leather_dark", matrix=q @ T(0, 0, z))
    for k in range(4):
        arrow(gear, q @ T(-.04 + k * .025, (k % 2) * .03, .2) @ R(.1 * (k - 1.5), .08 * k, 0) @ R(math.pi, 0, 0) @ T(0, 0, -.62), .62)
    cl = prim_prism_xz([(-.35, 0), (.35, 0), (.42, -.75), (.3, -.6), (.2, -.85), (.05, -.65), (-.08, -.9), (-.2, -.62), (-.33, -.8), (-.42, -.6)], .03)
    gear.add(cl, "cloth_green", matrix=Mc @ T(.35, -.97, hp + .98) @ R(.05, 0, 0), uv="box")
    gear.add(prim_prism_xz([(-.35, 0), (.35, 0), (.3, -.35), (-.3, -.35)], .03), "cloth_green", matrix=Mc @ T(.35, -.9, hp + 1.0) @ R(-1.4, 0, 0), uv="box")
    for (x, y, r) in ((-1.7, 2.0, .8), (1.9, 2.4, .7), (-1.0, 4.0, .9), (1.5, 4.2, .8)):
        bush(bushes, rng, T(x, y, 0), r=r)
    rock(deco, rng, T(-2.5, 1.2, 0), r=.5)
    ground_patch(deco, T(.2, 2.2, 0), 1.8, 1.4, "soil", seed=13)
    plants(pl, rng, [(-1.2, 1.0, 1.0), (1.4, 1.2, 1.0), (.2, 3.0, .9), (-2.6, 2.8, 1.1), (2.7, 3.2, 1.1), (2.5, .6, .9), (-.9, .5, .8)])
    for p in (tower, gear, bushes, deco, pl):
        p.build(coll, parent=root)
    col_box("tower", coll, (2.0, 2.0, 3.4), (c.x, c.y, 1.7), root)
    empty("cam_focus", coll, (c.x, c.y - 1.0, 2.0), root, .3, "SPHERE")


def build_ev09_cache(coll, root, rng):
    """Bandit cache under the roots of a huge oak: half dug-out chest, pouches, a bear trap, crows."""
    bark, leaves, props, birds, deco, pl = Part("tree_trunk"), Part("tree_crown"), Part("cache"), Part("crows"), Part("ground_details"), Part("plants")
    tm = W((.5, 5.4, 0), -.15)
    old_tree(bark, leaves, rng, tm, crown=1.05)
    bark.add(blob(.55, 1.2, .6, .7), "eye", matrix=tm @ T(-.1, -1.05, .35), smooth=True)  # burrow
    bark.add(prim_tube([(-.6, 0, 3.0), (-1.4, -.3, 3.5), (-2.1, -.5, 3.7)], [.18, .1, .05], segs=7), "bark_oak", matrix=tm, smooth=True)
    crow(birds, tm @ T(-1.75, -.42, 3.62) @ R(0, 0, -.5))
    for (x, y, z, a) in ((-1.2, 1.0, 8.0, .3), (.8, -.3, 8.6, -.4), (2.0, .6, 7.7, 2.5)):
        crow(birds, tm @ T(x, y, z) @ R(0, 0, a) @ S(1.3), flying=True)
    ch = Matrix.Translation((.1, 4.05, 0)) @ R(.28, 0, .3) @ T(0, 0, -.06)
    chest(props, ch, open_=True)
    props.add(prim_box(.06, .3, .02), "wood_dark", matrix=ch @ T(.25, -.22, .2) @ R(0, .3, .2))
    spill = Matrix.Translation((.1, 3.55, 0))
    for k, (x, y) in enumerate(((-.45, -.05), (.5, -.15), (.15, -.35))):
        props.add(blob(.1, 1, 1, .9, amp=.1, freq=6, seed=k), "leather", matrix=spill @ T(x, y, .09), smooth=True)
        props.add(prim_torus(.035, .012, segs=8, rsegs=3), "rope", matrix=spill @ T(x, y, .18))
    for k, (x, y) in enumerate(((-.2, -.3), (.32, .02))):
        props.add(prim_cyl(.06, .06, .14, segs=10, z0=-.07), "bandage", matrix=spill @ T(x, y, .06) @ R(0, math.pi / 2, k), smooth=True)
    for k, (x, y) in enumerate(((-.62, .18), (.7, .12), (-.05, -.55))):
        bottle(props, spill @ T(x, y, 0) @ (R(1.4, 0, k) if k == 2 else Matrix.Identity(4)) @ (T(0, 0, -.06) if k == 2 else Matrix.Identity(4)), "glass_blue" if k != 1 else "glass_green", h=.2)
    bear_trap(props, T(1.55, 2.55, 0))
    for k in range(40):  # fallen leaves
        a = rng.uniform(0, 6.28); r = rng.uniform(0, 1.3)
        deco.add(blob(.07, 1.3, .9, .12, subdiv=1), rng.choice(("bread", "copper", "leaves_oak")), matrix=T(.7 + math.cos(a) * r, 3.2 + math.sin(a) * r * .8, .012) @ R(0, 0, a))
    ground_patch(deco, T(.2, 3.9, 0), 1.6, 1.0, "soil_dark", seed=17, z=.014)
    footpath(deco, [(-.6, -.4), (-.4, 1.0), (-.1, 2.2), (.1, 3.1)], width=.7, seed=5)
    for (x, y, r) in ((-2.5, 2.0, .5), (2.6, 2.8, .45), (-1.2, 1.0, .2)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-1.6, 1.5, 1.0), (1.4, 1.2, .9), (-2.4, 3.4, 1.1), (2.7, 4.0, 1.1), (-.9, 2.6, .8), (2.8, 1.0, .9), (-2.9, .5, .9)])
    for p in (bark, leaves, props, birds, deco, pl):
        p.build(coll, parent=root)
    col_box("tree", coll, (2.0, 2.0, 3.0), (.5, 5.4, 1.5), root)
    empty("cam_focus", coll, (.3, 3.6, .6), root, .3, "SPHERE")


def build_ev10_turncoat(coll, root, rng):
    """A young bandit steps out of the bushes with his hands up; his knife lies in the grass."""
    people, props, bushes, bark, leaves, deco, pl = {"body": Part("turncoat")}, Part("props"), Part("bushes"), Part("tree_trunk"), Part("tree_crown"), Part("ground_details"), Part("plants")
    chibi(people, rng, W((-.1, 1.7, 0), .2), "turncoat", "hands_up")
    knife(props, T(.85, 1.15, .02) @ R(0, 0, -.5))
    old_tree(bark, leaves, rng, W((-.6, 5.6, 0), .4, .62), crown=.9)
    for (x, y, r) in ((-1.2, 2.5, .9), (.7, 2.9, .95), (-2.3, 1.9, .75), (1.9, 2.4, .8), (-.3, 3.4, .8)):
        bush(bushes, rng, T(x, y + .3, 0), r=r * .72)
    for (x, y, r) in ((-2.6, .8, .45), (2.6, 1.4, .5), (1.5, .5, .2)):
        rock(deco, rng, T(x, y, 0), r=r)
    ground_patch(deco, T(.2, 1.4, 0), 1.3, .8, "soil", seed=19)
    plants(pl, rng, [(-1.4, .9, .9), (1.0, 1.9, .8), (-2.8, 2.9, 1.0), (2.9, 3.0, 1.0), (.3, .5, .7)])
    for p in (people["body"], props, bushes, bark, leaves, deco, pl):
        p.build(coll, parent=root)
    empty("cam_focus", coll, (0, 1.6, .9), root, .3, "SPHERE")


def build_ev11_idol(coll, root, rng):
    """Mossy stone idol of an old forest god holding a heap of copper coins; ribbons and offerings."""
    idol, moss, gifts, bark, leaves, deco, pl = Part("idol"), Part("moss"), Part("offerings"), Part("tree_trunk"), Part("tree_crown"), Part("ground_details"), Part("plants")
    c = Matrix.Translation((.1, 2.7, 0))
    for k, (x, y, r) in enumerate(((-.7, -.1, .42), (.75, -.05, .45), (-.35, -.55, .3), (.4, -.55, .32), (0, .5, .5), (-.8, .5, .35), (.85, .45, .38))):
        rock(idol, rng, c @ T(x, y, 0), r=r, flat=.8)
    body = prim_lathe([(.0, .2), (.55, .2), (.6, .5), (.55, .9), (.45, 1.2), (.3, 1.32), (.0, 1.34)], segs=16, uvscale=.6)
    body.transform(S(1, .8, 1))
    lumpy(body, .03, 3, 2)
    idol.add(body, "stone", matrix=c, uv="world", smooth=True)
    H = c @ T(0, -.02, 1.62)
    head = blob(.36, .95, .85, 1.05, amp=.04, freq=3)
    idol.add(head, "stone", matrix=H, uv="world", smooth=True)
    for sx in (-1, 1):
        idol.add(blob(.08, .8, .4, 1.2), "eye", matrix=H @ T(sx * .13, -.27, .05), smooth=True)
        idol.add(blob(.08, .5, .7, .9), "stone", matrix=H @ T(sx * .33, 0, 0), uv="world", smooth=True)
        idol.add(prim_tube([(sx * .5, -.1, 1.15), (sx * .48, -.35, .95), (sx * .18, -.52, .92)], [.13, .12, .11], segs=8), "stone", matrix=c, uv="world", smooth=True)
        idol.add(blob(.13, 1, 1, .7), "stone", matrix=c @ T(sx * .14, -.55, .9), uv="world", smooth=True)
    idol.add(prim_box(.12, .03, .02), "eye", matrix=H @ T(0, -.31, -.17))
    coin_heap(idol, rng, c @ T(0, -.55, .98), n=30, r=.17)
    for k in range(12):  # moss drapes
        a = rng.uniform(-2.6, -.5) if k < 8 else rng.uniform(-3.1, .2)
        z = rng.uniform(.6, 1.9)
        rr = .58 if z < 1.3 else .36
        moss.add(blob(rng.uniform(.12, .22), 1, .5, 1.6, amp=.25, freq=5, seed=k), "moss",
                 matrix=c @ T(math.cos(a) * rr * (1 if z < 1.3 else .9), math.sin(a) * rr * .8 + (0 if z < 1.3 else -.02), z), uv="world", smooth=True)
    moss.add(blob(.3, 1.1, 1, .45, amp=.2, freq=5), "moss", matrix=H @ T(0, .04, .25), uv="world", smooth=True)
    for k in range(6):
        moss.add(prim_leaf(.18, .08, segs=3, curve=.3), "fern", matrix=H @ T(-.2 + k * .08, -.1, .3) @ R(0, 0, -1.57 + k * .3) @ R(0, -.4, 0))
    # ribbon tree behind, offerings in front
    old_tree(bark, leaves, rng, W((1.7, 4.4, 0), .7, .55), crown=.85)
    br = Matrix.Translation((-1.05, 3.0, 0))
    bark.add(prim_tube([(0, 0, 0), (.05, 0, 1.2), (-.2, -.05, 2.0)], [.09, .07, .03], segs=7), "bark", matrix=br, smooth=True)
    bark.add(prim_tube([(.03, 0, 1.3), (.5, -.1, 1.9)], [.05, .02], segs=6), "bark", matrix=br, smooth=True)
    for (x, z) in ((-.25, 2.05), (.55, 1.95)):
        leaves.add(blob(.35, amp=.1, freq=3), "leaves_oak", matrix=br @ T(x, 0, z + .1), uv="world", smooth=True)
    for k, mat in enumerate(("cloth_red", "cloth_blue", "cloth_red", "cloth_blue")):
        ribbon(gifts, br @ T(.03 * k - .02, -.08, 1.3 - (k // 2) * .25 + .25) @ R(0, 0, .3 * k), mat)
    apple(gifts, c @ T(-.25, -.95, 0))
    apple(gifts, c @ T(-.12, -1.0, 0))
    flower(gifts, c @ T(.25, -.95, 0))
    flower(gifts, c @ T(.4, -.85, 0), "petal_lavender")
    ground_patch(deco, T(.1, 2.3, 0), 1.6, 1.0, "soil", seed=23)
    plants(pl, rng, [(-1.8, 1.7, 1.0), (1.8, 1.6, 1.0), (-2.6, 3.2, 1.1), (2.8, 2.7, 1.1), (-.9, .8, .8), (.9, .9, .8)])
    for p in (idol, moss, gifts, bark, leaves, deco, pl):
        p.build(coll, parent=root)
    col_box("idol", coll, (1.6, 1.4, 2.0), (.1, 2.7, 1.0), root)
    empty("cam_focus", coll, (.1, 2.0, 1.1), root, .3, "SPHERE")


def build_ev12_corpse(coll, root, rng):
    """A dead mercenary against a fallen tree; split shield, travel sack, huge claw gouges in the earth."""
    log, people, props, birds, deco, pl, bark, leaves = Part("fallen_log"), {"body": Part("mercenary")}, Part("props"), Part("crow"), Part("ground_details"), Part("plants"), Part("tree_trunk"), Part("tree_crown")
    lc = Matrix.Translation((.3, 3.4, 0)) @ R(0, 0, -.12)
    log.add(prim_tube([(-2.6, 0, .55), (0, 0, .5), (2.6, 0, .4)], [.58, .52, .45], segs=14, rough=.12, seed=3, uvscale=1.4, caps=(False, True)),
            "bark", matrix=lc, smooth=True)
    for k in range(9):  # splintered broken end
        a = 2 * math.pi * k / 9
        d = Vector((0, math.cos(a), math.sin(a)))
        L = rng.uniform(.35, .85)
        log.add(prim_tube([Vector((-2.6, 0, .55)) + d * .4, Vector((-2.6 - L, 0, .55)) + d * .3 + Vector((0, 0, L * .3))], [.12, 0], segs=5), "wood_raw", matrix=lc)
    log.add(prim_cyl(.5, .5, .02, segs=12), "wood_raw", matrix=lc @ T(-2.6, 0, .55) @ R(0, -math.pi / 2, 0))
    for k in range(3):  # stump splinters left behind
        log.add(prim_tube([(-3.3 + k * .2, .4, 0), (-3.3 + k * .2, .45, .9 + k * .25)], [.16, 0], segs=6), "wood_raw", matrix=lc)
    log.add(prim_cyl(.48, .5, .25, segs=12), "bark", matrix=lc @ T(-3.1, .45, 0), smooth=True)
    for (x, ang, ln) in ((1.2, .8, 1.3), (1.9, .5, 1.0)):
        log.add(prim_tube([(x, 0, .8), (x + .3, .1, .8 + ln), (x + .6, .2, 1.1 + ln)], [.12, .07, .02], segs=7), "bark", matrix=lc, smooth=True)
    for k in range(4):
        log.add(blob(.3, 1.6, .8, .3, amp=.2, freq=4, seed=k), "moss", matrix=lc @ T(-1.8 + k * 1.1, 0, 1.0 - k * .03), uv="world", smooth=True)
    crow(birds, lc @ T(2.3, .2, 2.25) @ R(0, 0, -.8))
    # the mercenary, shield halves, travel sack
    chibi(people, rng, lc @ T(-.4, -.75, 0) @ R(0, 0, .05), "mercenary", "slump")
    for k, (x, a) in enumerate(((-1.45, .3), (-1.15, -.2))):
        sh = Matrix.Translation((x, 2.6, .3)) @ R(-1.2 + k * .2, 0, a)
        half = prim_cyl(.3, .3, .04, segs=16, z0=-.02)
        for v in half.verts:
            if (v.co.x > 0) == (k == 0):
                v.co.x = 0
        props.add(half, ["shield_planks"][0], matrix=sh @ R(math.pi / 2, 0, 0), uv="box")
        props.add(prim_torus(.3, .022, segs=16, rsegs=4), "iron", matrix=sh @ R(math.pi / 2, 0, 0) @ S(1, 1, 1)) if k == 0 else None
    props.add(blob(.08, 1, 1, .6), "steel", matrix=T(-1.3, 2.6, .3))
    bp = Matrix.Translation((.75, 2.9, 0)) @ R(0, 0, -.3)
    props.add(prim_box(.45, .3, .45, bevel=.08), "burlap", matrix=bp @ T(0, 0, .23), uv="box")
    props.add(prim_tube([(-.22, 0, .5), (.22, 0, .5)], [.09, .09], segs=10), "cloth_brown", matrix=bp, smooth=True)
    for x in (-.12, .12):
        props.add(prim_box(.05, .32, .47), "leather", matrix=bp @ T(x, 0, .24))
    # trampled path with four claw gouges
    footpath(deco, [(-.5, -.4), (-.4, .9), (-.15, 1.8), (0, 2.6)], width=1.3, seed=7)
    for k in range(4):
        g = blob(.5, .16, 1, .1, subdiv=2)
        deco.add(g, "mud_dark", matrix=T(-.65 + k * .28, 1.5 + k * .05, .015) @ R(0, 0, .45), smooth=True)
    for k in range(12):
        deco.add(blob(.05, 1, 1, .6, subdiv=1), "stone_grey", matrix=T(rng.uniform(-1.1, .6), rng.uniform(.6, 2.6), .01))
    old_tree(bark, leaves, rng, W((2.9, 4.6, 0), 2.6, .7), crown=.9)
    for (x, y, r) in ((-2.6, 1.8, .5), (2.4, 1.6, .55), (1.4, 1.1, .25)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-1.9, 1.0, 1.0), (1.5, 2.2, 1.0), (-2.8, 3.2, 1.1), (-.8, 4.4, 1.0), (1.2, 4.6, 1.0), (2.8, .6, .9), (-3.0, .4, .9)])
    for p in (log, people["body"], props, birds, deco, pl, bark, leaves):
        p.build(coll, parent=root)
    col_box("log", coll, (5.4, 1.1, 1.0), (.3, 3.4, .5), root, rot=(0, 0, -.12))
    empty("cam_focus", coll, (-.1, 2.6, .6), root, .3, "SPHERE")


def build_ev13_chapel(coll, root, rng):
    """Tiny roadside chapel of the Sun with a burning oil lamp; an old caretaker sweeps the doorstep."""
    ch, roofp, props, people, deco, pl = Part("chapel"), Part("roof"), Part("props"), {"body": Part("caretaker")}, Part("ground_details"), Part("plants")
    C = Matrix.Translation((-.2, 2.6, 0))
    w, d, h = 1.3, 1.1, 1.7
    ch.add(prim_box(w + .4, d + .3, .28, bevel=.03), "stone", matrix=C @ T(0, 0, .14), uv="world")
    for k in range(2):
        ch.add(prim_box(w * .8 - k * .2, .28, .14, bevel=.02), "stone", matrix=C @ T(0, -d / 2 - .28 - k * .0 + k * .14, .07 + k * .14 - (.07 if k == 0 else 0) + .0), uv="world")
    for sx in (-1, 1):
        for sy in (-1, 1):
            ch.add(prim_box(.14, .14, h, bevel=.015), "wood_mid", matrix=C @ T(sx * w / 2, sy * d / 2, .28 + h / 2), uv="box", long_axis=2)
    plank_wall(ch, C @ T(0, d / 2, .28), w, h, "wood_light", rng, plank=.22)
    for sx in (-1, 1):
        plank_wall(ch, C @ T(sx * w / 2, 0, .28) @ R(0, 0, math.pi / 2), d, h, "wood_light", rng, plank=.22)
        ch.add(prim_box(.22, .18, h - .2), "stone", matrix=C @ T(sx * (w / 2 - .1), -d / 2 - .05, .28 + (h - .2) / 2), uv="world")
    ch.add(prim_torus(.43, .09, segs=16, rsegs=4), "stone", matrix=C @ T(0, -d / 2 - .05, .28 + h - .55) @ R(math.pi / 2, 0, 0) @ S(1, 1, 2))
    ch.add(prim_box(w, .1, .5), "stone", matrix=C @ T(0, -d / 2 - .05, .28 + h - .02) @ S(1, 1, .5))
    ch.add(prim_box(w - .1, d - .1, .04), "wood_dark", matrix=C @ T(0, 0, .3))
    # altar shelf, oil lamp, donation box, sun on the back wall
    ch.add(prim_box(.6, .35, .5), "wood_mid", matrix=C @ T(0, .2, .55), uv="box")
    props.add(prim_lathe([(.0, 0), (.08, .02), (.11, .07), (.1, .08)], segs=12, uvscale=.2), "brass", matrix=C @ T(0, .2, .8), smooth=True)
    props.add(prim_tube([(0, 0, .06), (0, 0, .13), (.01, 0, .2)], [.035, .025, 0], segs=6), "lantern_glow", matrix=C @ T(0, .2, .8), smooth=True)
    props.add(prim_box(.22, .18, .16, bevel=.01), "wood_light", matrix=C @ T(.05, -.2, .38), uv="box")
    props.add(prim_box(.1, .02, .015), "eye", matrix=C @ T(.05, -.29, .44))
    sun = C @ T(0, d / 2 - .06, 1.45) @ R(math.pi / 2, 0, 0)
    props.add(prim_cyl(.13, .13, .03, segs=16), "gold", matrix=sun, smooth=True)
    for k in range(8):
        props.add(prim_pyramid(.05, .1, z0=0), "gold", matrix=sun @ R(0, 0, k * .785) @ T(.16, 0, 0) @ R(0, math.pi / 2, 0))
    # steep slate roof, ridge along Y, golden sun disc on top
    pitch = math.radians(55)
    sl = (w / 2 + .2) / math.cos(pitch)
    for sx in (-1, 1):
        Mr = C @ T(sx * (w / 2 + .2) / 2, 0, .28 + h + (w / 2 + .2) * math.tan(pitch) / 2) @ R(0, sx * pitch, 0)
        roofp.add(prim_box(sl, d + .5, .06), "wood_mid", matrix=Mr, uv="box")
        for r_ in range(4):
            for c_ in range(4 + r_ % 2):
                yy = -(d + .5) / 2 + (c_ + (0 if r_ % 2 else .5)) * (d + .5) / 4
                if abs(yy) > (d + .5) / 2 - .05:
                    continue
                roofp.add(prim_box(sl / 4 + .05, (d + .5) / 4 - .02, .05, bevel=.01), "roof_slate", matrix=Mr @ T(-sl / 2 + (r_ + .5) * sl / 4, yy, .055), uv="box", uvscale=.4)
    rz = .28 + h + (w / 2 + .2) * math.tan(pitch)
    for sy in (-1, 1):
        for sx in (-1, 1):
            roofp.add(prim_box(sl + .1, .1, .12), "wood_mid", matrix=C @ T(sx * (w / 2 + .2) / 2, sy * (d / 2 + .27), rz - (w / 2 + .2) * math.tan(pitch) / 2) @ R(0, sx * pitch, 0))
    roofp.add(prim_box(.16, .16, .25), "wood_mid", matrix=C @ T(0, -d / 2 - .2, rz))
    top = C @ T(0, -d / 2 - .2, rz + .45) @ R(math.pi / 2, 0, 0)
    roofp.add(prim_cyl(.17, .17, .05, segs=18, z0=-.025), "gold", matrix=top, smooth=True)
    for k in range(10):
        roofp.add(prim_pyramid(.07, .12, z0=0), "gold", matrix=top @ R(0, 0, k * .628) @ T(.2, 0, 0) @ R(0, math.pi / 2, 0))
    # caretaker sweeping, broom
    g = chibi(people, rng, W((.85, 1.55, 0), -.35), "caretaker", "sweep", eyes="closed")
    hm = g["hand_l"]
    b0 = (hm @ Vector((0, 0, 0)))
    tip = Vector((b0.x - .05, b0.y - .35, .12))
    people["body"].add(prim_tube([b0 + (b0 - tip).normalized() * .25, tip], [.016, .016], segs=6), "wood_mid")
    dd = (tip - b0).normalized()
    people["body"].add(prim_tube([tip - dd * .02, tip + dd * .25], [.04, .11], segs=10), "thatch", matrix=Matrix.Identity(4), smooth=True)
    for k in range(6):
        deco.add(blob(.03, 1.3, 1, .2, subdiv=1), "leaves_oak", matrix=T(.55 + k * .08, 1.05 + (k % 2) * .1, .01))
    # fences, flower pot, rocks
    fence(deco, T(-3.2, 1.6, 0), 2.2)
    fence(deco, T(1.5, 1.8, 0) @ R(0, 0, .25), 2.0)
    pot = T(-.95, 1.75, 0)
    props.add(prim_lathe([(.0, 0), (.12, 0), (.16, .25), (.15, .28)], segs=12, uvscale=.3), "terracotta", matrix=pot, smooth=True)
    for k in range(3):
        flower(props, pot @ T(-.06 + k * .06, (k % 2) * .05, .24))
    for (x, y, r) in ((-1.8, 2.6, .5), (1.4, 3.2, .45), (-2.6, .8, .3), (.8, 3.6, .55)):
        rock(deco, rng, T(x, y, 0), r=r)
    ground_patch(deco, T(-.1, 1.6, 0), 1.4, .7, "stone_plates", seed=29)
    plants(pl, rng, [(-1.2, 1.3, .8), (1.9, 2.6, 1.0), (-2.4, 3.4, 1.1), (2.6, 1.0, .9), (-3.0, 2.2, 1.0)])
    for p in (ch, roofp, props, people["body"], deco, pl):
        p.build(coll, parent=root)
    col_box("chapel", coll, (w + .4, d + .4, 2.6), (-.2, 2.6, 1.3), root)
    empty("cam_focus", coll, (.2, 2.0, 1.0), root, .3, "SPHERE")
    empty("light_lamp", coll, (-.2, 2.8, 1.0), root, .2)


def build_ev14_dice(coll, root, rng):
    """Caravan guards play dice on an upturned barrel by a campfire; spears lean on a crate."""
    camp, people, deco, pl, cartp = Part("camp"), {"body": Part("guards")}, Part("ground_details"), Part("plants"), Part("cart")
    bt = Matrix.Translation((.3, 2.3, 0))
    barrel(camp, bt, h=.7, r=.32)
    for k, (x, y, a) in enumerate(((-.08, .05, .3), (.06, -.06, .9), (.1, .08, .1))):
        dm = bt @ T(x, y, .74) @ R(0, 0, a)
        camp.add(prim_box(.05, .05, .05, bevel=.008), "bone", matrix=dm)
        for j in range(k + 1):
            camp.add(prim_cyl(.007, .007, .004, segs=6), "eye", matrix=dm @ T(-.012 + j * .012, -.012 + j * .012, .025))
    for (x, y) in ((-.18, -.12), (.2, .16), (-.15, .18)):
        mug(camp, bt @ T(x, y, .7))
    coins(camp, bt @ T(0, 0, .7), stacks=((.18, -.12, 3), (-.02, -.2, 2), (.05, .2, 1)))
    seats = [((-.42, 2.4), math.pi / 2 - .2, "guard", "closed"), ((.35, 2.98), .0, "guard_b", "open"), ((1.05, 2.35), -math.pi / 2 + .25, "guard_c", "open")]
    for (xy, yaw, look, eyes) in seats:
        sm = Matrix.Translation((xy[0], xy[1], 0)) @ R(0, 0, yaw)
        camp.add(prim_cyl(.2, .2, .38, segs=12), "bark", matrix=sm @ T(0, .12, 0), smooth=True)
        camp.add(prim_cyl(.18, .18, .01, segs=12, z0=.38), "wood_raw", matrix=sm @ T(0, .12, 0))
        g = chibi(people, rng, sm @ T(0, .12, 0), look, "sit_log", eyes=eyes)
        if look == "guard":
            mug(people["body"], g["hand_r"] @ T(0, 0, -.05))
    fc = Matrix.Translation((-1.35, 1.9, 0))
    campfire(camp, rng, fc)
    cr = Matrix.Translation((1.95, 3.1, 0))
    crate(camp, cr, .62)
    for k in range(2):
        sp = cr @ T(-.15 + k * .25, -.32, 0) @ R(-.25, .1 * k, 0)
        camp.add(prim_tube([(0, 0, 0), (0, 0, 2.0)], [.025, .025], segs=6), "wood_mid", matrix=sp)
        camp.add(prim_pyramid(.06, .18, z0=2.0), "steel", matrix=sp)
        camp.add(prim_torus(.03, .01, segs=8, rsegs=3), "brass", matrix=sp @ T(0, 0, 1.2))
    logs_pile(camp, T(2.6, 2.2, 0) @ R(0, 0, .3) @ S(.8))
    cart(cartp, Matrix.Translation((-2.5, 3.4, 0)) @ R(0, 0, .5))
    for (x, y) in ((-2.5, 3.6), (-2.4, 3.1)):
        crate(cartp, Matrix.Translation((x, y, .53)) @ R(0, 0, .5), .45)
    sack(cartp, T(-1.75, 3.0, 0), seed=7)
    barrel(cartp, T(-1.6, 3.6, 0))
    ground_patch(deco, T(-.2, 2.3, 0), 2.4, 1.2, "dirt", seed=31)
    for (x, y, r) in ((-3.0, 1.2, .4), (3.1, 3.6, .5)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-2.0, .8, .9), (1.6, 1.0, .9), (3.0, 1.4, 1.0), (-3.2, 2.4, 1.0), (.4, 4.0, 1.1), (-.8, 3.8, 1.0)])
    for p in (camp, people["body"], deco, pl, cartp):
        p.build(coll, parent=root)
    col_box("camp", coll, (2.0, 1.4, 1.0), (.3, 2.5, .5), root)
    empty("cam_focus", coll, (.2, 2.2, .8), root, .3, "SPHERE")
    empty("light_fire", coll, (-1.35, 1.9, .6), root, .2)


def build_ev15_hive(coll, root, rng):
    """Old linden with a wild beehive in a hollow, honey dripping; a round sticky badger below."""
    bark, leaves, hive, animals, deco, pl = Part("tree_trunk"), Part("tree_crown"), Part("hive"), Part("animals"), Part("ground_details"), Part("plants")
    tm = W((.9, 4.2, 0), -.2)
    old_tree(bark, leaves, rng, tm, crown=1.0)
    hv = tm @ T(-.05, -.78, 2.0)
    hive.add(blob(.32, 1, .35, 1.3), "eye", matrix=hv, smooth=True)
    hive.add(prim_torus(.3, .07, segs=16, rsegs=5), "bark_oak", matrix=hv @ T(0, -.06, 0) @ R(math.pi / 2, 0, 0) @ S(1, 1.3, 1), smooth=True)
    comb = prim_cyl(.26, .26, .04, segs=16)
    hive.add(comb, "honeycomb", matrix=hv @ T(0, -.06, 0) @ R(math.pi / 2, 0, 0) @ S(1, 1.25, 1), uv="box", uvscale=.25)
    honey_drips(hive, hv @ T(0, -.12, -.3), n=4, rng=rng)
    for k in range(12):
        a = rng.uniform(0, 6.28); r = rng.uniform(.4, 1.1)
        bee(hive, hv @ T(math.cos(a) * r, -abs(math.sin(a)) * r * .6 - .3, rng.uniform(-.3, .6)) @ R(0, 0, a) @ S(1.4))
    badger(animals, W((-.55, 2.95, 0), .35))
    hive.add(blob(.2, 1.2, 1, .2, amp=.2, freq=5), "honey", matrix=T(-.4, 2.55, .01), smooth=True)
    comb2 = prim_cyl(.11, .11, .04, segs=6)
    hive.add(comb2, "honeycomb", matrix=T(-.05, 2.6, .03) @ R(.2, .1, .5), uv="box", uvscale=.25)
    footpath(deco, [(-.8, -.4), (-.6, .9), (-.3, 2.0), (-.2, 2.6)], width=.8, seed=9)
    for (x, y, r) in ((2.5, 2.4, .55), (2.9, 3.6, .45), (-2.6, 2.0, .5)):
        rock(deco, rng, T(x, y, 0), r=r)
    for k in range(10):
        flower(pl, T(rng.uniform(-2.5, 2.5), rng.uniform(.6, 3.6), 0), rng.choice(("petal_cream", "petal_lavender")))
    plants(pl, rng, [(-1.9, 1.1, 1.0), (1.4, 1.4, .9), (-2.2, 3.4, 1.1), (2.0, 1.0, .9), (-1.2, 4.0, 1.0), (.4, .6, .8)])
    for p in (bark, leaves, hive, animals, deco, pl):
        p.build(coll, parent=root)
    col_box("tree", coll, (2.0, 2.0, 3.0), (.9, 4.2, 1.5), root)
    empty("cam_focus", coll, (0, 3.0, 1.2), root, .3, "SPHERE")


def build_ev16_ditch(coll, root, rng):
    """A peasant cart tipped over in the roadside ditch, cargo spilled, the driver's hand sticks out."""
    cartp, cargo, deco, pl = Part("cart"), Part("cargo"), Part("ground_details"), Part("plants")
    ground_patch(deco, T(.2, 1.3, 0), 3.2, .85, "soil", seed=37, z=.01)
    deco.add(blob(.55, 1.6, .8, .03, amp=.1, freq=3), "water", matrix=T(-1.7, 1.2, .02), uv="world")
    for sy, yy in ((-1, .45), (1, 2.15)):  # grassy banks of the ditch
        for k in range(7):
            deco.add(blob(.45, 1.6, .7, .28, amp=.2, freq=3, seed=k * 3 + sy), "grass_ground", matrix=T(-3.0 + k * 1.0, yy, .02), uv="world", smooth=True)
    cm = Matrix.Translation((.7, 1.45, .62)) @ R(0, 0, math.pi / 2 + .15) @ R(0, -1.45, 0)
    cart(cartp, cm)
    hand = cm @ T(-.55, .2, .6)
    cargo.add(prim_tube([(0, 0, 0), (0, -.25, -.05)], [.055, .05], segs=8), "cloth_cream", matrix=Matrix.Translation((.2, .85, .05)), smooth=True)
    cargo.add(blob(.05, 1, 1.2, .8, subdiv=1), "skin", matrix=T(.2, .58, .04), smooth=True)
    for k in range(3):
        cargo.add(prim_tube([(0, 0, 0), (0, -.06, 0)], [.014, .012], segs=4), "skin", matrix=T(.17 + k * .03, .54, .04))
    barrel(cargo, T(-1.15, 1.6, .29) @ R(math.pi / 2, 0, .4) @ T(0, 0, -.39))
    barrel(cargo, T(-.55, 2.0, 0))
    barrel(cargo, T(1.9, .95, .29) @ R(math.pi / 2, 0, 1.4) @ T(0, 0, -.39))
    crate(cargo, T(-.4, 1.15, 0) @ R(0, 0, .3), .5)
    crate(cargo, T(-1.1, .95, 0) @ R(0, 0, -.2), .45)
    for k, (x, y, a) in enumerate(((-.2, .7, .4), (.2, .55, -.6), (-.7, .6, 1.2), (.5, .75, .2))):
        cargo.add(prim_box(.5, .1, .03, bevel=.006), "wood_light", matrix=T(x, y, .02 + k * .006) @ R(0, 0, a), uv="box")
    for k in range(7):
        apple(cargo, T(rng.uniform(-1.0, .2), rng.uniform(.45, 1.0), 0))
    sack(cargo, T(2.4, 1.3, 0) @ R(1.3, 0, .3) @ T(0, 0, -.17), seed=4)
    for k in range(3):
        cargo.add(prim_torus(.2 - k * .02, .03, segs=16, rsegs=5), "rope", matrix=T(2.9, .7, .03 + k * .055))
    for (x, y, r) in ((-2.8, 2.9, .5), (3.2, 2.8, .45)):
        rock(deco, rng, T(x, y, 0), r=r)
    plants(pl, rng, [(-2.4, .5, .9), (2.6, 2.3, 1.0), (-1.8, 2.5, 1.0), (1.2, 2.6, 1.0), (-3.2, 1.6, .9), (3.3, 1.4, .9)])
    for p in (cartp, cargo, deco, pl):
        p.build(coll, parent=root)
    col_box("cart", coll, (2.2, 1.4, 1.4), (.7, 1.5, .7), root)
    empty("cam_focus", coll, (.2, 1.4, .6), root, .3, "SPHERE")


def build_ev_cart(coll, root, rng):
    p = Part("cart"); cart(p, W()); p.build(coll, parent=root)
    col_box("cart", coll, (1.4, 1.9, 1.0), (0, 0, .5), root)


for _k in EV_IDS:
    BUILDERS[_k] = globals()["build_" + _k]


def preview_scene(aid, res=900):
    """Like preview() but from the road camera: 3/4 view looking into +Y."""
    out = preview(aid, res)
    return out
