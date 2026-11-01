# Full Neris build: s2w.blend -> mx.blend -> neris2.blend (staff + fitted) -> game GLB
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"; cd "$(dirname "$0")"; W=../_work
rm -f $W/clips.json $W/staff_fit.json
"$B" -b --python-use-system-env --python mx_retarget.py -- $W/s2w.blend $W/mx.blend > $W/b_retarget.log 2>&1 || exit 1
"$B" -b --python-use-system-env --python s3_staff.py -- mx.blend mxs.blend > $W/b_staff.log 2>&1 || exit 1
"$B" -b --python-use-system-env --python staff_fit.py -- mxs.blend neris2.blend > $W/b_fit.log 2>&1 || exit 1
cp $W/neris2.blend ../neris2.blend
mkdir -p ../../../assets/models/characters/neris2
"$B" -b --python-use-system-env --python game_export.py -- $W/neris2.blend ../../../assets/models/characters/neris2/neris2.glb > $W/b_export.log 2>&1 || exit 1
grep -E "^FIT" $W/b_fit.log; grep GAME $W/b_export.log
