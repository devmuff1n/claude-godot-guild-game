# dump mesh objects of a .blend to npz (verts, tris, uv/colour optional) for offline analysis
import bpy, sys, numpy as np, os
argv = sys.argv[sys.argv.index("--")+1:]
out=argv[0]; names=argv[1:]
d={}
for n in names:
    o=bpy.data.objects[n]; me=o.data
    me.calc_loop_triangles()
    v=np.empty(len(me.vertices)*3,np.float32); me.vertices.foreach_get("co",v)
    t=np.empty(len(me.loop_triangles)*3,np.int32); me.loop_triangles.foreach_get("vertices",t)
    mw=np.array(o.matrix_world,dtype=np.float32)
    v=v.reshape(-1,3)@mw[:3,:3].T+mw[:3,3]
    d[n+"_v"]=v; d[n+"_t"]=t.reshape(-1,3)
np.savez_compressed(out,**d)
print("NPZ", {k:v.shape for k,v in d.items()})
