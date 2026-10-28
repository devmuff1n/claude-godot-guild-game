# -*- coding: utf-8 -*-
"""Generates Godot level scenes (scenes/levels/<cid>.tscn) for every contract route.

Godot coords: X along the road (direction of travel), Y up, Z toward the camera.
Road centre line z = 0. Far side (behind the units) z < 0, near side z > 0.
Node k of a route is reached at scroll (k+1) * SEG px; its set piece sits at
A_k = (k+1) * SEG_M + 11.5 m (right half of the screen, where enemies arrive / events happen).
"""
import math, random, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
SEG_M = 260.0 * 2.6 / 100.0          # WALK_SPEED * walk_dur / PX_PER_M  = 6.76 m
CAT = {"ground_road_tile": "landscape", "stream_channel": "landscape", "field_rock": "landscape",
       "fallen_tree_root": "landscape", "vegetable_garden_bed": "landscape",
       "oak_tree": "vegetation", "pine_tree": "vegetation", "roadside_bush": "vegetation", "grass_tuft": "vegetation",
       "flower_patch": "vegetation", "potted_plant": "vegetation",
       "low_stone_wall": "road_defense", "wooden_garden_fence": "road_defense", "wooden_barricade": "road_defense",
       "checkpoint_barrier": "road_defense", "forest_defense_gate": "road_defense", "timber_footbridge": "road_defense",
       "toll_sign": "road_defense", "decorative_spear": "road_defense", "round_watch_shield": "road_defense"}
# route-event dioramas (generated-models/_tools/build_event_kit.py): origin on the far road edge, scene extends into -Z
EV_CAT = {k: "dioramas" for k in ("ev01_spring", "ev02_peddler", "ev03_toll", "ev04_smithy", "ev05_captive", "ev06_cage",
                                  "ev07_barn", "ev08_tower", "ev09_cache", "ev10_turncoat", "ev11_idol",
                                  "ev12_corpse", "ev13_chapel", "ev14_dice", "ev15_hive", "ev16_ditch")}


