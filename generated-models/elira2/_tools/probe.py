import bpy, os, json
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(W,'source.glb'))
out=[]
for o in bpy.data.objects:
    if o.type!='MESH': continue
    me=o.data; uv=me.uv_layers[0].data
    us=[d.uv[0] for d in uv]; vs=[d.uv[1] for d in uv]
    m=o.material_slots[0].material if o.material_slots else None; img=None
    for n in (m.node_tree.nodes if m else []):
        if n.type=='TEX_IMAGE': img=n.image
    vg=sorted({o.vertex_groups[g.group].name for v in me.vertices for g in v.groups if g.weight>0.2})
    out.append((o.name,len(me.polygons),round(min(us),3),round(max(us),3),round(min(vs),3),round(max(vs),3),tuple(img.size) if img else None,[x.replace('mixamorig:','') for x in vg], o.parent.name if o.parent else None, [m.name for m in o.modifiers]))
for r in out: print(r)
