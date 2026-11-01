# Named poses for Elira's bow clips. A pose is a dict of parameters; clips interpolate parameters and solve each frame.
import math
from mathutils import Vector, Matrix
import animlib as L
V = Vector

def torso(P, q):
    hips = q['hips']; tw = q['tw']
    L.add(P, 'Hips', 'Z', hips)
    L.add(P, 'Hips', 'loc', 0) if False else None
    if q.get('drop'): P.setdefault('Hips', {})['loc'] = (0, 0, -q['drop'])
    for n in ('LeftUpLeg', 'RightUpLeg'): L.add(P, n, 'Z', -hips*q.get('feet', 0.55))
    L.add(P, 'LeftUpLeg', 'Y', q.get('stance', 0)); L.add(P, 'RightUpLeg', 'Y', -q.get('stance', 0))
    kb = q.get('knee', 0)
    for s in ('Left', 'Right'):
        L.add(P, s+'UpLeg', 'X', -kb); L.add(P, s+'Leg', 'X', kb*2); L.add(P, s+'Foot', 'X', -kb)
    L.add(P, 'Spine', 'Z', tw*0.3); L.add(P, 'Spine1', 'Z', tw*0.35); L.add(P, 'Spine2', 'Z', tw*0.35)
    lean = q.get('lean', 0); L.add(P, 'Spine1', 'X', lean*0.5); L.add(P, 'Spine2', 'X', lean*0.5)
    side_lean = q.get('slean', 0); L.add(P, 'Spine1', 'Y', side_lean*0.5); L.add(P, 'Spine2', 'Y', side_lean*0.5)
    if q.get('wamp'):   # walk / run cycle, phase wph 0..1
        a = q['wamp']; ph = 2*math.pi*q['wph']
        for s, sg in (('Left', 1), ('Right', -1)):
            sw = math.sin(ph if sg > 0 else ph+math.pi)
            lift = max(0.0, math.sin((ph if sg > 0 else ph+math.pi)-math.pi/2))
            L.add(P, s+'UpLeg', 'X', -28*a*sw-10*a*lift)
            L.add(P, s+'Leg', 'X', 15*a+45*a*lift)
            L.add(P, s+'Foot', 'X', -8*a*sw)
        bob = abs(math.sin(ph))
        P.setdefault('Hips', {})['loc'] = (0, 0, -0.012*a+0.018*a*bob-q.get('drop', 0))
        L.add(P, 'Hips', 'Z', 6*a*math.sin(ph))
        L.add(P, 'Spine1', 'Z', -8*a*math.sin(ph))
        L.add(P, 'Spine', 'X', 5*a*q.get('runlean', 0))
    if q.get('breath'): L.add(P, 'Spine1', 'X', 1.2*q['breath']); L.add(P, 'Spine2', 'X', 0.8*q['breath'])
    L.add(P, 'Neck', 'Z', q['yaw']*0.4); L.add(P, 'Head', 'Z', q['yaw']*0.6)
    L.add(P, 'Head', 'X', q.get('pitch', 0))
    L.add(P, 'Head', 'Y', q.get('tilt', 0))

