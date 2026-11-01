# -*- coding: utf-8 -*-
"""Prologue kit («Проклятый лес»): cursed forest, Timofey's farm, guild yard props, bandit hamlet,
burnt village and cave assets, built procedurally after the ChatGPT references in Desktop/prologue_refs
(NN_<id>.png + NN_<id>.blender.md). Textures: gen_prologue_textures.py.

Usage (Blender 5.x, background):
    blender -b --factory-startup --python run_prologue.py -- out.json ALL|id1 id2 ...
Conventions as in build_environment_kit.py: 1 unit = 1 m, Z up, front = -Y, origin = footprint centre on
the ground. GLBs go to assets/models/prologue/<group>/<id>.glb.
"""
import os, math, random
from mathutils import Vector, Matrix, Euler

_PROJECT = os.environ.get("POOREST_GUILD", r"C:\Users\armor\Documents\poorest_guild")
exec(open(os.path.join(_PROJECT, "generated-models", "_tools", "build_town_kit.py"), encoding="utf-8").read(), globals())

GROUPS = {
    "forest": ["cursed_oak", "dead_spruce", "cursed_stump", "thorn_bush"],
    "farm": ["farmhouse_log", "haystack", "chicken_coop", "wattle_fence", "farm_gate"],
    "yard": ["training_dummy", "covered_wagon"],
    "hamlet": ["plank_shack", "patched_tent", "drying_rack", "antler_totem", "palisade_unfinished"],
    "ruins": ["burnt_house", "charred_fence", "broken_cart", "bone_shrine", "dead_tree_burnt"],
    "cave": ["cave_rock_wall", "stalactites", "glow_mushrooms", "obelisk", "cave_path_tile"],
}
PROLOGUE_IDS = []
for _g, _ids in GROUPS.items():
    for _k in _ids:
        CATEGORY[_k] = "prologue/" + _g
        PROLOGUE_IDS.append(_k)

SPEC.update({
    "cursed_oak": (4.4, 3.8, 6.0), "dead_spruce": (2.2, 2.0, 7.5), "cursed_stump": (2.2, 2.0, 1.1), "thorn_bush": (1.9, 1.6, 1.3),
    "farmhouse_log": (6.6, 7.0, 6.4), "haystack": (2.4, 2.1, 2.9), "chicken_coop": (2.8, 2.0, 1.9), "wattle_fence": (3.0, 0.4, 1.15),
    "farm_gate": (3.1, 0.5, 2.0), "training_dummy": (1.5, 0.8, 2.0), "covered_wagon": (2.0, 3.8, 2.6),
    "plank_shack": (3.8, 3.2, 3.2), "patched_tent": (3.2, 2.8, 1.9), "drying_rack": (2.6, 1.0, 2.0), "antler_totem": (1.5, 0.8, 3.3),
    "palisade_unfinished": (3.4, 1.4, 2.3), "burnt_house": (5.0, 4.6, 4.2), "charred_fence": (3.0, 0.8, 1.3),
    "broken_cart": (2.6, 2.2, 1.2), "bone_shrine": (2.4, 1.8, 2.7), "dead_tree_burnt": (3.0, 2.8, 4.6),
    "cave_rock_wall": (4.0, 1.6, 3.6), "stalactites": (2.4, 1.4, 1.6), "glow_mushrooms": (1.3, 1.2, 1.3), "obelisk": (1.3, 1.3, 3.2), "cave_path_tile": (6, 6, 0.2),
})

for _n, _r, _s in (("cave_rock_ref", .95, 1.6), ("cave_floor_ref", .95, 2.0), ("ash_ground", .95, 2.0),
                   ("forest_floor_cursed", .95, 2.0), ("thatch_ref", .95, 1.2), ("burnt_wood", .9, 0.8),
                   ("rune_glow", .5, 1.0), ("ember", .6, 1.0), ("mushroom_glow", .5, 1.0), ("obelisk_glow", .4, 1.0),
                   ("obelisk_stone", .7, 1.0), ("bark_cursed", .95, 1.4), ("bark_burnt", .95, 1.2), ("leaves_sick", .9, 1.0),
                   ("needles_dead", .9, 1.0), ("moss_grey", .95, 1.0), ("thorn_stem", .8, .6), ("berry_red", .4, .3),
                   ("canvas_dirty", .9, 1.0), ("canvas_patch", .9, 1.0), ("ribbon_red", .9, .5), ("straw_dummy", .95, .6),
                   ("limestone", .85, 1.0), ("target_paint", .8, .5), ("mask_wood", .8, .5)):
    MATS[_n] = (_n, _r, 0, _s, _n in ("canvas_dirty", "canvas_patch", "ribbon_red", "moss_grey", "leaves_sick", "needles_dead"), None)
EMISSIVE.update({"rune_glow": 2.6, "ember": 2.2, "mushroom_glow": 2.0, "obelisk_glow": 2.8})


def V(*a):
    return Vector(a)


def tube(part, pts, radii, mat, segs=8, smooth=True, **kw):
    part.add(prim_tube([Vector(p) for p in pts], radii, segs=segs, **kw), mat, smooth=smooth)


def branch(part, rng, base, d, L, r, mat, depth=2, spread=.6, up=.35):
    """Crooked branch from base along direction d, recursively forking."""
    d = d.normalized()
    pts = [base]
    p = base.copy()
    for i in range(3):
        jit = Vector((rng.uniform(-.3, .3), rng.uniform(-.3, .3), rng.uniform(-.1, .25)))
        p = p + (d + jit).normalized() * (L / 3)
        pts.append(p.copy())
    tube(part, pts, [r, r * .75, r * .5, r * .2], mat, segs=6, rough=.1)
    if depth > 0:
        for k in range(2):
            nd = d + Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), up))
            branch(part, rng, pts[2 + k % 2], nd, L * .55, r * .45, mat, depth - 1, spread, up)
    return pts[-1]


