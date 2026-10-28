# Writes scenes/village/Town3D.tscn — the guild settlement (layout after the concept
# ChatGPT/godot-guild-relationship-game/assets/village/guild_district/concepts/town-kit-v1.png):
# round cobbled square with the well, guild hall up north, inn west, smithy east, market south-east,
# winding dirt paths, cottages, a creek with a footbridge in the south-west, forest around.
# Godot coords: x right, y up, z toward the camera; models face +Z at rotation 0.
# Note: tscn Transform3D lists the basis by rows.
# Usage: python gen_town3d.py
import math, random

OUT = r"C:\Users\armor\Documents\poorest_guild\scenes\village\Town3D.tscn"
T = "res://assets/models/town/"
E = "res://assets/models/environment/"
MODELS = {
    "guild_hall_exterior": T + "buildings/", "party_inn": T + "buildings/", "village_cottage": T + "buildings/",
    "blacksmith_exterior": T + "buildings/", "alchemy_workshop_exterior": T + "buildings/", "leather_workshop_exterior": T + "buildings/",
    "stone_well": T + "props/", "market_stall": T + "props/", "quest_noticeboard": T + "props/", "street_lamp": T + "props/",
    "wooden_barrel": T + "props/", "wooden_crate": T + "props/", "burlap_sack": T + "props/", "wicker_basket": T + "props/",
    "wooden_planter": T + "props/", "market_handcart": T + "props/", "small_wooden_chest": T + "props/",
    "village_bench": T + "furniture/", "guild_table": T + "furniture/", "guild_backless_bench": T + "furniture/",
    "anvil": T + "crafts/", "tanning_vat": T + "crafts/", "hide_stretching_rack": T + "crafts/",
    "weapon_rack": T + "crafts/", "leather_roll": T + "crafts/",
    "oak_tree": E + "vegetation/", "pine_tree": E + "vegetation/", "roadside_bush": E + "vegetation/", "grass_tuft": E + "vegetation/",
    "flower_patch": E + "vegetation/", "potted_plant": E + "vegetation/",
    "wooden_garden_fence": E + "road_defense/", "low_stone_wall": E + "road_defense/", "wooden_barricade": E + "road_defense/",
    "round_watch_shield": E + "road_defense/", "decorative_spear": E + "road_defense/", "timber_footbridge": E + "road_defense/",
    "vegetable_garden_bed": E + "landscape/", "field_rock": E + "landscape/", "stream_channel": E + "landscape/",
}
ids = {k: "m_" + k for k in MODELS}


def face(pos, target=(0, 0)):
    """Rotation (deg) that turns a model's front (+Z) toward target (x, z)."""
    return math.degrees(math.atan2(target[0] - pos[0], target[1] - pos[2]))


