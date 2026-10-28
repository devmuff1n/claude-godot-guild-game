import bpy, sys, numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
o=bpy.data.objects["Elira"]; me=o.data
co=np.array([v.co[:] for v in me.vertices]); f=[p.vertices[:] for p in me.polygons]
ed=np.array([e.vertices[:] for e in me.edges])
uv=me.uv_layers[0].data
img=[i for i in bpy.data.images if 'basecolor' in i.name][0]
print(img.filepath)
np.savez(argv[1],co=co,ed=ed)
