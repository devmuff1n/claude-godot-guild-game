"""Painted, seamless textures for the environment kit (cel-ish, broad colour patches).

All maps are periodic (built from FFT-filtered noise), so they tile without seams.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def pnoise(n, scale, aniso=(1.0, 1.0), seed=None):
    """Periodic smooth noise in [0,1]. scale ~ feature size in px."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    w = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * aniso[0]
    g = np.exp(-((fx ** 2 + fy ** 2) * (scale ** 2) * 2.0))
    r = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
    r -= r.min(); r /= max(r.max(), 1e-9)
    return r


def fbm(n, scale, octaves=3, aniso=(1, 1), seed=None):
    acc = np.zeros((n, n)); amp = 1.0; tot = 0
    for o in range(octaves):
        acc += amp * pnoise(n, scale / (2 ** o), aniso, None if seed is None else seed + o)
        tot += amp; amp *= 0.5
    return acc / tot


def ramp(v, cols, steps=None, soft=0.35):
    """Map v in [0,1] through a palette. steps -> posterise with soft band edges (cel look)."""
    cols = [hexc(c) for c in cols]
    k = len(cols) - 1
    if steps:
        q = v * steps
        base = np.floor(q)
        frac = q - base
        frac = np.clip((frac - (1 - soft)) / soft, 0, 1)  # soft step at band edge
        v = np.clip((base + frac) / steps, 0, 1)
    x = v * k
    i = np.clip(np.floor(x).astype(int), 0, k - 1)
    t = (x - i)[..., None]
    a = np.stack(cols)[i]
    b = np.stack(cols)[i + 1]
    return a * (1 - t) + b * t


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def blend(a, b, m):
    m = np.clip(m, 0, 1)[..., None]
    return a * (1 - m) + b * m


N = 512

# ---------------------------------------------------------------- wood (grain along U)
def wood(name, cols, seed, grain=0.12):
    g = fbm(N, 40, 3, aniso=(1.0, 0.12), seed=seed)          # long streaks along X
    blot = pnoise(N, 70, seed=seed + 10)
    v = 0.65 * g + 0.35 * blot
    img = ramp(v, cols, steps=4)
    # thin darker grain strokes
    lines = fbm(N, 6, 2, aniso=(1.0, 0.05), seed=seed + 20)
    img = blend(img, img * 0.72, (lines > 0.72) * 0.8)
    # a few knots
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(3):
        cx, cy = RNG.integers(0, N, 2)
        dx = np.minimum(abs(xx - cx), N - abs(xx - cx)); dy = np.minimum(abs(yy - cy), N - abs(yy - cy))
        d = np.sqrt(dx ** 2 + (dy / 2.4) ** 2)
        img = blend(img, img * 0.6, np.clip(1 - d / 9, 0, 1))
    save(img, name)

wood("wood_light", ["#7a5236", "#946a47", "#b0825a", "#c7956a", "#d9aa7c"], 1)
wood("wood_mid", ["#5e4030", "#755038", "#8b6442", "#a5794f"], 2)
wood("wood_dark", ["#352a25", "#46372f", "#574536", "#6a5544"], 3)

# ---------------------------------------------------------------- bark (fissures along U = trunk length)
g = fbm(N, 30, 3, aniso=(1.0, 0.18), seed=40)
img = ramp(g, ["#3d2c22", "#55402f", "#6e543c", "#8a6c4c"], steps=4)
fiss = fbm(N, 8, 2, aniso=(1.0, 0.1), seed=41)
img = blend(img, hexc("#1e1814") * np.ones_like(img), (fiss > 0.66) * 0.85)
save(img, "bark")

# light inner wood for broken ends / root tips
g = fbm(N, 25, 2, seed=45)
save(ramp(g, ["#8a6a4a", "#a98a68", "#c4a682"], steps=3), "wood_raw")

# ---------------------------------------------------------------- stone
g = fbm(N, 60, 3, seed=50)
img = ramp(g, ["#8a7d75", "#a39388", "#b8a698", "#cbb9aa", "#dccbbb"], steps=4)
cr = fbm(N, 5, 2, seed=51)
img = blend(img, img * 0.75, (cr > 0.75) * 0.6)
save(img, "stone")