# ============================================================================= forest
def build_cursed_oak(coll, root, rng):
    bark, leaves, glow = Part("trunk"), Part("leaves_moss"), Part("runes")
    tube(bark, [(0, 0, -.1), (.15, 0, 1.0), (-.1, .05, 2.0), (.25, 0, 2.9)], [.75, .5, .42, .36], "bark_cursed", segs=12, rough=.28, seed=3)
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-.3, .3)
        d = V(math.cos(a), math.sin(a), 0)
        tube(bark, [d * .4 + V(0, 0, .6), d * .9 + V(0, 0, .15), d * rng.uniform(1.3, 1.7) + V(0, 0, -.05)], [.28, .16, .03], "bark_cursed", segs=7, rough=.15)
    tips = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + .5
        tips.append(branch(bark, rng, V(.2, 0, 2.6 + k * .08), V(math.cos(a), math.sin(a), .9), 2.2, .24, "bark_cursed", depth=2, spread=.7))
    # hanging grey moss and a few sick leaves
    for t in tips:
        for j in range(3):
            o = t + V(rng.uniform(-.5, .5), rng.uniform(-.5, .5), rng.uniform(-.6, 0))
            tube(leaves, [o, o + V(.02, 0, -.35), o + V(-.03, .02, -.75)], [.05, .035, .01], "moss_grey", segs=4)
        for j in range(4):
            leaves.add(blob(.14, 1, .5, .9, amp=.3, seed=j), "leaves_sick", matrix=T(*(t + V(rng.uniform(-.4, .4), rng.uniform(-.4, .4), rng.uniform(-.2, .3)))), smooth=True)
    # red runes on the trunk front (-Y) and a glowing hollow
    for z, s in ((1.0, .22), (1.45, .16), (1.8, .2)):
        glow.add(prim_torus(s, .025, segs=12, rsegs=4), "rune_glow", matrix=T(.05, -.46, z) @ R(math.pi / 2, 0, 0))
        glow.add(prim_box(.04, .03, s * 1.6), "rune_glow", matrix=T(.05, -.47, z))
    glow.add(blob(.18, 1, .4, 1.4), "rune_glow", matrix=T(-.05, -.38, .55), smooth=True)
    objs = [p.build(coll, parent=root) for p in (bark, leaves, glow)]
    fit_parts(objs, SPEC["cursed_oak"])
    col_box("trunk", coll, (.9, .9, 2.4), (0, 0, 1.2), root)


def build_dead_spruce(coll, root, rng):
    bark, needles, glow = Part("trunk"), Part("needles"), Part("crack")
    tube(bark, [(0, 0, -.1), (0, 0, .4), (.05, 0, 3.5), (-.05, .05, 7.0)], [.38, .26, .17, .02], "bark_cursed", segs=10, rough=.12)
    for k in range(4):
        a = 2 * math.pi * k / 4 + .3
        d = V(math.cos(a), math.sin(a), 0)
        tube(bark, [d * .15 + V(0, 0, .35), d * .6 + V(0, 0, 0)], [.13, .01], "bark_cursed", segs=6)
    for i in range(14):
        z = 1.4 + i * .38
        a = rng.uniform(0, 6.28)
        L = (1.25 - i / 16) * rng.uniform(.6, 1.0)
        d = V(math.cos(a), math.sin(a), 0)
        end = d * L + V(0, 0, z - .55 * L)
        tube(bark, [V(0, 0, z), d * L * .5 + V(0, 0, z - .1), end], [.05, .03, .005], "bark_cursed", segs=5)
        if i > 8 or rng.random() < .3:
            needles.add(prim_tube([d * L * .3 + V(0, 0, z - .1), end + V(0, 0, -.1)], [.16, .02], segs=6, flat_y=.4), "needles_dead", smooth=False)
    needles.add(prim_cyl(.35, 0, 1.2, segs=7, z0=6.0), "needles_dead")
    glow.add(prim_tube([V(.02, -.25, .4), V(-.02, -.2, 1.6), V(.03, -.16, 2.8), V(0, -.13, 3.6)], [.035, .03, .025, .01], segs=5), "rune_glow")
    objs = [p.build(coll, parent=root) for p in (bark, needles, glow)]
    fit_parts(objs, SPEC["dead_spruce"])
    col_box("trunk", coll, (.6, .6, 3.0), (0, 0, 1.5), root)


def build_cursed_stump(coll, root, rng):
    body, moss, glow = Part("stump"), Part("moss_shrooms"), Part("runes")
    tube(body, [(0, 0, -.05), (0, 0, .6), (0, 0, .85)], [.62, .55, .55], "bark_oak", segs=14, rough=.15, caps=(True, False))
    body.add(prim_cyl(.53, .53, .03, segs=14, z0=.84), "wood_raw", uv="world")
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-.3, .3)
        d = V(math.cos(a), math.sin(a), 0)
        tube(body, [d * .4 + V(0, 0, .45), d * .8 + V(0, 0, .12), d * rng.uniform(1.0, 1.2) + V(0, 0, -.02)], [.22, .13, .02], "bark_oak", segs=7)
    glow.add(prim_torus(.36, .03, segs=16, rsegs=4), "rune_glow", matrix=T(0, 0, .88))
    glow.add(prim_torus(.18, .025, segs=12, rsegs=4), "rune_glow", matrix=T(0, 0, .88))
    for k in range(4):
        a = k * math.pi / 2
        glow.add(prim_box(.36, .04, .02), "rune_glow", matrix=T(0, 0, .885) @ R(0, 0, a))
    for k in range(5):
        a = rng.uniform(0, 6.28)
        moss.add(blob(.28, 1, 1, .45, amp=.3, seed=k), "moss", matrix=T(math.cos(a) * .5, math.sin(a) * .5, rng.uniform(.2, .6)), smooth=True)
    for k in range(3):
        x = .58; z = .35 + k * .12
        moss.add(prim_cyl(.02, .02, .08, segs=6, z0=0), "limestone", matrix=T(x, -.1 + k * .1, z - .08))
        moss.add(prim_lathe([(.0, 0), (.09, .0), (.06, .05), (0, .07)], segs=8), "stone_grey", matrix=T(x, -.1 + k * .1, z), smooth=True)
    objs = [p.build(coll, parent=root) for p in (body, moss, glow)]
    fit_parts(objs, SPEC["cursed_stump"])
    col_box("stump", coll, (1.3, 1.3, .9), (0, 0, .45), root)


def build_thorn_bush(coll, root, rng):
    stems, berries = Part("stems"), Part("berries")
    for k in range(16):
        a = rng.uniform(0, 6.28)
        d = V(math.cos(a), math.sin(a), 0)
        top = d * rng.uniform(.3, .9) + V(0, 0, rng.uniform(.6, 1.25))
        mid = d * rng.uniform(.2, .5) + V(0, 0, top.z * .6 + .1)
        tip = top + d * .25 + V(0, 0, -.25)
        pts = [d * .05, mid, top, tip]
        tube(stems, pts, [.05, .04, .025, .005], "thorn_stem", segs=5)
        for t in (mid, top, (mid + top) / 2):
            o = V(rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.2, 1)).normalized()
            stems.add(prim_cyl(.025, 0, .12, segs=4), "thorn_stem", matrix=T(*t) @ o.to_track_quat("Z", "Y").to_matrix().to_4x4())
        if k % 2 == 0:
            for j in range(3):
                berries.add(blob(.04, subdiv=1), "berry_red", matrix=T(*(top + V(rng.uniform(-.08, .08), rng.uniform(-.08, .08), rng.uniform(-.1, 0)))), smooth=True)
    objs = [p.build(coll, parent=root) for p in (stems, berries)]
    fit_parts(objs, SPEC["thorn_bush"])
    col_box("bush", coll, (1.6, 1.4, 1.1), (0, 0, .55), root)


