"""Painted textures for the town kit (plaster, masonry, roof shingles, floor planks, wicker...).
Same look as gen_textures.py / gen_event_textures.py: periodic noise, posterised palettes.
Usage: python gen_town_textures.py <out_dir>"""
import os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def pnoise(n, scale, aniso=(1.0, 1.0), seed=None):
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * aniso[0]
    g = np.exp(-((fx ** 2 + fy ** 2) * (scale ** 2) * 2.0))
    r = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
    r -= r.min(); r /= max(r.max(), 1e-9)
    return r


def fbm(n, scale, octaves=3, aniso=(1, 1), seed=0):
    acc = np.zeros((n, n)); amp = 1.0; tot = 0
    for o in range(octaves):
        acc += amp * pnoise(n, scale / (2 ** o), aniso, seed + o)
        tot += amp; amp *= 0.5
    return acc / tot


def ramp(v, cols, steps=None, soft=0.35):
    cols = [hexc(c) for c in cols]
    k = len(cols) - 1
    if steps:
        q = v * steps; base = np.floor(q); frac = q - base
        frac = np.clip((frac - (1 - soft)) / soft, 0, 1)
        v = np.clip((base + frac) / steps, 0, 1)
    x = v * k
    i = np.clip(np.floor(x).astype(int), 0, k - 1)
    t = (x - i)[..., None]
    a = np.stack(cols)[i]; b = np.stack(cols)[i + 1]
    return a * (1 - t) + b * t


def blend(a, b, m):
    m = np.clip(m, 0, 1)[..., None]
    return a * (1 - m) + b * m


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def flat(name, cols, seed, scale=40, n=256, steps=3):
    save(ramp(fbm(n, scale, 2, seed=seed), cols, steps=steps), name)


# ---------------------------------------------------------------- plaster (cream, soft blotches)
N = 512
g = 0.7 * fbm(N, 70, 3, seed=101) + 0.3 * fbm(N, 12, 2, seed=102)
img = ramp(g, ["#cdb994", "#dccaa6", "#e7d8b9", "#efe3c8", "#f6eedb"], steps=4)
save(img, "plaster")