# cooler boulder stone (field rock is greyer/bluer)
g = fbm(N, 60, 3, seed=55)
save(ramp(g, ["#4d5254", "#62676a", "#7a7d7a", "#959690", "#b3b1a3"], steps=4), "stone_grey")

# ---------------------------------------------------------------- moss / grass ground
g = fbm(N, 28, 3, seed=60)
img = ramp(g, ["#5b6a26", "#76852d", "#939d30", "#a9b03a", "#c2c25a"], steps=4)
save(img, "moss")

g = fbm(N, 36, 3, seed=61)
img = ramp(g, ["#3f5030", "#4f6134", "#647236", "#747b35", "#8e9a3c"], steps=4)
# little blade strokes
st = fbm(N, 3, 1, aniso=(1.0, 0.25), seed=62)
img = blend(img, img * 1.18, (st > 0.7) * 0.6)
save(img, "grass_ground")

# ---------------------------------------------------------------- dirt / soil
g = fbm(N, 40, 3, seed=70)
img = ramp(g, ["#946238", "#a7713f", "#b77f48", "#c58f57", "#d3a06a"], steps=4)
pb = pnoise(N, 2.2, seed=71)
img = blend(img, img * 0.7, (pb > 0.78) * 0.7)
save(img, "dirt_road")

g = fbm(N, 30, 3, seed=72)
img = ramp(g, ["#3e2e1d", "#4b3823", "#5c4530", "#6c5238"], steps=4)
save(img, "soil_dark")

g = fbm(N, 34, 3, seed=73)
img = ramp(g, ["#6a4830", "#7d553a", "#91623f", "#a8754d"], steps=4)
pb = pnoise(N, 2.0, seed=74)
img = blend(img, img * 0.75, (pb > 0.8) * 0.6)
save(img, "soil")

# ---------------------------------------------------------------- road tile top (1024, seamless in X; Y is the 6 m depth)
M = 1024
yy = np.mgrid[0:M, 0:M][0] / M  # 0..1 across depth
edge_noise = (fbm(M, 60, 3, aniso=(1.0, 0.0001), seed=80)[0] - 0.5) * 0.14  # per-column wobble
edge_noise2 = (fbm(M, 60, 3, aniso=(1.0, 0.0001), seed=81)[0] - 0.5) * 0.14
lo = 0.2 + edge_noise[None, :]
hi = 0.8 + edge_noise2[None, :]
road_mask = np.clip(np.minimum((yy - lo) / 0.04, (hi - yy) / 0.04), 0, 1)
grass_tex = np.asarray(Image.open(os.path.join(OUT, "grass_ground.png")).resize((M, M)), float)
grass_tex = np.tile(np.asarray(Image.open(os.path.join(OUT, "grass_ground.png")), float), (2, 2, 1))
dirt_tex = np.tile(np.asarray(Image.open(os.path.join(OUT, "dirt_road.png")), float), (2, 2, 1))
soil_tex = np.tile(np.asarray(Image.open(os.path.join(OUT, "soil.png")), float), (2, 2, 1))
# forest-soil transition band just outside road
trans = np.clip(np.minimum((yy - (lo - 0.06)) / 0.04, ((hi + 0.06) - yy) / 0.04), 0, 1)
patch = fbm(M, 30, 2, seed=82)
img = blend(grass_tex, soil_tex, np.clip(trans * 0.85 + (patch > 0.62) * 0.35 * trans, 0, 1))
img = blend(img, dirt_tex, road_mask)
# wheel ruts: two slightly darker bands
for c in (0.42, 0.58):
    rut = np.exp(-((yy - c - edge_noise[None, :] * 0.3) / 0.018) ** 2)
    img = blend(img, img * 0.9, rut * road_mask * 0.5)
save(img, "road_tile_top")

# ---------------------------------------------------------------- foliage clump textures (tileable leafy blobs)
def foliage(name, cols, seed, blob=55, leafy=15):
    big = fbm(N, blob, 2, seed=seed)
    small = fbm(N, leafy, 2, seed=seed + 1)
    v = 0.55 * big + 0.45 * small
    img = ramp(v, cols, steps=5, soft=0.25)
    # scalloped leaf highlights
    hl = pnoise(N, 8, seed=seed + 2)
    img = blend(img, hexc(cols[-1]) * np.ones_like(img), ((hl > 0.7) & (big > 0.45)) * 0.55)
    save(img, name)

