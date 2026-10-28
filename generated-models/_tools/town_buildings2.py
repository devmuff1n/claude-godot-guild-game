# Town kit: workshops and the guild hall interior shell (loaded by build_town_kit.py).


def lean_to(part, M, x0, z0, x1, z1, y0, y1, mat, thick=.14, barge=True):
    """Single roof slab sloping along local X from (x0, z0) to (x1, z1), spanning y0..y1."""
    L = math.hypot(x1 - x0, z1 - z0); ang = math.atan2(z1 - z0, x1 - x0)
    nrm = Vector((-math.sin(ang), 0, math.cos(ang)))
    c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) + nrm * thick / 2
    part.add(prim_box(L, y1 - y0, thick, bevel=.03), mat, matrix=M @ T(*c) @ R(0, -ang, 0), uv="box", long_axis=1)
    if barge:
        for yy in (y0, y1):
            cb = Vector(((x0 + x1) / 2, yy, (z0 + z1) / 2)) + nrm * (thick + .02)
            part.add(prim_box(L + .05, .12, .12, bevel=.02), "timber", matrix=M @ T(*cb) @ R(0, -ang, 0), uv="box", long_axis=0)


def post(part, M, x, y, h, size=.18, base=True):
    part.add(prim_box(size, size, h, bevel=.02), "timber", matrix=M @ T(x, y, h / 2), uv="box", long_axis=2)
    if base:
        part.add(prim_box(size + .18, size + .18, .3, bevel=.03), "stone_block", matrix=M @ T(x, y, .15), uv="world")


def swing_sign(coll, root, hang, name, mat, outline, depth=.08, ring_dx=.1):
    sg = Part(name)
    for sx in (-1, 1):
        sg.add(prim_tube([(sx * ring_dx, 0, 0), (sx * ring_dx * 1.2, 0, -.16)], [.006, .006], segs=4), "iron", matrix=hang)
    A = hang @ T(0, 0, -.22)
    sg.add(prim_prism_xz(list(reversed(outline)), depth), mat, matrix=A @ T(0, depth / 2, 0), uv="world")
    so = sg.build(coll, pivot=hang.to_translation(), parent=root)
    so["pivot_axis"] = "local X (swing)"
    return so, A


