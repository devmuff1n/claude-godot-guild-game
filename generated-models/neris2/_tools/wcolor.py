# Colour every vertex by its dominant bone group (rest pose) -> _work/wcol_*.png
# head/neck red, spine green, hips blue, L leg yellow, R leg orange, L arm cyan, R arm magenta, hands white
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from common import setup_render, shoot
W=os.path.join(os.path.dirname(__file__),'..','_work')
f=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 's1.blend'
bpy.ops.wm.open_mainfile(filepath=os.path.join(W,f))
o=bpy.data.objects['Neris']; me=o.data
gi={g.index:g.name.replace('mixamorig:','') for g in o.vertex_groups}
def cat(n):
    if n in ('Head','Neck','HeadTop_End'): return (1,0.1,0.1)
    if n.startswith('Spine'): return (0.1,0.9,0.1)
    if n=='Hips': return (0.1,0.2,1)
    if 'Hand' in n: return (1,1,1)
    if n.startswith('Left') and ('Leg' in n or 'Foot' in n or 'Toe' in n): return (1,1,0)
    if n.startswith('Right') and ('Leg' in n or 'Foot' in n or 'Toe' in n): return (1,0.5,0)
    if n.startswith('Left'): return (0,1,1)
    if n.startswith('Right'): return (1,0,1)
    return (0,0,0)
ca=me.color_attributes.new('wc','FLOAT_COLOR','POINT')
for v in me.vertices:
    gs=sorted(v.groups,key=lambda g:-g.weight)
    c=cat(gi[gs[0].group]) if gs else (0,0,0)
    if gs and gs[0].weight<0.6: c=tuple(x*0.55 for x in c)   # mixed -> darker
    ca.data[v.index].color=(*c,1)
m=bpy.data.materials.new('wcm'); m.use_nodes=True; nt=m.node_tree
a=nt.nodes.new('ShaderNodeAttribute'); a.attribute_name='wc'
e=nt.nodes.new('ShaderNodeEmission'); nt.links.new(a.outputs[0],e.inputs[0])
nt.links.new(e.outputs[0],nt.nodes['Material Output'].inputs[0])
me.materials.clear(); me.materials.append(m)
setup_render((500,800),'BLENDER_EEVEE')
from PIL import Image
g=Image.new('RGB',(2000,800))
for i,(n,d) in enumerate([('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0)),('lside',(-1,0,0))]):
    p=os.path.join(W,f'wcol_{n}.png'); shoot(p,(0,0,0.81),1.75,d); g.paste(Image.open(p),(500*i,0))
g.save(os.path.join(W,'wcol_all.png'))