# hotspot: name, tab, title, position, rot_y, collision size, collision centre, badge height, children [(model, pos, rot)]
GH = (0, 0, -11.5)
INN = (-12.5, 0, -3.0)
SMITH = (12.5, 0, -2.5)
ALCH = (10.5, 0, -13.5)
TAN = (-11.0, 0, -14.0)
MARKET = (8.0, 0, 7.0)
YARD = (-7.0, 0, 9.0)
HOT = [
    ("GuildHall", "home", "Дом гильдии", GH, 0, (7.4, 8.4, 6.6), (0, 4.2, 0), 9.0,
     [("guild_hall_exterior", (0, 0, 0), 0), ("potted_plant", (-1.7, 0, -2.5 + 6.0), 0)]),
    ("PartyInn", "party", "Дом отряда", INN, face(INN), (6.4, 6.8, 6.2), (0, 3.4, 0), 7.4,
     [("party_inn", (0, 0, 0), 0), ("guild_table", (2.6, 0, 4.0), 90), ("guild_backless_bench", (2.0, 0, 4.0), 90),
      ("guild_backless_bench", (3.2, 0, 4.0), 90), ("wooden_barrel", (-2.9, 0, 3.0), 0), ("weapon_rack", (-3.4, 0, 1.0), 70)]),
    ("Noticeboard", "board", "Доска поручений", (4.2, 0, -7.4), -20, (2.6, 2.1, 1.0), (0, 1.0, 0), 2.6,
     [("quest_noticeboard", (0, 0, 0), 0)]),
    ("Alchemist", "shop", "Алхимик", ALCH, -25, (6.6, 6.2, 5.2), (0, 3.1, 0), 6.8,
     [("alchemy_workshop_exterior", (0, 0, 0), 0), ("wooden_planter", (-2.2, 0, 3.0), 0)]),
    ("Smithy", "shop", "Кузница", SMITH, face(SMITH), (6.8, 6.4, 5.2), (0, 3.2, 0), 7.0,
     [("blacksmith_exterior", (0, 0, 0), 0), ("anvil", (1.8, 0, 2.6), -20), ("wooden_barrel", (-2.8, 0, 2.8), 0),
      ("wooden_crate", (-2.2, 0, 3.2), 25)]),
    ("Tannery", "shop", "Кожевня", TAN, 25, (6.8, 5.0, 5.2), (0, 2.5, 0), 5.6,
     [("leather_workshop_exterior", (0, 0, 0), 0), ("tanning_vat", (2.2, 0, 2.8), 0), ("hide_stretching_rack", (3.6, 0, 1.6), -40),
      ("leather_roll", (0.8, 0, 3.1), 15)]),
    ("Market", "shop", "Рынок", MARKET, -35, (7.6, 2.6, 3.4), (0, 1.25, 0), 3.2,
     [("market_stall", (-2.9, 0, 0.3), 12), ("market_stall", (0, 0, -0.2), 0), ("market_stall", (2.9, 0, 0.3), -12),
      ("wicker_basket", (-3.4, .88, -.05), 0), ("wicker_basket", (-0.5, .88, -.55), 30), ("wicker_basket", (2.4, .88, -.05), 0),
      ("burlap_sack", (4.6, 0, .6), 0), ("burlap_sack", (4.9, 0, 1.1), 40), ("wooden_crate", (-4.5, 0, .8), 20),
      ("wooden_barrel", (-4.4, 0, -.4), 0), ("market_handcart", (1.0, 0, 2.6), 10)]),
    ("TrainingYard", "arena", "Тренировочный двор", YARD, 25, (6.4, 2.4, 3.8), (0, 1.1, 0), 2.8,
     [("wooden_garden_fence", (-1.5, 0, -1.5), 0), ("wooden_garden_fence", (1.5, 0, -1.5), 0), ("wooden_garden_fence", (-1.5, 0, 1.5), 0),
      ("wooden_garden_fence", (-3.0, 0, 0.0), 90), ("wooden_garden_fence", (3.0, 0, 0.0), 90), ("weapon_rack", (-0.8, 0, -0.9), 0),
      ("decorative_spear", (2.3, 0, -1.0), 0), ("decorative_spear", (2.5, 0, -0.9), 0), ("round_watch_shield", (1.6, 0.0, -1.05), 0),
      ("wooden_barricade", (0.6, 0, 0.3), 15), ("wooden_barrel", (-2.4, 0, -0.9), 0)]),
]

DECOR = [("stone_well", (0, 0, 0), 20)]
# lamps and benches around the square
for ang in (35, 145, 215, 325, 100, 260):
    a = math.radians(ang)
    p = (math.cos(a) * 6.9, 0, math.sin(a) * 6.9)
    DECOR.append(("street_lamp", p, face(p) + 90))
for ang in (60, 200):
    a = math.radians(ang)
    p = (math.cos(a) * 5.3, 0, math.sin(a) * 5.3)
    DECOR.append(("village_bench", p, face(p) + 180))
DECOR += [
    ("wooden_planter", (-3.0, 0, -9.0), 0), ("wooden_planter", (3.0, 0, -9.6), 0), ("small_wooden_chest", (2.6, 0, -6.6), -30),
    # cottages
    ("village_cottage", (5.6, 0, 14.6), -90), ("village_cottage", (-19.0, 0, 13.0), 60), ("village_cottage", (-21.0, 0, -9.0), 70),
    ("village_cottage", (21.0, 0, -8.0), -70), ("village_cottage", (19.0, 0, 9.0), -110),
    ("vegetable_garden_bed", (9.6, 0, 15.0), 0), ("wooden_garden_fence", (9.6, 0, 17.0), 0), ("wooden_garden_fence", (12.4, 0, 17.0), 0),
    ("vegetable_garden_bed", (-17.6, 0, -5.0), 70), ("wooden_garden_fence", (-16.5, 0, -2.4), 70),
    ("hide_stretching_rack", (-15.2, 0, -12.4), 30), ("wooden_crate", (15.4, 0, -5.4), 0), ("burlap_sack", (16.0, 0, -5.0), 0),
    # creek with a footbridge (south-west)
    ("timber_footbridge", (-15.0, 0.0, 8.4), 31),
    ("field_rock", (-12.6, 0, 5.6), 30), ("field_rock", (-21.0, 0, 14.6), 120), ("field_rock", (-23.0, 0, 4.5), 0),
    ("field_rock", (22.5, 0, 0.5), 80), ("field_rock", (-3.6, 0, 15.2), 200),
]
# stream pieces along a line through the bridge
d = (0.52, 0.855)
rot_stream = math.degrees(math.atan2(-d[1], d[0]))  # local +X along (d.x, d.z)
for k in range(-8, 6):
    c = (-15.0 + d[0] * 6 * k, 0, 8.4 + d[1] * 6 * k)
    DECOR.append(("stream_channel", (c[0], 0.0, c[2]), rot_stream))