# ============================================================================= farm
def log_wall(part, M, w, h, r=.13, mat="wood_mid"):
    """Horizontal logs along local X stacked to height h, wall plane y=0."""
    n = int(h / (2 * r * .92))
    for i in range(n):
        z = r + i * 2 * r * .92
        part.add(prim_tube([V(-w / 2 - .18, 0, z), V(w / 2 + .18, 0, z)], [r, r], segs=8), mat, matrix=M, smooth=True)
        for ex in (-w / 2 - .18, w / 2 + .18):
            part.add(prim_cyl(r * .9, r * .9, .01, segs=8), "wood_raw", matrix=M @ T(ex, 0, z) @ R(0, math.pi / 2, 0))


def build_farmhouse_log(coll, root, rng):
    walls, roof, deco = Part("walls"), Part("roof"), Part("details")
    w, d, h, pz = 5.4, 4.6, 2.5, .45
    walls.add(prim_box(w + .5, d + .5, pz, bevel=.04, center=(0, .4, pz / 2)), "stone_block", uv="world")
    cy = .4
    for (M, L) in ((T(0, cy - d / 2, pz), w), (T(0, cy + d / 2, pz), w), (T(-w / 2, cy, pz) @ R(0, 0, math.pi / 2), d), (T(w / 2, cy, pz) @ R(0, 0, math.pi / 2), d)):
        log_wall(walls, M, L, h)
    # gables: triangle prisms of planks, front and back (ridge along Y => gables on the left/right? ridge along X so gables at ±X)
    rh = 2.1
    for sx in (-1, 1):
        walls.add(prim_prism_xz([(-d / 2, 0), (d / 2, 0), (0, rh)], .18), "wood_light",
                  matrix=T(sx * (w / 2), cy, pz + h) @ R(0, 0, math.pi / 2) @ T(0, .09, 0), uv="world")
    # thatch roof, ridge along X
    gable_roof(roof, T(0, cy, pz + h), w, d, rh, "thatch_ref", ov=.7, ovx=.5, thick=.3)
    roof.add(prim_tube([V(-w / 2 - .5, cy, pz + h + rh + .2), V(w / 2 + .5, cy, pz + h + rh + .2)], [.18, .18], segs=8), "thatch_ref", smooth=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            roof.add(prim_box(.1, .9, .1), "wood_dark", matrix=T(sx * (w / 2 + .45), cy + sy * .25, pz + h + rh + .35) @ R(sy * .7, 0, 0))
    chimney(walls, T(1.5, cy + .9, 0), .7, .7, pz + h + rh + .9, z0=pz + h)
    # porch on the front
    py = cy - d / 2 - .9
    walls.add(prim_box(w - .4, 1.6, .2, bevel=.02, center=(0, py, .5)), "floor_planks", uv="box")
    for x in (-w / 2 + .4, -1.0, 1.0, w / 2 - .4):
        walls.add(prim_box(.18, .18, 2.3, bevel=.02, center=(x, py - .65, .6 + 1.15)), "wood_mid", uv="box", long_axis=2)
    for x0, x1 in ((-w / 2 + .4, -1.0), (1.0, w / 2 - .4)):
        walls.add(prim_box(x1 - x0, .08, .1, center=((x0 + x1) / 2, py - .65, 1.4)), "wood_light", uv="box", long_axis=0)
    roof.add(prim_box(w, 2.0, .2, bevel=.05), "thatch_ref", matrix=T(0, py - .1, 3.0) @ R(-.32, 0, 0), uv="box", long_axis=0)
    steps(walls, T(0, py - .8, 0), 1.6, n=2, rise=.25, run=.35, mat="wood_mid")
    # door, windows with shutters, herbs, lantern
    fy = cy - d / 2 - .14
    deco.add(prim_box(1.0, .1, 2.0, bevel=.02), "wood_dark", matrix=T(0, fy, pz + 1.0), uv="box", long_axis=2)
    deco.add(prim_torus(.07, .015, segs=10, rsegs=4), "iron", matrix=T(.35, fy - .07, pz + 1.0) @ R(math.pi / 2, 0, 0))
    for x in (-1.7, 1.7):
        deco.add(prim_box(.8, .06, .8), "window_glow", matrix=T(x, fy, pz + 1.4))
        deco.add(prim_box(.95, .1, .1), "wood_light", matrix=T(x, fy - .03, pz + 1.85))
        deco.add(prim_box(.95, .14, .08), "wood_light", matrix=T(x, fy - .05, pz + .97))
        for sx in (-1, 1):
            deco.add(prim_box(.38, .06, .85, bevel=.01), "wood_mid", matrix=T(x + sx * .64, fy - .06, pz + 1.4), uv="box", long_axis=2)
    for k in range(3):
        deco.add(blob(.09, 1, .6, 1.8, amp=.2, seed=k), "flower_leaf", matrix=T(-.75 + k * .12, fy - .1, pz + 1.55), smooth=True)
    lantern(deco, T(.9, py - .6, 2.4), s=.6)
    for p in (walls, roof, deco):
        p.build(coll, parent=root)
    col_box("house", coll, (w + .4, d + .4, pz + h + rh), (0, cy, (pz + h + rh) / 2), root)
    col_box("porch", coll, (w - .4, 1.7, .6), (0, py, .3), root)


def build_haystack(coll, root, rng):
    hay, pole = Part("hay"), Part("pole_fork")
    prof = [(.0, 0), (.95, 0), (1.05, .4), (1.0, 1.0), (.82, 1.6), (.5, 2.15), (.15, 2.45), (0, 2.5)]
    hay.add(prim_lathe(prof, segs=18, uvscale=1.0), "thatch_ref", smooth=True)
    for k in range(10):
        a = 2 * math.pi * k / 10
        hay.add(prim_box(.08, .5, .02), "thatch_ref", matrix=T(math.cos(a) * 1.0, math.sin(a) * 1.0, .2) @ R(0, 0, a) @ R(.2, 0, 0))
    tube(pole, [(0, 0, 1.0), (0, 0, 2.9)], [.06, .05], "wood_mid", segs=6)
    tube(pole, [(1.05, -.55, 0), (1.15, -.6, 1.4)], [.03, .03], "wood_mid", segs=5)
    for dx in (-.08, 0, .08):
        tube(pole, [(1.15 + dx, -.6, 1.4), (1.15 + dx, -.62, 1.75)], [.012, .006], "iron", segs=4)
    pole.add(prim_box(.22, .03, .03), "iron", matrix=T(1.15, -.6, 1.4))
    for p in (hay, pole):
        p.build(coll, parent=root)
    col_hull("hay", coll, [(math.cos(a) * 1.0, math.sin(a) * 1.0, z) for a in [i * math.pi / 5 for i in range(10)] for z in (0, 1.5)] + [(0, 0, 2.5)], root)


def build_chicken_coop(coll, root, rng):
    box, roof, run = Part("house"), Part("roof"), Part("run")
    hx, hy = -.55, .3
    for x in (-.5, .5):
        for y in (-.4, .4):
            box.add(prim_box(.09, .09, .55), "wood_mid", matrix=T(hx + x, hy + y, .275))
    box.add(prim_box(1.2, 1.0, .9, bevel=.02), "wood_light", matrix=T(hx, hy, 1.0), uv="box")
    box.add(prim_box(.38, .05, .4), "wood_dark", matrix=T(hx + .2, hy - .52, .8))
    box.add(prim_box(.3, .05, .3), "window_glow", matrix=T(hx - .25, hy - .52, 1.15))
    for k in range(3):
        box.add(prim_box(.05, .04, .32), "iron", matrix=T(hx - .25 - .1 + k * .1, hy - .55, 1.15))
    roof.add(prim_box(1.5, 1.35, .08, bevel=.02), "roof_red", matrix=T(hx, hy, 1.58) @ R(0, -.32, 0), uv="box")
    run.add(prim_box(.3, 1.0, .04), "wood_mid", matrix=T(hx + .55, hy - .9, .35) @ R(-.6, 0, 0))
    for k in range(5):
        run.add(prim_box(.3, .03, .02), "wood_dark", matrix=T(hx + .55, hy - .6 - k * .17, .5 - k * .1))
    # fenced run to the right
    xs, ys = (.1, 1.35), (-.85, .85)
    for x in xs:
        for y in ys:
            run.add(prim_box(.07, .07, .75), "wood_mid", matrix=T(x, y, .375))
    for (a, b) in (((xs[0], ys[0]), (xs[1], ys[0])), ((xs[1], ys[0]), (xs[1], ys[1])), ((xs[0], ys[1]), (xs[1], ys[1]))):
        for z in (.15, .7):
            tube(run, [(a[0], a[1], z), (b[0], b[1], z)], [.025, .025], "wood_light", segs=5)
        cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        run.add(prim_box(L if a[1] == b[1] else .01, .01 if a[1] == b[1] else L, .55), "rope", matrix=T(cx, cy, .42))
    for p in (box, roof, run):
        p.build(coll, parent=root)
    col_box("coop", coll, (2.6, 1.8, 1.6), (0, 0, .8), root)


def build_wattle_fence(coll, root, rng):
    st, wv = Part("stakes"), Part("wattle")
    n = 7
    xs = [-1.45 + i * 2.9 / (n - 1) for i in range(n)]
    for x in xs:
        h = rng.uniform(1.0, 1.15)
        tube(st, [(x, 0, 0), (x + rng.uniform(-.03, .03), 0, h)], [.05, .04], "wood_mid", segs=6)
    for k in range(9):
        z = .12 + k * .09
        pts = [(x, (.045 if (i + k) % 2 else -.045), z + rng.uniform(-.01, .01)) for i, x in enumerate(xs)]
        tube(wv, pts, [.025] * len(pts), "wood_light", segs=5)
    wv.add(prim_lathe([(.0, 0), (.1, .02), (.14, .12), (.1, .24), (.07, .26)], segs=10), "terracotta", matrix=T(xs[0] + .02, -.1, .78) @ R(0, math.pi, 0), smooth=True)
    for p in (st, wv):
        p.build(coll, parent=root)
    col_box("fence", coll, (3.0, .2, 1.0), (0, 0, .5), root)
    empty("snap_west", coll, (-1.5, 0, 0), root); empty("snap_east", coll, (1.5, 0, 0), root)


def build_farm_gate(coll, root, rng):
    posts, leaf = Part("posts"), Part("gate_leaf")
    for x in (-1.35, 1.35):
        tube(posts, [(x, 0, 0), (x, 0, 2.0)], [.2, .18], "wood_mid", segs=10, rough=.05)
        posts.add(prim_cyl(.17, .17, .02, segs=10, z0=2.0), "wood_raw")
    for z in (.35, .85, 1.35):
        leaf.add(prim_box(2.4, .08, .28, bevel=.02), "wood_light", matrix=T(0, 0, z), uv="box", long_axis=0)
    for x in (-1.1, 1.1):
        leaf.add(prim_box(.2, .1, 1.35, bevel=.02), "wood_mid", matrix=T(x, -.04, .85), uv="box", long_axis=2)
    Ld = math.hypot(2.0, 1.0)
    leaf.add(prim_box(Ld, .09, .2, bevel=.02), "wood_mid", matrix=T(0, -.06, .85) @ R(0, -math.atan2(1.0, 2.0), 0), uv="box", long_axis=0)
    for z in (.4, 1.3):
        leaf.add(prim_box(.4, .03, .08), "iron", matrix=T(-1.0, -.09, z))
    leaf.add(prim_box(.35, .05, .06), "iron", matrix=T(1.2, -.08, .9))
    leaf.add(prim_torus(.13, .025, segs=12, rsegs=4), "iron", matrix=T(0, -.09, 1.65) @ R(math.pi / 2, 0, 0) @ S(1, 1.2, 1))
    posts.build(coll, parent=root)
    leaf.build(coll, pivot=(-1.15, 0, 0), parent=root)
    col_box("gate", coll, (3.0, .4, 1.6), (0, 0, .8), root)


# ============================================================================= yard
def build_training_dummy(coll, root, rng):
    p, body = Part("post"), Part("dummy")
    p.add(prim_box(1.3, .18, .14), "wood_mid", matrix=T(0, 0, .07), uv="box", long_axis=0)
    p.add(prim_box(.18, .9, .14), "wood_mid", matrix=T(0, 0, .07), uv="box", long_axis=1)
    tube(p, [(0, 0, 0), (0, 0, 1.6)], [.08, .07], "wood_mid", segs=8)
    tube(p, [(-.7, 0, 1.3), (.7, 0, 1.3)], [.06, .06], "wood_mid", segs=7)
    for sx in (-1, 1):
        body.add(blob(.12, 1.8, .9, .9, amp=.15, seed=sx), "straw_dummy", matrix=T(sx * .72, 0, 1.3), smooth=True)
    body.add(blob(.32, 1, .75, 1.25, amp=.12, seed=1), "burlap", matrix=T(0, 0, 1.15), smooth=True)
    body.add(prim_lathe([(0, 0), (.22, 0), (.24, .2), (.2, .32), (0, .36)], segs=12), "iron", matrix=T(0, 0, 1.55), smooth=True)
    body.add(prim_box(.3, .02, .03), "wood_dark", matrix=T(0, -.23, 1.7))
    for r, m in ((.2, "target_paint"), (.14, "canvas_dirty"), (.08, "target_paint")):
        body.add(prim_cyl(r, r, .01, segs=16), m, matrix=T(0, -.24 - (.2 - r) * .05, 1.15) @ R(math.pi / 2, 0, 0))
    for k in range(3):
        arrow(body, T(rng.uniform(-.15, .15), -.3, 1.0 + k * .15) @ R(rng.uniform(-.3, .3), 0, math.pi / 2 + rng.uniform(-.2, .2)), .5)
    for q in (p, body):
        q.build(coll, parent=root)
    col_box("dummy", coll, (.7, .6, 1.9), (0, 0, .95), root)


def build_covered_wagon(coll, root, rng):
    c, cover, load = Part("cart"), Part("canvas"), Part("load")
    cart(c, T(0, 0, 0))
    for k in range(5):
        y = -.8 + k * .4
        pts = [(math.cos(a) * .55, y, .98 + math.sin(a) * .9) for a in [i * math.pi / 8 for i in range(9)]]
        tube(cover, pts, [.035] * 9, "wood_dark", segs=5)
    bm = prim_lathe([(.58, -.85), (.58, .85)], segs=24, close_bottom=False)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.z, v.co.y))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -.01], context="VERTS")
    cover.add(bm, "canvas_dirty", matrix=T(0, 0, .98) @ S(1, 1, 1.5), uv="world", smooth=True)
    for (x, y, z) in ((.45, -.2, 1.55), (-.3, .4, 1.75)):
        cover.add(prim_box(.4, .35, .02), "canvas_patch", matrix=T(x, y, z) @ R(0, x * 1.2, 0))
    for k in range(3):
        sack(load, T(-.25 + k * .25, .5, .56), s=.8, seed=k)
    barrel(load, T(.25, -.4, .53), h=.6, r=.22)
    for p in (c, cover, load):
        p.build(coll, parent=root)
    col_box("wagon", coll, (1.6, 2.0, 2.4), (0, 0, 1.2), root)


