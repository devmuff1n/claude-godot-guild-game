# Town kit: buildings (loaded by build_town_kit.py into its namespace).


def hanging_board(coll, root, M, w, h, mat, name="hanging_sign", emblem="star", trim="brass"):
    """Sign board hanging under the point M (pivot), swinging around local X."""
    sg = Part(name)
    for sx in (-1, 1):
        sg.add(prim_tube([(sx * w * .3, 0, 0), (sx * w * .3, 0, -.16)], [.008, .008], segs=4), "iron", matrix=M)
    outline = [(-w / 2, -.16), (w / 2, -.16), (w / 2, -.16 - h * .75), (0, -.16 - h), (-w / 2, -.16 - h * .75)]
    sg.add(prim_prism_xz(list(reversed(outline)), .05), mat, matrix=M @ T(0, .025, 0), uv="world")
    for (a, b) in zip(outline, outline[1:] + outline[:1]):
        (x0, z0), (x1, z1) = a, b
        Lg = math.hypot(x1 - x0, z1 - z0); ang = math.atan2(z1 - z0, x1 - x0)
        sg.add(prim_box(Lg + .03, .07, .04), trim, matrix=M @ T((x0 + x1) / 2, 0, (z0 + z1) / 2) @ R(0, -ang, 0))
    E = M @ T(0, -.04, -.16 - h * .45)
    if emblem == "star":
        for k in range(4):
            sg.add(prim_prism_xz([(0, -.04), (w * .28, 0), (0, .04)], .02), trim, matrix=E @ R(0, -k * math.pi / 2, 0))
        sg.add(prim_torus(w * .14, .014, segs=14, rsegs=4), trim, matrix=E @ R(math.pi / 2, 0, 0))
    ob = sg.build(coll, pivot=M.to_translation(), parent=root)
    ob["pivot_axis"] = "local X (swing)"
    return ob


