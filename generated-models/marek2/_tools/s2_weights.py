# Step 2a: weight fixes. Belt/buckle/pouch -> Hips (were mostly LeftUpLeg); waist side plates -> Spine/Spine1 (were
# Shoulder/Arm); chest brooches -> Spine2+Shoulder (were 40% Arm); torso centre loses Arm weights; tabard flaps get
# symmetric legs + Hips by height.
import bpy, os, json
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Marek']; me=o.data; M='mixamorig:'
I=json.load(open(os.path.join(W,'islands.json'))); par=I['par']
vg={g.name:g for g in o.vertex_groups}
def setw(i, d):
    for g in list(me.vertices[i].groups): o.vertex_groups[g.group].remove([i])
    s=sum(d.values())
    for n,w in d.items():
        if w>0: vg[M+n].add([i], w/s, 'REPLACE')
RIGID={6439:{'Hips':1}, 5143:{'Hips':1}, 6317:{'Hips':1},
       7429:{'Spine1':0.6,'Spine':0.4}, 7573:{'Spine1':0.6,'Spine':0.4},
       5086:{'Spine2':0.7,'RightShoulder':0.3}, 6505:{'Spine2':0.7,'LeftShoulder':0.3}}
cnt={}
ARMS={vg[M+n].index for n in ('LeftArm','RightArm','LeftForeArm','RightForeArm') }
for v in me.vertices:
    k=par[v.index]; c=v.co
    if k in RIGID: setw(v.index, RIGID[k]); cnt[k]=cnt.get(k,0)+1; continue
    flap = (k==7582 and c.z<0.93) or k==6277
    if flap:
        h=max(0.0,min(1.0,(c.z-0.45)/(0.92-0.45)))
        hp=0.2+0.8*h*h
        setw(v.index, {'Hips':hp,'LeftUpLeg':(1-hp)/2,'RightUpLeg':(1-hp)/2}); cnt['flap']=cnt.get('flap',0)+1; continue
    if k==7582 and abs(c.x)<0.17 and 0.95<c.z<1.4:
        ws={g.group:g.weight for g in v.groups}
        a=sum(w for i,w in ws.items() if i in ARMS)
        if a>1e-3:
            for i in ARMS:
                if i in ws: o.vertex_groups[i].remove([v.index])
            vg[M+'Spine2'].add([v.index], a, 'ADD'); cnt['torso']=cnt.get('torso',0)+1
print('WFIX', cnt)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s2w.blend'))
