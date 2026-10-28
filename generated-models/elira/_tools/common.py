import bpy, os, math
from mathutils import Vector

def setup_render(res=(768,1024), engine='CYCLES', samples=16):
    sc=bpy.context.scene
    sc.render.engine=engine
    if engine=='CYCLES':
        sc.cycles.samples=samples; sc.cycles.use_denoising=False
        try:
            prefs=bpy.context.preferences.addons['cycles'].preferences
            for t in ('OPTIX','CUDA','HIP','ONEAPI'):
                try:
                    prefs.compute_device_type=t; prefs.get_devices()
                    if any(d.type==t for d in prefs.devices):
                        for d in prefs.devices: d.use = True
                        sc.cycles.device='GPU'; break
                except Exception: pass
        except Exception: pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent=False
    if sc.world is None: sc.world=bpy.data.worlds.new("w")
    sc.world.use_nodes=True
    bg=sc.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value=(0.32,0.32,0.35,1); bg.inputs[1].default_value=0.8
    sc.view_settings.view_transform='Standard'
    if "key" not in bpy.data.objects:
        l=bpy.data.objects.new("key",bpy.data.lights.new("key",'SUN')); l.data.energy=3.0; l.rotation_euler=(0.8,0.2,0.6); sc.collection.objects.link(l)
        l2=bpy.data.objects.new("fill",bpy.data.lights.new("fill",'SUN')); l2.data.energy=1.2; l2.rotation_euler=(1.2,0,3.5); sc.collection.objects.link(l2)
    if "pcam" not in bpy.data.objects:
        cam=bpy.data.objects.new("pcam", bpy.data.cameras.new("pcam")); sc.collection.objects.link(cam)
    sc.camera=bpy.data.objects["pcam"]

def shoot(path, center, size, direction, ortho=True):
    sc=bpy.context.scene; cam=bpy.data.objects["pcam"]
    cam.data.type='ORTHO' if ortho else 'PERSP'
    cam.data.ortho_scale=size
    d=Vector(direction).normalized()
    cam.location=Vector(center)+d*6
    cam.rotation_euler=(Vector(center)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.clip_end=50
    sc.render.filepath=path
    bpy.ops.render.render(write_still=True)

def views(prefix, center, size, which=("front","side","back","q")):
    dirs={"front":(0,-1,0),"side":(1,0,0),"lside":(-1,0,0),"back":(0,1,0),"q":(0.7,-0.7,0.25),"top":(0,-0.05,1)}
    for w in which: shoot(f"{prefix}_{w}.png", center, size, dirs[w])

def wire_material(name="wire", base=(0.75,0.72,0.7,1)):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; N=nt.nodes; L=nt.links
    bsdf=N["Principled BSDF"]; bsdf.inputs["Base Color"].default_value=base
    wf=N.new("ShaderNodeWireframe"); wf.use_pixel_size=True; wf.inputs[0].default_value=1.0
    mix=N.new("ShaderNodeMix"); mix.data_type='RGBA'
    mix.inputs[6].default_value=base; mix.inputs[7].default_value=(0.05,0.05,0.08,1)
    L.new(wf.outputs[0], mix.inputs[0]); L.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m
