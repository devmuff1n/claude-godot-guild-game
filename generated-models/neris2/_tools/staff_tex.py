# Staff swatch texture 256x256 (8 vertical bands of 32 px), colours sampled from Neris's atlas:
# 0 wood light (u gradient = grain), 1 wood dark, 2 gold, 3 gold dark, 4 robe crimson, 5 crystal (dark->bright),
# 6 crystal core, 7 wrap leather.
import os, numpy as np
from PIL import Image
W = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '_work')
A = np.asarray(Image.open(os.path.join(W, 'neris_atlas.png')).convert('RGB')).astype(np.float32).reshape(-1, 3)
r, g, b = A[:, 0], A[:, 1], A[:, 2]
GOLD = np.median(A[(r > 190) & (g > 140) & (b < 90)], 0)
HORN = np.median(A[(r > 70) & (r < 140) & (r - g > 20) & (r - g < 55) & (g - b > 8) & (g > 45)], 0)
ROBE = np.median(A[(r > 85) & (r < 115) & (g < 45) & (b > 45) & (b < 70)], 0)
RED = np.median(A[(r > 170) & (g < 50) & (b < 60)], 0) if ((r > 170) & (g < 50) & (b < 60)).sum() > 20 else np.array([200, 30, 40.])
print('COLS gold', GOLD, 'horn', HORN, 'robe', ROBE, 'red', RED)
T = np.zeros((256, 256, 3), np.float32)
grad = np.linspace(0, 1, 32)[None, :, None]
T[:, 0:32] = HORN*0.95*(1-grad)+HORN*1.25*grad
T[:, 32:64] = HORN*0.62
T[:, 64:96] = GOLD
T[:, 96:128] = GOLD*0.68
T[:, 128:160] = ROBE
T[:, 160:192] = RED*0.45*(1-grad)+np.array([255, 120, 150.])*grad
T[:, 192:224] = np.array([255, 205, 220.])
T[:, 224:256] = HORN*0.45+ROBE*0.25
Image.fromarray(np.clip(T, 0, 255).astype(np.uint8)).save(os.path.join(W, 'neris_staff.png'))