def build_blacksmith_exterior(coll, root, rng):
    walls, roof, porch = Part("walls"), Part("roof"), Part("work_porch")
    pz, hw = .45, 2.3
    cx = -1.3
    Mm = T(cx, .3, 0)
    F = volume(walls, roof, Mm, 3.6, 3.3, hw, 2.0, "roof_plum", pz=pz,
               openings={"front": [(-1.3, -.2, 0, 2.0), (.45, 1.15, .6, 1.6)], "left": [(-.4, .4, .6, 1.6)],
                         "back": [(-.4, .4, .6, 1.5)], "right": [(-1.2, 1.2, 0, 2.2)]})
    door_x, door_w, door_h = -.75, .85, 1.75
    stone_arch(walls, F["front"], door_x, door_w, door_h)
    door_leaf(coll, root, F["front"], door_x, door_w, door_h)
    steps(walls, F["front"] @ T(door_x, 0, -pz), 1.0, n=3, rise=.15, run=.25)
    window(walls, F["front"], .8, .65, .6, .9, rng=rng)
    window(walls, F["left"], 0, .65, .55, .9, rng=rng)
    window(walls, F["left"], 0, hw + .2, .5, .75, rng=rng)
    window(walls, F["back"], 0, .65, .55, .8, arch=False, rng=rng)
    wall_lantern(walls, F["front"], .1, 1.5)
    dormer(walls, roof, T(cx + .55, .3 - 1.5, pz + hw - .05), .95, 1.3, .75, .5, "roof_plum", rng)
    # forge block with an arched glowing mouth under the work porch, tall stone flue
    wx = cx + 1.8
    fx0, fx1, fy0, fy1 = wx, wx + 1.35, -.3, 1.25
    walls.add(prim_box(fx1 - fx0, fy1 - fy0, 1.25, bevel=.03), "stone_block", matrix=T((fx0 + fx1) / 2, (fy0 + fy1) / 2, .625), uv="world")
    Fm = T((fx0 + fx1) / 2, fy0, 0)
    pts = arch_pts(0, .55, .38, 8)
    walls.add(prim_prism_xz([(-.38, .2), (.38, .2)] + list(reversed(pts)), .02), "fire", matrix=Fm @ T(0, .01, 0), uv="world")
    walls.add(prim_box(.7, .3, .1), "coal", matrix=Fm @ T(0, -.05, .25), uv="world")
    stone_arch(walls, Fm @ T(0, 0, .2), 0, .76, .75, depth=.16, thick=.16)
    walls.add(prim_box(1.45, 1.65, .12, bevel=.02), "stone_block", matrix=T((fx0 + fx1) / 2, (fy0 + fy1) / 2, 1.3), uv="world")
    chimney(walls, T(wx + .55, .75, 0), .85, .85, 6.2, z0=1.3)
    # work porch on two posts with a lean-to roof and a low rail
    px1 = wx + 2.05
    pm = T(0, 0, 0)
    for y in (-1.25, 1.55):
        post(porch, pm, px1, y, 2.3)
        porch.add(prim_box(px1 - wx, .14, .16, bevel=.02), "timber", matrix=T((wx + px1) / 2, y, 2.25), uv="box", long_axis=0)
        porch.add(prim_box(.12, .12, .7), "timber", matrix=T(px1 - .3, y, 2.0) @ R(0, -.8, 0), uv="box", long_axis=2)
    porch.add(prim_box(.16, 2.95, .18, bevel=.02), "timber", matrix=T(px1, .15, 2.3), uv="box", long_axis=1)
    for z in (.45, .85):
        porch.add(prim_box(.08, 2.6, .1), "wood_mid", matrix=T(px1, .15, z), uv="box", long_axis=1)
    lean_to(roof, T(0, 0, 0), wx - .1, pz + hw + .35, px1 + .4, 2.25, -1.55, 1.85, "roof_plum")
    # anvil-shaped iron sign on a bracket at the front porch post
    br, hang = bracket_sign(coll, root, T(px1 + .05, -1.32, 2.05), length=.6)
    anvil_out = [(-.3, .1), (.24, .1), (.36, .04), (.22, .0), (.1, -.04), (.08, -.12), (.16, -.2),
                 (-.16, -.2), (-.08, -.12), (-.1, -.04), (-.26, -.02)]
    swing_sign(coll, root, hang, "anvil_sign", "iron", anvil_out)
    for p in (walls, roof, porch, br):
        p.build(coll, parent=root)
    col_box("body", coll, (3.7, 3.4, pz + hw + 1.0), (cx, .3, (pz + hw + 1.0) / 2), root)
    col_box("forge", coll, (fx1 - fx0, fy1 - fy0, 1.3), ((fx0 + fx1) / 2, (fy0 + fy1) / 2, .65), root)
    col_box("chimney", coll, (.85, .85, 6.2), (wx + .55, .75, 3.1), root)
    for y in (-1.25, 1.55):
        col_box("porch_post_%d" % (y > 0), coll, (.36, .36, 2.3), (px1, y, 1.15), root)
    empty("vfx_forge_fire", coll, ((fx0 + fx1) / 2, fy0 + .2, .5), root, .2, "SPHERE")
    empty("vfx_chimney_smoke", coll, (wx + .55, .75, 6.35), root, .2, "SPHERE")


def flask_sign(coll, root, M):
    sg = Part("flask_sign")
    for sx in (-1, 1):
        sg.add(prim_tube([(sx * .05, 0, 0), (sx * .08, 0, -.14)], [.006, .006], segs=4), "iron", matrix=M)
    B = M @ T(0, 0, -.62)
    sg.add(prim_lathe([(.0, -.26), (.16, -.24), (.26, -.12), (.27, 0), (.22, .14), (.1, .22), (.07, .3), (.07, .4)], segs=16, uvscale=.4, close_bottom=False),
           "flask_glass", matrix=B, smooth=True)
    sg.add(prim_lathe([(.0, -.27), (.17, -.25), (.275, -.12), (.28, .02), (.0, .02)], segs=16, uvscale=.4, close_bottom=False), "potion_glow", matrix=B, smooth=True)
    sg.add(prim_cyl(.09, .09, .06, segs=12, z0=.38), "brass", matrix=B)
    sg.add(prim_torus(.09, .025, segs=12, rsegs=4), "brass", matrix=B @ T(0, 0, .3))
    sg.add(prim_torus(.275, .02, segs=16, rsegs=4), "brass", matrix=B @ R(math.pi / 2, 0, 0))
    so = sg.build(coll, pivot=M.to_translation(), parent=root)
    so["pivot_axis"] = "local X (swing)"


