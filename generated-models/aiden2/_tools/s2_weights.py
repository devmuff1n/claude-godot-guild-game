# Step 2: weight fixes for Aiden.
# - small rigid pieces: chest star brooch -> Spine2; belt medallion / tassels / beads (had thigh weights) -> Hips(+Spine);
# - robe flaps and the hanging sash (verts below the belt farther than the leg radius from the leg bones) ->
#   Hips + both thighs, leg share by x (smooth left/right), Hips share by height, so panels don't tear between legs.
import bpy, os, json, math
from mathutils import Vector as V
from mathutils.geometry import intersect_point_line
W=os.path.join(os.path.dirname(__file__),'..','_work')
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,'s1.blend'))
o=bpy.data.objects['Aiden']; me=o.data; M='mixamorig:'
rig=bpy.data.objects['Aiden_Rig']; B=rig.data.bones
I=json.load(open(os.path.join(W,'islands.json'))); par=I['par']
isl={d['id']:d for d in I['isl']}
vg={g.name:g for g in o.vertex_groups}
gi={g.index:g.name.replace(M,'') for g in o.vertex_groups}
def setw(i, d):
    for g in list(me.vertices[i].groups): o.vertex_groups[g.group].remove([i])
    s=sum(d.values())
    for n,w in d.items():
        if w>1e-4: vg[M+n].add([i], w/s, 'REPLACE')
def sstep(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a))); return t*t*(3-2*t)
hips=B[M+'Hips'].head_local
# rigid small islands by location (ids are vertex roots from islands.json)
RIGID={}
for k,d in isl.items():
    k=int(k); mn,mx=d['mn'],d['mx']; cz=(mn[2]+mx[2])/2
    if d['n']>200: continue
    if cz>1.15: RIGID[k]={'Spine2':1}                      # chest star
    elif 0.6<cz<1.1: RIGID[k]={'Hips':0.75,'Spine':0.25}   # belt medallion, tassels, beads
def seg(n):
    b=B[M+n]; return b.head_local, b.tail_local
LEG={s:[seg(s+'UpLeg'),seg(s+'Leg')] for s in ('Left','Right')}
def legdist(c):
    best=9
    for s in LEG.values():
        for a,b in s:
            p,t=intersect_point_line(c,a,b); t=max(0,min(1,t)); best=min(best,(c-(a+(b-a)*t)).length)
    return best
def leg_r(z): return 0.082+0.045*sstep(0.40,0.85,z)
MAIN=max(isl,key=lambda k:isl[k]['n']); MAIN=int(MAIN)
cnt={}
HIP_TOP=hips.z+0.06
for v in me.vertices:
    c=v.co; k=par[v.index]
    if k in RIGID: setw(v.index,RIGID[k]); cnt['rigid']=cnt.get('rigid',0)+1; continue
    gs={gi[g.group]:g.weight for g in v.groups}
    dom=max(gs,key=gs.get) if gs else ''
    if k==MAIN and 0.36<c.z<HIP_TOP and dom in ('Hips','LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','Spine') and legdist(c)>leg_r(c.z):
        h=sstep(0.32, HIP_TOP, c.z)
        hp=0.25+0.75*h*h
        sL=sstep(-0.14,0.14,c.x)
        setw(v.index,{'Hips':hp,'LeftUpLeg':(1-hp)*sL,'RightUpLeg':(1-hp)*(1-sL)}); cnt['skirt']=cnt.get('skirt',0)+1; continue
print('WFIX', cnt, 'rigid', RIGID, 'hipsz', round(hips.z,3))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W,'s2w.blend'))