def build_party_inn(coll, root, rng):
    walls, roof, deco = Part("walls"), Part("roof"), Part("balcony")
    pz, hw = .5, 3.4
    Mm = T(0, .45, 0)
    F = volume(walls, roof, Mm, 4.6, 3.3, hw, 2.1, "roof_blue", pz=pz, rail=.5,
               openings={"front": [(-2.0, -1.2, .6, 1.6), (-2.0, -1.2, 2.2, 3.1), (1.45, 2.05, .6, 1.6), (1.4, 2.1, 2.2, 3.1)],
                         "left": [(-.9, -.1, .6, 1.6), (.3, 1.1, 2.2, 3.0)], "right": [(-.4, .4, .6, 1.6), (-.4, .4, 2.2, 3.1)],
                         "back": [(-1.2, -.4, .6, 1.5), (.6, 1.4, 2.2, 3.0)]})
    for (x, z) in ((-1.6, .65), (-1.6, 2.25), (1.75, .65), (1.75, 2.25)):
        window(walls, F["front"], x, z, .58, .95, arch=True, rng=rng, box=(z > 1 and x > 0))
    window(walls, F["left"], -.5, .65, .55, .9, rng=rng); window(walls, F["left"], .7, 2.25, .55, .8, rng=rng)
    window(walls, F["right"], 0, .65, .55, .9, rng=rng); window(walls, F["right"], 0, 2.25, .55, .9, rng=rng)
    window(walls, F["back"], -.8, .65, .55, .8, arch=False, rng=rng); window(walls, F["back"], 1.0, 2.25, .55, .8, rng=rng)
    # central front bay with door, balcony and gable
    Mc = T(.15, -1.15, 0) @ R(0, 0, math.pi / 2)
    door_w, door_h = .95, 1.85
    Fc = volume(walls, roof, Mc, 1.5, 2.1, hw, 1.8, "roof_blue", pz=pz, gables=("left",), gable_windows=("left",), rail=.5,
                openings={"left": [(-.6, .6, 0, door_h + .2), (-.45, .45, 2.0, 3.2)]}, ov=.35, ovx=.3)
    G = Fc["left"]
    stone_arch(walls, G, 0, door_w, door_h)
    door_leaf(coll, root, G, 0, door_w, door_h)
    window(walls, G, 0, 2.05, .62, 1.05, arch=True, rng=rng)
    window(walls, G, 0, hw + .15, .5, .75, arch=True, rng=rng)
    wall_lantern(walls, G, -.78, 1.5); wall_lantern(walls, G, .78, 1.5)
    gy = -1.15 - .75  # front face of the bay
    steps(walls, T(.15, gy - .75, 0), 1.3, n=3, rise=.167, run=.26)
    walls.add(prim_box(2.4, .8, .5), "stone_block", matrix=T(.15, gy - .4, .25), uv="world")
    # balcony = porch roof: deck on two posts, railing with balusters, blue roof edge below
    bz = pz + 1.72
    deco.add(prim_box(2.7, .95, .14, bevel=.02), "timber", matrix=T(.15, gy - .45, bz), uv="box", long_axis=0)
    for sx in (-1, 1):
        deco.add(prim_box(.17, .17, bz, bevel=.02), "timber", matrix=T(.15 + sx * 1.22, gy - .82, bz / 2), uv="box", long_axis=2)
        deco.add(prim_box(.3, .3, .2), "stone_block", matrix=T(.15 + sx * 1.22, gy - .82, .1), uv="world")
        deco.add(prim_box(.12, .55, .12), "timber", matrix=T(.15 + sx * 1.22, gy - .5, bz - .35) @ R(.8, 0, 0), uv="box", long_axis=1)
    deco.add(prim_box(2.76, .09, .12), "timber", matrix=T(.15, gy - .9, bz + .85), uv="box", long_axis=0)
    for sx in (-1, 1):
        deco.add(prim_box(.09, .95, .12), "timber", matrix=T(.15 + sx * 1.33, gy - .45, bz + .85), uv="box", long_axis=1)
    for i in range(13):
        x = .15 - 1.3 + i * 2.6 / 12
        deco.add(prim_cyl(.03, .03, .78, segs=6, z0=bz + .07), "wood_mid", matrix=T(x, gy - .9, 0))
    for sy in (0, 1):
        for sx in (-1, 1):
            deco.add(prim_cyl(.03, .03, .78, segs=6, z0=bz + .07), "wood_mid", matrix=T(.15 + sx * 1.33, gy - .2 - sy * .35, 0))
    for sx in (-1, 1):
        deco.add(prim_box(.12, .12, .95), "timber", matrix=T(.15 + sx * 1.33, gy - .9, bz + .45), uv="box", long_axis=2)
        deco.add(prim_pyramid(.12, .12, z0=bz + .92), "brass", matrix=T(.15 + sx * 1.33, gy - .9, 0))
    roof.add(prim_box(2.9, .75, .1, bevel=.02), "roof_blue", matrix=T(.15, gy - .55, bz - .12) @ R(-.32, 0, 0), uv="box", long_axis=0)
    # dormer on the left of the front slope, chimney on the right
    dormer(walls, roof, T(-1.45, .45 - 1.6, pz + hw - .05), 1.0, 1.4, .8, .55, "roof_blue", rng)
    chimney(walls, T(1.35, 1.0, 0), .7, .7, 6.7, z0=3.5)
    # blue banner on the front wall
    ban = Part("banners")
    M = F["front"] @ T(-.85, -.12, 3.2)
    banner_rod(ban, M, .62); banner_cloth(ban, M @ T(0, 0, -.03), .5, 1.25, emblem="star")
    # hanging sign on an iron bracket at the right front corner
    br, hang = bracket_sign(coll, root, T(2.3, -1.0, 3.25), length=.85)
    hanging_board(coll, root, hang, .5, .62, "cloth_navy", emblem="star")
    for p in (walls, roof, deco, ban, br):
        p.build(coll, parent=root)
    col_box("body", coll, (4.7, 3.4, pz + hw + 1.2), (0, .45, (pz + hw + 1.2) / 2), root)
    col_box("bay", coll, (2.2, 1.6, pz + hw), (.15, -1.15, (pz + hw) / 2), root)
    col_box("porch_posts", coll, (2.7, .3, bz), (.15, gy - .82, bz / 2), root)