# trees: forest ring + scattered
rng = random.Random(7)
FIX_TREES = [("oak_tree", (-6.0, 0, -15.0)), ("oak_tree", (6.5, 0, -16.5)), ("oak_tree", (-16.5, 0, 3.6)), ("oak_tree", (17.0, 0, 3.0)),
             ("oak_tree", (-2.4, 0, 9.6)), ("oak_tree", (13.0, 0, 13.0)), ("oak_tree", (-9.6, 0, 16.0)), ("pine_tree", (-16.0, 0, -18.0)),
             ("pine_tree", (16.0, 0, -18.5)), ("pine_tree", (0.5, 0, -19.0)), ("pine_tree", (-4.0, 0, -20.0)), ("pine_tree", (4.5, 0, -21.0)),
             ("pine_tree", (-24.0, 0, -15.0)), ("pine_tree", (24.0, 0, -14.0)), ("pine_tree", (-26.0, 0, -2.0)), ("pine_tree", (26.0, 0, -1.0)),
             ("pine_tree", (25.0, 0, 12.0)), ("pine_tree", (-10.0, 0, -21.0)), ("pine_tree", (10.0, 0, -22.0)), ("pine_tree", (-20.0, 0, -21.0)),
             ("pine_tree", (20.0, 0, -22.0)), ("oak_tree", (-25.0, 0, 8.0)), ("pine_tree", (14.0, 0, 18.0)), ("pine_tree", (-6.0, 0, 19.0))]
for (m, p) in FIX_TREES:
    DECOR.append((m, p, rng.uniform(0, 360)))
for p in [(-4.2, 0, -12.6), (4.6, 0, -13.2), (-7.6, 0, -6.4), (7.8, 0, -6.6), (-17.6, 0, -9.6), (17.4, 0, -10.2), (-8.6, 0, 4.0),
          (14.6, 0, 6.8), (3.0, 0, 9.4), (-12.0, 0, 7.2), (-2.0, 0, 13.0), (11.2, 0, 10.4), (16.6, 0, -13.4), (-16.6, 0, -15.6),
          (21.0, 0, 15.0), (-12.6, 0, 17.6)]:
    DECOR.append(("roadside_bush", p, rng.uniform(0, 360)))
for i in range(22):
    a = rng.uniform(0, 2 * math.pi); r = rng.uniform(7.6, 17.0)
    p = (math.cos(a) * r * 1.2, 0, math.sin(a) * r * .8)
    DECOR.append(("flower_patch" if i % 3 == 0 else "grass_tuft", p, rng.uniform(0, 360)))

# dirt paths (polyline, width)
PATHS = [
    ([(0, -5.5), (0, -8.6)], 3.2),
    ([(-5.8, -1.2), (-8.4, -2.0), (-10.0, -2.6)], 2.2),
    ([(5.8, -1.0), (8.2, -1.8), (10.0, -2.2)], 2.2),
    ([(0.6, 5.8), (1.2, 9.0), (0.4, 12.5), (-0.6, 16.0), (-1.6, 22.0)], 2.2),
    ([(-4.6, 3.8), (-7.4, 5.6), (-10.8, 7.2), (-14.6, 8.6), (-18.2, 10.2), (-21.8, 11.8), (-26.0, 13.0)], 2.0),
    ([(4.4, 4.2), (6.2, 5.6)], 2.2),
    ([(3.8, -4.4), (6.6, -7.6), (8.8, -10.4)], 2.0),
    ([(-3.8, -4.4), (-6.8, -7.8), (-9.2, -11.0)], 2.0),
    ([(-14.6, 8.6), (-13.2, 10.4)], 1.6),
    ([(1.2, 9.0), (3.0, 11.2)], 1.6),
]