class Level:
    def __init__(self, cid, title, nodes, night=False, pine=0.75, density=1.0, seed=1):
        self.cid, self.title, self.nodes, self.night = cid, title, nodes, night
        self.pine, self.density = pine, density
        self.rng = random.Random(seed)
        self.items = []       # (group, name, id, x, y, z, rx, ry, rz, s)
        self.reserved = []    # (x0, x1, z0, z1, level) level: 'trees' blocks trees only, 'all' blocks dressing too
        self.streams = []     # x centres of creek crossings
        self.forks = []
        self.lights = []      # (name, x, y, z, color, energy, range)
        self.counts = {}
        n = len(nodes)
        self.x_min = -32.0
        self.x_max = n * SEG_M + 16.0 + 34.0
        self.anchors = [(k + 1) * SEG_M + 11.5 for k in range(n)]
        self.cur = -1          # index of the route node whose set piece is being placed
        self.road_x = None     # (x0, x1) extent of the road tiles

    # ---------------------------------------------------------------- placement
    FOOT = {"field_rock": 0.7, "fallen_tree_root": 1.4, "oak_tree": 1.6, "pine_tree": 1.2, "roadside_bush": 0.7,
            "low_stone_wall": 1.5, "wooden_garden_fence": 1.5, "wooden_barricade": 0.85, "checkpoint_barrier": 1.8,
            "forest_defense_gate": 1.15, "timber_footbridge": 2.1, "toll_sign": 0.4, "decorative_spear": 0.2,
            "round_watch_shield": 0.3, "vegetable_garden_bed": 1.8, "potted_plant": 0.25, "flower_patch": 0.35, "grass_tuft": 0.3,
            "ev01_spring": 3.2, "ev02_peddler": 3.2, "ev03_toll": 2.6}

    def put(self, aid, x, z, rot=0.0, s=1.0, y=0.0, group="SetPieces", name=None, rx=0.0, rz=0.0, scale=None):
        r = self.FOOT.get(aid, 1.0) * s
        if group == "SetPieces" and aid not in EV_CAT:
            for it in self.items:
                if it[0] == "SetPieces" and it[10] != self.cur and (it[3] - x) ** 2 + (it[5] - z) ** 2 < (r + it[11]) ** 2 * 0.7:
                    return False  # earlier node's set piece already stands here
        self.counts[aid] = self.counts.get(aid, 0) + 1
        nm = name or "%s_%03d" % (aid, self.counts[aid])
        self.items.append((group, nm, aid, x, y, z, rx, math.radians(rot), rz, s, self.cur, r, scale))
        return True

    def clear_area(self, x0, x1, z0, z1):
        """Remove other nodes' set-piece props from an area a creek or fork now occupies."""
        self.items = [it for it in self.items if not (it[0] == "SetPieces" and it[10] != self.cur
                                                       and x0 <= it[3] <= x1 and z0 <= it[5] <= z1)]

    def reserve(self, x0, x1, z0, z1, level="all"):
        self.reserved.append((min(x0, x1), max(x0, x1), min(z0, z1), max(z0, z1), level))

    def free(self, x, z, kind):
        for (x0, x1, z0, z1, lv) in self.reserved:
            if x0 <= x <= x1 and z0 <= z <= z1 and (lv == "all" or kind == "tree"):
                return False
        for xs in self.streams:
            if abs(x - xs) < (3.2 if kind == "tree" else 2.4) and z > -22:
                return False
        return True

    def stream(self, x):
        # Water starts right in front of the party on its own node (front hero at A - 2.5)
        # and ends before the rear hero on the next node (A + 0.96): centre the 4 m module at A - 0.4.
        xs = x - 0.4
        self.streams.append(xs)
        self.clear_area(xs - 2.8, xs + 2.8, -22, 10)
        for k, zc in enumerate((6.0, 0.0, -6.0, -12.0, -18.0)):
            self.put("stream_channel", xs, zc, rot=90, group="Creek", name="creek_%d_%d" % (int(xs), k))
        # hide the far end of the creek
        self.put("field_rock", xs - 1.6, -21.3, rot=30, s=1.8, group="Creek")
        self.put("roadside_bush", xs + 1.2, -21.6, s=1.5, group="Creek")
        self.put("pine_tree", xs + 2.6, -22.5, s=1.3, group="Creek")
        for dz in (-4.0, -8.5, 3.6):
            self.put("grass_tuft", xs - 2.5 + self.rng.uniform(-.3, .3), dz, rot=self.rng.uniform(0, 360), s=1.3, group="Creek")
            self.put("grass_tuft", xs + 2.5 + self.rng.uniform(-.3, .3), dz + 0.6, rot=self.rng.uniform(0, 360), s=1.5, group="Creek")
        return xs

    def fork(self, x):
        xf = x
        self.forks.append(xf)
        self.clear_area(xf - 3.4, xf + 3.4, -22, -2.4)
        for k, zc in enumerate((-6.0, -12.0, -18.0)):
            self.put("ground_road_tile", xf, zc, rot=90, group="Road", name="fork_%d_%d" % (int(xf), k))
        self.reserve(xf - 3.2, xf + 3.2, -2.4, -24, "all")
        return xf

    # ---------------------------------------------------------------- dressing
    def dress(self):
        r = self.rng
        placed = []

        def ok(x, z, d):
            for (px, pz, pd) in placed:
                if (px - x) ** 2 + (pz - z) ** 2 < (max(d, pd)) ** 2:
                    return False
            return True

        def scatter(n, x0, x1, z0, z1, pick, kind, mind):
            tries = 0
            k = 0
            while k < n and tries < n * 30:
                tries += 1
                x, z = r.uniform(x0, x1), r.uniform(z0, z1)
                if not self.free(x, z, kind) or not ok(x, z, mind):
                    continue
                aid, s = pick()
                placed.append((x, z, mind))
                self.put(aid, x, z, rot=r.uniform(0, 360), s=s, group={"tree": "Forest", "wall": "ForestWall"}.get(kind, "Verges"))
                k += 1

        L = self.x_max - self.x_min
        # set pieces already placed count as obstacles
        for (g, nm, aid, x, y, z, *_r) in list(self.items):
            if g in ("SetPieces", "Creek") and aid not in ("grass_tuft", "flower_patch", "stream_channel"):
                placed.append((x, z, 1.4))

        def tree():
            if r.random() < self.pine:
                return "pine_tree", r.uniform(0.8, 1.15)
            return "oak_tree", r.uniform(0.75, 1.0)

        def wall_tree():
            if r.random() < max(self.pine, 0.85):
                return "pine_tree", r.uniform(1.1, 1.6)
            return "oak_tree", r.uniform(1.0, 1.25)

        d = self.density
        scatter(int(L * 0.4 * d), self.x_min, self.x_max, -15.0, -6.2, tree, "tree", 2.2)
        scatter(int(L * 0.9 * d), self.x_min - 10, self.x_max + 10, -36.0, -15.0, wall_tree, "wall", 2.4)
        verge = lambda: r.choices([("roadside_bush", r.uniform(.8, 1.2)), ("grass_tuft", r.uniform(1.0, 1.6)),
                                   ("flower_patch", r.uniform(.9, 1.3)), ("field_rock", r.uniform(.35, .8))],
                                  weights=[3, 6, 2, 1.2])[0]
        scatter(int(L * 0.55), self.x_min, self.x_max, -6.0, -3.0, verge, "verge", 0.9)
        near = lambda: r.choices([("grass_tuft", r.uniform(1.0, 1.5)), ("flower_patch", r.uniform(.8, 1.1)),
                                  ("field_rock", r.uniform(.3, .6)), ("roadside_bush", r.uniform(.55, .75))],
                                 weights=[6, 2, 1, 1])[0]
        scatter(int(L * 0.35), self.x_min, self.x_max, 2.9, 5.2, near, "near", 0.9)

    # ---------------------------------------------------------------- road
    def road(self):
        """Continuous road: whole 6 m tiles, and narrower fitted tiles against each creek bank."""
        x0, x1 = math.floor(self.x_min / 6.0) * 6.0 - 3.0, math.ceil(self.x_max / 6.0) * 6.0 + 3.0
        self.road_x = (x0, x1)
        cuts = sorted(self.streams)
        spans, a = [], x0
        for xs in cuts:
            spans.append((a, xs - 2.0)); a = xs + 2.0
        spans.append((a, x1))
        k = 0
        for (a, b) in spans:
            x = a
            while b - x > 1e-3:
                w = min(6.0, b - x)
                k += 1
                sx = w / 6.0
                self.put("ground_road_tile", x + w / 2.0, 0.0, group="Road", name="road_%03d" % k,
                         scale=None if abs(sx - 1.0) < 1e-3 else (sx, 1.0, 1.0))
                x += w

    # ---------------------------------------------------------------- write .tscn
    def write(self, path):
        ids = sorted({it[2] for it in self.items})
        ext = []
        ext.append('[ext_resource type="Script" path="res://scripts/level/RoadLevel.gd" id="script"]')
        ext.append('[ext_resource type="Texture2D" path="res://assets/textures/env/grass_ground.png" id="tex_grass"]')
        for aid in ids:
            if aid in EV_CAT:
                ext.append('[ext_resource type="PackedScene" path="res://assets/models/events/%s/%s.glb" id="%s"]' % (EV_CAT[aid], aid, aid))
            else:
                ext.append('[ext_resource type="PackedScene" path="res://assets/models/environment/%s/%s.glb" id="%s"]' % (CAT[aid], aid, aid))
        # ground strips with holes for the creeks
        Z0, Z1 = -60.0, 22.0
        X0, X1 = self.x_min - 40, self.x_max + 40
        holes = [(self.road_x[0], self.road_x[1], -3.0, 3.0)]
        holes += [(xs - 2.0, xs + 2.0, -21.0, 9.0) for xs in self.streams]
        holes += [(xf - 3.0, xf + 3.0, -21.0, -3.0) for xf in self.forks]
        bx = sorted({X0, X1} | {h[0] for h in holes} | {h[1] for h in holes})
        bz = sorted({Z0, Z1} | {h[2] for h in holes} | {h[3] for h in holes})
        strips = []
        for j in range(len(bz) - 1):
            za, zb = bz[j], bz[j + 1]
            run = None
            for i in range(len(bx) - 1):
                xa, xb = bx[i], bx[i + 1]
                cx, cz = (xa + xb) / 2, (za + zb) / 2
                covered = any(h[0] <= cx <= h[1] and h[2] <= cz <= h[3] for h in holes)
                if not covered:
                    run = (run[0], xb) if run else (xa, xb)
                elif run:
                    strips.append((run[0], run[1], za, zb)); run = None
            if run:
                strips.append((run[0], run[1], za, zb))
        night = self.night
        sub = []
        sub.append('''[sub_resource type="StandardMaterial3D" id="mat_ground"]
albedo_color = %s
albedo_texture = ExtResource("tex_grass")
roughness = 1.0
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
uv1_world_triplanar = true''' % ("Color(0.55, 0.62, 0.75, 1)" if night else "Color(1, 1, 1, 1)"))
        sub.append('''[sub_resource type="StandardMaterial3D" id="mat_backdrop"]
shading_mode = 0
albedo_color = %s''' % ("Color(0.04, 0.07, 0.1, 1)" if night else "Color(0.2, 0.3, 0.22, 1)"))
        for i, (x0, x1, z0, z1) in enumerate(strips):
            sub.append('[sub_resource type="PlaneMesh" id="plane_%d"]\nsize = Vector2(%.2f, %.2f)' % (i, x1 - x0, z1 - z0))
        sub.append('[sub_resource type="PlaneMesh" id="plane_backdrop"]\nsize = Vector2(%.1f, 30)\norientation = 2' % (self.x_max - self.x_min + 120))
        if night:
            sub.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.03, 0.05, 0.11, 1)
