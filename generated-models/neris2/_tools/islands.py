import bpy, os, bmesh
from mathutils import Vector
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Neris']; me=o.data
bm=bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen=set(); isl=[]
for v in bm.verts:
    if v.index in seen: continue
    st=[v]; comp=[]; seen.add(v.index)
    while st:
        x=st.pop(); comp.append(x.index)
        for e in x.link_edges:
            y=e.other_vert(x)
            if y.index not in seen: seen.add(y.index); st.append(y)
    isl.append(comp)
names={g.index:g.name.replace('mixamorig:','') for g in o.vertex_groups}
for i,c in enumerate(isl):
    pts=[me.vertices[k].co for k in c]
    cen=sum(pts,Vector())/len(pts)
    mn=Vector([min(p[j] for p in pts) for j in range(3)]); mx=Vector([max(p[j] for p in pts) for j in range(3)])
    wsum={}
    for k in c:
        for g in me.vertices[k].groups: wsum[names[g.group]]=wsum.get(names[g.group],0)+g.weight
    top=sorted(wsum.items(),key=lambda t:-t[1])[:3]
    print('ISL',i,len(c),[round(x,2) for x in cen],[round(x,2) for x in mn],[round(x,2) for x in mx],[(a,round(b/len(c),2)) for a,b in top])