L = []
ext = []
for k, base in MODELS.items():
    ext.append('[ext_resource type="PackedScene" path="%s%s.glb" id="%s"]' % (base, k, ids[k]))
ext.append('[ext_resource type="Script" path="res://scripts/ui/village/TownHotspot.gd" id="s_hot"]')
ext.append('[ext_resource type="Texture2D" path="res://assets/textures/town/grass_ground.png" id="t_grass"]')
ext.append('[ext_resource type="Texture2D" path="res://assets/textures/town/dirt_road.png" id="t_dirt"]')
ext.append('[ext_resource type="Texture2D" path="res://assets/textures/town/stone_block.png" id="t_stone"]')
ext.append('[ext_resource type="Texture2D" path="res://assets/textures/town/cobble.png" id="t_cobble"]')
sub = []
sub.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.62, 0.74, 0.84, 1)
ambient_light_source = 2
ambient_light_color = Color(0.86, 0.9, 0.95, 1)
ambient_light_energy = 0.42
fog_enabled = true
fog_light_color = Color(0.66, 0.76, 0.84, 1)
fog_density = 0.0025''')
sub.append('''[sub_resource type="StandardMaterial3D" id="mat_grass"]
albedo_color = Color(0.85, 0.9, 0.8, 1)
albedo_texture = ExtResource("t_grass")
roughness = 1.0
uv1_scale = Vector3(0.4, 0.4, 0.4)
uv1_triplanar = true
uv1_world_triplanar = true''')
sub.append('''[sub_resource type="PlaneMesh" id="mesh_grass"]
material = SubResource("mat_grass")
size = Vector2(150, 70)''')
sub.append('''[sub_resource type="StandardMaterial3D" id="mat_dirt"]
albedo_color = Color(0.8, 0.72, 0.6, 1)
albedo_texture = ExtResource("t_dirt")
roughness = 1.0
uv1_scale = Vector3(0.45, 0.45, 0.45)
uv1_triplanar = true
uv1_world_triplanar = true''')
sub.append('''[sub_resource type="PlaneMesh" id="mesh_path"]
material = SubResource("mat_dirt")
size = Vector2(1, 1)''')
sub.append('''[sub_resource type="CylinderMesh" id="mesh_joint"]
material = SubResource("mat_dirt")
top_radius = 0.5
bottom_radius = 0.5
height = 0.02
radial_segments = 16
rings = 1''')
sub.append('''[sub_resource type="StandardMaterial3D" id="mat_cobble"]
albedo_color = Color(0.95, 0.92, 0.88, 1)
albedo_texture = ExtResource("t_cobble")
roughness = 0.95
uv1_scale = Vector3(0.3, 0.3, 0.3)
uv1_triplanar = true
uv1_world_triplanar = true''')
sub.append('''[sub_resource type="StandardMaterial3D" id="mat_kerb"]
albedo_color = Color(0.62, 0.6, 0.57, 1)
albedo_texture = ExtResource("t_stone")
roughness = 0.95
uv1_scale = Vector3(1.6, 1.6, 1.6)
uv1_triplanar = true
uv1_world_triplanar = true''')
sub.append('''[sub_resource type="CylinderMesh" id="mesh_square"]
material = SubResource("mat_cobble")
top_radius = 6.0
bottom_radius = 6.0
height = 0.08
radial_segments = 48
rings = 1''')
sub.append('''[sub_resource type="CylinderMesh" id="mesh_kerb"]
material = SubResource("mat_kerb")
top_radius = 6.35
bottom_radius = 6.4
height = 0.06
radial_segments = 48
rings = 1''')
sub.append('''[sub_resource type="CylinderMesh" id="mesh_ring"]
material = SubResource("mat_kerb")
top_radius = 2.3
bottom_radius = 2.3
height = 0.1
radial_segments = 32
rings = 1''')
for i, h in enumerate(HOT):
    sub.append('[sub_resource type="BoxShape3D" id="box_%d"]\nsize = Vector3(%g, %g, %g)' % (i, *h[5]))


def xform(pos, rot, sx=1.0, sz=1.0):
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    # basis columns x=(c,0,-s)*sx, y=(0,1,0), z=(s,0,c)*sz; written by rows
    return "Transform3D(%.5g, 0, %.5g, 0, 1, 0, %.5g, 0, %.5g, %g, %g, %g)" % (c * sx, s * sz, -s * sx, c * sz, pos[0], pos[1], pos[2])


nodes = ['''[node name="Town3D" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-52, -38, 0)
light_color = Color(1, 0.96, 0.88, 1)
light_energy = 0.95
shadow_enabled = true
directional_shadow_max_distance = 80.0

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.643, 0.766, 0, -0.766, 0.643, 0, 22.0, 17.0)
fov = 54.0
current = true

