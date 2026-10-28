# Inspect raw Tripo GLB: bounds, loose parts, render reference views.
import bpy, sys, os, json, bmesh, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type=='MESH'][0]
me = obj.data
mw = obj.matrix_world
co = [mw @ v.co for v in me.vertices]
mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
bm = bmesh.new(); bm.from_mesh(me)
# loose parts
bm.verts.ensure_lookup_table()
seen=set(); parts=[]
for v in bm.verts:
    if v.index in seen: continue
    stack=[v]; seen.add(v.index); n=0; pmn=[1e9]*3; pmx=[-1e9]*3
    while stack:
        a=stack.pop(); n+=1
        c=mw@a.co
        for i in range(3): pmn[i]=min(pmn[i],c[i]); pmx[i]=max(pmx[i],c[i])
        for e in a.link_edges:
            b=e.other_vert(a)
            if b.index not in seen: seen.add(b.index); stack.append(b)
    parts.append((n,[round(x,3) for x in pmn],[round(x,3) for x in pmx]))
parts.sort(reverse=True)
nonman = sum(1 for e in bm.edges if not e.is_manifold)
info = {"verts":len(me.vertices),"tris":sum(len(p.vertices)-2 for p in me.polygons),
  "bounds_min":list(mn),"bounds_max":list(mx),"parts":len(parts),"top_parts":parts[:15],"nonmanifold_edges":nonman,
  "images":[(i.name,list(i.size)) for i in bpy.data.images], "rot":list(obj.rotation_euler), "scale":list(obj.scale)}
json.dump(info, open(os.path.join(out,"raw_info.json"),"w"), indent=1)
# render views
sc=bpy.context.scene
sc.render.engine='BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x=768; sc.render.resolution_y=1024
sc.world = bpy.data.worlds.new("w"); sc.world.color=(0.35,0.35,0.38)
sc.view_settings.view_transform='Standard'
center=(mn+mx)/2; h=(mx-mn).length
cam=bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=max(mx.z-mn.z, mx.x-mn.x, mx.y-mn.y)*1.08
for name,ang in [("sun",(0.8,0.2,0.6))]:
    l=bpy.data.objects.new(name,bpy.data.lights.new(name,'SUN')); l.data.energy=3.5; l.rotation_euler=ang; sc.collection.objects.link(l)
l2=bpy.data.objects.new("fill",bpy.data.lights.new("fill",'SUN')); l2.data.energy=1.5; l2.rotation_euler=(1.2,0,3.5); sc.collection.objects.link(l2)
for nm,d in [("front",Vector((0,-1,0))),("side",Vector((1,0,0))),("back",Vector((0,1,0))),("q",Vector((0.7,-0.7,0.25)).normalized())]:
    cam.location=center+d*h*2
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=os.path.join(out,f"raw_{nm}.png")
    bpy.ops.render.render(write_still=True)
print("DONE", json.dumps(info)[:500])
