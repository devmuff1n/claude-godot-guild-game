# Town kit: furniture and craft objects (loaded by build_town_kit.py).


def build_guild_table(coll, root, rng):
    top, legs = Part("tabletop"), Part("legs_crossbeams")
    w, d, h = 2.0, .9, .75
    for i in range(3):
        top.add(prim_box(w, d / 3 - .012, .07, bevel=.012), "wood_light", matrix=T(0, -d / 2 + (i + .5) * d / 3, h - .035), uv="box", long_axis=0, rng=rng)
    for sy in (-1, 1):
        top.add(prim_box(w - .3, .07, .08), "wood_mid", matrix=T(0, sy * (d / 2 - .12), h - .11), uv="box", long_axis=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.add(prim_box(.12, .12, h - .07, bevel=.015), "wood_mid", matrix=T(sx * (w / 2 - .2), sy * (d / 2 - .12), (h - .07) / 2), uv="box", long_axis=2)
        legs.add(prim_box(.08, d - .24, .08), "wood_mid", matrix=T(sx * (w / 2 - .2), 0, .18), uv="box", long_axis=1)
    legs.add(prim_box(w - .4, .08, .08), "wood_mid", matrix=T(0, 0, .18), uv="box", long_axis=0)
    top.build(coll, parent=root); legs.build(coll, parent=root)
    col_box("table", coll, (w, d, h), (0, 0, h / 2), root)


def build_guild_backless_bench(coll, root, rng):
    seat, trestles, stretcher = Part("seat"), Part("trestle_legs"), Part("stretcher")
    w, d, h = 1.8, .38, .42
    seat.add(prim_box(w, d, .07, bevel=.015), "wood_light", matrix=T(0, 0, h - .035), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        x = sx * (w / 2 - .25)
        out = [(-.04, .0), (.04, .0), (.05, .1), (.13, .12), (.17, .35), (-.17, .35), (-.13, .12), (-.05, .1)]
        out = [(.19, 0), (.19, .05), (.06, .09), (.07, .32), (.15, .35), (-.15, .35), (-.07, .32), (-.06, .09), (-.19, .05), (-.19, 0)]
        trestles.add(prim_prism_xz(list(reversed(out)), .07), "wood_mid", matrix=T(x, 0, 0) @ R(0, 0, math.pi / 2) @ T(0, .035, 0), uv="world")
    stretcher.add(prim_box(w - .5, .06, .07, bevel=.01), "wood_mid", matrix=T(0, 0, .17), uv="box", long_axis=0)
    for p in (seat, trestles, stretcher):
        p.build(coll, parent=root)
    col_box("bench", coll, (w, d, h), (0, 0, h / 2), root)


def build_village_bench(coll, root, rng):
    seat, back, legs = Part("seat_slats"), Part("back_slats"), Part("metal_legs")
    w = 1.8
    for i in range(3):
        seat.add(prim_box(w, .13, .045, bevel=.01), "wood_light", matrix=T(0, -.2 + i * .15, .46), uv="box", long_axis=0, rng=rng)
    for i, z in enumerate((.7, .88)):
        back.add(prim_box(w, .035, .12, bevel=.01), "wood_light", matrix=T(0, .2 + i * .02, z) @ R(-.18, 0, 0), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        x = sx * (w / 2 - .2)
        legs.add(prim_tube([(x, -.27, 0), (x, -.24, .2), (x, -.25, .44)], [.025, .022, .022], segs=6, flat_y=.5), "iron")
        legs.add(prim_tube([(x, .27, 0), (x, .23, .25), (x, .2, .45), (x, .24, .8), (x, .26, 1.0)], [.025, .022, .022, .022, .02], segs=6, flat_y=.5), "iron")
        legs.add(prim_tube([(x, -.27, .44), (x, .2, .44)], [.022, .022], segs=6), "iron")
        legs.add(prim_tube([(x, -.24, .2), (x, -.05, .1), (x, .23, .25)], [.018] * 3, segs=6), "iron")
        legs.add(prim_torus(.05, .012, segs=10, rsegs=4), "iron", matrix=T(x, -.07, .3) @ R(0, math.pi / 2, 0))
        for yy in (-.27, .27):
            legs.add(prim_box(.08, .1, .025), "iron", matrix=T(x, yy, .012))
        for z in (.46, .7, .88):
            legs.add(blob(.018, subdiv=1), "brass", matrix=T(x + sx * .0, -.2 if z < .5 else .17, z + .03))
    for p in (seat, back, legs):
        p.build(coll, parent=root)
    col_box("seat", coll, (w, .55, .48), (0, 0, .24), root)
    col_box("back", coll, (w, .1, .5), (0, .22, .78), root)


def build_guild_reception_counter(coll, root, rng):
    shell, top, panels, cloth = Part("counter_shell"), Part("countertop"), Part("front_panels"), Part("guild_cloth")
    w, d, h = 3.3, .8, .95
    shell.add(prim_box(w, d, h - .07, bevel=.015), "wood_mid", matrix=T(0, .02, (h - .07) / 2), uv="box", long_axis=0)
    shell.add(prim_box(w + .04, d + .04, .1, bevel=.015), "timber", matrix=T(0, .02, .05), uv="box", long_axis=0)
    top.add(prim_box(w + .12, d + .1, .07, bevel=.015), "wood_light", matrix=T(0, .02, h - .035), uv="box", long_axis=0, rng=rng)
    n = 5
    for i in range(n + 1):
        x = -w / 2 + i * w / n
        panels.add(prim_box(.08, .04, h - .2), "wood_light", matrix=T(x, -d / 2 + .0, .1 + (h - .2) / 2), uv="box", long_axis=2)
    for z in (.14, h - .14):
        panels.add(prim_box(w, .04, .07), "wood_light", matrix=T(0, -d / 2, z), uv="box", long_axis=0)
    for i in range(n):
        x = -w / 2 + (i + .5) * w / n
        for k in range(4):
            panels.add(prim_box(.006, .01, h - .36), "wood_dark", matrix=T(x - .21 + k * .14, -d / 2 + .015, h / 2))
    banner_cloth(cloth, T(0, -d / 2 - .07, h - .03), .5, .62, mat="cloth_teal", emblem="star", tail=.16)
    cloth.add(prim_box(.56, .12, .02), "cloth_teal", matrix=T(0, -d / 2 + .0, h + .005))
    for p in (shell, top, panels):
        p.build(coll, parent=root)
    cloth.build(coll, pivot=(0, -d / 2, h), parent=root)
    col_box("counter", coll, (w + .12, d + .1, h), (0, .02, h / 2), root)


def build_wooden_bookshelf(coll, root, rng):
    sides, shelves, cap = Part("side_panels"), Part("shelves"), Part("top_base")
    w, d, h = 1.6, .42, 2.4
    for sx in (-1, 1):
        sides.add(prim_box(.07, d, h - .12, bevel=.012), "wood_mid", matrix=T(sx * (w / 2 - .035), 0, (h - .12) / 2 + .06), uv="box", long_axis=2)
        sides.add(prim_box(.06, .06, h - .1), "wood_light", matrix=T(sx * (w / 2 - .035), -d / 2 - .01, h / 2), uv="box", long_axis=2)
    sides.add(prim_box(w - .1, .03, h - .2), "wood_dark", matrix=T(0, d / 2 - .02, h / 2), uv="box", long_axis=2)
    for i in range(5):
        z = .18 + i * (h - .38) / 4
        shelves.add(prim_box(w - .12, d - .04, .045, bevel=.008), "wood_light", matrix=T(0, 0, z), uv="box", long_axis=0, rng=rng)
        if 0 < i:
            for sx in (-1, 1):
                shelves.add(prim_box(.04, .14, .1), "wood_mid", matrix=T(sx * (w / 2 - .09), -d / 2 + .12, z - .07) @ R(.6, 0, 0), uv="box")
    cap.add(prim_box(w + .1, d + .08, .1, bevel=.015), "wood_mid", matrix=T(0, -.02, h - .05), uv="box", long_axis=0)
    cap.add(prim_box(w + .04, d + .03, .06), "wood_light", matrix=T(0, -.01, h - .13), uv="box", long_axis=0)
    cap.add(prim_box(w + .06, d + .04, .15, bevel=.015), "wood_mid", matrix=T(0, -.01, .075), uv="box", long_axis=0)
    for p in (sides, shelves, cap):
        p.build(coll, parent=root)
    col_box("bookshelf", coll, (w + .1, d + .08, h), (0, 0, h / 2), root)


def build_anvil(coll, root, rng):
    anvil, stump = Part("iron_anvil"), Part("wooden_stump")
    hs = .5
    prof = [(.27, 0), (.29, .05), (.3, .25), (.29, .45), (.27, hs)]
    stump.add(prim_lathe(prof, segs=14, uvscale=.5), "wood_mid", smooth=True)
    stump.add(prim_cyl(.26, .26, .02, segs=14, z0=hs - .01), "wood_raw", uv="box")
    for z in (.1, .38):
        stump.add(prim_torus(.3, .018, segs=16, rsegs=4), "iron", matrix=T(0, 0, z) @ S(1, 1, 2.5))
        for k in range(6):
            a = 2 * math.pi * k / 6
            stump.add(prim_pyramid(.03, .02, z0=0), "iron", matrix=T(math.cos(a) * .31, math.sin(a) * .31, z) @ R(0, math.pi / 2, a))
    A = T(-.05, 0, hs)
    anvil.add(prim_box(.32, .26, .06, bevel=.01), "iron", matrix=A @ T(0, 0, .03))
    anvil.add(prim_tube([(0, 0, .06), (0, 0, .2)], [.1, .07], segs=4), "iron", matrix=A @ R(0, 0, math.pi / 4) @ S(1.3, 1, 1))
    anvil.add(prim_box(.5, .2, .14, bevel=.012), "steel", matrix=A @ T(0, 0, .27), uv="box")
    anvil.add(prim_tube([(.25, 0, .3), (.4, 0, .28), (.55, 0, .3)], [.075, .05, .008], segs=8, flat_y=.9), "steel", matrix=A, smooth=True)
    anvil.add(prim_box(.1, .17, .1, bevel=.01), "steel", matrix=A @ T(-.28, 0, .29))
    anvil.add(prim_box(.04, .04, .02), "eye", matrix=A @ T(-.2, 0, .345))
    stump.build(coll, parent=root); anvil.build(coll, parent=root)
    col_box("anvil", coll, (.95, .5, .88), (.0, 0, .44), root)


def build_forge_hearth(coll, root, rng):
    body, coal, glow = Part("masonry_body"), Part("coal_bed"), Part("ember_glow")
    w, d, h = 1.5, 1.0, .82
    body.add(prim_box(w - .1, d - .1, h - .16), "stone_grey", matrix=T(0, 0, (h - .16) / 2), uv="world")
    for c in range(3):
        z = .13 + c * .25
        for side in range(4):
            L = w if side < 2 else d
            n = 4 if side < 2 else 3
            for i in range(n):
                p = -L / 2 + (i + .5 + (.5 if c % 2 else 0) * (1 if i < n - 1 else 0)) * L / n
                bl = prim_box(L / n - .03, .2, .24, bevel=.03)
                jitter(bl, .008, rng)
                if side < 2:
                    M = T(p, (d / 2 - .08) * (1 if side else -1), z)
                else:
                    M = T((w / 2 - .08) * (1 if side == 3 else -1), p, z) @ R(0, 0, math.pi / 2)
                if side == 0 and c < 2 and abs(p) < .3:
                    continue
                body.add(bl, "stone_grey", matrix=M, uv="world")
    for sx in (-1, 1):  # top rim
        body.add(prim_box(w + .02, .24, .14, bevel=.03), "stone_grey", matrix=T(0, sx * (d / 2 - .1), h - .07), uv="world")
        body.add(prim_box(.24, d - .45, .14, bevel=.03), "stone_grey", matrix=T(sx * (w / 2 - .1), 0, h - .07), uv="world")
    body.add(prim_box(.66, .22, .1, bevel=.02), "stone_grey", matrix=T(0, -d / 2 + .08, .55), uv="world")
    body.add(prim_box(.56, .05, .38), "eye", matrix=T(0, -d / 2 + .05, .27))
    for i in range(18):
        x = rng.uniform(-.45, .45); y = rng.uniform(-.22, .22)
        coal.add(blob(rng.uniform(.06, .1), 1, 1, .6, amp=.3, freq=6, seed=i, subdiv=1), "coal", matrix=T(x, y, h - .1), uv="world")
    for i in range(5):
        x = rng.uniform(-.25, .25)
        coal.add(blob(.07, 1, 1, .5, amp=.3, freq=6, seed=40 + i, subdiv=1), "coal", matrix=T(x, -d / 2 + .2, .1), uv="world")
    glow.add(prim_box(w - .5, d - .5, .02), "coal_glow", matrix=T(0, 0, h - .13), uv="world")
    glow.add(prim_box(.5, .4, .02), "coal_glow", matrix=T(0, -d / 2 + .25, .07), uv="world")
    for p in (body, coal, glow):
        p.build(coll, parent=root)
    col_box("hearth", coll, (w, d, h), (0, 0, h / 2), root)
    empty("vfx_fire_anchor", coll, (0, 0, h), root, .15, "SPHERE")


def build_tanning_vat(coll, root, rng):
    vat, hoops, liquid = Part("vat_body"), Part("hoops"), Part("liquid_surface")
    r, h = .46, .66
    prof = [(0, 0), (r * .9, 0), (r * .92, .02), (r, h), (r - .05, h), (r * .87, .06), (0, .06)]
    vat.add(prim_lathe(prof, segs=20, uvscale=.5, close_bottom=False), "wood_mid", smooth=True)
    for k in range(20):
        a = 2 * math.pi * k / 20
        vat.add(prim_tube([(math.cos(a) * (r * .92 + .003), math.sin(a) * (r * .92 + .003), .02), (math.cos(a) * (r + .003), math.sin(a) * (r + .003), h)], [.005, .005], segs=3), "wood_dark")
    for z in (.12, .5):
        rr = r * .92 + (r - r * .92) * z / h
        hoops.add(prim_torus(rr + .012, .02, segs=20, rsegs=4), "iron", matrix=T(0, 0, z) @ S(1, 1, 2.8))
        for k in range(8):
            a = 2 * math.pi * k / 8
            hoops.add(blob(.016, subdiv=1), "iron", matrix=T(math.cos(a) * (rr + .035), math.sin(a) * (rr + .035), z))
    liquid.add(prim_cyl(r - .06, r - .06, .01, segs=20, z0=h - .1), "liquid_tan")
    for p in (vat, hoops, liquid):
        p.build(coll, parent=root)
    col_hull("vat", coll, [(math.cos(a) * r, math.sin(a) * r, z) for a in [i * math.pi / 6 for i in range(12)] for z in (0, h)], root)


def build_hide_stretching_rack(coll, root, rng):
    frame, hide, ties = Part("wooden_frame"), Part("hide_sheet"), Part("rope_ties")
    w, h = 1.4, 2.35
    for sx in (-1, 1):
        x = sx * w / 2
        frame.add(prim_box(.12, .12, h, bevel=.015), "wood_mid", matrix=T(x, 0, h / 2), uv="box", long_axis=2)
        frame.add(prim_box(.14, .16, .1), "wood_mid", matrix=T(x, 0, h + .02), uv="box")
        frame.add(prim_box(.12, .9 * .28, .1), "wood_mid", matrix=T(x, 0, .05), uv="box", long_axis=1)
        frame.add(prim_box(.08, .7, .08), "wood_mid", matrix=T(x, .0, .3) @ R(0, 0, 0) @ T(0, 0, 0) @ R(math.pi / 2 - .5, 0, 0), uv="box", long_axis=2)
        for z in (.35, h - .2):
            frame.add(prim_box(.13, .13, .05), "iron", matrix=T(x, 0, z))
        frame.add(prim_box(.17, .34, .06), "wood_dark", matrix=T(x + sx * .0, 0, .03), uv="box", long_axis=1)
    for z in (.35, h - .2):
        frame.add(prim_box(w + .24, .12, .12, bevel=.015), "wood_mid", matrix=T(0, 0, z), uv="box", long_axis=0)
    out = []
    n = 16
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + .12 * math.sin(a * 3 + 1) + (.1 if i % 2 else 0)
        out.append((math.cos(a) * .52 * k, 1.27 + math.sin(a) * .75 * k))
    hide.add(prim_prism_xz(list(reversed(out)), .015), "hide_pale", matrix=T(0, -.005, 0), uv="world")
    for i in range(0, n, 2):
        x, z = out[i]
        if abs(x) > abs(z - 1.27) * .7:
            tx, tz = (w / 2 - .06) * (1 if x > 0 else -1), z
        else:
            tx, tz = x, (h - .2 - .06) if z > 1.27 else .41
        ties.add(prim_tube([(x * .97, -.01, z), (tx, -.01, tz)], [.008, .008], segs=4), "rope")
        ties.add(prim_torus(.035, .009, segs=8, rsegs=4), "rope", matrix=T(tx, 0, tz) @ (R(0, 0, 0) if abs(x) > abs(z - 1.27) * .7 else R(0, math.pi / 2, 0)))
    for p in (frame, hide, ties):
        p.build(coll, parent=root)
    col_box("rack", coll, (w + .2, .3, h), (0, 0, h / 2), root)


def build_leather_roll(coll, root, rng):
    roll = Part("rolled_leather")
    L = 1.0
    R0 = .13
    roll.add(prim_cyl(R0, R0, L, segs=16, z0=-L / 2), "leather_red", matrix=T(0, 0, R0) @ R(0, math.pi / 2, 0), uv="box", smooth=True)
    for sx in (-1, 1):
        for k in range(3):
            roll.add(prim_torus(R0 * (.3 + .25 * k), .01, segs=14, rsegs=4), "leather_dark", matrix=T(sx * (L / 2 + .002), 0, R0) @ R(0, math.pi / 2, 0))
    flap = prim_box(.92, .16, .012)
    for v in flap.verts:
        v.co.z += .008 * math.sin(v.co.x * 9) + (.03 if v.co.y > 0 else 0)
    roll.add(flap, "leather_red", matrix=T(.04, -R0 - .02, .008), uv="world")
    for x in (-.25, .25):
        roll.add(prim_torus(R0 + .012, .015, segs=16, rsegs=4), "leather_dark", matrix=T(x, 0, R0) @ R(0, math.pi / 2, 0) @ S(1, 1, 2.2))
        roll.add(prim_box(.05, .02, .04), "brass", matrix=T(x, -R0 - .015, R0 + .02))
    roll.build(coll, parent=root)
    col_box("roll", coll, (L, .3, .28), (0, -.02, .14), root)


def build_hanging_herb_bundle(coll, root, rng):
    stems, leaves, twine = Part("stems"), Part("leaves"), Part("twine_loop")
    top = .5
    twine.add(prim_torus(.05, .008, segs=12, rsegs=4), "rope", matrix=T(0, 0, top + .06) @ R(math.pi / 2, 0, 0) @ S(.8, 1.3, 1))
    for z in (top - .02, top - .06):
        twine.add(prim_torus(.03, .01, segs=10, rsegs=4), "rope", matrix=T(0, 0, z))
    for i in range(10):
        a = 2 * math.pi * i / 10 + rng.uniform(-.2, .2)
        spread = rng.uniform(.06, .14)
        tip = Vector((math.cos(a) * spread, math.sin(a) * spread, rng.uniform(.0, .12)))
        stems.add(prim_tube([(math.cos(a) * .015, math.sin(a) * .015, top), (tip.x * .5, tip.y * .5, top - .25), tuple(tip)], [.006, .005, .003], segs=4), "flower_leaf")
        for k in range(3):
            t = .3 + .25 * k
            p = Vector((tip.x * t, tip.y * t, top - (top - tip.z) * t))
            yaw = a + rng.uniform(-.6, .6)
            leaves.add(prim_leaf(.11, .045, segs=4, curve=.2), "leaf_broad",
                       matrix=T(*p) @ R(0, 0, yaw) @ R(0, math.radians(rng.uniform(40, 75)), 0))
        if i % 2 == 0:
            for k in range(5):
                q = tip + Vector((0, 0, .015 * k))
                leaves.add(blob(.012, 1, 1, 1.4, subdiv=1), "petal_lavender", matrix=T(*q), smooth=True)
    for p in (stems, leaves, twine):
        p.build(coll, parent=root)
    empty("hang_point", coll, (0, 0, top + .1), root, .05)


def build_weapon_rack(coll, root, rng):
    posts, bar, feet = Part("posts"), Part("crossbar"), Part("feet")
    w = 1.3
    for sx in (-1, 1):
        x = sx * w / 2
        posts.add(prim_box(.1, .1, 1.35, bevel=.012), "wood_mid", matrix=T(x, 0, .1 + 1.35 / 2), uv="box", long_axis=2)
        for z in (.75, 1.38):
            posts.add(prim_box(.12, .12, .06), "iron", matrix=T(x, 0, z))
        posts.add(prim_box(.13, .13, .05), "brass", matrix=T(x, 0, 1.47))
        posts.add(prim_pyramid(.11, .14, z0=1.49), "brass", matrix=T(x, 0, 0))
        posts.add(prim_box(.02, .005, .2), "brass", matrix=T(x, -.052, 1.05))
        feet.add(prim_box(.12, .55, .08, bevel=.012), "wood_mid", matrix=T(x, 0, .04), uv="box", long_axis=1)
        for sy in (-1, 1):
            feet.add(prim_box(.13, .1, .1), "brass", matrix=T(x, sy * .27, .05))
            feet.add(prim_box(.07, .3, .07), "wood_mid", matrix=T(x, sy * .12, .2) @ R(sy * -.8, 0, 0), uv="box", long_axis=1)
    bar.add(prim_box(w + .1, .1, .1, bevel=.012), "wood_mid", matrix=T(0, 0, 1.25), uv="box", long_axis=0)
    for i in range(5):
        x = -w / 2 + .22 + i * (w - .44) / 4
        for dx in (-.045, .045):
            bar.add(prim_box(.03, .1, .09), "wood_mid", matrix=T(x + dx, 0, 1.34), uv="box")
        bar.add(prim_box(.07, .11, .015), "brass", matrix=T(x, 0, 1.3))
    bar.add(prim_box(w, .08, .08), "wood_mid", matrix=T(0, 0, .35), uv="box", long_axis=0)
    for p in (posts, bar, feet):
        p.build(coll, parent=root)
    col_box("rack", coll, (w + .15, .55, 1.6), (0, 0, .8), root)
