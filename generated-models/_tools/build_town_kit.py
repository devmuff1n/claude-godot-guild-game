"""Town kit for The Kingdom's Poorest Guild (Blender, procedural): buildings, town props,
furniture and craft objects from the asset-kit prompts (game-asset-kit-2026-10-26).

Extends build_event_kit.py -> build_environment_kit.py (same primitives, materials, pipeline).
Usage inside Blender:
    ns = {}; exec(open(r"...\\generated-models\\_tools\\build_town_kit.py", encoding="utf-8").read(), ns)
    ns["run"](["village_cottage"])
    ns["run"](ns["TOWN_IDS"])

Conventions (SCALE_GUIDE): 1 unit = 1 m, Z up, front = -Y, origin = centre of the footprint on the
ground. glTF exporter converts Z-up -> Y-up. Collision proxies use the Godot suffix "-convcolonly".
Moving parts carry the custom property "pivot_axis" and have their origin on the hinge / axle.
Runtime GLBs go to assets/models/town/<category>/<id>.glb.
"""
import os, math, random
from mathutils import Vector, Matrix, Euler

_PROJECT = os.environ.get("POOREST_GUILD", r"C:\Users\armor\Documents\poorest_guild")
exec(open(os.path.join(_PROJECT, "generated-models", "_tools", "build_event_kit.py"), encoding="utf-8").read(), globals())

TOWN_BUILDINGS = ["village_cottage", "party_inn", "guild_hall_exterior", "blacksmith_exterior",
                  "alchemy_workshop_exterior", "leather_workshop_exterior", "guild_hall_interior_shell"]
TOWN_PROPS = ["wooden_barrel", "wooden_crate", "burlap_sack", "wicker_basket", "small_wooden_chest",
              "wooden_planter", "street_lamp", "portable_lantern", "stone_well", "market_stall",
              "quest_noticeboard", "guild_banner", "ledger_book", "parchment_scroll", "wooden_tankard",
              "metal_pitcher", "market_handcart"]
TOWN_FURNITURE = ["guild_table", "guild_backless_bench", "village_bench", "guild_reception_counter", "wooden_bookshelf"]
TOWN_CRAFTS = ["anvil", "forge_hearth", "tanning_vat", "hide_stretching_rack", "leather_roll",
               "hanging_herb_bundle", "weapon_rack"]
for _k in TOWN_BUILDINGS:
    CATEGORY[_k] = "town/buildings"
for _k in TOWN_PROPS:
    CATEGORY[_k] = "town/props"
for _k in TOWN_FURNITURE:
    CATEGORY[_k] = "town/furniture"
for _k in TOWN_CRAFTS:
    CATEGORY[_k] = "town/crafts"
TOWN_IDS = TOWN_BUILDINGS + TOWN_PROPS + TOWN_FURNITURE + TOWN_CRAFTS

# target bounds X (width), Y (depth), Z (height) from the kit manifests
SPEC.update({
    "guild_hall_exterior": (7.2, 6, 8.1), "village_cottage": (4.5, 4, 4.6), "blacksmith_exterior": (6.5, 5, 6.2),
    "party_inn": (6.3, 5.7, 6.7), "alchemy_workshop_exterior": (6.2, 4.8, 6), "leather_workshop_exterior": (6, 4.8, 4.8),
    "guild_hall_interior_shell": (10.5, 8, 6),
    "stone_well": (2.4, 2.2, 2.7), "market_stall": (2.8, 2, 2.5), "quest_noticeboard": (2.3, 0.16, 1.8),
    "wooden_planter": (1.1, 0.75, 0.8), "street_lamp": (1, 0.55, 3), "portable_lantern": (0.3, 0.3, 0.46),
    "wooden_barrel": (0.6, 0.6, 0.8), "wooden_crate": (0.7, 0.6, 0.65), "burlap_sack": (0.45, 0.4, 0.6),
    "wicker_basket": (0.6, 0.6, 0.4), "market_handcart": (2.5, 1, 0.8), "guild_banner": (0.95, 0.12, 1.7),
    "ledger_book": (0.32, 0.24, 0.08), "parchment_scroll": (0.35, 0.2, 0.06), "wooden_tankard": (0.17, 0.13, 0.22),
    "metal_pitcher": (0.23, 0.19, 0.32), "small_wooden_chest": (0.65, 0.42, 0.4),
    "village_bench": (1.8, 0.65, 1.1), "guild_table": (2, 0.9, 0.75), "guild_reception_counter": (3.4, 0.9, 1),
    "guild_backless_bench": (1.8, 0.4, 0.42), "wooden_bookshelf": (1.7, 0.45, 2.5),
    "anvil": (1, 0.5, 0.9), "hanging_herb_bundle": (0.35, 0.28, 0.6), "hide_stretching_rack": (1.8, 0.25, 2.4),
    "forge_hearth": (1.5, 1, 1), "tanning_vat": (1, 1, 0.7), "leather_roll": (1.2, 0.3, 0.3), "weapon_rack": (1.5, 0.6, 1.6),
})