[node name="Ground" type="Node3D" parent="."]
GROUND_HALVES
[node name="Square" type="Node3D" parent="."]

[node name="Kerb" type="MeshInstance3D" parent="Square"]
position = Vector3(0, 0.0, 0)
mesh = SubResource("mesh_kerb")

[node name="Cobbles" type="MeshInstance3D" parent="Square"]
position = Vector3(0, 0.0, 0)
mesh = SubResource("mesh_square")

[node name="WellRing" type="MeshInstance3D" parent="Square"]
position = Vector3(0, 0.02, 0)
mesh = SubResource("mesh_ring")

[node name="Paths" type="Node3D" parent="."]
''']
k = 0
for pts, w in PATHS:
    for i in range(len(pts) - 1):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        L_ = math.hypot(x1 - x0, z1 - z0)
        rot = math.degrees(math.atan2(x1 - x0, z1 - z0))
        nodes.append('[node name="Seg%d" type="MeshInstance3D" parent="Paths"]\ntransform = %s\nmesh = SubResource("mesh_path")\n'
                     % (k, xform(((x0 + x1) / 2, -0.012, (z0 + z1) / 2), rot, w, L_)))
        k += 1
    for (x, z) in pts:
        nodes.append('[node name="Seg%d" type="MeshInstance3D" parent="Paths"]\ntransform = Transform3D(%g, 0, 0, 0, 1, 0, 0, 0, %g, %g, -0.018, %g)\nmesh = SubResource("mesh_joint")\n'
                     % (k, w, w, x, z))
        k += 1
nodes.append('[node name="Hotspots" type="Node3D" parent="."]\n')


def inst(name, model, parent, pos, rot):
    return '[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s\n' % (name, parent, ids[model], xform(pos, rot))


for i, (nm, tab, title, pos, rot, sz, cen, bh, kids) in enumerate(HOT):
    nodes.append('[node name="%s" type="Area3D" parent="Hotspots"]\ntransform = %s\nscript = ExtResource("s_hot")\ntab = "%s"\ntitle = "%s"\n'
                 % (nm, xform(pos, rot), tab, title))
    nodes.append('[node name="Shape" type="CollisionShape3D" parent="Hotspots/%s"]\nposition = Vector3(%g, %g, %g)\nshape = SubResource("box_%d")\n' % (nm, *cen, i))
    nodes.append('[node name="Badge" type="Label3D" parent="Hotspots/%s"]\nvisible = false\nposition = Vector3(0, %g, 0)\nbillboard = 1\nno_depth_test = true\nmodulate = Color(1, 0.84, 0.35, 1)\noutline_modulate = Color(0.18, 0.1, 0.03, 1)\ntext = "!"\nfont_size = 96\noutline_size = 24\n' % (nm, bh))
    for j, (m, p, r) in enumerate(kids):
        nodes.append(inst("%s_%d" % (m, j), m, "Hotspots/" + nm, p, r))
nodes.append('[node name="Decor" type="Node3D" parent="."]\n')
for j, (m, p, r) in enumerate(DECOR):
    nodes.append(inst("%s_%d" % (m, j), m, "Decor", p, r))

# ground: two halves with a gap along the creek so the sunken channel shows
a_ = math.radians(rot_stream)
nz = (math.sin(a_), math.cos(a_))  # local +Z of a node rotated by rot_stream
halves = ""
for side, nm in ((1, "North"), (-1, "South")):
    off = side * (1.75 + 35)
    c = (-15.0 + nz[0] * off, -0.03, 8.4 + nz[1] * off)
    halves += '[node name="%s" type="MeshInstance3D" parent="Ground"]\ntransform = %s\nmesh = SubResource("mesh_grass")\n\n' % (nm, xform(c, rot_stream))
nodes[0] = nodes[0].replace("GROUND_HALVES", "\n" + halves)
txt = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n".join(nodes)
open(OUT, "w", encoding="utf-8").write(txt)
print("ok", len(nodes))