ambient_light_source = 2
ambient_light_color = Color(0.36, 0.44, 0.72, 1)
ambient_light_energy = 0.45
fog_enabled = true
fog_light_color = Color(0.05, 0.08, 0.15, 1)
fog_density = 0.018''')
        else:
            sub.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.62, 0.74, 0.84, 1)
ambient_light_source = 2
ambient_light_color = Color(0.86, 0.9, 0.95, 1)
ambient_light_energy = 0.65
fog_enabled = true
fog_light_color = Color(0.62, 0.72, 0.78, 1)
fog_density = 0.007''')
        lines = ['[gd_scene load_steps=%d format=3]' % (len(ext) + len(sub) + 1), '']
        lines += ext + ['']
        for s in sub:
            lines += [s, '']
        lines += ['[node name="Level_%s" type="Node3D"]' % self.cid,
                  'script = ExtResource("script")',
                  'metadata/title = "%s"' % self.title,
                  'metadata/nodes = PackedStringArray(%s)' % ", ".join('"%s"' % n for n in self.nodes), '',
                  '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("env")', '']
        if night:
            lines += ['[node name="Moon" type="DirectionalLight3D" parent="."]', 'rotation_degrees = Vector3(-42, 30, 0)',
                      'light_color = Color(0.6, 0.7, 1, 1)', 'light_energy = 0.35', 'shadow_enabled = true',
                      'directional_shadow_max_distance = 60.0', '']
        else:
            lines += ['[node name="Sun" type="DirectionalLight3D" parent="."]', 'rotation_degrees = Vector3(-52, -38, 0)',
                      'light_color = Color(1, 0.96, 0.88, 1)', 'light_energy = 1.15', 'shadow_enabled = true',
                      'directional_shadow_max_distance = 60.0', '']
        lines += ['[node name="Camera3D" type="Camera3D" parent="."]', 'position = Vector3(8, 7.34, 12.8)',
                  'rotation_degrees = Vector3(-24, 0, 0)', 'current = true', 'fov = 34.0', 'far = 160.0', '']
        lines += ['[node name="Ground" type="Node3D" parent="."]', '']
        for i, (x0, x1, z0, z1) in enumerate(strips):
            lines += ['[node name="Ground_%d" type="MeshInstance3D" parent="Ground"]' % i,
                      'position = Vector3(%.2f, -0.012, %.2f)' % ((x0 + x1) / 2, (z0 + z1) / 2),
                      'mesh = SubResource("plane_%d")' % i, 'surface_material_override/0 = SubResource("mat_ground")', '']
        lines += ['[node name="Backdrop" type="MeshInstance3D" parent="Ground"]',
                  'position = Vector3(%.1f, 10, -40)' % ((self.x_min + self.x_max) / 2),
                  'mesh = SubResource("plane_backdrop")', 'surface_material_override/0 = SubResource("mat_backdrop")', '']
        groups = ["Road", "Creek", "SetPieces", "Forest", "ForestWall", "Verges"]
        for g in groups:
            lines += ['[node name="%s" type="Node3D" parent="."]' % g, '']
            for (gg, nm, aid, x, y, z, rx, ry, rz, s, _node, _r, sc3) in self.items:
                if gg != g:
                    continue
                lines.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % (nm, g, aid))
                lines.append('position = Vector3(%.3f, %.3f, %.3f)' % (x, y, z))
                if rx or ry or rz:
                    lines.append('rotation = Vector3(%.4f, %.4f, %.4f)' % (rx, ry, rz))
                if sc3:
                    lines.append('scale = Vector3(%.3f, %.3f, %.3f)' % sc3)
                elif abs(s - 1.0) > 1e-3:
                    lines.append('scale = Vector3(%.3f, %.3f, %.3f)' % (s, s, s))
                lines.append('')
        if self.lights:
            lines += ['[node name="FireLights" type="Node3D" parent="."]', '']
            for (nm, x, y, z, col, en, rg) in self.lights:
                lines += ['[node name="%s" type="OmniLight3D" parent="FireLights"]' % nm,
                          'position = Vector3(%.2f, %.2f, %.2f)' % (x, y, z),
                          'light_color = Color(%.2f, %.2f, %.2f, 1)' % col, 'light_energy = %.2f' % en,
                          'omni_range = %.1f' % rg, '']
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
        return len(self.items)