def build_alchemy_workshop_exterior(coll, root, rng):
    walls, roof, annex, awn = Part("walls"), Part("roof"), Part("glass_annex"), Part("awning")
    pz, hw = .45, 2.4
    cx = -.65
    Mm = T(cx, .4, 0)
    F = volume(walls, roof, Mm, 3.7, 3.2, hw, 2.15, "roof_green", pz=pz,
               openings={"front": [(-1.75, -.75, 0, 2.0), (-.45, 1.45, .55, 1.85)], "left": [(-.4, .4, .6, 1.6)],
                         "back": [(-.4, .4, .6, 1.5)]})
    door_x, door_w, door_h = -1.25, .8, 1.75
    stone_arch(walls, F["front"], door_x, door_w, door_h)
    door_leaf(coll, root, F["front"], door_x, door_w, door_h)
    steps(walls, F["front"] @ T(door_x, 0, -pz), .95, n=3, rise=.15, run=.24)
    for x in (.0, .5, 1.0):
        window(walls, F["front"], x, .7, .42, 1.1, arch=True, rng=rng)
    walls.add(prim_box(1.9, .5, .08, bevel=.01), "wood_mid", matrix=F["front"] @ T(.5, -.25, .55), uv="box", long_axis=0)
    for sx in (-1, 1):
        walls.add(prim_box(.08, .08, .5), "timber", matrix=F["front"] @ T(.5 + sx * .85, -.4, .3), uv="box", long_axis=2)
    for (mat, dx) in (("glass_green", .0), ("glass_red", .3), ("glass_blue", .6), ("glass_green", 1.2)):
        bottle(walls, F["front"] @ T(-.3 + dx, -.3, .59), mat, h=.2, r=.06)
    window(walls, F["left"], 0, .65, .55, .9, rng=rng)
    window(walls, F["left"], 0, hw + .2, .5, .75, rng=rng)
    window(walls, F["back"], 0, .65, .55, .8, arch=False, rng=rng)
    wall_lantern(walls, F["front"], -1.85 + .1, 1.5)
    # striped awning over the display window
    A = F["front"] @ T(.5, 0, 2.05)
    n = 8
    for i in range(n):
        x = -1.0 + (i + .5) * 2.0 / n
        m = "canvas_green" if i % 2 else "canopy_cream"
        awn.add(prim_box(2.0 / n, .75, .03), m, matrix=A @ T(x, -.35, -.17) @ R(-.45, 0, 0), uv="box")
        awn.add(prim_prism_xz([(-1.0 / n, 0), (1.0 / n, 0), (0, -.14)], .01), m, matrix=A @ T(x, -.69, -.34))
    for sx in (-1, 1):
        awn.add(prim_tube([(sx * 1.0, 0, 0), (sx * 1.0, -.7, -.33)], [.015, .015], segs=4), "iron", matrix=A)
    awn.add(prim_box(2.05, .04, .04), "wood_dark", matrix=A @ T(0, -.68, -.33))
    dormer(walls, roof, T(cx + .35, .4 - 1.6, pz + hw - .05), .95, 1.3, .75, .5, "roof_green", rng)
    chimney(walls, T(cx + 1.1, 1.0, 0), .65, .65, 6.0, z0=3.0)
    # glass annex on the right
    ax0, ax1, ay0, ay1, ah = cx + 1.85, cx + 1.85 + 1.5, -.85, 1.45, 2.2
    annex.add(prim_box(ax1 - ax0, ay1 - ay0, .55, bevel=.02), "stone_block", matrix=T((ax0 + ax1) / 2, (ay0 + ay1) / 2, .275), uv="world")
    for (x, y) in ((ax0, ay0), (ax1, ay0), (ax1, ay1)):
        annex.add(prim_box(.12, .12, ah, bevel=.015), "timber", matrix=T(x, y, ah / 2), uv="box", long_axis=2)
    for z in (.55, ah):
        annex.add(prim_box(ax1 - ax0 + .12, .1, .1), "timber", matrix=T((ax0 + ax1) / 2, ay0, z), uv="box", long_axis=0)
        annex.add(prim_box(.1, ay1 - ay0 + .12, .1), "timber", matrix=T(ax1, (ay0 + ay1) / 2, z), uv="box", long_axis=1)
    for k in range(1, 3):
        annex.add(prim_box(.06, .06, ah - .55), "timber", matrix=T(ax0 + k * (ax1 - ax0) / 3, ay0, .55 + (ah - .55) / 2), uv="box", long_axis=2)
    for k in range(1, 4):
        annex.add(prim_box(.06, .06, ah - .55), "timber", matrix=T(ax1, ay0 + k * (ay1 - ay0) / 4, .55 + (ah - .55) / 2), uv="box", long_axis=2)
    annex.add(prim_box(ax1 - ax0, .02, ah - .55), "glass_pane", matrix=T((ax0 + ax1) / 2, ay0, .55 + (ah - .55) / 2), uv="box")
    annex.add(prim_box(.02, ay1 - ay0, ah - .55), "glass_pane", matrix=T(ax1, (ay0 + ay1) / 2, .55 + (ah - .55) / 2), uv="box")
    for (x, y, r) in ((ax0 + .45, ay0 + .45, .3), (ax0 + .9, ay0 + .9, .35), (ax0 + .5, ay1 - .6, .4)):
        annex.add(blob(r, 1, 1, 1.1, amp=.2, freq=3, seed=x), "leaves_bush", matrix=T(x, y, .55 + r), uv="world", smooth=True)
    gable_roof(roof, T((ax0 + ax1) / 2, (ay0 + ay1) / 2, ah) @ R(0, 0, math.pi / 2), ay1 - ay0, ax1 - ax0, .7, "glass_pane",
               ov=.12, ovx=.1, thick=.05, ridge=True, barge=True, ends=(-1,))
    br, hang = bracket_sign(coll, root, T(cx - 1.85, -.95, 2.6) @ R(0, 0, math.pi), length=.9)
    flask_sign(coll, root, hang)
    for p in (walls, roof, annex, awn, br):
        p.build(coll, parent=root)
    col_box("body", coll, (3.8, 3.3, pz + hw + 1.0), (cx, .4, (pz + hw + 1.0) / 2), root)
    col_box("annex", coll, (ax1 - ax0, ay1 - ay0, ah), ((ax0 + ax1) / 2, (ay0 + ay1) / 2, ah / 2), root)


