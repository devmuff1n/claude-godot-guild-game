# Relaxed sword carry for plain (non-combat) clips: in the Mixamo "Walking" the right arm swings with the
# blade along the forearm, so it cuts through the hip. Per frame the Sword bone turns about the fist so the
# blade hangs down, a little outward from the body and back; keyed on the Sword bone of each listed clip.
# blender -b --python sword_walk.py -- <in_blend> <out_blend> [clips]   (paths relative to _work)
import bpy, sys, os
from mathutils import Vector as V, Matrix
W = os.path.join(os.path.dirname(__file__), '..', '_work')
argv = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, argv[0]))
CLIPS = argv[2].split(',') if len(argv) > 2 else ['MX_PlainWalk']
rig = bpy.data.objects['Marek_Rig']; M = 'mixamorig:'
sc = bpy.context.scene
sp = rig.pose.bones['Sword']; sp.rotation_mode = 'QUATERNION'
hips = rig.pose.bones[M+'Hips']; hand = rig.pose.bones[M+'RightHand']
for clip in CLIPS:
    act = bpy.data.actions.get(clip)
    if act is None:
        print('SWORD no clip', clip); continue
    rig.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    # forward of the body: from the rest pose, the character faces -Y in Blender (Mixamo import)
    fwd = V((0, -1, 0))
    keys = []
    for fr in range(f0, f1+1):
        sc.frame_set(fr)
        sp.rotation_quaternion = (1, 0, 0, 0)
        bpy.context.view_layer.update()
        M0 = sp.matrix.copy()                      # armature space, no own rotation
        d0 = M0.to_3x3().col[1].normalized()       # blade direction (bone Y)
        out = hand.head - hips.head; out.z = 0.0
        out = out - fwd*out.dot(fwd)
        out = out.normalized() if out.length > 1e-4 else V((-1, 0, 0))
        target = (V((0, 0, -1)) + out*0.30 - fwd*0.25).normalized()
        Rw = d0.rotation_difference(target).to_matrix()
        R0 = M0.to_3x3()
        local = (R0.inverted() @ Rw @ R0).to_quaternion()
        keys.append(local)
    # light smoothing over time (loop-aware)
    n = len(keys)
    sm = []
    for i in range(n):
        q = keys[i].copy()
        a, b = keys[(i-1) % n], keys[(i+1) % n]
        if a.dot(q) < 0: a = -a
        if b.dot(q) < 0: b = -b
        sm.append((a*0.25+q*0.5+b*0.25).normalized())
    for i, fr in enumerate(range(f0, f1+1)):
        sp.rotation_quaternion = sm[i]
        sp.keyframe_insert('rotation_quaternion', frame=fr)
    print('SWORD', clip, n, 'frames')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, argv[1]))