# ======================================================================== set pieces
def sp_clearing(L, A):
    L.put("oak_tree", A - 2.5, -7.8, rot=40, s=0.9)
    L.put("oak_tree", A + 5.5, -8.4, rot=200, s=0.85)
    L.put("flower_patch", A + 0.8, -3.6, s=1.2); L.put("flower_patch", A + 3.2, -4.1, rot=60)
    L.put("field_rock", A + 4.4, -3.7, rot=20, s=0.6)
    L.reserve(A - 4, A + 7, -3, -7.2, "trees")


def event_scene(L, aid, x, event, x0=-3.4, x1=3.4, depth=11.0):
    """Roadside event diorama: origin on the far road edge (z = -3), the scene goes back into the forest."""
    L.clear_area(x + x0, x + x1, -3.0 - depth, -2.5)
    L.put(aid, x, -3.0, name="Event_" + event)
    L.reserve(x + x0, x + x1, -2.9, -3.0 - depth, "all")


def sp_spring(L, A):
    # forest spring at the roots of an old tree (event "spring")
    event_scene(L, "ev01_spring", A, "spring", depth=12.0)
    L.put("field_rock", A + 2.5, 3.5, rot=10, s=0.45)
    L.put("flower_patch", A - 2.2, 3.6, s=1.1)


def sp_fork_trader(L, A):
    # crossroads with the wounded peddler under the signpost (event "wounded_trader")
    # the fork sits mid-screen, the peddler just right of it (the screen ends ~4.5 m past the anchor)
    xf = L.fork(A - 5.0)
    L.put("field_rock", xf - 3.6, -3.4, rot=80, s=0.6)
    L.put("oak_tree", xf - 5.0, -7.0, rot=300, s=0.95)
    event_scene(L, "ev02_peddler", A + 1.6, "wounded_trader", x0=-2.8, x1=4.2, depth=8.0)


def sp_toll(L, A):
    # toll keeper's booth at the bridge (event "bridge")
    xs = sp_bridge(L, A)
    event_scene(L, "ev03_toll", xs + 4.7, "bridge", x0=-2.6, x1=2.4, depth=5.0)  # just past the bridge: the previous node has its own creek right before it


def sp_windfall(L, A):
    L.put("fallen_tree_root", A - 1.0, -4.3, rot=15)
    L.put("fallen_tree_root", A + 3.6, -6.6, rot=200, s=1.1)
    L.put("fallen_tree_root", A + 1.2, 3.9, rot=170, s=0.8)
    L.put("field_rock", A + 5.4, -3.8, rot=70, s=0.8)
    L.put("roadside_bush", A - 3.4, -5.0, s=1.1)
    L.put("pine_tree", A + 6.5, -6.6, rot=20)
    L.reserve(A - 3, A + 6, -3, -7.5, "trees")


def sp_camp(L, A):
    L.put("fallen_tree_root", A + 0.4, -4.6, rot=8, s=0.8)
    cx, cz = A + 2.6, -3.7
    for i in range(8):
        a = 2 * math.pi * i / 8
        L.put("field_rock", cx + math.cos(a) * 0.45, cz + math.sin(a) * 0.3, rot=i * 47, s=0.2, name="firepit_stone_%d" % i)
    L.put("field_rock", A + 4.0, -4.4, rot=120, s=0.45)
    L.put("flower_patch", A - 1.6, -3.6, rot=30)
    L.put("grass_tuft", A + 5.2, -3.4, s=1.3)
    L.reserve(A - 3, A + 6, -3, -7, "all")


def sp_fork(L, A):
    xf = L.fork(A)
    L.put("field_rock", xf - 3.6, -3.4, rot=80, s=0.6)
    L.put("roadside_bush", xf + 3.8, -3.6, s=1.1)
    L.put("oak_tree", xf - 5.0, -7.0, rot=300, s=0.95)


def sp_den(L, A):
    for (dx, dz, s) in ((-2.0, -4.6, 1.1), (2.2, -5.2, 1.2), (5.6, -4.7, 1.0), (8.3, -5.6, 1.15), (-4.6, -5.8, 1.05)):
        L.put("pine_tree", A + dx, dz, rot=L.rng.uniform(0, 360), s=s)
    L.put("field_rock", A + 0.9, -3.7, rot=30, s=1.3)
    L.put("field_rock", A + 4.0, -3.5, rot=140, s=0.9)
    L.put("fallen_tree_root", A + 6.7, -3.9, rot=-20)
    L.put("field_rock", A + 3.0, 3.7, rot=200, s=0.8)


