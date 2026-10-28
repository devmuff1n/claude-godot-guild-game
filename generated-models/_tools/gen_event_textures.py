"""Painted textures for the route-event dioramas (cloth, skin, hair, roof tiles...).
Same look as gen_textures.py: periodic noise, posterised palettes. Usage: python gen_event_textures.py <out_dir>"""
import os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(11)
N = 256


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


def cloth(name, cols, seed, weave=0.06):
    g = fbm(N, 30, 3, seed=seed)
    img = ramp(g, cols, steps=3)
    yy, xx = np.mgrid[0:N, 0:N]
    w = ((np.sin(xx * np.pi / 2) * np.sin(yy * np.pi / 2)) > 0) * weave  # fine weave
    img = img * (1 - w[..., None])
    save(img, name)


def flat(name, cols, seed, scale=40):
    save(ramp(fbm(N, scale, 2, seed=seed), cols, steps=3), name)


cloth("cloth_cream", ["#c9b291", "#dcc7a5", "#e9d8ba", "#f3e6cc"], 1)
cloth("cloth_brown", ["#4a3324", "#5a3f2b", "#6a4b33", "#7a573b"], 2)
cloth("cloth_green", ["#334a2c", "#40593a", "#4e6a43", "#5d7a4c"], 3)
cloth("cloth_red", ["#6a2420", "#80302a", "#943c32", "#a84a3c"], 4)
cloth("cloth_blue", ["#3f5f8f", "#4c6ea0", "#5b7eb0", "#7092c0"], 5)
cloth("cloth_purple", ["#4a3058", "#5a3a6a", "#6c4a7c", "#80608e"], 6)
cloth("bandage", ["#d8d0c2", "#e6dfd2", "#f1ece2", "#faf7f0"], 7, weave=0.03)
cloth("burlap", ["#a88a62", "#b99a70", "#c9ab80", "#d8bc92"], 8, weave=0.12)
flat("skin", ["#e2ad8a", "#ecbd9b", "#f3cbab", "#f8d7bb"], 10, 60)
flat("leather_dark", ["#2f2019", "#3c2a20", "#4a3427", "#5a412f"], 11)
flat("bone", ["#cdbf9f", "#ddd1b4", "#e9e0c8", "#f3ecda"], 12)
flat("bread", ["#9a5a26", "#b56f30", "#c9853c", "#dca15a"], 13)
flat("smoke", ["#cfcdc8", "#dddbd6", "#e8e6e2", "#f3f2ee"], 14, 60)
flat("mud_dark", ["#2b2016", "#33261a", "#3b2c1e", "#443322"], 15)
flat("glass_blue", ["#3d6fa8", "#5288c0", "#6ea2d4", "#9cc4e6"], 16)
flat("glass_green", ["#4d6b38", "#5f8044", "#759752", "#93b06c"], 17)
flat("glass_red", ["#7a2b36", "#933a44", "#ac4c54", "#c66a6c"], 18)
flat("cork", ["#8a6844", "#9c7850", "#ae8a5e", "#c09c6e"], 19)
flat("lantern_glow", ["#ffc35a", "#ffd075", "#ffdc90", "#ffe8b0"], 20)
flat("eye", ["#17141a", "#1d1a20", "#231f27", "#2a2530"], 21)
flat("eye_white", ["#f4f1ea", "#f7f5ef", "#faf8f4", "#ffffff"], 22)
flat("wound", ["#4a1414", "#5e1a1a", "#721f1f", "#862a26"], 23)

# hair: strands along U
for name, cols, seed in (("hair_blond", ["#9c845f", "#b49a72", "#c7af86", "#dac59e"], 30),
                         ("hair_dark", ["#231d2c", "#2e2638", "#3a3046", "#4a3e58"], 31),
                         ("hair_brown", ["#3a2618", "#4a3120", "#5b3d28", "#6c4a32"], 32)):
    g = fbm(N, 26, 3, aniso=(0.12, 1.0), seed=seed)
    save(ramp(g, cols, steps=4), name)

# blue roof tiles: staggered rows, U along the row, V down the slope (1 tile = 1/4 of the image)
yy, xx = np.mgrid[0:N, 0:N]
row = yy // 64
off = (row % 2) * 32
col = ((xx + off) % 64)
base = ramp(fbm(N, 30, 2, seed=40), ["#3c5a8c", "#4a6aa0", "#5878b0", "#6a8ac0"], steps=3)
shade = (yy % 64) / 64.0
img = base * (1.05 - 0.25 * shade[..., None])
gap = ((col < 3) | ((yy % 64) > 58))
img = blend(img, hexc("#22304a") * np.ones_like(img), gap * 0.9)
save(img, "roof_blue")