def hide_sign(coll, root, M):
    out = [(-.26, .26), (-.1, .3), (.1, .3), (.26, .26), (.3, .05), (.24, -.15), (.12, -.32), (0, -.38), (-.12, -.32), (-.24, -.15), (-.3, .05)]
    sg = Part("hide_sign")
    for sx in (-1, 1):
        sg.add(prim_tube([(sx * .12, 0, 0), (sx * .14, 0, -.14)], [.006, .006], segs=4), "iron", matrix=M)
    E = M @ T(0, 0, -.48)
    sg.add(prim_prism_xz(list(reversed(out)), .05), "leather_red", matrix=E @ T(0, .025, 0), uv="world")
    inner = [(x * .72, z * .72 + .01) for (x, z) in out]
    sg.add(prim_prism_xz(list(reversed(inner)), .02), "hide_pale", matrix=E @ T(0, -.02, 0), uv="world")
    for (x, z) in out:
        sg.add(blob(.018, subdiv=1), "brass", matrix=E @ T(x * .88, -.04, z * .88 + .005))
    so = sg.build(coll, pivot=M.to_translation(), parent=root)
    so["pivot_axis"] = "local X (swing)"


def build_leather_workshop_exterior(coll, root, rng):
    walls, roof, shed = Part("walls"), Part("roof"), Part("drying_shed")
    pz, hw = .45, 2.0
    cx = -.75
    Mm = T(cx, .35, 0)
    F = volume(walls, roof, Mm, 3.5, 3.2, hw, 1.75, "roof_brown", pz=pz,
               openings={"front": [(.45, 1.15, .6, 1.5)], "left": [(-.4, .4, .6, 1.5)], "back": [(-.4, .4, .6, 1.5)]})
    window(walls, F["front"], .8, .62, .55, .85, rng=rng, shutters=True)
    window(walls, F["left"], 0, .62, .55, .85, rng=rng)
    window(walls, F["left"], 0, hw + .15, .45, .7, rng=rng)
    window(walls, F["back"], 0, .62, .55, .8, arch=False, rng=rng)
    Mc = T(cx - .6, -1.05, 0) @ R(0, 0, math.pi / 2)
    door_w, door_h = .85, 1.7
    Fc = volume(walls, roof, Mc, 1.4, 1.9, hw, 1.6, "roof_brown", pz=pz, gables=("left",), gable_windows=("left",),
                openings={"left": [(-.5, .5, 0, door_h + .2)]}, ov=.35, ovx=.3)
    G = Fc["left"]
    stone_arch(walls, G, 0, door_w, door_h)
    door_leaf(coll, root, G, 0, door_w, door_h)
    steps(walls, G @ T(0, 0, -pz), 1.05, n=3, rise=.15, run=.24)
    window(walls, G, 0, hw + .12, .45, .7, arch=True, rng=rng)
    wall_lantern(walls, G, .72, 1.45)
    chimney(walls, T(cx + .3, 1.1, 0), .6, .6, 4.8, z0=2.4)
    # open drying shed on the right
    wx = cx + 1.75
    px1 = wx + 1.9
    for y in (-1.15, 1.5):
        post(shed, T(0, 0, 0), px1, y, 2.0, size=.16)
        shed.add(prim_box(px1 - wx, .12, .14), "timber", matrix=T((wx + px1) / 2, y, 1.95), uv="box", long_axis=0)
        shed.add(prim_box(.11, .11, .6), "timber", matrix=T(px1 - .27, y, 1.75) @ R(0, -.8, 0), uv="box", long_axis=2)
    shed.add(prim_box(.15, 2.85, .16, bevel=.02), "timber", matrix=T(px1, .17, 2.0), uv="box", long_axis=1)
    shed.add(prim_cyl(.03, .03, 2.5, segs=6, z0=-1.25), "wood_mid", matrix=T((wx + px1) / 2, .17, 1.7) @ R(math.pi / 2, 0, 0))
    lean_to(roof, T(0, 0, 0), wx - .1, pz + hw + .3, px1 + .35, 1.95, -1.45, 1.8, "roof_brown")
    br, hang = bracket_sign(coll, root, T(cx - 1.75, -.9, 2.2) @ R(0, 0, math.pi), length=.75)
    hide_sign(coll, root, hang)
    for p in (walls, roof, shed, br):
        p.build(coll, parent=root)
    col_box("body", coll, (3.6, 3.3, pz + hw + .9), (cx, .35, (pz + hw + .9) / 2), root)
    col_box("entrance", coll, (2.0, 1.5, pz + hw), (cx - .6, -1.05, (pz + hw) / 2), root)
    for y in (-1.15, 1.5):
        col_box("shed_post_%d" % (y > 0), coll, (.34, .34, 2.0), (px1, y, 1.0), root)