def sp_bridge(L, A, broken=False):
    xs = L.stream(A)
    if broken:
        L.put("timber_footbridge", xs + 0.3, 0.0, rot=4, y=-0.55, rz=0.13, name="broken_bridge")
        L.put("wooden_barricade", xs - 3.3, -2.7, rot=8)
    else:
        L.put("timber_footbridge", xs, 0.0, y=-0.34, name="bridge")
    L.put("field_rock", xs - 2.6, -3.3, rot=40, s=0.5); L.put("field_rock", xs + 2.7, 3.3, rot=200, s=0.5)
    return xs


def sp_shop(L, A):
    L.put("wooden_garden_fence", A - 1.5, -3.7); L.put("wooden_garden_fence", A + 1.5, -3.7)
    L.put("vegetable_garden_bed", A, -6.3)
    L.put("toll_sign", A + 3.3, -2.9, name="shop_sign")
    L.put("potted_plant", A + 2.5, -3.1)
    L.put("flower_patch", A - 3.3, -3.5); L.put("flower_patch", A + 4.4, -3.6, rot=90)
    L.put("oak_tree", A + 5.5, -8.0, rot=60, s=0.9)
    L.reserve(A - 3.5, A + 5, -3, -8.2, "all")


def sp_ravine(L, A):
    for (dx, dz, s, rot) in ((-2.4, -4.4, 2.2, 10), (2.4, -4.9, 2.9, 80), (6.2, -4.2, 2.1, 160), (9.4, -5.0, 2.4, 230)):
        L.put("field_rock", A + dx, dz, rot=rot, s=s)
    for (dx, dz, s, rot) in ((0.8, 4.0, 0.85, 40), (5.0, 4.2, 0.7, 300)):
        L.put("field_rock", A + dx, dz, rot=rot, s=s)
    L.put("fallen_tree_root", A + 3.8, -3.2, rot=10, s=0.9)
    L.reserve(A - 4, A + 11, -3, -6.5, "trees")


def sp_hamlet(L, A):
    for dx in (-4.5, -1.5, 1.5, 4.5):
        L.put("wooden_garden_fence", A + dx, -3.7)
    L.put("vegetable_garden_bed", A - 3.0, -6.4); L.put("vegetable_garden_bed", A + 1.2, -6.4)
    L.put("low_stone_wall", A + 7.6, -3.8, rot=180)
    L.put("oak_tree", A + 4.6, -8.8, rot=20)
    L.put("flower_patch", A + 6.2, -3.3); L.put("potted_plant", A + 6.6, -3.2)
    L.reserve(A - 6.5, A + 9.5, -3, -9, "all")


def sp_forest(L, A):
    for (dx, dz, s) in ((-1.0, -4.7, 1.0), (4.2, -5.3, 1.1)):
        L.put("pine_tree", A + dx, dz, rot=L.rng.uniform(0, 360), s=s)
    L.put("roadside_bush", A + 1.6, -3.6); L.put("roadside_bush", A + 6.0, 3.5, s=0.7)


def sp_ford(L, A):
    xs = L.stream(A)
    for (dx, dz, s) in ((-0.7, 0.9, 0.32), (0.5, -0.6, 0.36), (0.9, 1.4, 0.28), (-0.4, -1.5, 0.3)):
        L.put("field_rock", xs + dx, dz, rot=L.rng.uniform(0, 360), s=s, y=-0.32, name="ford_stone_%d" % L.counts.get("field_rock", 0))
    L.put("field_rock", xs - 2.6, -3.4, rot=60, s=0.6)
    return xs


def sp_checkpoint(L, A):
    L.put("forest_defense_gate", A + 2.0, -3.9, name="outpost_gate")
    L.put("low_stone_wall", A - 0.6, -3.9); L.put("low_stone_wall", A + 4.6, -3.9, rot=180)
    L.put("checkpoint_barrier", A + 8.0, -2.7)
    L.put("toll_sign", A - 2.9, -2.8, name="toll_sign")
    L.put("decorative_spear", A + 3.5, -3.45, rz=0.08)
    L.put("round_watch_shield", A + 5.2, -3.57, y=0.72)
    L.reserve(A - 3, A + 10, -3, -7, "all")


def sp_gorge(L, A):
    for (dx, dz, s, rot) in ((-3.2, -4.2, 3.0, 20), (1.0, -5.0, 3.6, 120), (5.2, -4.4, 3.0, 200), (9.2, -5.1, 3.4, 300)):
        L.put("field_rock", A + dx, dz, rot=rot, s=s)
    for (dx, dz, s, rot) in ((0.0, 4.1, 0.9, 70), (4.2, 4.3, 0.95, 150), (7.6, 4.0, 0.8, 250)):
        L.put("field_rock", A + dx, dz, rot=rot, s=s)
    L.put("fallen_tree_root", A + 2.8, -3.3, rot=-8, s=0.85)
    L.reserve(A - 5, A + 11, -3, -7.5, "trees")


def sp_captive(L, A):
    # trader tied to a pine, arrows in the bushes (event "captive_one")
    event_scene(L, "ev05_captive", A, "captive_one", depth=9.0)
    L.put("field_rock", A - 4.6, -3.5, rot=10, s=0.5)


