# Preview Elira's clips with the bow in the left fist, string and arrow drawn to the right fist (game camera angle).
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
argv = sys.argv[sys.argv.index("--")+1:]
blend, bowblend, out = argv[0], argv[1], argv[2]
shots = [s.split(":") for s in argv[3].split(",")]   # Clip:frame
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene; rig = bpy.data.objects["Elira_Rig"]; pose = rig.pose.bones
with bpy.data.libraries.load(bowblend) as (src, dst):
    dst.objects = [n for n in src.objects if n in ("EliraBow", "TipTop", "TipBottom", "EliraArrow")]
for o in dst.objects: sc.collection.objects.link(o)
bow = bpy.data.objects["EliraBow"]; arrow = bpy.data.objects["EliraArrow"]
tt = bpy.data.objects["TipTop"]; tb = bpy.data.objects["TipBottom"]
smat = bpy.data.materials.new("str"); smat.use_nodes = True
smat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.88, 0.8, 1)
def seg(name, a, b, r=0.0022):
    d = b-a; L = d.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=L, location=(a+b)/2)
    o = bpy.context.active_object; o.name = name
    o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    o.data.materials.append(smat); return o
def fist(side):
    h = pose["mixamorig:"+side+"Hand"]; M = rig.matrix_world @ h.matrix
    return M.translation + M.to_3x3() @ Vector((0, 0.045, 0)), M
setup_render(res=(640, 800), samples=12)
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
pulled = {"Bow_Draw": (12, 99), "Bow_Aim": (0, 99), "Bow_Shoot": (0, 1), "Bow_Quick": (7, 17)}
for clip, f in shots:
    f = int(f)
    rig.animation_data.action = bpy.data.actions[clip]; sc.frame_set(f); bpy.context.view_layer.update()
    g, _ = fist("Left")
    def ph(n): return rig.matrix_world @ pose["mixamorig:"+n].head
    hd = (ph("LeftHandMiddle1")-ph("LeftHand")).normalized()
    g = ph("LeftHand")+hd*0.045
    kk = ph("LeftHandIndex1")-ph("LeftHandPinky1"); kk = (kk-hd*kk.dot(hd)).normalized()
    Yl = -hd; Zl = kk; Xl = Yl.cross(Zl)
    bow.matrix_world = Matrix.Translation(g) @ Matrix((Xl, Yl, Zl)).transposed().to_4x4()   # bow along the knuckles, belly where the fingers point
    bpy.context.view_layer.update()
    a, b = tt.matrix_world.translation.copy(), tb.matrix_world.translation.copy()
    tmp = []
    w = pulled.get(clip)
    if w and w[0] <= f <= w[1]:
        r, _ = fist("Right")
        tmp += [seg("s1", a, r), seg("s2", r, b)]
        d = (g-r).normalized()
        arrow.rotation_mode = 'QUATERNION'; arrow.rotation_quaternion = Vector((0, -1, 0)).rotation_difference(d)
        arrow.location = r; arrow.hide_render = False
    else:
        tmp += [seg("s0", a, b)]; arrow.hide_render = True
    bpy.context.view_layer.update()
    shoot(os.path.join(out, f"pv_{clip}_{f}_game.png"), (0.05, -0.05, 0.75), 1.65, (-0.76, -0.64, 0.12))
    shoot(os.path.join(out, f"pv_{clip}_{f}_side.png"), (0.05, -0.05, 0.75), 1.65, (1, -0.05, 0.05))
    shoot(os.path.join(out, f"pv_{clip}_{f}_front.png"), (0.05, -0.05, 0.75), 1.65, (0, -1, 0.05))
    shoot(os.path.join(out, f"pv_{clip}_{f}_top.png"), (0.05, -0.05, 0.75), 1.65, (0, -0.02, 1))
    for o in tmp: bpy.data.objects.remove(o)