def build(q, arrow_state=None):
    """Apply a full parameter pose. q keys: hips, tw, yaw, pitch, WL,dL,kL,pL, WR,dR,kR,pR, hook, rfist, string, flex,
    arrow ('hide'|'hand'|'nock' blend via q['nock']), adir, avis."""
    P = {}
    torso(P, q)
    L.fingers(P, 'Left', L.GRIP, thumb=1.0)
    hk = q.get('hook', 0); rf = q.get('rfist', 0)
    curl = {k: L.RELAX[k]+(L.HOOK[k]-L.RELAX[k])*hk+(L.GRIP[k]-L.RELAX[k])*rf for k in L.RELAX}
    L.fingers(P, 'Right', curl, thumb=0.5*hk+rf)
    sh = V(q.get('shift', (0, 0, 0)))
    if sh.length:
        h = P.setdefault('Hips', {}); h['loc'] = tuple(V(h.get('loc', (0, 0, 0)))+sh)
    L.apply_pose(P); L.upd()
    L.place_arm('Left', V(q['WL'])+sh, q['pL'], q['dL'], q['kL'])
    L.place_arm('Right', V(q['WR'])+sh, q['pR'], q['dR'], q['kR'])
    L.flex_bow(q.get('flex', 0)); L.upd()
    hook = L.hook_point(); srest = L.string_rest_point()
    s = q.get('string', 0)
    L.place_string(srest.lerp(hook, s)); L.upd()
    nk = q.get('nock', 0)
    rest_pt = L.bow_rest_point()
    nock_pos = L.pose['BowString'].head.copy()
    d_nock = (rest_pt-nock_pos).normalized()
    up_bow = (L.deform('Bow').to_3x3() @ L.META['up']).normalized()
    d_hand = V(q.get('adir', (0, 0, -1))).normalized()
    pos = hook.lerp(nock_pos, nk)
    d = d_hand.lerp(d_nock, nk).normalized()
    upv = V((0, 0, 1)).lerp(up_bow, nk)
    if abs(d.dot(upv.normalized())) > 0.95: upv = V((1, 0, 0))
    L.place_arrow(pos, d, upv, q.get('avis', 1) > 0.5)
    L.upd()

def hold_bow(q, Gt, A, k):
    """left wrist so that the grip lands on Gt, arrow direction A, bow up k."""
    A = V(A).normalized(); k = V(k).normalized()
    R = L.hand_R('Left', A, k)
    q.update(WL=V(Gt)-R @ (L.META['G']-L.rest_head('LeftHand')), dL=A, kL=k)
    return q
def on_string(q, dist, iters=5):
    """right hook on the string, `dist` metres behind the arrow rest along the bow's aim."""
    build(q); L.upd()
    Ab = (L.deform('Bow').to_3x3() @ L.META['T']).normalized()
    tgt = L.bow_rest_point()-Ab*dist
    up_b = (L.deform('Bow').to_3x3() @ L.META['up']).normalized()
    q.update(dR=Ab, kR=up_b)
    Wr = q.get('WR_guess', tgt-Ab*0.06)
    for _ in range(iters):
        q['WR'] = Wr; build(q); L.upd()
        Wr = Wr+(tgt-L.hook_point())
    q['WR'] = Wr
    return q

def solve_full(base, A, anchor_off=(0.035, 0.07, 0.03), pole_l=(1, 0.2, -0.6), pole_r=(-1, 0.4, 0.35), cant=0.12):
    """Full draw: string hand anchored at the chin, bow arm extended along aim A. Returns pose params."""
    q = dict(base)
    A = V(A).normalized()
    right = A.cross(V((0, 0, 1))).normalized()
    # torso + rest arms first, to read the head and shoulders
    q.update(WL=V((0.4, -0.3, 0.9)), dL=A, kL=V((0, 0, 1)), pL=V(pole_l), WR=V((-0.2, -0.2, 1.0)), dR=A, kR=V((0, 0, 1)), pR=V(pole_r),
             hook=1, string=0, nock=1, flex=0)
    build(q); L.upd()
    hd = L.head('Head')
    C = hd+right*anchor_off[0]+A*anchor_off[1]+V((0, 0, anchor_off[2]))
    kL = (V((0, 0, 1))+right*(-cant)).normalized()
    R = L.hand_R('Left', A, kL)
    off = L.META['G']-L.rest_head('LeftHand')
    S = L.head('LeftArm'); la, lb = L.arm_len('Left'); reach = (la+lb)*0.985
    lo, hi = 0.05, 1.2
    for _ in range(40):
        D = (lo+hi)/2
        Wl = C+A*D-R @ off
        if (Wl-S).length > reach: hi = D
        else: lo = D
    D = lo; Wl = C+A*D-R @ off
    q.update(WL=Wl, kL=kL)
    # right hand: iterate wrist so that the hook lands on C
    Wr = C-A*0.06
    for _ in range(5):
        q['WR'] = Wr; build(q); L.upd()
        Wr = Wr+(C-L.hook_point())
    q['WR'] = Wr
    q['string'] = 1; q['flex'] = 1
    return q, C, D