def sp_posts(L, A):
    L.put("checkpoint_barrier", A + 1.0, -2.75)
    L.put("wooden_barricade", A - 2.6, -2.8); L.put("wooden_barricade", A + 4.2, -2.8, rot=-6)
    L.put("wooden_barricade", A + 2.0, 2.85, rot=180)
    L.put("decorative_spear", A + 5.6, -3.4, rz=0.06); L.put("decorative_spear", A - 3.9, -3.35, rz=-0.07)
    L.put("round_watch_shield", A + 6.1, -3.25, y=0.3, rx=-0.4)
    L.reserve(A - 4.5, A + 7, -3, -4.5, "all")


def sp_bandit_camp(L, A, big=False):
    for dx in (-3.0, 0.0, 3.0):
        L.put("wooden_barricade", A + dx, -3.1)
    L.put("wooden_barricade", A - 4.5, -5.0, rot=90); L.put("wooden_barricade", A + 4.5, -5.0, rot=-90)
    L.put("fallen_tree_root", A + 0.2, -6.0, rot=4, s=0.8)
    cx, cz = A - 2.0, -5.0
    for i in range(7):
        a = 2 * math.pi * i / 7
        L.put("field_rock", cx + math.cos(a) * 0.42, cz + math.sin(a) * 0.3, rot=i * 51, s=0.2)
    L.put("decorative_spear", A - 1.4, -6.7, rz=0.05); L.put("decorative_spear", A + 1.6, -6.7, rz=-0.05)
    L.put("round_watch_shield", A + 0.6, -6.5, y=0.3, rx=-0.4)
    L.put("round_watch_shield", A + 2.4, -6.6, y=0.3, rx=-0.35, rot=20)
    L.reserve(A - 5.5, A + 5.5, -3, -7.6, "all")
    if big:
        L.put("wooden_barricade", A + 1.0, 2.9, rot=180); L.put("wooden_barricade", A + 4.2, 2.9, rot=176)
        L.put("low_stone_wall", A + 8.4, -3.8, rot=180)
        L.put("checkpoint_barrier", A + 8.0, 2.85, rot=180)


def sp_village_edge(L, A):
    for dx in (-3.0, 0.0, 3.0):
        L.put("wooden_garden_fence", A + dx, -3.7)
    L.put("vegetable_garden_bed", A - 1.5, -6.3)
    L.put("potted_plant", A + 4.6, -3.2)
    L.put("oak_tree", A + 5.4, -7.6, rot=80)
    L.reserve(A - 4.5, A + 4.5, -3, -8, "all")


def sp_barn_fire(L, A):
    # burning barn, a crying farm girl at the well (event "barn_fire")
    event_scene(L, "ev07_barn", A, "barn_fire", x0=-3.6, x1=4.2, depth=10.0)
    L.lights.append(("barn_fire", A + 0.9, 3.4, -6.9, (1.0, 0.55, 0.22), 6.0, 11.0))
    L.lights.append(("barn_fire_glow", A + 0.9, 1.2, -5.6, (1.0, 0.45, 0.15), 3.0, 6.0))


def sp_mill(L, A):
    xs = sp_bridge(L, A)
    L.put("low_stone_wall", xs + 3.6, -4.6, rot=90); L.put("low_stone_wall", xs - 3.6, -4.6, rot=90)
    L.put("oak_tree", xs + 5.5, -7.0, rot=40)


def sp_sheepfold(L, A):
    for dx in (-3.0, 0.0, 3.0):
        L.put("wooden_garden_fence", A + dx, -3.7)
        L.put("wooden_garden_fence", A + dx, -6.7)
    L.put("wooden_garden_fence", A - 4.5, -5.2, rot=90); L.put("wooden_garden_fence", A + 4.5, -5.2, rot=90)
    L.put("low_stone_wall", A + 7.6, -3.8, rot=180)
    L.put("grass_tuft", A, -5.2, s=1.4); L.put("grass_tuft", A + 2, -5.0, s=1.2)
    L.lights.append(("fold_lantern", A + 6.3, 1.9, -3.4, (1.0, 0.7, 0.35), 2.2, 6.0))
    L.reserve(A - 5, A + 9, -3, -7.4, "all")


def sp_tracks(L, A):
    # abandoned watchtower with a quiver and a torn cloak (event "tracks")
    event_scene(L, "ev08_tower", A, "tracks", depth=8.0)
    L.put("pine_tree", A - 5.6, -6.8, rot=40, s=1.0); L.put("pine_tree", A + 5.4, -7.4, rot=200, s=1.1)
    L.put("flower_patch", A + 4.0, -3.5); L.put("field_rock", A - 4.4, -3.6, rot=30, s=0.5)


def sp_thicket(L, A):
    for dx in (-3.5, -1.5, 0.8, 3.0, 5.4, 7.6):
        L.put("roadside_bush", A + dx, -3.4 - L.rng.uniform(0, .8), rot=L.rng.uniform(0, 360), s=L.rng.uniform(1.0, 1.35))
    for dx in (-2.5, 1.6, 4.4):
        L.put("roadside_bush", A + dx, 3.4, rot=L.rng.uniform(0, 360), s=0.75)
    for (dx, dz) in ((-1.0, -5.6), (2.4, -6.0), (6.4, -5.4)):
        L.put("pine_tree", A + dx, dz, rot=L.rng.uniform(0, 360), s=1.05)


def sp_charcoal(L, A):
    L.put("fallen_tree_root", A - 1.0, -4.3, rot=0, s=0.8)
    L.put("fallen_tree_root", A - 0.8, -4.9, rot=180, s=0.75)
    L.put("fallen_tree_root", A + 0.4, -5.6, rot=6, s=0.7)
    L.put("toll_sign", A + 3.1, -2.85, name="charcoal_sign")
    L.put("field_rock", A + 4.5, -4.3, rot=50, s=0.7)
    L.lights.append(("charcoal_glow", A + 1.6, 0.6, -5.2, (1.0, 0.45, 0.2), 1.8, 5.0))
    L.reserve(A - 3, A + 6, -3, -7, "all")


