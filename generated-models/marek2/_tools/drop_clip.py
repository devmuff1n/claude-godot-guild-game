import bpy, sys, os
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=a[0])
for n in a[2].split(','):
    if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
bpy.ops.wm.save_as_mainfile(filepath=a[1]); print('DROP ok')
