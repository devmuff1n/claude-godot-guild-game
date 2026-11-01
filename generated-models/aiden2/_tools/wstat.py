import bpy, os
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Aiden']; gi={g.index:g.name.replace('mixamorig:','') for g in o.vertex_groups}
rig=bpy.data.objects['Aiden_Rig']
for n in ('Hips','LeftUpLeg','LeftLeg','Spine','LeftShoulder','LeftArm'): print(n,[round(x,3) for x in rig.data.bones['mixamorig:'+n].head_local])
def band(x0,x1,y0,y1,z0,z1,label):
    acc={}; n=0
    for v in o.data.vertices:
        c=v.co
        if x0<=c.x<=x1 and y0<=c.y<=y1 and z0<=c.z<=z1:
            n+=1
            for g in v.groups: acc[gi[g.group]]=acc.get(gi[g.group],0)+g.weight
    print(label,n,sorted([(k,round(w/max(n,1),2)) for k,w in acc.items()],key=lambda t:-t[1])[:6])
for z in (0.85,0.75,0.65,0.55,0.45):
    band(-0.08,0.08,-1,-0.05,z-0.05,z+0.05,f'front z{z}')
    band(-0.08,0.08,0.05,1,z-0.05,z+0.05,f'back z{z}')
    band(0.08,0.25,-1,1,z-0.05,z+0.05,f'leftside z{z}')