def bell_tower(walls, roof, M, s=1.0):
    """Square timber bell tower; M at its base centre (inside the main roof)."""
    w = 1.1 * s
    walls.add(prim_box(w, w, .9, bevel=.02), "plaster", matrix=M @ T(0, 0, .45), uv="world")
    for sx in (-1, 1):
        for sy in (-1, 1):
            walls.add(prim_box(.14, .14, 1.9, bevel=.015), "timber", matrix=M @ T(sx * (w / 2 - .02), sy * (w / 2 - .02), .95), uv="box", long_axis=2)
    for z in (.9, 1.0):
        walls.add(prim_box(w + .1, w + .1, .1, bevel=.015), "timber", matrix=M @ T(0, 0, z), uv="box")
    for k in range(4):
        F = M @ R(0, 0, k * math.pi / 2) @ T(0, -w / 2 - .01, 0)
        beam(walls, F, (-w / 2, .1), (w / 2, .85), .1)
        pts = arch_pts(0, 1.35, w * .36, 8)
        walls.add(prim_tube([(px, -.03, pz) for px, pz in pts], [.05] * len(pts), segs=6), "timber", matrix=F)
        walls.add(prim_box(w, .1, .08), "timber", matrix=F @ T(0, .02, 1.05))
    walls.add(prim_box(w + .12, w + .12, .12, bevel=.02), "timber", matrix=M @ T(0, 0, 1.9), uv="box")
    walls.add(prim_lathe([(.0, 1.1), (.26 * s, 1.12), (.22 * s, 1.3), (.15 * s, 1.55), (.06, 1.62)], segs=14, uvscale=.4, close_bottom=False), "brass", matrix=M, smooth=True)
    walls.add(prim_cyl(.04, .04, w, segs=6, z0=-w / 2), "iron", matrix=M @ T(0, 0, 1.7) @ R(0, math.pi / 2, 0))
    roof.add(prim_box(w + .5, w + .5, .1, bevel=.02), "roof_red", matrix=M @ T(0, 0, 2.0), uv="box")
    roof.add(prim_pyramid(w + .45, 1.05 * s, z0=2.05), "roof_red", matrix=M, uv="world")
    roof.add(prim_cyl(.03, .03, .42, segs=6, z0=3.0 * s), "brass", matrix=M)
    roof.add(blob(.06, subdiv=1), "brass", matrix=M @ T(0, 0, 3.08 * s), smooth=True)
    roof.add(prim_prism_xz([(0, 0), (.45, -.07), (.38, -.12), (.5, -.2), (0, -.18)], .015), "cloth_navy", matrix=M @ T(.02, 0, 3.4 * s))


def crest_shield(part, M, w=.84, h=.86, face="cloth_navy"):
    outline = [(-w / 2, h * .44), (w / 2, h * .44), (w / 2, -h * .06), (0, -h * .56), (-w / 2, -h * .06)]
    part.add(prim_prism_xz(list(reversed(outline)), .06), face, matrix=M @ T(0, .03, 0), uv="world")
    for (a, b) in zip(outline, outline[1:] + outline[:1]):
        (x0, z0), (x1, z1) = a, b
        Lg = math.hypot(x1 - x0, z1 - z0); ang = math.atan2(z1 - z0, x1 - x0)
        part.add(prim_box(Lg + .06, .1, .07), "brass", matrix=M @ T((x0 + x1) / 2, -.01, (z0 + z1) / 2) @ R(0, -ang, 0))
    crossed_swords(part, M @ T(0, -.06, 0), s=w * 1.1, mat="steel", hilt="brass")
    part.add(blob(.07, subdiv=1), "brass", matrix=M @ T(0, -.06, h * .55), smooth=True)


