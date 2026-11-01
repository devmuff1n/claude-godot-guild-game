# Action 'GripTest': rest pose with the staff-hand fist (both hands) -> used by fist_probe before Mixamo clips exist.
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from grip import curl_map
W = os.path.join(os.path.dirname(__file__), '..', '_work')
a = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.join(W, a[0]))
rig = bpy.data.objects['Aiden_Rig']
if rig.animation_data is None: rig.animation_data_create()
act = bpy.data.actions.new('GripTest'); act.use_fake_user = True; rig.animation_data.action = act
for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'
R0 = {b.name: b.matrix_local.to_3x3().normalized() for b in rig.data.bones}
for side in ('Left', 'Right'):
    C = curl_map(rig, side)
    for n, D in C.items():
        p = rig.data.bones[n].parent.name
        Dp = C.get(p, D.__class__.Identity(3))
        rig.pose.bones[n].rotation_quaternion = (R0[n].inverted() @ Dp.inverted() @ D @ R0[n]).to_quaternion()
for pb in rig.pose.bones: pb.keyframe_insert('rotation_quaternion', frame=0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(W, a[1]))