MATS.update({
    "plaster": ("plaster", .9, 0, 2.0, False, None),
    "stone_block": ("stone_block", .9, 0, 1.0, False, None),
    "timber": ("timber", .85, 0, 1.0, False, None),
    "roof_red": ("roof_red", .8, 0, 1.0, False, None),
    "roof_green": ("roof_green", .8, 0, 1.0, False, None),
    "roof_plum": ("roof_plum", .8, 0, 1.0, False, None),
    "roof_brown": ("roof_brown", .8, 0, 1.0, False, None),
    "floor_planks": ("floor_planks", .8, 0, 1.0, False, None),
    "wicker": ("wicker", .9, 0, 0.3, False, None),
    "parchment": ("parchment", .9, 0, 0.5, True, None),
    "leather_red": ("leather_red", .7, 0, 0.4, False, None),
    "hide_pale": ("hide_pale", .85, 0, 1.0, True, None),
    "liquid_tan": ("liquid_tan", .15, 0, 1.0, False, None),
    "pewter": ("pewter", .4, .7, 0.4, False, None),
    "cloth_teal": ("cloth_teal", .9, 0, 1.0, True, None),
    "cloth_navy": ("cloth_navy", .9, 0, 1.0, True, None),
    "canvas_green": ("canvas_green", .9, 0, 1.0, True, None),
    "canopy_cream": ("cloth_cream", .9, 0, 1.0, True, None),
    "coal": ("coal", .95, 0, 0.6, False, None),
    "window_glow": ("lantern_glow", .5, 0, 1.0, False, None),
    "glass_pane": ("glass_green", .1, 0, 1.0, True, 0.55),
    "flask_glass": ("glass_green", .1, 0, 0.5, False, None),
    "potion_glow": ("glass_green", .3, 0, 0.5, False, None),
})
EMISSIVE.update({"window_glow": 0.9, "potion_glow": 1.2})


# ============================================================================= building helpers
def wall_frames(w, d, z0=0.0):
    """Wall-local frames of a w x d box: local X along the wall, Z up, outward = local -Y."""
    return {
        "front": T(0, -d / 2, z0),
        "back": T(0, d / 2, z0) @ R(0, 0, math.pi),
        "left": T(-w / 2, 0, z0) @ R(0, 0, -math.pi / 2),
        "right": T(w / 2, 0, z0) @ R(0, 0, math.pi / 2),
    }


def beam(part, M, a, b, size=.14, t=.06, mat="timber"):
    """Flat timber member on a wall face between wall-local points a=(x,z) and b=(x,z)."""
    (x0, z0), (x1, z1) = a, b
    L = math.hypot(x1 - x0, z1 - z0)
    ang = math.atan2(z1 - z0, x1 - x0)
    part.add(prim_box(L + size * .5, t, size, bevel=.012), mat,
             matrix=M @ T((x0 + x1) / 2, -t / 2 - .005, (z0 + z1) / 2) @ R(0, -ang, 0), uv="box", long_axis=0)


