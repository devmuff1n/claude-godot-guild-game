import bpy,sys,numpy as np
argv=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
lo=bpy.data.objects["Elira"]; me=lo.data
co=np.array([v.co[:] for v in me.vertices]); ed=np.array([e.vertices[:] for e in me.edges])
names=[]; W=np.zeros((len(co),1))
np.savez(argv[1],co=co,ed=ed)