def sp_old_road(L, A):
    L.put("low_stone_wall", A - 3.0, -3.8, y=-0.25)
    L.put("low_stone_wall", A + 1.0, -4.0, rot=8, y=-0.35)
    L.put("low_stone_wall", A + 5.2, -4.3, rot=-12, y=-0.3)
    L.put("field_rock", A + 7.6, -3.6, rot=10, s=0.7)
    L.put("flower_patch", A + 3.2, -3.3)
    L.reserve(A - 5, A + 8, -3, -5.5, "all")


def sp_cache(L, A):
    # hollow under an old tree, a trap and crows (event "cache")
    event_scene(L, "ev09_cache", A, "cache", depth=9.0)
    L.put("roadside_bush", A + 4.2, -4.1)


def sp_palisade(L, A):
    L.put("forest_defense_gate", A + 2.0, -4.0, name="lair_gate")
    for dx, rot in ((-0.6, 0), (-3.6, 0), (4.6, 180), (7.6, 180)):
        L.put("low_stone_wall", A + dx, -4.0, rot=rot)
    L.put("wooden_barricade", A - 1.2, -2.8); L.put("wooden_barricade", A + 5.6, -2.8)
    L.put("decorative_spear", A + 3.5, -3.55, rz=0.07); L.put("decorative_spear", A + 0.5, -3.55, rz=-0.06)
    L.put("round_watch_shield", A - 1.6, -3.67, y=0.72); L.put("round_watch_shield", A + 6.2, -3.67, y=0.72)
    L.reserve(A - 6, A + 10, -3, -8, "all")


def sp_turncoat(L, A):
    # young bandit steps out of the bushes with his hands up (event "turncoat")
    event_scene(L, "ev10_turncoat", A, "turncoat", depth=8.0)
    L.put("roadside_bush", A + 4.6, -4.2)


def sp_yard(L, A):
    L.put("wooden_garden_fence", A - 3.0, -3.7); L.put("wooden_garden_fence", A + 3.0, -3.7)
    L.put("wooden_barricade", A, -3.0)
    L.put("decorative_spear", A + 1.5, -3.45, rz=0.06); L.put("decorative_spear", A - 1.5, -3.45, rz=-0.06)
    L.put("round_watch_shield", A + 2.0, -3.3, y=0.3, rx=-0.45)
    L.put("vegetable_garden_bed", A + 5.0, -6.4)
    L.put("low_stone_wall", A + 8.4, -3.8, rot=180)
    L.reserve(A - 5, A + 10, -3, -8, "all")


def sp_chief(L, A):
    for dx, rot in ((-3.0, 0), (0.0, 0), (3.0, 180)):
        L.put("low_stone_wall", A + dx, -4.2, rot=rot)
    L.put("forest_defense_gate", A + 5.9, -4.2, name="chief_gate")
    L.put("low_stone_wall", A + 9.0, -4.2, rot=180)
    L.put("wooden_barricade", A + 0.0, 2.9, rot=180); L.put("wooden_barricade", A + 3.2, 2.9, rot=176)
    for dx in (-2.0, 2.0, 7.6):
        L.put("decorative_spear", A + dx, -3.7, rz=L.rng.uniform(-.08, .08))
    L.put("round_watch_shield", A - 3.4, -3.87, y=0.72); L.put("round_watch_shield", A + 3.4, -3.87, y=0.72)
    L.reserve(A - 5, A + 11, -3, -8, "all")


def sp_outpost(L, A, gate_x):
    # gate across the road where BattleSim.GATE_X is on screen; the 2D gate body is replaced by this one
    L.put("forest_defense_gate", gate_x, 0.0, rot=90, name="Gate")
    for zc in (-2.65, -5.65, -8.65, -11.65):
        L.put("low_stone_wall", gate_x, zc, rot=90)
    L.put("low_stone_wall", gate_x, 2.65, rot=-90)
    for zc in (-3.0, -6.0, -9.0):
        L.put("wooden_garden_fence", gate_x - 4.5, zc, rot=90)
    L.put("wooden_barricade", gate_x + 2.6, -2.9, rot=90); L.put("wooden_barricade", gate_x + 2.6, 2.9, rot=90)
    L.put("decorative_spear", gate_x - 0.9, -1.6, rz=0.05)
    L.put("round_watch_shield", gate_x + 0.3, -2.65, y=0.72, rot=90)
    L.put("checkpoint_barrier", gate_x - 6.5, -2.7)
    L.put("toll_sign", gate_x - 2.6, -2.85)
    L.reserve(gate_x - 8, gate_x + 4, -3, -13, "all")


def sp_ford_smithy(L, A):
    # creek, then the roadside smithy with a broken wagon wheel (event "stuck_wagon")
    event_scene(L, "ev04_smithy", A, "stuck_wagon", depth=8.0)
    L.lights.append(("forge_glow", A + 1.0, 0.7, -5.1, (1.0, 0.5, 0.2), 2.5, 5.0))


def sp_cage_camp(L, A):
    # bandit camp with captives in a cage cart (event "captive_camp")
    event_scene(L, "ev06_cage", A, "captive_camp", depth=8.0)
    L.put("wooden_barricade", A - 4.6, -3.1); L.put("wooden_barricade", A + 4.4, -3.1, rot=6)
    L.lights.append(("camp_fire", A + 0.15, 0.6, -5.3, (1.0, 0.5, 0.2), 2.5, 6.0))