# ---------------------------------------------------------------- masonry blocks (1 m = image, 4 rows of 0.25 m)
yy, xx = np.mgrid[0:N, 0:N]
rowh = N // 4
row = yy // rowh
off = (row % 2) * (N // 6)
blkw = N // 3
col = (xx + off) % blkw
bid = (row * 7 + (xx + off) // blkw) % 13
tint = (np.sin(bid * 2.3) * 0.5 + 0.5)[..., None]
base = ramp(fbm(N, 50, 3, seed=110), ["#8e8478", "#a49a8c", "#b8ad9c", "#cabfae", "#d8cebd"], steps=4)
img = base * (0.9 + 0.16 * tint)
ey = np.minimum(yy % rowh, rowh - 1 - yy % rowh)
ex = np.minimum(col, blkw - 1 - col)
edge = np.minimum(ey, ex)
img = blend(img, img * 0.82, (edge < 9) * 0.5)          # chamfer shade
img = blend(img, hexc("#4e463f") * np.ones_like(img), (edge < 4) * 0.95)  # mortar
save(img, "stone_block")


# ---------------------------------------------------------------- roof shingles: rows along U, V down the slope
def shingles(name, cols, gap, seed, n=256, rows=4, per_row=4):
    yy, xx = np.mgrid[0:n, 0:n]
    rh = n // rows; cw = n // per_row
    row = yy // rh
    off = (row % 2) * (cw // 2)
    col = (xx + off) % cw
    tid = (row * 5 + (xx + off) // cw) % 11
    base = ramp(fbm(n, 30, 2, seed=seed), cols, steps=3)
    tint = (np.sin(tid * 1.9) * 0.5 + 0.5)[..., None]
    shade = (yy % rh) / rh
    img = base * (0.92 + 0.14 * tint) * (1.06 - 0.28 * shade[..., None])
    # rounded tile bottoms
    cx = (col - cw / 2) / (cw / 2)
    bottom = rh - 1 - (yy % rh)
    curve = (bottom < 5 + 6 * (cx ** 2))
    g_ = (col < 3) | curve
    img = blend(img, hexc(gap) * np.ones_like(img), g_ * 0.9)
    save(img, name)


shingles("roof_red", ["#8e3a26", "#a8472c", "#bf5734", "#d06a40"], "#4a1d14", 120)
shingles("roof_green", ["#3c5a44", "#4a6c50", "#5a7e5c", "#6c906a"], "#1f2e24", 121)
shingles("roof_plum", ["#4e2a38", "#5e3444", "#703f52", "#834c60"], "#26141c", 122)
shingles("roof_brown", ["#8a4a2a", "#a05832", "#b4683c", "#c67a48"], "#432414", 123)

# ---------------------------------------------------------------- floor planks (planks along U, 4 per tile)
g = fbm(N, 40, 3, aniso=(1.0, 0.1), seed=130)
img = ramp(0.7 * g + 0.3 * pnoise(N, 60, seed=131), ["#6a4228", "#7e5030", "#93603a", "#a87048", "#b98052"], steps=4)
ph = N // 4
pid = yy // ph
seg = (xx + (pid * 151) % N) % (N // 2)
img = img * (0.92 + 0.1 * (np.sin(pid * 2.7) * 0.5 + 0.5))[..., None]
gap = ((yy % ph) < 4) | (seg < 3)
img = blend(img, hexc("#2c1a10") * np.ones_like(img), gap * 0.9)
save(img, "floor_planks")

# ---------------------------------------------------------------- wicker weave
n = 256
yy, xx = np.mgrid[0:n, 0:n]
cell = 32
cu = (xx // cell + yy // (cell // 2)) % 2
v = np.where(cu == 0, np.sin((yy % (cell // 2)) / (cell / 2) * np.pi), np.sin((xx % cell) / cell * np.pi))
base = ramp(fbm(n, 30, 2, seed=140), ["#7a4f28", "#94622f", "#ad7638", "#c48a46"], steps=3)
img = base * (0.6 + 0.45 * v[..., None])
save(img, "wicker")

flat("parchment", ["#cdb68c", "#ddc8a0", "#e9d8b4", "#f3e6c8"], 150, 50)
flat("leather_red", ["#4a2016", "#5c2a1c", "#6e3422", "#80402a"], 151, 40)
flat("hide_pale", ["#d6b48c", "#e2c4a0", "#ecd3b4", "#f4e2c8"], 152, 60)
flat("liquid_tan", ["#2a1210", "#361814", "#42201a", "#502820"], 153, 60)
flat("pewter", ["#4a4e54", "#5c6168", "#70767c", "#8a9096"], 154, 50)


def cloth(name, cols, seed, weave=0.06):
    g = fbm(256, 30, 3, seed=seed)
    img = ramp(g, cols, steps=3)
    yy, xx = np.mgrid[0:256, 0:256]
    w = ((np.sin(xx * np.pi / 2) * np.sin(yy * np.pi / 2)) > 0) * weave
    save(img * (1 - w[..., None]), name)


cloth("cloth_teal", ["#1e4e58", "#255c66", "#2d6a74", "#367a84"], 160)
cloth("cloth_navy", ["#25365e", "#2d406c", "#364c7c", "#42598c"], 161)
cloth("canvas_green", ["#6e8a72", "#7b977e", "#89a48a", "#97b096"], 162)

# coal bed: near black with a few dull embers
g = fbm(n, 8, 2, seed=170)
img = ramp(g, ["#141214", "#1e1b1e", "#2a2629", "#38323a"], steps=4)
emb = fbm(n, 10, 2, seed=171)
img = blend(img, hexc("#c4501e") * np.ones_like(img), (emb > 0.8) * 0.8)
save(img, "coal")

# timber beams: warm dark brown with grain along U
g = fbm(N, 40, 3, aniso=(1.0, 0.1), seed=180)
img = ramp(0.7 * g + 0.3 * pnoise(N, 70, seed=181), ["#3a2416", "#48301e", "#573a24", "#66452c", "#76522f"], steps=4)
lines = fbm(N, 6, 2, aniso=(1.0, 0.05), seed=182)
img = blend(img, img * 0.75, (lines > 0.72) * 0.7)
save(img, "timber")