def build_guild_hall_exterior(coll, root, rng):
    walls, roof = Part("walls"), Part("roof")
    pz, hw = .6, 2.6
    Mm = T(0, .65, 0)
    F = volume(walls, roof, Mm, 6.2, 4.0, hw, 2.5, "roof_red", pz=pz,
               openings={"front": [(-2.85, -2.25, .7, 1.8), (2.25, 2.85, .7, 1.8)],
                         "left": [(-1.4, -.6, .7, 1.8), (.6, 1.4, .7, 1.8)], "right": [(-1.4, -.6, .7, 1.8), (.6, 1.4, .7, 1.8)],
                         "back": [(-1.5, -.9, .7, 1.8), (.9, 1.5, .7, 1.8)]})
    for x in (-2.55, 2.55):
        window(walls, F["front"], x, .75, .48, 1.0, rng=rng)
    for k in ("left", "right"):
        for x in (-1.0, 1.0):
            window(walls, F[k], x, .75, .55, 1.0, rng=rng)
        window(walls, F[k], 0, hw + .25, .5, .8, rng=rng)
    for x in (-1.2, 1.2):
        window(walls, F["back"], x, .75, .5, 1.0, rng=rng)
    Mc = T(0, -1.35, 0) @ R(0, 0, math.pi / 2)
    door_w, door_h = 1.15, 2.1
    Fc = volume(walls, roof, Mc, 1.5, 2.6, hw, 2.5, "roof_red", pz=pz, gables=("left",), gable_windows=("left",),
                openings={"left": [(-.75, .75, 0, door_h + .25)]}, ov=.4, ovx=.35)
    G = Fc["left"]
    stone_arch(walls, G, 0, door_w, door_h, depth=.18, thick=.2)
    door_leaf(coll, root, G, 0, door_w, door_h)
    wall_lantern(walls, G, -.95, 1.6); wall_lantern(walls, G, .95, 1.6)
    window(walls, G, 0, hw + 1.05, .46, .7, arch=True, rng=rng)
    gy = -1.35 - .75
    steps(walls, T(0, gy, 0), 2.2, n=4, rise=.15, run=.28)
    for sx in (-1, 1):
        walls.add(prim_box(.4, 1.1, .7, bevel=.03), "stone_block", matrix=T(sx * 1.45, gy - .55, .35), uv="world")
        walls.add(prim_box(.46, .46, .12, bevel=.02), "stone_block", matrix=T(sx * 1.45, gy - .9, .76), uv="world")
    crest = Part("crest")
    crest_shield(crest, G @ T(0, -.06, hw + .4))
    ban = Part("banners")
    for x in (-1.75, 1.75):
        M = F["front"] @ T(x, -.14, 2.45)
        ban.add(prim_box(.05, .16, .05), "iron", matrix=M @ T(0, .07, 0))
        banner_rod(ban, M, .62)
        banner_cloth(ban, M @ T(0, 0, -.03), .5, 1.55, emblem="swords")
    for x in (-2.2, 2.2):
        dormer(walls, roof, T(x, .65 - 1.6, pz + hw - .05), .9, 1.4, .7, .5, "roof_red", rng)
    bell_tower(walls, roof, T(0, .9, pz + hw + 2.5 - .8))
    for p in (walls, roof, crest, ban):
        p.build(coll, parent=root)
    col_box("body", coll, (6.3, 4.1, pz + hw + 1.3), (0, .65, (pz + hw + 1.3) / 2), root)
    col_box("entrance", coll, (2.6, 1.6, pz + hw), (0, -1.35, (pz + hw) / 2), root)
    col_box("steps", coll, (3.3, 1.2, .6), (0, gy - .55, .3), root)