# ============================================================================= hamlet
def build_plank_shack(coll, root, rng):
    w, d, h = 2.8, 2.4, 2.0
    walls, roof, deco = Part("walls"), Part("roof"), Part("details")
    plank_wall(walls, T(0, -d / 2, 0) @ R(0, 0, .02), w, h, "wood_mid", rng, plank=.22)
    plank_wall(walls, T(0, d / 2, 0), w, h - .2, "wood_dark", rng)
    for sx in (-1, 1):
        plank_wall(walls, T(sx * w / 2, 0, 0) @ R(0, 0, math.pi / 2), d, h - (.1 if sx > 0 else 0), "wood_dark", rng)
    deco.add(prim_box(.8, .1, 1.6), "soil_dark", matrix=T(-.4, -d / 2 - .02, .8))
    deco.add(prim_box(.85, .04, 1.2), "canvas_patch", matrix=T(-.4, -d / 2 - .08, 1.0))
    gable_roof(roof, T(0, 0, h) @ R(.03, .04, 0), w, d, .9, "wood_dark", ov=.4, ovx=.3, thick=.08)
    for sx in (-1, 1):
        gable_fill(walls, T(sx * w / 2, 0, h) @ R(0, 0, sx * math.pi / 2), d, .9, mat="wood_dark", timber=False)
    logs_pile(deco, T(w / 2 + .45, -.6, 0) @ S(.6, .7, .6))
    roof.add(prim_box(.9, 1.4, .06), "wood_dark", matrix=T(w / 2 + .45, -.3, 1.3) @ R(0, .5, 0))
    for p in (walls, roof, deco):
        p.build(coll, parent=root)
    col_box("shack", coll, (w + .2, d + .2, h + .9), (0, 0, (h + .9) / 2), root)


