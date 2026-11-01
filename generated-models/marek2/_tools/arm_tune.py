# Picks extra left-arm space per clip (degrees) where the shield still sinks into the body -> _work/arm_extra.json
import subprocess, json, os, re, sys
B = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
T = os.path.dirname(os.path.abspath(__file__)); W = os.path.join(T, '..', '_work')
CL = sys.argv[1].split(',')
res = {c: {} for c in CL}
for a in (0, 8, 16, 24, 32):
    env = dict(os.environ, ARM_EXTRA=json.dumps({c: a for c in CL}), FIT_CLIPS=','.join(CL))
    subprocess.run([B, '-b', '--python', os.path.join(T, 'mx_retarget.py'), '--', os.path.join(W, 'marek2.blend'), os.path.join(W, '_try.blend'), ','.join(CL)], env=env, capture_output=True)
    out = subprocess.run([B, '-b', '--python', os.path.join(T, 'shield_fit.py'), '--', '_try.blend', 'eval'], env=env, capture_output=True, text=True).stdout
    line = [l for l in out.splitlines() if l.startswith('CURRENT')][0]
    per = eval(line[line.index('{', line.index('mean_worst')):])
    for c in CL: res[c][a] = per[c]
    print('ARM', a, per, flush=True)
best = {}
for c in CL:
    a = min(res[c], key=lambda k: res[c][k]+k*0.0015)   # prefer a small change
    if a: best[c] = a
print('PICK', best)
json.dump(best, open(os.path.join(W, 'arm_extra.json'), 'w'), indent=1)
