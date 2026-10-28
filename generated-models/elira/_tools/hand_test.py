import bpy,bmesh,sys,os,json,numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0]); vox=float(argv[1]); out=argv[2]
hi=bpy.data.objects["Elira_High"]; SH=json.loads(argv[3])
res={}
for side,sg in (("L",1),("R",-1)):
    # box in s2 space -> s1 space
    bm=bmesh.new(); bm.from_mesh(hi.data)
    def inbox(c):
        x=c.x+SH[0]; y=c.y+SH[1]; z=c.z+SH[2]
        return sg*x>0.235 and sg*x<0.37 and -0.16<y<0.05 and 0.37<z<0.49
    kill=[v for v in bm.verts if not inbox(v.co)]
    bmesh.ops.delete(bm,geom=kill,context='VERTS')
    me=bpy.data.meshes.new("H"+side); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new("Hand"+side,me); bpy.context.collection.objects.link(o)
    o.data.remesh_voxel_size=vox
    bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.voxel_remesh()
    bm=bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    seen=set(); comps=[]
    for v in bm.verts:
        if v.index in seen: continue
        st=[v]; seen.add(v.index); n=[]
        while st:
            a=st.pop(); n.append(a.co.copy())
            for e in a.link_edges:
                b=e.other_vert(a)
                if b.index not in seen: seen.add(b.index); st.append(b)
        comps.append(len(n))
    res[side]={"faces":len(o.data.polygons),"comps":sorted(comps,reverse=True)[:8]}
    bm.free()
bpy.ops.wm.save_as_mainfile(filepath=out)
print("RES",json.dumps(res))
