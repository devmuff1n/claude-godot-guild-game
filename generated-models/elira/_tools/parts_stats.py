# Per loose-part stats of the raw Tripo mesh: bbox, centroid, area, mean texture colour.
import bpy, sys, os, json, numpy as np
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type=='MESH'][0]
me = obj.data
nv=len(me.vertices); nf=len(me.polygons)
co=np.empty(nv*3,np.float32); me.vertices.foreach_get("co",co); co=co.reshape(-1,3)
# connectivity via union-find on edges
ed=np.empty(len(me.edges)*2,np.int64); me.edges.foreach_get("vertices",ed); ed=ed.reshape(-1,2)
par=np.arange(nv)
def find(a):
    r=a
    while par[r]!=r: r=par[r]
    while par[a]!=r: par[a],a=r,par[a]
    return r
# vectorised-ish union
import sys as _s
for a,b in ed:
    ra,rb=find(a),find(b)
    if ra!=rb: par[max(ra,rb)]=min(ra,rb)
roots=np.array([find(i) for i in range(nv)])
uniq,lab=np.unique(roots,return_inverse=True)
np.save(os.path.join(out,"vert_part.npy"),lab.astype(np.int32))
# face -> part, area, uv centroid colour
lt=np.empty(len(me.loop_triangles)*3,np.int64) if False else None
area=np.empty(nf,np.float32); me.polygons.foreach_get("area",area)
fv0=np.empty(nf,np.int64); me.polygons.foreach_get("loop_start",fv0)
lv=np.empty(len(me.loops),np.int64); me.loops.foreach_get("vertex_index",lv)
uv=np.empty(len(me.loops)*2,np.float32); me.uv_layers[0].data.foreach_get("uv",uv); uv=uv.reshape(-1,2)
fpart=lab[lv[fv0]]
fuv=uv[fv0]
img=[i for i in bpy.data.images if 'basecolor' in i.name][0]
W,H=img.size
px=np.empty(W*H*4,np.float32); img.pixels.foreach_get(px); px=px.reshape(H,W,4)
xi=np.clip((fuv[:,0]%1)*W,0,W-1).astype(int); yi=np.clip((fuv[:,1]%1)*H,0,H-1).astype(int)
fcol=px[yi,xi,:3]
P=len(uniq); res=[]
for p in range(P):
    m=fpart==p
    vm=lab==p
    c=co[vm]
    a=area[m].sum()
    col=(fcol[m]*area[m,None]).sum(0)/max(a,1e-12)
    res.append({"id":p,"nv":int(vm.sum()),"area":float(a),"min":c.min(0).round(4).tolist(),"max":c.max(0).round(4).tolist(),
                "cen":c.mean(0).round(4).tolist(),"col":col.round(3).tolist()})
json.dump(res,open(os.path.join(out,"parts.json"),"w"))
print("PARTS",P)