def frame_wall(part, M, w, h, openings=(), rail=.48, bay=1.25, size=.14, braces=True, mat="timber"):
    """Half-timbering over a wall of width w, height h. openings: (x0, x1, z0, z1) in wall-local coords."""
    hs = size / 2
    beam(part, M, (-w / 2, hs), (w / 2, hs), size, mat=mat)
    beam(part, M, (-w / 2, h - hs), (w / 2, h - hs), size, mat=mat)
    xs = {-w / 2 + hs, w / 2 - hs}
    n = max(1, int(round(w / bay)))
    for i in range(1, n):
        xs.add(-w / 2 + i * w / n)
    for (x0, x1, z0, z1) in openings:
        xs = {x for x in xs if not (x0 - size < x < x1 + size)}
        for x in (x0 - hs - .02, x1 + hs + .02):
            if -w / 2 + hs <= x <= w / 2 - hs:
                xs.add(x)
    xs = sorted(xs)
    for x in xs:
        beam(part, M, (x, size), (x, h - size), size, mat=mat)
    zr = h * rail
    segs = [(-w / 2, w / 2)]
    for (x0, x1, z0, z1) in openings:
        if z0 - size < zr < z1 + size:
            nxt = []
            for (a, b) in segs:
                if x1 + hs <= a or x0 - hs >= b:
                    nxt.append((a, b))
                    continue
                if x0 - hs > a:
                    nxt.append((a, x0 - hs))
                if x1 + hs < b:
                    nxt.append((x1 + hs, b))
            segs = nxt
    for (a, b) in segs:
        if b - a > .2:
            beam(part, M, (a, zr), (b, zr), size * .9, mat=mat)
    if braces:
        for i in range(len(xs) - 1):
            a, b = xs[i] + hs, xs[i + 1] - hs
            if b - a < .45:
                continue
            if any(not (x1 <= a or x0 >= b) for (x0, x1, z0, z1) in openings):
                continue
            if i % 2 == 0:
                beam(part, M, (a, zr + hs), (b, h - size), size * .8, mat=mat)
            else:
                beam(part, M, (a, h - size), (b, zr + hs), size * .8, mat=mat)


def arch_pts(cx, zs, r, n=8):
    return [(cx - r * math.cos(math.pi * i / n), zs + r * math.sin(math.pi * i / n)) for i in range(n + 1)]


def window(part, M, x, z, ww, wh, arch=True, box=False, rng=None, frame="timber", shutters=False):
    """Lit window on a wall face. (x, z) = bottom centre in wall-local coords."""
    r = ww / 2
    rect_h = wh - (r if arch else 0)
    if arch:
        outline = [(x - r, z), (x + r, z)] + list(reversed(arch_pts(x, z + rect_h, r)))
    else:
        outline = [(x - r, z), (x + r, z), (x + r, z + wh), (x - r, z + wh)]
    part.add(prim_prism_xz(outline, .02), "window_glow", matrix=M @ T(0, -.005, 0), uv="world")
    t = .06
    beam(part, M, (x - r - t / 2, z), (x - r - t / 2, z + rect_h), .09, t=.08, mat=frame)
    beam(part, M, (x + r + t / 2, z), (x + r + t / 2, z + rect_h), .09, t=.08, mat=frame)
    if arch:
        pts = arch_pts(x, z + rect_h, r + .045, 8)
        part.add(prim_tube([(px, -.045, pz) for px, pz in pts], [.055] * len(pts), segs=6), frame, matrix=M)
    else:
        beam(part, M, (x - r - t, z + wh + .04), (x + r + t, z + wh + .04), .1, t=.08, mat=frame)
    # mullions
    beam(part, M, (x, z), (x, z + wh - .02), .045, t=.04, mat=frame)
    beam(part, M, (x - r, z + rect_h * .55), (x + r, z + rect_h * .55), .045, t=.04, mat=frame)
    # sill
    part.add(prim_box(ww + .26, .16, .07, bevel=.01), frame, matrix=M @ T(x, -.07, z - .035), uv="box", long_axis=0)
    if box:
        flower_box(part, M @ T(x, -.17, z - .07), ww + .2, rng)
    if shutters:
        for sx in (-1, 1):
            part.add(prim_box(r * .95, .04, rect_h, bevel=.01), "wood_mid", matrix=M @ T(x + sx * (r * 1.55 + .05), -.05, z + rect_h / 2), uv="box", long_axis=2)


