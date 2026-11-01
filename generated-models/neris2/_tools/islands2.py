# islands after welding coincident verts (Tripo splits on UV seams); prints pieces around the waist
import bpy, os, bmesh, sys
from mathutils import Vector
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 's1.blend'))
o=bpy.data.objects['Neris']; me=o.data
from mathutils import kdtree
kd=kdtree.KDTree(len(me.vertices))
for v in me.vertices: kd.insert(v.co,v.index)
kd.balance()
par=list(range(len(me.vertices)))
def f(a):
    while par[a]!=a: par[a]=par[par[a]]; a=par[a]
    return a
def u(a,b): a,b=f(a),f(b); par[a]=b
for e in me.edges: u(*e.vertices)
for v in me.vertices:
    for co,i,d in kd.find_range(v.co,1e-4): u(v.index,i)
comp={}
for v in me.vertices: comp.setdefault(f(v.index),[]).append(v.index)
names={g.index:g.name.replace('mixamorig:','') for g in o.vertex_groups}
print('NISL',len(comp))
import json
out=[]
for k,c in sorted(comp.items(),key=lambda t:-len(t[1])):
    pts=[me.vertices[i].co for i in c]
    mn=Vector([min(p[j] for p in pts) for j in range(3)]); mx=Vector([max(p[j] for p in pts) for j in range(3)])
    ws={}
    for i in c:
        for g in me.vertices[i].groups: ws[names[g.group]]=ws.get(names[g.group],0)+g.weight
    top=sorted(ws.items(),key=lambda t:-t[1])[:4]
    out.append(dict(id=k,n=len(c),mn=[round(x,3) for x in mn],mx=[round(x,3) for x in mx],top=[(a,round(b/len(c),2)) for a,b in top]))
    print('ISL',k,len(c),[round(x,2) for x in mn],[round(x,2) for x in mx],[(a,round(b/len(c),2)) for a,b in top])
json.dump({'par':[f(i) for i in range(len(me.vertices))],'isl':out},open(os.path.join(W,'islands.json'),'w'))
