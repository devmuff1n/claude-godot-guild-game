import bpy, os, json
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s2w.blend'))
o=bpy.data.objects['Neris']; me=o.data; uv=me.uv_layers[0].data
par=json.load(open(os.path.join(W,'islands.json')))['par']
us=[];vs=[]
for p in me.polygons:
    cs=[me.vertices[i].co for i in p.vertices]
    if all(par[i]==7582 and c.z<0.9 and c.y<-0.1 and abs(c.x)<0.13 for i,c in zip(p.vertices,cs)):
        for li in p.loop_indices: us.append(uv[li].uv[0]); vs.append(uv[li].uv[1])
print('FLAPUV',len(us),min(us),max(us),min(vs),max(vs))