foliage("leaves_oak", ["#4a4a30", "#6b6a36", "#8f8740", "#aea24a", "#cfc26a"], 90)
foliage("leaves_pine", ["#21433d", "#30554a", "#456a50", "#5d7a50", "#86986a"], 92, blob=40, leafy=9)
foliage("leaves_bush", ["#2a4a40", "#3a5c46", "#4f7049", "#6e8a4c", "#a0aa52"], 94)

# ---------------------------------------------------------------- broad leaf / blade gradients (UV v: 0 root -> 1 tip; u: 0..1 across)
def leaf(name, base_cols, rib_col, seed):
    S = 256
    v = np.linspace(0, 1, S)[:, None] * np.ones((1, S))
    u = np.ones((S, 1)) * np.linspace(0, 1, S)[None, :]
    n = pnoise(S, 18, seed=seed)
    t = np.clip(0.75 * v + 0.25 * n, 0, 1)
    img = ramp(t, base_cols, steps=4)
    # half-leaf shading (one side darker) + midrib
    img = blend(img, img * 0.8, (u < 0.5) * 0.6)
    img = blend(img, hexc(rib_col) * np.ones_like(img), np.exp(-((u - 0.5) / 0.025) ** 2) * 0.8)
    save(img[::-1], name)  # flip so v=0 (bottom of image in Blender) is the root

leaf("leaf_broad", ["#3f5a2c", "#557a35", "#6b8d40", "#8ca64a", "#b0c25c"], "#c9d47a", 100)
leaf("leaf_bush_card", ["#2c4a40", "#43664a", "#628048", "#8fa050", "#c6c45e"], "#b9bc5c", 101)
leaf("grass_blade", ["#3b5530", "#56713c", "#76904a", "#9aae58", "#c9cc6c"], "#aab862", 102)
leaf("fern", ["#2e4724", "#45632e", "#628436", "#86a443", "#a9bf55"], "#b6c866", 105)
leaf("flower_leaf", ["#3a4a2c", "#4f6236", "#6b7c42", "#93a04e", "#b4bb62"], "#b4bb62", 103)
leaf("seedling_leaf", ["#34461f", "#4e6a2a", "#667a38", "#8aa043", "#a7b552"], "#b8c26a", 104)

# ---------------------------------------------------------------- metals, rope, paint, misc
g = fbm(N, 30, 2, seed=110)
save(ramp(g, ["#3a3634", "#4a4542", "#5c5652", "#6e6863"], steps=3), "iron")
g = fbm(N, 30, 2, seed=111)
save(ramp(g, ["#5e5a57", "#7b7774", "#9a9693", "#bdb9b5"], steps=4), "steel")
g = fbm(N, 30, 2, seed=112)
save(ramp(g, ["#8a6326", "#b0832f", "#cfa042", "#e4bf62"], steps=4), "brass")
g = fbm(N, 40, 2, seed=113)
save(ramp(g, ["#8e4428", "#a5532f", "#b9633a", "#c87548"], steps=4), "terracotta")

# rope: diagonal strands, tile along U
S = 256
yy, xx = np.mgrid[0:S, 0:S] / S
stripes = (np.sin((xx * 8 + yy * 2) * 2 * np.pi) * 0.5 + 0.5)
img = ramp(stripes, ["#6b5636", "#8d744a", "#ad945f", "#c4ab74"], steps=3)
save(img, "rope")

# water: calm blue-green with soft lighter ripple bands (U along flow)
g = fbm(N, 40, 3, aniso=(1.0, 0.35), seed=120)
img = ramp(g, ["#3f7a74", "#4f8c82", "#6aa391", "#8cbca6", "#b6d8c4"], steps=5, soft=0.3)
save(img, "water")

# stream bed: wet pebbles in soil
g = fbm(N, 30, 2, seed=121)
img = ramp(g, ["#52492e", "#655a3a", "#7b6f4a", "#958862"], steps=4)
peb = pnoise(N, 6, seed=122)
img = blend(img, ramp(pnoise(N, 10, seed=123), ["#5a6560", "#7c8a82", "#9aa69c"], steps=3), (peb > 0.62) * 0.9)
save(img, "streambed")

