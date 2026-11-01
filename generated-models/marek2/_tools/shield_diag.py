# For the placement in props_tune.json: worst frame per clip and which body part the shield sinks into.
import bpy, sys, os, json
sys.argv = sys.argv[:sys.argv.index('--')+1]+['marek2.blend', 'eval']
exec(open(os.path.join(os.path.dirname(__file__), 'shield_fit.py'), encoding='utf-8').read().split("cur = {k_")[0])
P = dict(shield_out=0.075, shield_back=0.03); P.update(json.load(open(TP))); pts = samples(P)
gi = {g.index: g.name.replace('mixamorig:', '') for g in body.vertex_groups}
def part(fi):
    vs = body.data.polygons[fi].vertices; acc = {}
    for vi in vs:
        for g in body.data.vertices[vi].groups: acc[gi[g.group]] = acc.get(gi[g.group], 0)+g.weight
    return max(acc, key=acc.get)
worst = {}; cnt = {}
for c, fr, bvh, D in cache:
    fw = 0
    for q in pts:
        w = D @ q
        loc, nrm, idx, dist = bvh.find_nearest(w, 0.1)
        if loc is not None and not SKIP[idx] and (w-loc).dot(nrm) < 0 and dist > worst.get(c, (0,))[0]:
            worst[c] = (dist, fr, part(idx))
        if loc is not None and not SKIP[idx] and (w-loc).dot(nrm) < 0: fw = max(fw, dist)
    cnt.setdefault(c, []).append(round(fw*100))
for c in CLIPS: print('W', c, [round(worst[c][0],3), worst[c][1], worst[c][2]] if c in worst else None, 'cm/frame', cnt.get(c))
