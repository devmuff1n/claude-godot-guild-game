import bpy, os, json
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Neris']; me=o.data
par=json.load(open(os.path.join(W,'islands.json')))['par']
gi={g.index:g.name.replace('mixamorig:','') for g in o.vertex_groups}
for z0 in (0.9,0.8,0.7,0.6,0.5):
  for x0 in (0.0,0.06,0.11,0.16):
    vs=[v for v in me.vertices if par[v.index]==7469 and abs(abs(v.co.x)-x0)<0.03 and abs(v.co.z-z0)<0.05]
    if not vs: continue
    ys=sorted(round(v.co.y,3) for v in vs)
    front=[v for v in vs if v.co.y<0]
    print(z0,x0,len(vs),'ymin',ys[0],'ymax',ys[-1], 'front y', sorted(set(round(v.co.y,2) for v in front))[:8])