def build_patched_tent(coll, root, rng):
    frame, fire = Part("poles"), Part("camp")
    L, half, h = 2.2, 1.0, 1.6
    tent2 = Part("tent_sheets")
    for sy in (-1, 1):
        a = math.atan2(h, half)
        tent2.add(prim_box(L, math.hypot(half, h), .03), "canvas_dirty", matrix=T(0, sy * half / 2, h / 2) @ R(-sy * a, 0, 0), uv="world")
        tent2.add(prim_box(.6, .5, .02), "cow_hide", matrix=T(-.4 + sy * .3, sy * half / 2, h / 2) @ R(-sy * a, 0, 0) @ T(0, 0, .03))
    tent2.add(prim_prism_xz([(-half, 0), (half, 0), (0, h)], .02), "canvas_patch", matrix=T(L / 2, 0, 0) @ R(0, 0, math.pi / 2))
    for x in (-L / 2, L / 2):
        tube(frame, [(x, 0, 0), (x, 0, h + .2)], [.04, .035], "wood_mid", segs=6)
    tube(frame, [(-L / 2 - .1, 0, h + .05), (L / 2 + .1, 0, h + .05)], [.035, .035], "wood_mid", segs=6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(frame, [(sx * L / 2, 0, h), (sx * (L / 2 + .5), sy * (half + .5), 0)], [.01, .01], "rope", segs=4)
    campfire(fire, rng, T(0, -1.7, 0), lit=False, r=.3)
    tripod_pot(fire, T(0, -1.7, 0) @ S(.8))
    for p in (tent2, frame, fire):
        p.build(coll, parent=root)
    col_box("tent", coll, (2.4, 2.2, 1.7), (0, 0, .85), root)


def build_drying_rack(coll, root, rng):
    fr, fish = Part("frame"), Part("fish")
    for x in (-1.15, 1.15):
        for sy in (-1, 1):
            tube(fr, [(x, sy * .45, 0), (x, 0, 1.9)], [.05, .045], "wood_mid", segs=6)
        fr.add(prim_torus(.07, .02, segs=8, rsegs=4), "rope", matrix=T(x, 0, 1.82) @ R(0, math.pi / 2, 0))
    tube(fr, [(-1.3, 0, 1.85), (1.3, 0, 1.85)], [.05, .05], "wood_light", segs=7)
    for k, x in enumerate((-.6, -.25, .15, .55)):
        tube(fr, [(x, 0, 1.82), (x, 0, 1.5)], [.008, .008], "rope", segs=4)
        if k in (0, 2):
            fish.add(blob(.1, .55, .25, 1.6, amp=.08, seed=k), "liquid_tan", matrix=T(x, 0, 1.25), smooth=True)
            fish.add(prim_prism_xz([(-.08, 0), (.08, 0), (0, .1)], .02), "liquid_tan", matrix=T(x, .01, .98) @ R(0, math.pi, 0))
    for p in (fr, fish):
        p.build(coll, parent=root)
    col_box("rack", coll, (2.5, 1.0, 1.9), (0, 0, .95), root)


def antler_pair(part, M, s=1.0):
    """Two branching antlers mirrored across local X, bases at M."""
    for sx in (-1, 1):
        def P(x, z):
            return V(sx * x * s, 0, z * s)
        part.add(prim_tube([P(0, 0), P(.15, .3), P(.45, .55), P(.7, .65)], [.05 * s, .04 * s, .03 * s, .01 * s], segs=5), "horn", matrix=M, smooth=True)
        for (a, b) in (((.15, .3), (.05, .6)), ((.45, .55), (.4, .9)), ((.6, .62), (.78, .95))):
            part.add(prim_tube([P(*a), P(*b)], [.025 * s, .006 * s], segs=4), "horn", matrix=M, smooth=True)


def build_antler_totem(coll, root, rng):
    pole, deco = Part("pole"), Part("antlers_ribbons")
    tube(pole, [(0, 0, 0), (0, 0, 2.7)], [.22, .18], "bark", segs=10, rough=.05)
    pole.add(prim_cyl(.18, .18, .02, segs=10, z0=2.7), "wood_raw")
    for z in (.6, 1.0, 1.9):
        deco.add(prim_torus(.21, .04, segs=12, rsegs=4), "ribbon_red", matrix=T(0, 0, z))
    for z in (1.3, 1.6):
        deco.add(prim_cyl(.205, .205, .08, segs=10, z0=z), "target_paint")
    antler_pair(deco, T(0, 0, 2.6), 1.0)
    deco.add(blob(.14, .9, .8, 1.1), "bone", matrix=T(0, -.15, 2.35), smooth=True)
    for k, x in enumerate((-.5, -.3, .3, .5)):
        for j in range(2):
            ribbon(deco, T(x, -.02, 2.75 + j * .1 - abs(x) * .3), "ribbon_red")
        deco.add(blob(.04, 1, 1, 1.6, subdiv=1), "bone", matrix=T(x, 0, 2.3 - abs(x) * .3), smooth=True)
        deco.add(prim_leaf(.18, .05, segs=3, shape="leaf"), "feather", matrix=T(x, -.02, 2.2 - abs(x) * .3) @ R(math.pi, 0, 0))
    for p in (pole, deco):
        p.build(coll, parent=root)
    col_box("totem", coll, (.5, .5, 2.8), (0, 0, 1.4), root)


def build_palisade_unfinished(coll, root, rng):
    logs, ground = Part("logs"), Part("ground_logs")
    n = 9
    for i in range(n):
        x = -1.5 + i * 3.0 / (n - 1)
        h = rng.uniform(1.4, 2.1) if i < 7 else rng.uniform(.9, 1.2)
        r = rng.uniform(.13, .16)
        tube(logs, [(x, 0, 0), (x, 0, h)], [r, r * .95], "bark", segs=8)
        logs.add(prim_cyl(r * .95, 0, .35, segs=8, z0=h), "wood_raw")
    for z in (.5, 1.1):
        tube(logs, [(-1.6, -.15, z), (.9, -.16, z)], [.02, .02], "rope", segs=4)
    for k in range(3):
        y = -.55 - k * .22
        tube(ground, [(-1.0 + k * .4, y, .13), (.6 + k * .4, y - .1, .13)], [.13, .13], "bark", segs=8)
    tube(ground, [(.7, -.55, .26), (.95, -.75, .55)], [.025, .02], "wood_mid", segs=5)
    ground.add(prim_box(.04, .18, .12), "steel", matrix=T(.7, -.55, .27) @ R(0, .2, .6))
    for p in (logs, ground):
        p.build(coll, parent=root)
    col_box("palisade", coll, (3.2, .4, 1.8), (0, 0, .9), root)


# ============================================================================= ruins
def build_burnt_house(coll, root, rng):
    walls, beams, glow = Part("walls"), Part("rafters"), Part("embers")
    w, d = 4.4, 3.8
    walls.add(prim_box(w + .3, d + .3, .3, bevel=.03, center=(0, 0, .15)), "stone_block", uv="world")
    for (x, y) in ((-w / 2, -d / 2), (w / 2, -d / 2), (-w / 2, d / 2), (w / 2, d / 2), (0, -d / 2), (-w / 2, 0)):
        h = rng.uniform(1.6, 2.8)
        walls.add(prim_box(.22, .22, h, bevel=.02, center=(x, y, .3 + h / 2)), "burnt_wood", uv="box", long_axis=2)
    for (M, L, h) in ((T(-1.1, -d / 2, .3), 2.0, 1.6), (T(-w / 2, .2, .3) @ R(0, 0, math.pi / 2), 3.0, 2.0), (T(.5, d / 2, .3), 3.2, 1.1)):
        plank_wall(walls, M, L, h, "burnt_wood", rng, plank=.25)
    chimney(walls, T(1.4, d / 2 - .4, 0), .8, .8, 3.9, z0=.3)
    for k in range(5):
        x = -1.8 + k * .9
        a = rng.uniform(-.5, .5)
        beams.add(prim_box(.14, d * .8, .14), "burnt_wood", matrix=T(x, rng.uniform(-.4, .4), 1.4 + rng.uniform(0, 1.2)) @ R(a, rng.uniform(-.3, .3), 0), uv="box", long_axis=1)
    beams.add(prim_box(w, .16, .16), "burnt_wood", matrix=T(0, 0, 2.2) @ R(0, .35, 0), uv="box", long_axis=0)
    for k in range(9):
        glow.add(blob(.18, 1.3, 1, .4, amp=.3, seed=k), "ember", matrix=T(rng.uniform(-1.8, 1.8), rng.uniform(-1.4, 1.4), .32), smooth=True)
    for k in range(4):
        glow.add(blob(.12, .6, .6, 1.4, amp=.2, seed=k + 9), "fire", matrix=T(rng.uniform(-1.5, 1.0), rng.uniform(-1.2, 1.2), .5), smooth=True)
    for p in (walls, beams, glow):
        p.build(coll, parent=root)
    col_box("ruin", coll, (w + .3, d + .3, 2.2), (0, 0, 1.1), root)


def build_charred_fence(coll, root, rng):
    pl, glow = Part("planks"), Part("embers")
    for i in range(9):
        x = -1.35 + i * .34
        fallen = i in (3, 6)
        h = rng.uniform(.7, 1.25)
        if fallen:
            pl.add(prim_box(.2, h, .06), "burnt_wood", matrix=T(x, -.4, .04) @ R(0, 0, rng.uniform(-.5, .5)), uv="box", long_axis=1)
        else:
            pl.add(prim_box(.2, .06, h), "burnt_wood", matrix=T(x, 0, h / 2) @ R(0, rng.uniform(-.15, .15), 0), uv="box", long_axis=2)
            glow.add(prim_cyl(.1, 0, .12, segs=5, z0=h - .05), "ember", matrix=T(x, 0, 0))
    for z in (.3, .75):
        pl.add(prim_box(2.4, .06, .12), "burnt_wood", matrix=T(-.2, .06, z) @ R(0, rng.uniform(-.06, .06), 0), uv="box", long_axis=0)
    for x in (-1.4, 1.4):
        pl.add(prim_box(.18, .18, 1.3), "burnt_wood", matrix=T(x, .08, .65), uv="box", long_axis=2)
    for p in (pl, glow):
        p.build(coll, parent=root)
    col_box("fence", coll, (2.9, .3, 1.1), (0, 0, .55), root)


def build_broken_cart(coll, root, rng):
    c, ld = Part("cart"), Part("spill")
    cart(c, T(0, 0, -.2) @ R(0, .5, 0), shafts=True)
    wheel(ld, T(1.2, -.7, .05) @ R(0, math.pi / 2, .3))
    sack(ld, T(-.7, -.6, 0) @ R(0, 1.3, 0), s=1.0, seed=2)
    for k in range(40):
        ld.add(blob(.025, subdiv=1), "honey", matrix=T(-.9 + rng.uniform(-.4, .4), -1.0 + rng.uniform(-.3, .3), .02))
    for p in (c, ld):
        p.build(coll, parent=root)
    col_box("cart", coll, (2.0, 2.0, 1.0), (0, 0, .5), root)


def build_bone_shrine(coll, root, rng):
    plat, frame, deco = Part("platform"), Part("frame"), Part("offerings")
    plat.add(prim_box(2.2, 1.6, .45, bevel=.03, center=(0, 0, .225)), "wood_mid", uv="box")
    steps(plat, T(0, -.8, 0), 1.0, n=2, rise=.2, run=.25, mat="wood_mid")
    plat.add(prim_box(1.9, 1.2, .04), "ribbon_red", matrix=T(0, 0, .47))
    for x in (-.8, .8):
        tube(frame, [(x, .3, .45), (x, .3, 2.2)], [.08, .07], "wood_dark", segs=7)
    tube(frame, [(-.9, .3, 2.1), (.9, .3, 2.1)], [.07, .07], "wood_dark", segs=7)
    antler_pair(frame, T(0, .3, 2.15), 1.1)
    deco.add(blob(.22, .85, .75, 1.0), "bone", matrix=T(0, .2, 1.7), smooth=True)
    deco.add(prim_box(.3, .05, .38), "mask_wood", matrix=T(0, .05, 1.25))
    for x in (-.08, .08):
        deco.add(blob(.035, subdiv=1), "rune_glow", matrix=T(x, .02, 1.33))
    for k, x in enumerate((-.7, -.45, .45, .7)):
        ribbon(deco, T(x, .25, 2.0), "ribbon_red")
        deco.add(blob(.07, 1, .8, 1.2), "bone", matrix=T(x, .22, 1.8), smooth=True)
    for k, x in enumerate((-.6, -.35, .35, .6)):
        deco.add(prim_cyl(.04, .04, .18 + k % 2 * .08, segs=6, z0=.49), "paint_cream", matrix=T(x, -.35, 0))
        deco.add(blob(.025, 1, 1, 1.8, subdiv=1), "fire", matrix=T(x, -.35, .49 + .22 + k % 2 * .08))
    deco.add(prim_lathe([(0, 0), (.18, .02), (.2, .1)], segs=12), "wood_dark", matrix=T(0, -.4, .49), smooth=True)
    deco.add(prim_cyl(.17, .17, .01, segs=12, z0=.58), "ash_ground", matrix=T(0, -.4, 0))
    for p in (plat, frame, deco):
        p.build(coll, parent=root)
    col_box("shrine", coll, (2.2, 1.6, 2.3), (0, 0, 1.15), root)


def build_dead_tree_burnt(coll, root, rng):
    bark, glow = Part("trunk"), Part("cracks")
    tube(bark, [(0, 0, -.1), (.1, 0, 1.0), (-.12, .05, 2.0), (.1, 0, 2.6)], [.45, .32, .26, .22], "bark_burnt", segs=10, rough=.25)
    for k in range(4):
        a = 2 * math.pi * k / 4 + .4
        d = V(math.cos(a), math.sin(a), 0)
        tube(bark, [d * .3 + V(0, 0, .4), d * .8 + V(0, 0, .05)], [.18, .03], "bark_burnt", segs=6)
    for k in range(4):
        a = 2 * math.pi * k / 4 + rng.uniform(-.3, .3)
        branch(bark, rng, V(.05, 0, 2.3 + k * .1), V(math.cos(a), math.sin(a), 1.0), 1.7, .16, "bark_burnt", depth=1, spread=.8)
    glow.add(prim_tube([V(0, -.33, .2), V(.05, -.28, .9), V(-.03, -.24, 1.6), V(.04, -.2, 2.2)], [.05, .045, .04, .01], segs=5), "ember")
    glow.add(prim_tube([V(.3, -.15, .3), V(.25, -.2, .8)], [.04, .01], segs=5), "ember")
    objs = [p.build(coll, parent=root) for p in (bark, glow)]
    fit_parts(objs, SPEC["dead_tree_burnt"])
    col_box("trunk", coll, (.7, .7, 2.4), (0, 0, 1.2), root)


# ============================================================================= cave
def build_cave_rock_wall(coll, root, rng):
    rk, green = Part("rock"), Part("roots_moss")
    for k in range(9):
        x = rng.uniform(-1.6, 1.6); z = rng.uniform(.4, 2.9); r = rng.uniform(.6, 1.0)
        rk.add(blob(r, 1.2, .7, .9, amp=.22, freq=2.0, seed=k * 1.7), "cave_rock_ref", matrix=T(x, rng.uniform(-.1, .2), z), uv="world", smooth=False)
    for k in range(6):
        x = rng.uniform(-1.5, 1.5)
        pts = [V(x, -.35, 3.3), V(x + rng.uniform(-.2, .2), -.55, 2.4), V(x + rng.uniform(-.3, .3), -.5, 1.4)]
        tube(green, pts, [.05, .035, .01], "bark_dark", segs=5)
    for k in range(5):
        green.add(blob(.35, 1.2, .5, .4, amp=.3, seed=k), "moss", matrix=T(rng.uniform(-1.5, 1.5), -.45, rng.uniform(1.0, 3.2)), smooth=True)
    objs = [p.build(coll, parent=root) for p in (rk, green)]
    fit_parts(objs, SPEC["cave_rock_wall"])
    col_box("rock", coll, (3.8, 1.2, 3.4), (0, 0, 1.7), root)


def build_stalactites(coll, root, rng):
    rk = Part("stalactites")
    rk.add(blob(1.0, 1.2, .65, .25, amp=.2, seed=2), "limestone", matrix=T(0, 0, 1.45), uv="world", smooth=True)
    for k in range(9):
        x = -1.0 + k * .25 + rng.uniform(-.08, .08)
        y = rng.uniform(-.3, .3)
        L = rng.uniform(.5, 1.3)
        rk.add(prim_tube([V(x, y, 1.45), V(x + rng.uniform(-.04, .04), y, 1.45 - L * .5), V(x, y, 1.45 - L)], [rng.uniform(.12, .2), .08, .0], segs=7, rough=.1), "limestone", smooth=True)
    rk.build(coll, parent=root)
    col_box("ceiling", coll, (2.2, 1.2, .5), (0, 0, 1.4), root)


def build_glow_mushrooms(coll, root, rng):
    base, caps = Part("rock"), Part("mushrooms")
    rock(base, rng, T(0, 0, 0), r=.55, moss=True, mat="cave_rock_ref")
    for k, (x, y, h, r) in enumerate(((0, 0, 1.1, .38), (.35, -.2, .6, .2), (-.35, -.15, .5, .17), (.2, .3, .4, .13), (-.15, .3, .7, .22))):
        tube(caps, [(x, y, .25), (x + .03, y, .25 + h * .6), (x, y, .25 + h)], [r * .22, r * .18, r * .2], "limestone", segs=7)
        caps.add(prim_lathe([(0, 0), (r, 0), (r * .95, r * .25), (r * .6, r * .5), (0, r * .58)], segs=14), "mushroom_glow", matrix=T(x, y, .25 + h - .02), smooth=True)
    for p in (base, caps):
        p.build(coll, parent=root)
    col_box("mush", coll, (1.1, 1.0, 1.0), (0, 0, .5), root)


def build_obelisk(coll, root, rng):
    st, glow, roots = Part("stone"), Part("glow"), Part("roots")
    st.add(prim_box(1.1, 1.1, .3, bevel=.04, center=(0, 0, .15)), "obelisk_stone", uv="world")
    bm = prim_tube([V(0, 0, .3), V(0, 0, 2.6), V(0, 0, 3.15)], [.42, .3, 0], segs=4)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"), verts=bm.verts)
    st.add(bm, "obelisk_stone", uv="world")
    for z in (1.0, 1.9):
        pts = [V(math.cos(a) * (.05 + a * .03), -.33 + .0 * a, z + math.sin(a) * (.05 + a * .03)) for a in [i * .5 for i in range(14)]]
        glow.add(prim_tube(pts, [.018] * len(pts), segs=4), "obelisk_glow")
    for k in range(3):
        glow.add(prim_tube([V(rng.uniform(-.2, .2), -.36, .5 + k * .7), V(rng.uniform(-.2, .2), -.33, .8 + k * .7)], [.02, .01], segs=4), "obelisk_glow")
    for k in range(6):
        glow.add(blob(.04, subdiv=1), "obelisk_glow", matrix=T(rng.uniform(-.4, .4), rng.uniform(-.4, .4), 3.0 + rng.uniform(0, .3)))
    for k in range(5):
        a = 2 * math.pi * k / 5
        d = V(math.cos(a), math.sin(a), 0)
        tube(roots, [d * .7 + V(0, 0, 0), d * .45 + V(0, 0, .5), d * .35 + V(0, 0, 1.0)], [.07, .05, .02], "bark_cursed", segs=5)
    for p in (st, glow, roots):
        p.build(coll, parent=root)
    col_box("obelisk", coll, (1.1, 1.1, 3.1), (0, 0, 1.55), root)


def build_cave_path_tile(coll, root, rng):
    """6x6 m cave floor tile (same footprint as ground_road_tile): packed earth with a flagstone path in the middle."""
    W = 6.0; n = 24; Tk = 0.2

    def h(x, y):
        k = 2 * math.pi * x / W
        taper = min(1.0, (3.0 - abs(y)) / 0.6)
        return 0.04 * noise.noise(Vector((math.cos(k) * 1.3, math.sin(k) * 1.3, y * 0.9))) * taper

    bm = _new(); uv = _uvl(bm)
    grid = [[bm.verts.new((-3 + 6 * i / n, -3 + 6 * j / n, h(-3 + 6 * i / n, -3 + 6 * j / n))) for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            for l in f.loops:
                l[uv].uv = ((l.vert.co.x + 3) / 3, (l.vert.co.y + 3) / 3)
    border = [grid[i][0] for i in range(n + 1)] + [grid[n][j] for j in range(1, n + 1)] + \
             [grid[i][n] for i in range(n - 1, -1, -1)] + [grid[0][j] for j in range(n - 1, 0, -1)]
    bot = [bm.verts.new((v.co.x, v.co.y, -Tk)) for v in border]
    for k in range(len(border)):
        k2 = (k + 1) % len(border)
        bm.faces.new((border[k2], border[k], bot[k], bot[k2]))
    bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    Part("floor").add(bm, "cave_floor_ref", smooth=True).build(coll, parent=root)
    # flagstones: two staggered rows across the path, a few loose ones at the edges
    stones = Part("flagstones")
    x = -2.9
    while x < 2.8:
        wdt = rng.uniform(.55, .85)
        for row, y in enumerate((-.75, 0.0, .75)):
            if rng.random() < .12:
                continue
            cx = x + wdt / 2 + (row % 2) * .2
            if abs(cx) > 2.75:
                continue
            sl = blob(1.0, wdt * .48, rng.uniform(.3, .38), .06, amp=.12, freq=3, seed=x * 7 + row, subdiv=1)
            stones.add(sl, "stone_plates", matrix=T(cx, y + rng.uniform(-.06, .06), h(cx, y) + .02) @ R(0, 0, rng.uniform(-.15, .15)), uv="world")
        x += wdt + .06
    for k in range(10):
        px, py = rng.uniform(-2.8, 2.8), rng.choice((-1, 1)) * rng.uniform(1.5, 2.6)
        stones.add(blob(rng.uniform(.06, .14), 1.2, 1, .6, amp=.2, seed=k, subdiv=1), "cave_rock_ref", matrix=T(px, py, h(px, py) + .02), uv="world")
    stones.build(coll, parent=root)
    col_box("ground", coll, (6, 6, Tk), (0, 0, -Tk / 2), root)
    empty("snap_west", coll, (-3, 0, 0), root); empty("snap_east", coll, (3, 0, 0), root)


def run(ids, steps=("build", "export", "verify", "preview")):
    BUILDERS.update({k: globals()["build_" + k] for k in PROLOGUE_IDS if "build_" + k in globals()})
    return _base_run(ids, steps)