def flower_box(part, M, L, rng):
    part.add(prim_box(L, .2, .18, bevel=.015), "wood_mid", matrix=M @ T(0, 0, -.09), uv="box", long_axis=0)
    part.add(prim_box(L - .06, .14, .02), "soil_dark", matrix=M @ T(0, 0, .0))
    n = max(3, int(L / .13))
    for i in range(n):
        x = -L / 2 + .07 + i * (L - .14) / (n - 1)
        part.add(blob(.11, 1, .9, .85, amp=.25, freq=5, seed=i + (rng.random() * 9 if rng else 0), subdiv=1), "leaves_bush",
                 matrix=M @ T(x, rng.uniform(-.02, .02) if rng else 0, .05), uv="world", smooth=True)
        if i % 2 == 0:
            part.add(blob(.04, subdiv=1), "petal_cream", matrix=M @ T(x + .03, -.08, .14), smooth=True)
            part.add(blob(.035, subdiv=1), "petal_cream", matrix=M @ T(x - .04, -.05, .17), smooth=True)


def stone_arch(part, M, x, w, h, depth=.14, thick=.16):
    """Stone surround of an arched opening (bottom at z=0)."""
    r = w / 2 + thick / 2
    rect_h = h - w / 2
    for sx in (-1, 1):
        for k in range(int(rect_h / .3) + 1):
            zz = min(k * .3, rect_h - .15)
            ww = thick * (1.25 if k % 2 else 1.0)
            part.add(prim_box(ww, depth, .28, bevel=.02), "stone_block", matrix=M @ T(x + sx * r, -depth / 2 + .02, zz + .14), uv="world")
    n = 7
    for i in range(n):
        a = math.pi * (i + .5) / n
        px = x - r * math.cos(a); pz = rect_h + r * math.sin(a)
        part.add(prim_box(.24 if i == n // 2 else .2, depth, thick * 1.1, bevel=.02), "stone_block",
                 matrix=M @ T(px, -depth / 2 + .02, pz) @ R(0, a - math.pi / 2, 0), uv="world")


def door_leaf(coll, root, M, x, w, h, name="door_leaf", hinge=-1, open_=0.0, mat="wood_mid"):
    """Arched plank door as its own object, origin on the hinge (local Z)."""
    leaf = Part(name)
    r = w / 2
    rect_h = h - r
    outline = [(x - r, 0), (x + r, 0)] + [p for p in reversed(arch_pts(x, rect_h, r))]
    hx = x + hinge * r
    Mo = M @ T(hx, 0, 0) @ R(0, 0, -hinge * open_) @ T(-hx, 0, 0)
    leaf.add(prim_prism_xz(outline, .07), mat, matrix=Mo @ T(0, .0, 0), uv="world")
    for k in range(1, int(w / .2)):
        leaf.add(prim_box(.015, .01, rect_h + r * .7), "wood_dark", matrix=Mo @ T(x - r + k * w / int(w / .2), -.075, (rect_h + r * .7) / 2))
    for zz in (.3, rect_h * .85):
        leaf.add(prim_box(w * .75, .02, .06), "iron", matrix=Mo @ T(x - hinge * w * .1, -.08, zz))
    leaf.add(prim_torus(.06, .012, segs=10, rsegs=4), "iron", matrix=Mo @ T(x - hinge * r * .6, -.09, h * .45) @ R(math.pi / 2, 0, 0))
    pw = M @ Vector((hx, -.035, 0))
    ob = leaf.build(coll, pivot=pw, parent=root)
    ob["pivot_axis"] = "local Z (hinge)"
    return ob


def gable_roof(part, M, w, d, rh, mat, ov=.45, ovx=.35, thick=.16, ridge=True, barge=True, flare=0.0, ends=(-1, 1)):
    """Two roof slabs, ridge along local X at height rh above M's origin (wall top)."""
    a = math.atan2(rh, d / 2)
    L = (d / 2 + ov) / math.cos(a)
    for s in (-1, 1):
        dirv = Vector((0, s * math.cos(a), -math.sin(a)))
        nrm = Vector((0, s * math.sin(a), math.cos(a)))
        c = Vector((0, 0, rh)) + dirv * (L / 2) + nrm * (thick / 2)
        part.add(prim_box(w + 2 * ovx, L, thick, bevel=.03), mat, matrix=M @ T(*c) @ R(-s * a, 0, 0), uv="box", long_axis=0)
        if barge:
            for sx in ends:
                cb = Vector((sx * (w / 2 + ovx), 0, rh)) + dirv * (L / 2) + nrm * (thick + .02)
                part.add(prim_box(.14, L + .05, .14, bevel=.02), "timber", matrix=M @ T(*cb) @ R(-s * a, 0, 0), uv="box", long_axis=1)
    if ridge:
        part.add(prim_box(w + 2 * ovx + .1, .2, .14, bevel=.03), "timber", matrix=M @ T(0, 0, rh + thick / math.cos(a) + .03), uv="box", long_axis=0)
        for sx in ends:
            part.add(prim_pyramid(.16, .28, z0=0), "brass", matrix=M @ T(sx * (w / 2 + ovx + .05), 0, rh + thick + .05))
    return a


def gable_fill(part, M, span, rh, mat="plaster", timber=True, window_gap=None):
    """Triangular gable wall above a wall frame M (z=0 = wall top), centred on local x=0."""
    part.add(prim_prism_xz([(-span / 2, 0), (span / 2, 0), (0, rh)], .2), mat, matrix=M @ T(0, .2, 0), uv="world")
    if timber:
        beam(part, M, (-span / 2 + .1, .07), (0, rh - .05), .14)
        beam(part, M, (span / 2 - .1, .07), (0, rh - .05), .14)
        if window_gap is None:
            beam(part, M, (0, .1), (0, rh - .15), .14)
            beam(part, M, (-span * .25, rh * .48), (span * .25, rh * .48), .12)


def volume(walls, roof, M, w, d, hw, rh, roof_mat, pz=.45, plinth=True, openings=None, gables=("left", "right"),
           gable_windows=(), ov=.45, ovx=.35, rail=.48, timber=True):
    """Timber-framed plaster house body + gable roof (ridge along local X). Returns wall frames (world)."""
    if plinth:
        walls.add(prim_box(w + .14, d + .14, pz, bevel=.03), "stone_block", matrix=M @ T(0, 0, pz / 2), uv="world")
    walls.add(prim_box(w, d, hw, bevel=.0), "plaster", matrix=M @ T(0, 0, pz + hw / 2), uv="world")
    F = {k: M @ v for k, v in wall_frames(w, d, pz).items()}
    openings = openings or {}
    if timber:
        for k, Fm in F.items():
            ww = w if k in ("front", "back") else d
            frame_wall(walls, Fm, ww, hw, openings.get(k, ()), rail=rail)
    for k in gables:
        Fm = F[k] @ T(0, 0, hw)
        gable_fill(walls, Fm, d, rh, timber=timber, window_gap=(k in gable_windows) or None)
    if roof is not None:
        gable_roof(roof, M @ T(0, 0, pz + hw), w, d, rh, roof_mat, ov=ov, ovx=ovx, ridge=len(gables) > 1,
                   ends=tuple(e for e, k in ((-1, "left"), (1, "right")) if k in gables))
    return F


def dormer(walls, roof, M, dw, depth, dh, rh, roof_mat, rng, box=False):
    """Small gable dormer: M at the bottom centre of its front face (front = -Y)."""
    walls.add(prim_box(dw, depth, dh), "plaster", matrix=M @ T(0, depth / 2, dh / 2), uv="world")
    F = M
    beam(walls, F, (-dw / 2 + .06, 0), (-dw / 2 + .06, dh), .12)
    beam(walls, F, (dw / 2 - .06, 0), (dw / 2 - .06, dh), .12)
    gable_fill(walls, F @ T(0, 0, dh), dw, rh, window_gap=True)
    window(walls, F, 0, .2, dw * .45, dh * .8 + rh * .2, arch=True, box=box, rng=rng)
    gable_roof(roof, M @ T(0, depth / 2, dh) @ R(0, 0, math.pi / 2), depth, dw, rh, roof_mat, ov=.2, ovx=.2, thick=.12, ends=(-1,), ridge=False)


def chimney(walls, M, sx, sy, h, z0=0.0):
    walls.add(prim_box(sx, sy, h - z0, bevel=.02), "stone_block", matrix=M @ T(0, 0, z0 + (h - z0) / 2), uv="world")
    walls.add(prim_box(sx + .14, sy + .14, .16, bevel=.02), "stone_block", matrix=M @ T(0, 0, h - .25), uv="world")
    for i, ox in enumerate((-.12, .12)):
        walls.add(prim_box(.16, .16, .22), "stone_grey", matrix=M @ T(ox * sx * 3, 0, h + .08), uv="world")


def steps(walls, M, w, n=3, rise=.15, run=.3, mat="stone_block"):
    """Stone steps descending toward -Y from M (top step edge at y=0, z=n*rise)."""
    for i in range(n):
        walls.add(prim_box(w + (n - i) * .12, run * (n - i), rise, bevel=.02), mat,
                  matrix=M @ T(0, -run * (n - i) / 2, rise * i + rise / 2), uv="world")


def wall_lantern(part, M, x, z):
    part.add(prim_box(.04, .22, .04), "iron", matrix=M @ T(x, -.11, z + .2))
    lantern(part, M @ T(x, -.24, z - .1), s=.55)


def lantern(part, M, s=1.0, ring=True):
    """Iron lantern with glowing core; M at its bottom centre."""
    part.add(prim_box(.24 * s, .24 * s, .04 * s), "iron", matrix=M @ T(0, 0, .02 * s))
    part.add(prim_box(.17 * s, .17 * s, .24 * s), "lantern_glow", matrix=M @ T(0, 0, .16 * s))
    for sx in (-1, 1):
        for sy in (-1, 1):
            part.add(prim_box(.035 * s, .035 * s, .28 * s), "iron", matrix=M @ T(sx * .095 * s, sy * .095 * s, .16 * s))
    part.add(prim_pyramid(.26 * s, .12 * s, z0=.3 * s), "iron", matrix=M)
    part.add(prim_box(.22 * s, .22 * s, .03 * s), "iron", matrix=M @ T(0, 0, .3 * s))
    if ring:
        part.add(prim_torus(.045 * s, .012 * s, segs=10, rsegs=4), "iron", matrix=M @ T(0, 0, .46 * s) @ R(math.pi / 2, 0, 0))


def bracket_sign(coll, root, M, length=1.0, name="hanging_sign"):
    """Iron wall bracket; returns (part with bracket, hanging point matrix)."""
    br = Part("sign_bracket")
    br.add(prim_box(length, .05, .06), "iron", matrix=M @ T(length / 2, 0, 0))
    br.add(prim_tube([(.05, 0, -.45), (length * .55, 0, -.02)], [.022, .022], segs=6), "iron", matrix=M)
    br.add(prim_box(.12, .06, .5), "iron", matrix=M @ T(.04, 0, -.22))
    br.add(prim_pyramid(.08, .14, z0=0), "brass", matrix=M @ T(length + .02, 0, -.03) @ R(0, math.pi / 2, 0))
    for k in (.3, .75):
        br.add(prim_torus(.03, .008, segs=8, rsegs=4), "iron", matrix=M @ T(length * k, 0, -.05) @ R(math.pi / 2, 0, 0))
    return br, M @ T(length * .52, 0, -.05)


def crossed_swords(part, M, s=1.0, mat="steel", hilt="brass"):
    for sg in (-1, 1):
        S_ = M @ R(0, sg * .65, 0)
        part.add(prim_box(.05 * s, .02, .62 * s), mat, matrix=S_ @ T(0, 0, .06 * s))
        part.add(prim_pyramid(.05 * s, .07 * s, z0=.37 * s), mat, matrix=S_ @ S(1, .4, 1))
        part.add(prim_box(.2 * s, .03, .035 * s), hilt, matrix=S_ @ T(0, -.005, -.25 * s))
        part.add(prim_box(.035 * s, .03, .14 * s), "leather", matrix=S_ @ T(0, -.005, -.33 * s))


def banner_cloth(part, M, w, h, mat="cloth_navy", trim="brass", emblem="swords", tail=.28):
    """Hanging banner, top edge centred at M, cloth in the XZ plane facing -Y, swallow/V bottom."""
    outline = [(-w / 2, 0), (-w / 2, -h + tail), (0, -h), (w / 2, -h + tail), (w / 2, 0)]
    outline = list(reversed(outline))
    part.add(prim_prism_xz(outline, .02), mat, matrix=M @ T(0, .01, 0), uv="world")
    for (a, b) in ((outline[0], outline[1]), (outline[1], outline[2]), (outline[2], outline[3]), (outline[3], outline[4])):
        (x0, z0), (x1, z1) = a, b
        Lg = math.hypot(x1 - x0, z1 - z0)
        ang = math.atan2(z1 - z0, x1 - x0)
        part.add(prim_box(Lg + .03, .026, .035), trim, matrix=M @ T((x0 + x1) / 2 + (-.0175 if x0 == x1 and x0 > 0 else .0175 if x0 == x1 else 0), 0, (z0 + z1) / 2) @ R(0, -ang, 0))
    if emblem == "swords":
        crossed_swords(part, M @ T(0, -.02, -h * .45), s=w * .9, mat="paint_cream", hilt="brass")
    elif emblem == "star":
        E = M @ T(0, -.02, -h * .42)
        part.add(prim_torus(w * .2, .018, segs=16, rsegs=4), trim, matrix=E @ R(math.pi / 2, 0, 0))
        for k in range(4):
            a = k * math.pi / 2
            part.add(prim_prism_xz([(0, -.05 * w), (w * .36, 0), (0, .05 * w)], .02), trim, matrix=E @ R(0, -a, 0))
        part.add(prim_cyl(.04 * w, .04 * w, .03, segs=10, z0=-.02), trim, matrix=E @ R(math.pi / 2, 0, 0))


def banner_rod(part, M, L):
    part.add(prim_cyl(.025, .025, L, segs=8, z0=-L / 2), "wood_dark", matrix=M @ R(0, math.pi / 2, 0))
    for sx in (-1, 1):
        part.add(blob(.04, subdiv=1), "brass", matrix=M @ T(sx * L / 2, 0, 0), smooth=True)


_base_run = run


def run(ids, steps=("build", "export", "verify", "preview")):
    BUILDERS.update({k: globals()["build_" + k] for k in TOWN_IDS if "build_" + k in globals()})
    return _base_run(ids, steps)


MATS["paint_cream"] = MATS.get("paint_cream", ("paint_cream", .8, 0, 1.0, False, None))


# ============================================================================= buildings
def build_village_cottage(coll, root, rng):
    walls, roof, deco = Part("walls"), Part("roof"), Part("window_boxes")
    pz, hw = .45, 1.9
    Mm = T(.3, .25, 0)
    door_x, door_w, door_h = -.12, .85, 1.72
    Fm = volume(walls, roof, Mm, 3.6, 2.8, hw, 1.7, "roof_red", pz=pz,
                openings={"front": [(.35, 1.25, .6, 1.5)], "left": [(-.4, .4, .5, 1.4)]})
    window(walls, Fm["front"], .8, .62, .6, .85, arch=False, box=True, rng=rng)
    window(walls, Fm["left"], 0, .55, .55, .8, arch=True, rng=rng)
    window(walls, Fm["back"], 0, .6, .6, .8, arch=False, rng=rng)
    # front cross gable with the door
    Mc = T(-.75, -1.0, 0) @ R(0, 0, math.pi / 2)
    Fc = volume(walls, roof, Mc, 1.6, 1.9, hw, 1.95, "roof_red", pz=pz, gables=("left",), gable_windows=("left",),
                openings={"left": [(door_x - .5, door_x + .5, 0, door_h + .2)], "back": [(-.3, .3, .6, 1.4)]}, ov=.4, ovx=.3)
    F = Fc["left"]
    stone_arch(walls, F, door_x, door_w, door_h)
    door_leaf(coll, root, F, door_x, door_w, door_h)
    steps(walls, F @ T(door_x, 0, -pz), 1.1, n=3, rise=.15, run=.25)
    window(walls, F, 0, hw + .12, .5, .75, arch=True, box=True, rng=rng)
    window(walls, Fc["back"], 0, .6, .5, .8, arch=True, rng=rng)
    wall_lantern(walls, F, .62, 1.45)
    # dormer on the main front slope, chimney at the back
    dormer(walls, roof, T(1.05, .25 - 1.2, pz + hw - .05), 1.05, 1.3, .8, .55, "roof_red", rng)
    chimney(walls, T(1.25, .85, 0), .62, .62, 4.6, z0=2.0)
    for p in (walls, roof):
        p.build(coll, parent=root)
    col_box("body", coll, (3.7, 2.9, pz + hw + 1.0), (.3, .25, (pz + hw + 1.0) / 2), root)
    col_box("cross_wing", coll, (2.0, 1.7, pz + hw), (-.75, -1.0, (pz + hw) / 2), root)
    empty("door_marker", coll, (-.75 + door_x * 0 + 0, -1.85 - .8, 0), root, .3, "SINGLE_ARROW")


# ============================================================================= props
def build_wooden_barrel(coll, root, rng):
    body, hoops, lid = Part("staves_body"), Part("hoops"), Part("lid")
    h, r = .8, .3
    prof = [(r * .8, 0), (r * .93, h * .2), (r, h * .5), (r * .93, h * .8), (r * .8, h)]
    body.add(prim_lathe(prof, segs=18, uvscale=.5), "wood_light", smooth=True)
    body.add(prim_cyl(r * .76, r * .76, .02, segs=18, z0=.02), "wood_dark")
    for k in range(18):  # stave seams as thin dark strips
        a = 2 * math.pi * k / 18
        pts = [(math.cos(a) * (rr + .003), math.sin(a) * (rr + .003), z) for (rr, z) in prof]
        body.add(prim_tube(pts, [.004] * len(pts), segs=3), "wood_dark")
    for z, rr in ((h * .24, .955), (h * .76, .955)):
        hoops.add(prim_torus(r * rr + .01, .018, segs=20, rsegs=4), "iron", matrix=T(0, 0, z) @ S(1, 1, 3.4))
        for k in range(8):
            a = 2 * math.pi * k / 8 + .2
            hoops.add(blob(.012, subdiv=1), "iron", matrix=T(math.cos(a) * (r * rr + .03), math.sin(a) * (r * rr + .03), z))
    lid.add(prim_cyl(r * .77, r * .77, .03, segs=18, z0=h - .05), "wood_dark", uv="box")
    for k in (-1, 0, 1):
        lid.add(prim_box(.008, r * 1.4, .005), "timber", matrix=T(k * .12, 0, h - .018))
    body.build(coll, parent=root); hoops.build(coll, parent=root)
    lid.build(coll, pivot=(0, 0, h - .035), parent=root)
    col_hull("barrel", coll, [(math.cos(a) * r, math.sin(a) * r, z) for a in [i * math.pi / 6 for i in range(12)] for z in (0, h)], root)


for _part in ("town_buildings.py", "town_buildings2.py", "town_props.py", "town_props2.py"):
    _fp = os.path.join(_PROJECT, "generated-models", "_tools", _part)
    if os.path.exists(_fp):
        exec(open(_fp, encoding="utf-8").read(), globals())
