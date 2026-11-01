# quick iteration: retarget a few clips + staff + overview.  bash run4.sh CLIP1,CLIP2,...
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"; cd "$(dirname "$0")"
"$B" -b --python-use-system-env --python mx_retarget.py -- ../_work/s2w.blend ../_work/mx_t.blend $1 > ../_work/retarget_t.log 2>&1; grep -E "Error|line [0-9]" -A3 ../_work/retarget_t.log
"$B" -b --python-use-system-env --python s3_staff.py -- mx_t.blend t.blend 2>&1 | grep -E "Error"
"$B" -b --python-use-system-env --python overview.py -- t.blend ov $1 2>&1 | grep -E "OV|Error"