def sp_ev(aid, event, depth=8.0, x0=-3.4, x1=3.4, light=None):
    """Random-pool event diorama right at the node anchor; light = (dx, y, dz, color, energy, range) or None."""
    def f(L, A):
        event_scene(L, aid, A, event, x0=x0, x1=x1, depth=depth)
        if light:
            dx, y, dz, col, en, rg = light
            L.lights.append((event + "_light", A + dx, y, dz, col, en, rg))
    return f


# ======================================================================== contracts
SP = {"clearing": sp_clearing, "spring": sp_spring, "windfall": sp_windfall, "camp": sp_camp, "fork": sp_fork,
      "den": sp_den, "bridge": sp_bridge, "broken_bridge": sp_toll, "fork_trader": sp_fork_trader, "shop": sp_shop,
      "ravine": sp_ravine, "hamlet": sp_hamlet, "forest": sp_forest, "ford": sp_ford, "checkpoint": sp_checkpoint,
      "gorge": sp_gorge, "captive": sp_captive, "posts": sp_posts, "bandit_camp": sp_bandit_camp,
      "cages": lambda L, A: sp_bandit_camp(L, A, True), "village_edge": sp_village_edge, "barn_fire": sp_barn_fire,
      "mill": sp_mill, "sheepfold": sp_sheepfold, "tracks": sp_tracks, "thicket": sp_thicket, "charcoal": sp_charcoal,
      "old_road": sp_old_road, "cache": sp_cache, "palisade": sp_palisade, "turncoat": sp_turncoat, "yard": sp_yard,
      "chief": sp_chief, "ford_smithy": sp_ford_smithy, "cage_camp": sp_cage_camp,
      "idol": sp_ev("ev11_idol", "idol"), "dead_merc": sp_ev("ev12_corpse", "dead_merc", depth=9.0),
      "chapel": sp_ev("ev13_chapel", "chapel", light=(-0.2, 1.0, -5.8, (1.0, 0.7, 0.35), 1.5, 4.0)),
      "dice": sp_ev("ev14_dice", "dice", light=(-1.35, 0.6, -4.9, (1.0, 0.5, 0.2), 2.5, 6.0)),
      "hive": sp_ev("ev15_hive", "hive", depth=9.0), "ditch_cart": sp_ev("ev16_ditch", "ditch_cart")}

LEVELS = {
    "c1": ("Первый лесной тракт", False, 0.7, 1.0,
           [("Опушка", "clearing"), ("Волчий родник", "spring"), ("Бурелом", "windfall"), ("Привал", "camp"), ("Развилка", "fork_trader"), ("Логово", "den")]),
    "c2": ("Запасы для Ольховки", False, 0.55, 0.9,
           [("Мост", "bridge"), ("Сборщик у моста", "broken_bridge"), ("Придорожная лавка", "shop"), ("Овраг", "ravine"), ("Привал", "camp"), ("Дикий улей", "hive"), ("Ольховка", "hamlet")]),
    "c3": ("Последний обоз", False, 0.75, 1.0,
           [("Лес", "forest"), ("Кузня", "ford_smithy"), ("Развилка", "fork"), ("Лагерь", "camp"), ("Застава", "checkpoint"), ("Мёртвый наёмник", "dead_merc"), ("Ущелье", "gorge")]),
    "c4": ("Спасение возчиков", False, 0.7, 1.0,
           [("Брод", "ford"), ("Пленник у дороги", "captive"), ("Посты", "posts"), ("Кости у костра", "dice"), ("Привал", "camp"), ("Клетка на колёсах", "cage_camp"), ("Клетки", "cages")]),
    "c5": ("Ночной дозор", True, 0.6, 0.9,
           [("Окраина", "village_edge"), ("Сарай в огне", "barn_fire"), ("Мельница", "mill"), ("Телега в кювете", "ditch_cart"), ("Ночёвка", "camp"), ("Овчарня", "sheepfold")]),
    "c6": ("След сборщика", False, 0.85, 1.15,
           [("Охотничья вышка", "tracks"), ("Чаща", "thicket"), ("Часовня", "chapel"), ("Угольщики", "charcoal"), ("Старый тракт", "old_road"), ("Привал", "camp"), ("Тайник", "cache"), ("Ущелье Ганса", "gorge")]),
    "c7": ("Долговая книга", False, 0.8, 1.05,
           [("Частокол", "palisade"), ("Перебежчик", "turncoat"), ("Двор логова", "yard"), ("Придорожный идол", "idol"), ("Последний привал", "camp"), ("Шатёр главаря", "chief")]),
}


def build_all():
    os.makedirs(OUT, exist_ok=True)
    summary = {}
    for i, (cid, (title, night, pine, dens, nodes)) in enumerate(LEVELS.items()):
        L = Level(cid, title, [n for n, _ in nodes], night, pine, dens, seed=100 + i)
        for k, (nm, sp) in enumerate(nodes):
            L.cur = k
            SP[sp](L, L.anchors[k])
        L.cur = -1
        L.road()
        L.dress()
        n = L.write(os.path.join(OUT, cid + ".tscn"))
        summary[cid] = (n, len(L.streams), round(L.x_max, 1))
    # side contract: forest outpost (one node, gate at BattleSim.GATE_X = 215 px)
    L = Level("s1", "Оборона лесной заставы", ["Застава"], False, 0.8, 1.0, seed=200)
    gate_x = 1 * SEG_M + 2.15
    L.cur = 0
    sp_outpost(L, L.anchors[0], gate_x)
    L.cur = -1
    L.road(); L.dress()
    summary["s1"] = (L.write(os.path.join(OUT, "s1.tscn")), 0, round(L.x_max, 1))
    return summary


if __name__ == "__main__":
    for k, v in build_all().items():
        print(k, "instances=%d creeks=%d length=%.0fm" % v)
