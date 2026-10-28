# Town kit: street props, small items and the market handcart (loaded by build_town_kit.py).

MATS.setdefault("wax_red", ("cloth_red", .5, 0, 0.3, False, None))


def hinged(coll, root, part, pivot, axis="local X (hinge)"):
    ob = part.build(coll, pivot=pivot, parent=root)
    ob["pivot_axis"] = axis
    return ob


def build_wooden_crate(coll, root, rng):
    body, frame, lid = Part("planked_body"), Part("frame_braces"), Part("lid")
    w, d, h = .7, .6, .6
    for z in range(4):  # horizontal planks on all four sides
        zz = .02 + (z + .5) * (h - .04) / 4
        for (sx, sy, L, rot) in ((0, -d / 2 + .02, w - .02, 0), (0, d / 2 - .02, w - .02, 0), (-w / 2 + .02, 0, d - .02, 1), (w / 2 - .02, 0, d - .02, 1)):
            bm = prim_box(L, .03, (h - .04) / 4 - .012, bevel=.006)
            body.add(bm, "wood_light", matrix=T(sx, sy, zz) @ R(0, 0, math.pi / 2 * rot), uv="box", long_axis=0, rng=rng)
    body.add(prim_box(w - .06, d - .06, .03), "wood_mid", matrix=T(0, 0, .03), uv="box")
    b = .075
    for sx in (-1, 1):
        for sy in (-1, 1):
            frame.add(prim_box(b, b, h, bevel=.01), "wood_mid", matrix=T(sx * (w / 2 - b / 2 + .005), sy * (d / 2 - b / 2 + .005), h / 2), uv="box", long_axis=2)
    for z in (b / 2, h - b / 2):
        for sy in (-1, 1):
            frame.add(prim_box(w, b * .7, b, bevel=.008), "wood_mid", matrix=T(0, sy * (d / 2 - b * .3), z), uv="box", long_axis=0)
        for sx in (-1, 1):
            frame.add(prim_box(b * .7, d, b, bevel=.008), "wood_mid", matrix=T(sx * (w / 2 - b * .3), 0, z), uv="box", long_axis=1)
    L = math.hypot(w - 2 * b, h - 2 * b); ang = math.atan2(h - 2 * b, w - 2 * b)
    for sy in (-1, 1):
        frame.add(prim_box(L, .04, b * .8, bevel=.006), "wood_mid", matrix=T(0, sy * (d / 2 + .005), h / 2) @ R(0, sy * ang, 0), uv="box", long_axis=0)
    for i in range(4):
        lid.add(prim_box(w + .01, (d + .01) / 4 - .01, .04, bevel=.006), "wood_light", matrix=T(0, -d / 2 + (i + .5) * (d + .01) / 4, h + .02), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        lid.add(prim_box(.06, d + .02, .025), "wood_mid", matrix=T(sx * (w / 2 - .08), 0, h + .05), uv="box", long_axis=1)
    body.build(coll, parent=root); frame.build(coll, parent=root)
    hinged(coll, root, lid, (0, d / 2, h))
    col_box("crate", coll, (w, d, h + .05), (0, 0, (h + .05) / 2), root)


def build_burlap_sack(coll, root, rng):
    body, rope = Part("sack_body"), Part("tie_rope")
    s = 1.0
    bm = blob(.24 * s, .95, .85, 1.05, amp=.06, freq=3, seed=4)
    for v in bm.verts:
        t = (v.co.z / (.24 * 1.05) + 1) / 2
        k = 1.05 - .5 * t * t
        v.co.x *= k; v.co.y *= k
        if v.co.z < -.17:
            v.co.z = -.17 - (v.co.z + .17) * .15
    body.add(bm, "burlap", matrix=T(0, 0, .19), uv="world", smooth=True)
    neck = blob(.09, 1, 1, 1.1, amp=.28, freq=6, seed=7, subdiv=2)
    body.add(neck, "burlap", matrix=T(0, 0, .5), uv="world", smooth=True)
    rope.add(prim_torus(.075, .02, segs=12, rsegs=5), "rope", matrix=T(0, 0, .43) @ R(.15, 0, 0))
    rope.add(prim_tube([(.06, -.04, .43), (.1, -.1, .36), (.11, -.12, .27)], [.016, .015, .013], segs=5), "rope")
    rope.add(prim_tube([(.05, -.06, .43), (.03, -.13, .35), (.05, -.15, .3)], [.015, .014, .012], segs=5), "rope")
    body.build(coll, parent=root); rope.build(coll, parent=root)
    col_hull("sack", coll, [(x * .2, y * .18, z) for x in (-1, 1) for y in (-1, 1) for z in (0, .45)] + [(0, 0, .6)], root)


def build_wicker_basket(coll, root, rng):
    body, rim = Part("basket_body"), Part("rim")
    prof = [(0, .0), (.2, 0), (.24, .05), (.28, .2), (.29, .33), (.27, .33), (.26, .2), (.22, .07), (.18, .035), (0, .035)]
    body.add(prim_lathe(prof, segs=24, uvscale=.3, close_bottom=False), "wicker", smooth=True)
    rim.add(prim_torus(.285, .035, segs=24, rsegs=6, uvscale=.15), "wicker", matrix=T(0, 0, .34) @ S(1, 1, 1.1), smooth=True)
    for k in range(10):
        a = 2 * math.pi * k / 10
        rim.add(prim_torus(.035, .01, segs=8, rsegs=4), "wood_mid", matrix=T(math.cos(a) * .285, math.sin(a) * .285, .34) @ R(0, 0, a) @ R(math.pi / 2, 0, 0) @ R(0, .5, 0))
    body.build(coll, parent=root); rim.build(coll, parent=root)
    col_hull("basket", coll, [(math.cos(a) * r, math.sin(a) * r, z) for a in [i * math.pi / 5 for i in range(10)] for (r, z) in ((.22, 0), (.3, .38))], root)


def build_small_wooden_chest(coll, root, rng):
    body, straps, lid = Part("body"), Part("straps"), Part("hinged_lid")
    w, d, h = .62, .4, .25
    body.add(prim_box(w, d, h, bevel=.012), "wood_mid", matrix=T(0, 0, h / 2), uv="box", long_axis=0)
    for i in range(1, 3):
        body.add(prim_box(w + .002, .005, .012), "wood_dark", matrix=T(0, -d / 2, i * h / 3))
    for x in (-w * .3, w * .3):
        straps.add(prim_box(.06, d + .02, h + .01), "iron", matrix=T(x, 0, h / 2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            straps.add(prim_box(.045, .045, h + .01), "iron", matrix=T(sx * (w / 2 - .012), sy * (d / 2 - .012), h / 2))
    straps.add(prim_box(.1, .03, .12), "iron", matrix=T(0, -d / 2 - .012, h - .05))
    straps.add(prim_torus(.025, .007, segs=8, rsegs=4), "brass", matrix=T(0, -d / 2 - .03, h - .07) @ R(math.pi / 2, 0, 0))
    bm = prim_cyl(d / 2, d / 2, w, segs=12, z0=-w / 2)
    for v in bm.verts:
        if v.co.x < 0:
            v.co.x = 0
    lid.add(bm, "wood_mid", matrix=T(0, 0, h) @ S(1, 1, .7) @ R(0, -math.pi / 2, 0), uv="box")
    for x in (-w * .3, w * .3):
        tb = prim_torus(d / 2 + .004, .03, segs=16, rsegs=4)
        for v in [v for v in tb.verts if v.co.x < -.01]:
            tb.verts.remove(v)
        lid.add(tb, "iron", matrix=T(x, 0, h) @ S(1, 1, .7) @ R(0, -math.pi / 2, 0))
    lid.add(prim_box(.08, .02, .08), "iron", matrix=T(0, -d / 2 - .01, h + .02))
    body.build(coll, parent=root); straps.build(coll, parent=root)
    hinged(coll, root, lid, (0, d / 2, h))
    col_box("chest", coll, (w, d, .4), (0, 0, .2), root)


def build_wooden_planter(coll, root, rng):
    box, soil, plant = Part("wooden_box"), Part("soil"), Part("plant_insert")
    w, d, h = 1.0, .65, .42
    for z in range(3):
        zz = .05 + (z + .5) * (h - .05) / 3
        for (sx, sy, L, rot) in ((0, -d / 2, w, 0), (0, d / 2, w, 0), (-w / 2, 0, d, 1), (w / 2, 0, d, 1)):
            box.add(prim_box(L, .04, (h - .05) / 3 - .01, bevel=.006), "wood_light", matrix=T(sx, sy, zz) @ R(0, 0, math.pi / 2 * rot), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box.add(prim_box(.08, .08, h + .04, bevel=.01), "wood_mid", matrix=T(sx * w / 2, sy * d / 2, (h + .04) / 2), uv="box", long_axis=2)
            for z in (.08, h - .04):
                box.add(prim_box(.1, .1, .05), "iron", matrix=T(sx * w / 2, sy * d / 2, z))
    for sy in (-1, 1):
        box.add(prim_box(w + .1, .07, .04), "wood_mid", matrix=T(0, sy * d / 2, h + .02), uv="box", long_axis=0)
    for sx in (-1, 1):
        box.add(prim_box(.07, d + .1, .04), "wood_mid", matrix=T(sx * w / 2, 0, h + .02), uv="box", long_axis=1)
    soil.add(prim_box(w - .06, d - .06, .04), "soil_dark", matrix=T(0, 0, h - .06), uv="world")
    for i in range(9):
        x = rng.uniform(-.3, .3); y = rng.uniform(-.12, .12); r = rng.uniform(.07, .1)
        plant.add(blob(r, 1, 1, .9, amp=.3, freq=6, seed=i), "leaves_bush", matrix=T(x, y, h + .02 + r * .8 + rng.uniform(0, .12)), uv="world", smooth=True)
    for i in range(46):
        x = rng.uniform(-.4, .4); y = rng.uniform(-.2, .2)
        plant.add(prim_leaf(.17, .08, segs=4, curve=.25), "leaf_broad",
                  matrix=T(x, y, h + .12 + rng.uniform(0, .15)) @ R(0, 0, rng.uniform(0, 6.28)) @ R(0, -math.radians(rng.uniform(10, 40)), 0))
    for i in range(12):
        x = rng.uniform(-.4, .4); y = rng.uniform(-.2, .2)
        z = h + .2 + rng.uniform(0, .18)
        flower(plant, T(x, y, z) @ R(rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0))
    box.build(coll, parent=root); soil.build(coll, parent=root)
    plant.build(coll, pivot=(0, 0, h - .04), parent=root)
    empty("insert_origin", coll, (0, 0, h - .04), root, .15)
    col_box("planter", coll, (w + .1, d + .1, h), (0, 0, h / 2), root)


def lantern_parts(frame, glass, cap, M, s=1.0):
    frame.add(prim_box(.26 * s, .26 * s, .04 * s, bevel=.006), "iron", matrix=M @ T(0, 0, .02 * s))
    glass.add(prim_box(.19 * s, .19 * s, .27 * s), "lantern_glow", matrix=M @ T(0, 0, .175 * s))
    for sx in (-1, 1):
        for sy in (-1, 1):
            frame.add(prim_box(.04 * s, .04 * s, .3 * s), "iron", matrix=M @ T(sx * .105 * s, sy * .105 * s, .18 * s))
    for k in range(4):
        F = M @ R(0, 0, k * math.pi / 2) @ T(0, -.1 * s, .18 * s)
        frame.add(prim_box(.02 * s, .01 * s, .26 * s), "iron", matrix=F)
    frame.add(prim_box(.24 * s, .24 * s, .03 * s), "iron", matrix=M @ T(0, 0, .33 * s))
    cap.add(prim_pyramid(.3 * s, .1 * s, z0=.345 * s), "iron", matrix=M)
    cap.add(prim_cyl(.03 * s, .03 * s, .04 * s, segs=8, z0=.44 * s), "iron", matrix=M)


def build_portable_lantern(coll, root, rng):
    frame, glass, cap, ring = Part("frame"), Part("glass_insert"), Part("cap"), Part("handle_ring")
    lantern_parts(frame, glass, cap, T(0, 0, 0), s=1.0)
    ring.add(prim_torus(.05, .012, segs=12, rsegs=5), "iron", matrix=T(0, 0, .45 + .04) @ R(math.pi / 2, 0, 0))
    for p in (frame, glass, cap):
        p.build(coll, parent=root)
    hinged(coll, root, ring, (0, 0, .46), "local X (handle swing)")
    col_box("lantern", coll, (.26, .26, .46), (0, 0, .23), root)
    empty("light_anchor", coll, (0, 0, .18), root, .1, "SPHERE")


def build_street_lamp(coll, root, rng):
    base, postp, frame, glass, cap = Part("stone_base"), Part("post_bracket"), Part("lantern_frame"), Part("glass_insert"), Part("cap")
    base.add(prim_box(.5, .5, .32, bevel=.03), "stone_block", uv="world", matrix=T(0, 0, .16))
    base.add(prim_box(.4, .4, .3, bevel=.03), "stone_block", uv="world", matrix=T(0, 0, .47))
    base.add(prim_box(.46, .46, .08, bevel=.02), "stone_block", uv="world", matrix=T(0, 0, .65))
    x0 = -.22
    postp.add(prim_cyl(.05, .04, 2.2, segs=10, z0=.68), "iron", matrix=T(x0 + .22, 0, 0), smooth=True)
    for z in (.75, 1.6, 2.6):
        postp.add(prim_cyl(.065, .065, .05, segs=10, z0=z), "iron", matrix=T(x0 + .22, 0, 0))
    postp.add(prim_pyramid(.11, .2, z0=2.88), "iron", matrix=T(x0 + .22, 0, 0))
    postp.add(blob(.04, subdiv=1), "brass", matrix=T(x0 + .22, 0, 2.9), smooth=True)
    arm = [(0, 0, 2.65), (.25, 0, 2.7), (.5, 0, 2.66), (.62, 0, 2.62)]
    postp.add(prim_tube(arm, [.025] * 4, segs=6), "iron")
    curl = [(.02, 0, 2.35), (.18, 0, 2.42), (.32, 0, 2.55), (.4, 0, 2.66)]
    postp.add(prim_tube(curl, [.018] * 4, segs=6), "iron")
    postp.add(prim_torus(.06, .012, segs=10, rsegs=4), "iron", matrix=T(.12, 0, 2.43) @ R(math.pi / 2, 0, 0))
    postp.add(prim_tube([(.6, 0, 2.62), (.6, 0, 2.5)], [.012, .012], segs=4), "iron")
    L = T(.6, 0, 2.02)
    lantern_parts(frame, glass, cap, L, s=1.25)
    frame.add(prim_torus(.04, .01, segs=8, rsegs=4), "iron", matrix=L @ T(0, 0, .58) @ R(math.pi / 2, 0, 0))
    for p in (base, postp, frame, glass, cap):
        p.build(coll, parent=root)
    col_box("base", coll, (.5, .5, .72), (0, 0, .36), root)
    col_box("post", coll, (.12, .12, 2.3), (0, 0, 1.8), root)
    empty("light_anchor", coll, (.6, 0, 2.25), root, .1, "SPHERE")


def build_stone_well(coll, root, rng):
    ring, posts, roof, axle, rope, water = Part("stone_ring"), Part("posts"), Part("roof"), Part("windlass"), Part("rope_bucket"), Part("water_surface")
    R0 = .82
    for c in range(3):
        n = 12
        for i in range(n):
            a = 2 * math.pi * (i + .5 * (c % 2)) / n
            blk = prim_box(.42, .3, .24, bevel=.035)
            jitter(blk, .01, rng)
            ring.add(blk, "stone_block", matrix=T(math.cos(a) * R0, math.sin(a) * R0, .12 + c * .245) @ R(0, 0, a + math.pi / 2), uv="world")
    ring.add(prim_torus(R0, .17, segs=24, rsegs=6, uvscale=.6), "stone_block", matrix=T(0, 0, .78) @ S(1, 1, .45), smooth=False)
    ring.add(prim_cyl(R0 - .12, R0 - .12, .05, segs=20, z0=.0), "eye")
    water.add(prim_cyl(R0 - .14, R0 - .14, .01, segs=20, z0=.45), "water")
    for sx in (-1, 1):
        posts.add(prim_box(.14, .14, 1.75, bevel=.02), "timber", matrix=T(sx * (R0 + .05), 0, .35 + 1.75 / 2), uv="box", long_axis=2)
        posts.add(prim_box(.12, .45, .12), "timber", matrix=T(sx * (R0 + .05), 0, 2.05), uv="box", long_axis=1)
        for sy in (-1, 1):
            posts.add(prim_box(.08, .35, .08), "timber", matrix=T(sx * (R0 + .05), sy * .18, 1.82) @ R(sy * .7, 0, 0), uv="box", long_axis=1)
    posts.add(prim_box(2 * R0 + .3, .12, .12, bevel=.015), "timber", matrix=T(0, 0, 2.1), uv="box", long_axis=0)
    gable_roof(roof, T(0, 0, 2.05), 2 * R0 + .4, 1.0, .45, "roof_red", ov=.4, ovx=.12, thick=.08, ridge=True)
    for sx in (-1, 1):
        roof.add(prim_prism_xz([(-.5, 0), (.5, 0), (0, .43)], .04), "timber", matrix=T(sx * (R0 + .12), 0, 2.06) @ R(0, 0, math.pi / 2))
    # windlass: drum with rope turns and a crank, turning on local X
    az = 1.4
    axle.add(prim_cyl(.07, .07, 2 * R0 + .2, segs=10, z0=-(R0 + .1)), "wood_mid", matrix=T(0, 0, az) @ R(0, math.pi / 2, 0), uv="box")
    for k in range(5):
        axle.add(prim_torus(.08, .015, segs=10, rsegs=4), "rope", matrix=T(-.15 + k * .07, 0, az) @ R(0, math.pi / 2, 0))
    axle.add(prim_box(.04, .04, .32), "iron", matrix=T(R0 + .2, 0, az - .14))
    axle.add(prim_cyl(.025, .025, .18, segs=6, z0=0), "wood_dark", matrix=T(R0 + .2, 0, az - .3) @ R(0, math.pi / 2, 0))
    rope.add(prim_tube([(0, -.08, az - .05), (0, -.08, .95)], [.012, .012], segs=5), "rope")
    bucket(rope, T(0, -.08, .68))
    for p in (ring, posts, roof, rope, water):
        p.build(coll, parent=root)
    hinged(coll, root, axle, (0, 0, az), "local X (windlass)")
    col_hull("ring", coll, [(math.cos(a) * (R0 + .2), math.sin(a) * (R0 + .2), z) for a in [i * math.pi / 6 for i in range(12)] for z in (0, .85)], root)
    for sx in (-1, 1):
        col_box("post_%d" % (sx > 0), coll, (.16, .16, 2.2), (sx * (R0 + .05), 0, 1.1), root)


def build_market_stall(coll, root, rng):
    frame, canopy, counter, trays = Part("frame"), Part("canvas_canopy"), Part("counter"), Part("produce_trays")
    w, d = 2.5, 1.6
    for sx in (-1, 1):
        for sy, hh in ((-1, 2.05), (1, 2.35)):
            frame.add(prim_box(.11, .11, hh, bevel=.015), "wood_mid", matrix=T(sx * w / 2, sy * d / 2, hh / 2), uv="box", long_axis=2)
            frame.add(prim_box(.17, .17, .06), "iron", matrix=T(sx * w / 2, sy * d / 2, .03))
            frame.add(prim_box(.13, .13, .08), "iron", matrix=T(sx * w / 2, sy * d / 2, .9))
        frame.add(prim_box(.08, d, .08), "wood_mid", matrix=T(sx * w / 2, 0, 2.0) @ R(math.atan2(.3, d), 0, 0), uv="box", long_axis=1)
        frame.add(prim_box(.08, .5, .08), "wood_mid", matrix=T(sx * w / 2, -d / 2 + .25, 1.75) @ R(.7, 0, 0), uv="box", long_axis=1)
    for sy, z in ((-1, 2.0), (1, 2.3)):
        frame.add(prim_box(w + .1, .08, .08), "wood_mid", matrix=T(0, sy * d / 2, z), uv="box", long_axis=0)
    # counter: front box with shelf on top
    counter.add(prim_box(w, .6, .75, bevel=.02), "wood_light", matrix=T(0, -d / 2 + .35, .4), uv="box", long_axis=0, rng=rng)
    for i in range(1, 6):
        counter.add(prim_box(.012, .005, .7), "wood_dark", matrix=T(-w / 2 + i * w / 6, -d / 2 + .045, .4))
    counter.add(prim_box(w + .12, .7, .06, bevel=.01), "wood_mid", matrix=T(0, -d / 2 + .35, .8), uv="box", long_axis=0)
    counter.add(prim_box(w + .12, .1, .1), "wood_mid", matrix=T(0, -d / 2 + .02, .06), uv="box", long_axis=0)
    # empty built-in trays on the counter top
    for i in range(4):
        x = -w / 2 + .35 + i * (w - .7) / 3
        tr = Matrix.Translation((x, -d / 2 + .35, .83))
        trays.add(prim_box(.5, .5, .02), "wood_mid", matrix=tr @ T(0, 0, .01), uv="box")
        for sy in (-1, 1):
            trays.add(prim_box(.52, .03, .08), "wood_light", matrix=tr @ T(0, sy * .25, .05), uv="box", long_axis=0)
        for sx in (-1, 1):
            trays.add(prim_box(.03, .5, .08), "wood_light", matrix=tr @ T(sx * .25, 0, .05), uv="box", long_axis=1)
    # striped canopy with a scalloped front edge
    n = 9
    ang = math.atan2(.38, d + .5)
    Lc = math.hypot(.38, d + .5)
    for i in range(n):
        x = -w / 2 - .1 + (i + .5) * (w + .2) / n
        m = "canvas_green" if i % 2 else "canopy_cream"
        C = T(x, 0, 2.2) @ R(ang, 0, 0)
        canopy.add(prim_box((w + .2) / n + .003, Lc, .025), m, matrix=C @ T(0, -.02, .05), uv="box", long_axis=1)
        canopy.add(prim_prism_xz([(-(w + .2) / n / 2, 0), ((w + .2) / n / 2, 0), (0, -.16)], .01), m, matrix=T(x, -(d + .5) / 2, 2.2 - .19 + .05))
    for sx in (-1, 1):
        for sy in (-1, 1):
            canopy.add(prim_torus(.06, .015, segs=8, rsegs=4), "rope", matrix=T(sx * w / 2, sy * d / 2, 2.0 + (sy + 1) * .15 + .05))
    for p in (frame, canopy, counter, trays):
        p.build(coll, parent=root)
    col_box("counter", coll, (w + .12, .7, .85), (0, -d / 2 + .35, .425), root)
    for sx in (-1, 1):
        col_box("posts_%d" % (sx > 0), coll, (.12, d + .1, 2.3), (sx * w / 2, 0, 1.15), root)


def build_quest_noticeboard(coll, root, rng):
    back, frame, notices, pins = Part("wooden_backing"), Part("frame"), Part("loose_notices"), Part("pins_seals")
    w, h0, h1 = 2.0, .35, 1.6
    for i in range(6):
        z = h0 + (i + .5) * (h1 - h0) / 6
        back.add(prim_box(w, .05, (h1 - h0) / 6 - .012, bevel=.006), "wood_mid", matrix=T(0, 0, z), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        frame.add(prim_box(.14, .14, 1.78, bevel=.02), "wood_mid", matrix=T(sx * (w / 2 + .07), 0, .89), uv="box", long_axis=2)
        frame.add(prim_pyramid(.16, .1, z0=1.78), "wood_dark", matrix=T(sx * (w / 2 + .07), 0, 0))
        frame.add(prim_box(.2, .16, .08), "wood_dark", matrix=T(sx * (w / 2 + .07), 0, .04), uv="box")
        for z in (h0, h1):
            frame.add(prim_box(.16, .16, .1), "iron", matrix=T(sx * (w / 2 + .07), 0, z))
    for z in (h0 - .04, h1 + .04):
        frame.add(prim_box(w + .1, .1, .1, bevel=.015), "wood_light", matrix=T(0, -.01, z), uv="box", long_axis=0)
    sheets = [(-.65, 1.15, .42, .5, .05), (-.05, 1.05, .38, .6, -.04), (.55, 1.25, .32, .3, .08), (-.6, .6, .3, .34, -.06), (.5, .72, .4, .42, .03)]
    for i, (x, z, sw, sh, rot) in enumerate(sheets):
        Mn = T(x, -.03 - i * .002, z) @ R(0, rot, 0)
        bm = prim_box(sw, .006, sh)
        uv_planar(bm, axes=(0, 2))
        notices.add(bm, "parchment", matrix=Mn)
        pins.add(prim_cyl(.012, .012, .03, segs=6, z0=0), "iron", matrix=Mn @ T(0, -.005, sh / 2 - .03) @ R(math.pi / 2, 0, 0))
        if i in (0, 2, 4):
            pins.add(prim_cyl(.03, .03, .012, segs=10, z0=0), "wax_red", matrix=Mn @ T(sw * .3, -.006, -sh * .3) @ R(math.pi / 2, 0, 0))
    for p in (back, frame, notices, pins):
        p.build(coll, parent=root)
    col_box("board", coll, (w + .3, .16, 1.85), (0, 0, .92), root)


def build_guild_banner(coll, root, rng):
    rod, cloth, cords = Part("rod"), Part("cloth"), Part("hanging_cords")
    top = 1.6
    banner_rod(rod, T(0, 0, top), .92)
    cloth.add(prim_box(.74, .05, .05), "cloth_teal", matrix=T(0, 0, top - .02))
    banner_cloth(cloth, T(0, 0, top - .03), .7, 1.48, mat="cloth_teal", emblem="star")
    for sx in (-1, 1):
        cords.add(prim_tube([(sx * .4, 0, top), (sx * .2, 0, top + .08), (0, 0, top + .1)], [.008] * 3, segs=4), "rope")
    cords.add(prim_torus(.025, .006, segs=8, rsegs=4), "brass", matrix=T(0, 0, top + .12) @ R(math.pi / 2, 0, 0))
    for p in (rod, cloth, cords):
        p.build(coll, parent=root)
    empty("hang_point", coll, (0, 0, top + .13), root, .1)


def build_ledger_book(coll, root, rng):
    cov, pages, clasps = Part("covers_spine"), Part("page_block"), Part("clasps")
    w, d, h = .3, .23, .075
    for z in (.006, h - .006):
        cov.add(prim_box(w, d, .012, bevel=.004), "leather_red", matrix=T(0, 0, z), uv="box")
    sp = prim_cyl(h / 2, h / 2, d, segs=10, z0=-d / 2)
    for v in sp.verts:
        if v.co.x > 0:
            v.co.x *= .25
    cov.add(sp, "leather_red", matrix=T(-w / 2 + .01, 0, h / 2) @ R(math.pi / 2, 0, 0) @ R(0, 0, 0), smooth=True)
    for z in (h * .3, h * .7):
        cov.add(prim_box(.012, d + .004, .008), "leather_dark", matrix=T(-w / 2 - .005, 0, z))
    pages.add(prim_box(w - .02, d - .014, h - .024, bevel=.003), "parchment", matrix=T(.006, 0, h / 2), uv="box")
    for sx in (1,):
        for sy in (-1, 1):
            for z in (.006, h - .006):
                clasps.add(prim_box(.045, .045, .015), "brass", matrix=T(sx * (w / 2 - .02), sy * (d / 2 - .02), z))
    clasps.add(prim_box(.04, .03, h + .006), "brass", matrix=T(w / 2 - .005, 0, h / 2))
    for p in (cov, pages, clasps):
        p.build(coll, parent=root)
    col_box("book", coll, (w, d, h), (0, 0, h / 2), root)


def build_parchment_scroll(coll, root, rng):
    sheet, cord = Part("parchment"), Part("tie_cord")
    r = .028
    for sx, rr in ((-1, r), (1, r * .9)):
        sheet.add(prim_cyl(rr, rr, .19, segs=12, z0=-.095), "parchment", matrix=T(sx * .14, 0, rr) @ R(math.pi / 2, 0, 0), uv="box")
        sheet.add(prim_torus(rr * .5, rr * .18, segs=8, rsegs=4), "parchment", matrix=T(sx * .14, -.096, rr) @ R(math.pi / 2, 0, 0))
    bm = prim_box(.28, .17, .004)
    for v in bm.verts:
        v.co.z += .006 * math.sin(v.co.x * 25)
    sheet.add(bm, "parchment", matrix=T(0, 0, .012), uv="world")
    cord.add(prim_torus(.092, .006, segs=16, rsegs=4), "leather", matrix=T(.05, 0, .012) @ S(1, 1, .14) @ R(0, math.pi / 2, 0))
    cord.add(prim_tube([(.05, -.092, .014), (.07, -.12, .008), (.1, -.14, .005)], [.005] * 3, segs=4), "leather")
    cord.add(prim_tube([(.05, -.092, .014), (.035, -.125, .008), (.02, -.15, .005)], [.005] * 3, segs=4), "leather")
    sheet.build(coll, parent=root); cord.build(coll, parent=root)
    col_box("scroll", coll, (.34, .2, .06), (0, 0, .03), root)


def build_wooden_tankard(coll, root, rng):
    cup, handle, bands = Part("cup_body"), Part("handle"), Part("rim_bands")
    prof = [(.0, .0), (.062, 0), (.06, .2), (.053, .2), (.054, .02), (0, .02)]
    cup.add(prim_lathe(prof, segs=16, uvscale=.15, close_bottom=False), "wood_mid", smooth=True)
    for k in range(12):
        a = 2 * math.pi * k / 12
        cup.add(prim_box(.003, .003, .19), "wood_dark", matrix=T(math.cos(a) * .0625, math.sin(a) * .0625, .1) @ R(0, 0, a))
    for z in (.03, .1, .18):
        bands.add(prim_torus(.064, .007, segs=16, rsegs=4), "iron", matrix=T(0, 0, z) @ S(1, 1, 1.8))
    handle.add(prim_tube([(.06, 0, .17), (.1, 0, .165), (.11, 0, .1), (.095, 0, .04), (.06, 0, .035)], [.012, .013, .014, .013, .012], segs=6, flat_y=1.6), "wood_mid", smooth=True)
    for p in (cup, handle, bands):
        p.build(coll, parent=root)
    col_box("tankard", coll, (.13, .13, .2), (0, 0, .1), root)


def build_metal_pitcher(coll, root, rng):
    body, handle = Part("body"), Part("handle")
    prof = [(0, 0), (.06, 0), (.065, .01), (.095, .08), (.098, .13), (.08, .2), (.055, .25), (.058, .28), (.068, .31), (.064, .315), (.05, .28), (.045, .25), (0, .25)]
    bm = prim_lathe(prof, segs=20, uvscale=.3, close_bottom=False)
    for v in bm.verts:  # pull the rim out into a spout toward -Y
        if v.co.z > .26:
            a = math.atan2(v.co.y, v.co.x)
            k = max(0, -math.cos(a)) ** 3
            v.co.x -= k * .07 * (v.co.z - .26) / .055
            v.co.z += k * .015
    body.add(bm, "pewter", smooth=True)
    handle.add(prim_tube([(.055, 0, .27), (.11, 0, .27), (.135, 0, .2), (.115, 0, .1), (.085, 0, .06)], [.011, .012, .012, .011, .01], segs=6, flat_y=.6), "pewter", smooth=True)
    body.build(coll, parent=root); handle.build(coll, parent=root)
    col_hull("pitcher", coll, [(math.cos(a) * .1, math.sin(a) * .1, z) for a in [i * math.pi / 4 for i in range(8)] for z in (0, .32)], root)


def build_market_handcart(coll, root, rng):
    tray, axles, shafts = Part("cargo_tray"), Part("axles"), Part("pulling_shafts")
    L, W = 1.35, .9
    zb = .42
    tray.add(prim_box(L, W, .05, bevel=.01), "wood_light", matrix=T(.3, 0, zb), uv="box", long_axis=0)
    for sy in (-1, 1):
        for z in (zb + .1, zb + .25):
            tray.add(prim_box(L, .04, .13, bevel=.008), "wood_light", matrix=T(.3, sy * W / 2, z), uv="box", long_axis=0, rng=rng)
    for sx in (-1, 1):
        for z in (zb + .1, zb + .25):
            tray.add(prim_box(.04, W, .13, bevel=.008), "wood_light", matrix=T(.3 + sx * L / 2, 0, z), uv="box", long_axis=1, rng=rng)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tray.add(prim_box(.07, .07, .38, bevel=.01), "wood_mid", matrix=T(.3 + sx * L / 2, sy * W / 2, zb + .17), uv="box", long_axis=2)
            tray.add(prim_box(.08, .08, .05), "iron", matrix=T(.3 + sx * L / 2, sy * W / 2, zb + .3))
    rw = .2
    for x in (-.15, .75):
        axles.add(prim_cyl(.03, .03, W + .22, segs=8, z0=-(W + .22) / 2), "iron", matrix=T(x, 0, rw) @ R(math.pi / 2, 0, 0))
        axles.add(prim_box(.08, W - .1, .06), "wood_mid", matrix=T(x, 0, zb - .05), uv="box", long_axis=1)
        for sy in (-1, 1):
            wh = Part("wheel_%s_%s" % ("front" if x < 0 else "rear", "L" if sy > 0 else "R"))
            wheel(wh, T(x, sy * (W / 2 + .1), rw) @ R(0, 0, math.pi / 2), r=rw, spokes=6)
            hinged(coll, root, wh, (x, sy * (W / 2 + .1), rw), "local Y (axle)")
    for sy in (-1, 1):
        shafts.add(prim_tube([(.6, sy * .32, zb - .04), (-.4, sy * .32, zb - .04), (-1.38, sy * .3, zb + .12)], [.028, .028, .025], segs=6), "wood_mid")
        shafts.add(prim_tube([(-1.38, sy * .3, zb + .12), (-1.52, sy * .3, zb + .14)], [.03, .03], segs=6), "wood_dark")
    shafts.add(prim_tube([(-1.1, -.31, zb + .075), (-1.1, .31, zb + .075)], [.022, .022], segs=6), "wood_mid")
    for p in (tray, axles, shafts):
        p.build(coll, parent=root)
    col_box("tray", coll, (L, W, .4), (.3, 0, zb + .15), root)
