"""Seamless painted cobblestone texture for the settlement square: python gen_cobble.py <out.png>"""
import sys
import numpy as np
from PIL import Image, ImageFilter

N = 512
rng = np.random.default_rng(5)
# jittered grid of stone centres (periodic)
g = 9
pts = []
for i in range(g):
    for j in range(g):
        pts.append(((i + .5 + rng.uniform(-.32, .32)) * N / g, (j + .5 + rng.uniform(-.32, .32)) * N / g))
pts = np.array(pts)
yy, xx = np.mgrid[0:N, 0:N].astype(float)
d1 = np.full((N, N), 1e9); d2 = np.full((N, N), 1e9); idx = np.zeros((N, N), int)
for k, (px, py) in enumerate(pts):
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d = np.hypot(xx - px - ox, yy - py - oy)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            idx = np.where(closer, k, idx)
            d1 = np.where(closer, d, d1)
edge = d2 - d1
tone = rng.uniform(0, 1, len(pts))[idx]
base = np.array([150, 140, 126], float)
light = np.array([196, 186, 168], float)
col = base[None, None, :] * (1 - tone[..., None]) + light[None, None, :] * tone[..., None]
shade = np.clip(edge / 14.0, 0, 1)[..., None]
col = col * (0.72 + 0.28 * shade)
mortar = np.array([88, 80, 70], float)
m = (edge < 3.5)[..., None]
col = np.where(m, mortar, col)
img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).filter(ImageFilter.SMOOTH)
img.save(sys.argv[1] if len(sys.argv) > 1 else "cobble.png")
print("ok")