def build_guild_hall_interior_shell(coll, root, rng):
    floor, walls, beams, stair, gal, wins = (Part("floor_panels"), Part("wall_panels"), Part("ceiling_beams"),
                                             Part("staircase"), Part("gallery"), Part("windows"))
    W, D, H = 10.5, 8.0, 6.0
    t = .22
    fz = .12
    for i in range(3):  # three floor modules
        x0 = -W / 2 + i * W / 3
        floor.add(prim_box(W / 3 - .01, D, fz, bevel=.01), "floor_planks", matrix=T(x0 + W / 6, 0, fz / 2), uv="box", long_axis=0)
    floor.add(prim_box(W + .02, .14, .16), "timber", matrix=T(0, -D / 2, .08), uv="box", long_axis=0)
    gz = fz + 3.0
    inner = {
        "back": (T(0, D / 2 - t, fz), W - 2 * t, (T(0, D / 2 - t / 2, fz + (H - fz) / 2), (W, t, H - fz))),
        "left": (T(-W / 2 + t, 0, fz) @ R(0, 0, math.pi / 2), D, (T(-W / 2 + t / 2, 0, fz + (H - fz) / 2), (t, D, H - fz))),
        "right": (T(W / 2 - t, 0, fz) @ R(0, 0, -math.pi / 2), D, (T(W / 2 - t / 2, 0, fz + (H - fz) / 2), (t, D, H - fz))),
    }
    ops = {
        "back": [(-3.4, -2.2, 3.5, 5.0), (-.6, .6, 3.5, 5.0), (2.2, 3.4, 3.5, 5.0), (-3.6, -2.4, 0, 2.2)],
        "left": [(-2.6, -1.6, .9, 2.4), (.4, 1.4, .9, 2.4), (-2.6, -1.6, 3.5, 5.0), (.4, 1.4, 3.5, 5.0), (2.4, 3.4, 0, 2.2)],
        "right": [(-1.0, 0.0, 3.5, 5.0), (1.6, 2.6, 3.5, 5.0)],
    }
    for k, (Fm, ww, (cm, sz)) in inner.items():
        walls.add(prim_box(*sz), "plaster", matrix=cm, uv="world")
        frame_wall(walls, Fm, ww, H - fz, ops[k], rail=(gz - fz) / (H - fz), bay=2.6, size=.22)
        walls.add(prim_box(ww, .1, .3, bevel=.02), "timber", matrix=Fm @ T(0, -.05, .15), uv="box", long_axis=0)
    for k, lst in (("back", [(-2.8, 3.55), (0, 3.55), (2.8, 3.55)]), ("left", [(-2.1, .95), (.9, .95), (-2.1, 3.55), (.9, 3.55)]),
                   ("right", [(-.5, 3.55), (2.1, 3.55)])):
        for (x, z) in lst:
            window(wins, inner[k][0], x, z, .8, 1.35, arch=False, rng=rng)
    for (Fm, x, nm) in ((inner["left"][0], 2.9, "side_door_left"), (inner["back"][0], -3.0, "side_door_back")):
        for sx in (-1, 1):
            walls.add(prim_box(.16, .14, 2.15), "timber", matrix=Fm @ T(x + sx * .58, -.07, 1.07), uv="box", long_axis=2)
        walls.add(prim_box(1.32, .14, .16), "timber", matrix=Fm @ T(x, -.07, 2.17), uv="box", long_axis=0)
        door_leaf(coll, root, Fm, x, 1.0, 2.1, name=nm)
    for i in range(5):
        y = -D / 2 + .3 + i * (D - .6) / 4
        beams.add(prim_box(W - 2 * t, .26, .32, bevel=.02), "timber", matrix=T(0, y, H - .16), uv="box", long_axis=0)
        for sx in (-1, 1):
            beams.add(prim_box(.5, .2, .2, bevel=.02), "timber", matrix=T(sx * (W / 2 - t - .3), y, H - .5) @ R(0, sx * .7, 0), uv="box", long_axis=0)
    for sx in (-1, 1):
        beams.add(prim_box(.3, D, .3, bevel=.02), "timber", matrix=T(sx * (W / 2 - t - .1), 0, H - .15), uv="box", long_axis=1)
    beams.add(prim_box(W - 2 * t, .3, .3, bevel=.02), "timber", matrix=T(0, D / 2 - t - .1, H - .15), uv="box", long_axis=0)
    # gallery along the back wall
    g0, g1 = D / 2 - t - 1.5, D / 2 - t
    gal.add(prim_box(W - 2 * t, g1 - g0, .16, bevel=.01), "floor_planks", matrix=T(0, (g0 + g1) / 2, gz - .08), uv="box", long_axis=0)
    gal.add(prim_box(W - 2 * t, .2, .3, bevel=.02), "timber", matrix=T(0, g0 + .1, gz - .3), uv="box", long_axis=0)
    rail_x = [x for x in [-W / 2 + t + .2 + i * .25 for i in range(int((W - 2 * t - .4) / .25) + 1)] if x < W / 2 - t - 1.25]
    for x in (-3.9, -1.3, 1.3, 3.9):
        gal.add(prim_box(.22, .22, gz - .45 - fz, bevel=.02), "timber", matrix=T(x, g0 + .11, fz + (gz - .45 - fz) / 2), uv="box", long_axis=2)
        gal.add(prim_box(.16, .5, .16), "timber", matrix=T(x, g0 + .35, gz - .55) @ R(.8, 0, 0), uv="box", long_axis=1)
    for x in rail_x:
        gal.add(prim_box(.05, .05, .82), "wood_mid", matrix=T(x, g0 + .06, gz + .41), uv="box", long_axis=2)
    gal.add(prim_box(rail_x[-1] - rail_x[0] + .14, .1, .1, bevel=.015), "timber", matrix=T((rail_x[0] + rail_x[-1]) / 2, g0 + .06, gz + .87), uv="box", long_axis=0)
    for x in (rail_x[0] - .07, rail_x[-1] + .07, -2.6, 0, 2.6):
        gal.add(prim_box(.12, .12, 1.0), "timber", matrix=T(x, g0 + .06, gz + .5), uv="box", long_axis=2)
    # staircase along the right wall: up toward +Y onto the gallery
    n = 15
    sx0, sx1 = W / 2 - t - 1.05, W / 2 - t
    ys = -2.2
    run = (g0 - ys) / n
    rise = (gz - fz) / n
    for i in range(n):
        y = ys + (i + .5) * run
        stair.add(prim_box(sx1 - sx0, run + .02, .07, bevel=.01), "wood_mid", matrix=T((sx0 + sx1) / 2, y, fz + (i + 1) * rise - .035), uv="box", long_axis=0)
        stair.add(prim_box(sx1 - sx0 - .05, .03, rise), "wood_dark", matrix=T((sx0 + sx1) / 2, y - run / 2 + .02, fz + (i + .5) * rise))
    Ls = math.hypot(g0 - ys, gz - fz); ang = math.atan2(gz - fz, g0 - ys)
    for x in (sx0 + .06, sx1 - .04):
        stair.add(prim_box(.1, Ls, .3, bevel=.015), "timber", matrix=T(x, (ys + g0) / 2, fz + (gz - fz) / 2 - .12) @ R(ang, 0, 0), uv="box", long_axis=1)
    for i in range(0, n, 2):
        y = ys + (i + .5) * run
        stair.add(prim_box(.05, .05, .85), "wood_mid", matrix=T(sx0 + .06, y, fz + (i + 1) * rise + .42), uv="box", long_axis=2)
    stair.add(prim_box(.09, Ls, .09, bevel=.015), "timber", matrix=T(sx0 + .06, (ys + g0) / 2, fz + (gz - fz) / 2 + .87) @ R(ang, 0, 0), uv="box", long_axis=1)
    stair.add(prim_box(.14, .14, 1.2), "timber", matrix=T(sx0 + .06, ys, fz + .6), uv="box", long_axis=2)
    for p in (floor, walls, beams, gal, stair, wins):
        p.build(coll, parent=root)
    col_box("floor", coll, (W, D, fz), (0, 0, fz / 2), root)
    col_box("wall_back", coll, (W, t, H), (0, D / 2 - t / 2, H / 2), root)
    col_box("wall_left", coll, (t, D, H), (-W / 2 + t / 2, 0, H / 2), root)
    col_box("wall_right", coll, (t, D, H), (W / 2 - t / 2, 0, H / 2), root)
    col_box("gallery", coll, (W - 2 * t, g1 - g0, .3), (0, (g0 + g1) / 2, gz - .15), root)
    col_hull("staircase", coll, [(x, ys, fz) for x in (sx0, sx1)] + [(x, g0, fz) for x in (sx0, sx1)] + [(x, g0, gz) for x in (sx0, sx1)], root)