# cream paint for barrier stripes
g = fbm(N, 40, 2, seed=130)
save(ramp(g, ["#a99c86", "#c2b49b", "#d4c7b0", "#e3d8c3"], steps=3), "paint_cream")

# flower petal colours (radial gradient: centre darker)
def petal(name, cols):
    S = 128
    yy, xx = np.mgrid[0:S, 0:S] / S
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2
    img = ramp(np.clip(r, 0, 1), cols, steps=3)
    save(img, name)

petal("petal_cream", ["#e9c66a", "#f1e5d0", "#f7efe0", "#fbf6ec"])
petal("petal_lavender", ["#6c4f9a", "#8b6db8", "#a78ccb", "#c0a5d8"])

# gate shield plaque: gold field with dark chevron (front UV 0..1)
S = 256
im = Image.new("RGB", (S, S), "#c99a35")
d = ImageDraw.Draw(im)
d.rectangle([10, 10, S - 11, S - 11], outline="#7a5520", width=10)
d.polygon([(70, 70), (128, 120), (186, 70), (186, 130), (128, 180), (70, 130)], fill="#2b2420")
im = im.filter(ImageFilter.GaussianBlur(1.2))
im.save(os.path.join(OUT, "plaque.png")); print("wrote plaque")

# shield front: radial-ish vertical planks with seams (planar UV over the disc)
S = 512
base = np.asarray(Image.open(os.path.join(OUT, "wood_mid.png")).resize((S, S)).transpose(Image.Transpose.ROTATE_90), float)
img = base.copy()
xs = np.arange(S)[None, :] * np.ones((S, 1))
for sx in (0.22, 0.42, 0.6, 0.79):
    img = blend(img, hexc("#2a1f19") * np.ones_like(img), np.exp(-((xs / S - sx) / 0.004) ** 2) * 0.95)
# vary plank tones
for i, (a, b) in enumerate([(0, .22), (.22, .42), (.42, .6), (.6, .79), (.79, 1)]):
    m = ((xs / S >= a) & (xs / S < b))[..., None]
    img = np.where(m, img * (0.9 + 0.1 * (i % 2) + 0.05 * (i % 3)), img)
save(img, "shield_planks")

print("done")

# leather (straps, grips)
g = fbm(N, 30, 2, seed=140)
save(ramp(g, ["#3b261a", "#523422", "#6a442c", "#7f5536"], steps=3), "leather")

# warm oak bark
g = fbm(N, 30, 3, aniso=(1.0, 0.18), seed=42)
img = ramp(g, ["#4f3624", "#6b4a30", "#8b6442", "#a57a52"], steps=4)
fiss = fbm(N, 8, 2, aniso=(1.0, 0.1), seed=43)
img = blend(img, hexc("#33241a") * np.ones_like(img), (fiss > 0.68) * 0.8)
save(img, "bark_oak")

# pine bark stays dark
g = fbm(N, 30, 3, aniso=(1.0, 0.18), seed=44)
img = ramp(g, ["#2a211b", "#3f3027", "#5a4434", "#755a42"], steps=4)
save(img, "bark_dark")

# boulder: big rounded plates (voronoi cells) with dark seams
S = 512
rng2 = np.random.default_rng(9)
pts = rng2.random((26, 2)) * S
yy, xx = np.mgrid[0:S, 0:S]
d1 = np.full((S, S), 1e9); d2 = np.full((S, S), 1e9); idx = np.zeros((S, S), int)
for k, (px, py) in enumerate(pts):
    for ox in (-S, 0, S):
        for oy in (-S, 0, S):
            d = np.hypot(xx - px - ox, yy - py - oy)
            m = d < d1
            d2 = np.where(m, d1, np.minimum(d2, d))
            idx = np.where(m, k, idx)
            d1 = np.where(m, d, d1)
tone = rng2.random(26)[idx]
edge = np.clip((d2 - d1) / 10, 0, 1)
v = np.clip(0.25 + 0.55 * tone + 0.25 * (1 - d1 / (d1 + d2 + 1e-6)) - 0.1, 0, 1)
img = ramp(v, ["#55595b", "#6b6f70", "#868884", "#a3a39b", "#bdbcb0"], steps=4)
img = blend(hexc("#2e3233") * np.ones_like(img), img, edge)
save(img, "stone_plates")
