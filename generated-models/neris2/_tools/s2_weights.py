# Step 2: weight fixes for Neris.
# - long hair (Head-dominant verts below the chin, outside the neck column) fades Head -> Spine2/Spine1 by height,
#   so a head turn no longer swings waist-length hair through the body;
# - tail -> Hips only;
# - skirt / robe flaps (verts below the hips farther than the leg radius from the leg bones) -> Hips + both thighs,
#   leg share by x (smooth left/right), Hips share by height; front/back panels are no longer torn between legs.
import bpy, os, json, math
from mathutils import Vector as V
from mathutils.geometry import intersect_point_line
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Neris']; me=o.data; M='mixamorig:'
rig=bpy.data.objects['Neris_Rig']; B=rig.data.bones
I=json.load(open(os.path.join(W,'islands.json'))); par=I['par']
isl={d['id']:d for d in I['isl']}
TAIL=[k for k,d in isl.items() if d['n']>250 and d['mx'][2]<0.95 and d['mn'][2]>0.4][0]
FRONT_HAIR=[k for k,d in isl.items() if d['n']>500 and d['mn'][2]>0.9 and d['mx'][2]<1.55][0]
vg={g.name:g for g in o.vertex_groups}
gi={g.index:g.name.replace(M,'') for g in o.vertex_groups}
def setw(i, d):
    for g in list(me.vertices[i].groups): o.vertex_groups[g.group].remove([i])
    s=sum(d.values())
    for n,w in d.items():
        if w>1e-4: vg[M+n].add([i], w/s, 'REPLACE')
def sstep(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a))); return t*t*(3-2*t)
neck=B[M+'Neck'].head_local; head=B[M+'Head'].head_local; hips=B[M+'Hips'].head_local
CHIN=head.z-0.03
def seg(n):
    b=B[M+n]; return b.head_local, b.tail_local
LEG={s:[seg(s+'UpLeg'),seg(s+'Leg')] for s in ('Left','Right')}
def legdist(c):
    best=9
    for s in LEG.values():
        for a,b in s:
            p,t=intersect_point_line(c,a,b); t=max(0,min(1,t)); best=min(best,(c-(a+(b-a)*t)).length)
    return best
def leg_r(z):   # rough leg radius (thigh thicker)
    return 0.062+0.05*sstep(0.35,0.78,z)
cnt={}
HIP_TOP=hips.z+0.05
for v in me.vertices:
    c=v.co; k=par[v.index]
    gs={gi[g.group]:g.weight for g in v.groups}
    dom=max(gs,key=gs.get) if gs else ''
    if k==TAIL:
        setw(v.index,{'Hips':1}); cnt['tail']=cnt.get('tail',0)+1; continue
    # hair
    hor=math.hypot(c.x-neck.x, c.y-neck.y)
    if (dom in ('Head','Neck') or k==FRONT_HAIR) and c.z<CHIN and (hor>0.075 or c.z<neck.z-0.02) :
        t=sstep(0.78, CHIN, c.z)
        h=t**1.3
        rest=1-h
        s1=sstep(0.95,0.75,c.z)   # lowest locks lean on Spine1
        setw(v.index,{'Head':h*0.85,'Neck':h*0.15,'Spine2':rest*(1-s1*0.5),'Spine1':rest*s1*0.5}); cnt['hair']=cnt.get('hair',0)+1; continue
    # skirt
    if 0.2<c.z<HIP_TOP and dom in ('Hips','LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','Spine') and legdist(c)>leg_r(c.z):
        h=sstep(0.25, HIP_TOP, c.z)
        hp=0.2+0.8*h*h
        sL=sstep(-0.13,0.13,c.x)
        setw(v.index,{'Hips':hp,'LeftUpLeg':(1-hp)*sL,'RightUpLeg':(1-hp)*(1-sL)}); cnt['skirt']=cnt.get('skirt',0)+1; continue
print('WFIX', cnt, 'tail', TAIL, 'fronthair', FRONT_HAIR, 'chin', round(CHIN,3), 'hipsz', round(hips.z,3))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s2w.blend'))
