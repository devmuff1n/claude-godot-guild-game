# Aiden staff swatch texture 256x256 (8 vertical bands of 32 px), colours sampled from Aiden's atlas:
# 0 ivory wood (u gradient = grain), 1 brown wood (boots), 2 gold, 3 gold dark, 4 robe white, 5 orb amber (dark->bright),
# 6 orb core, 7 teal wrap.
import os, numpy as np
from PIL import Image
W = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '_work')
A = np.asarray(Image.open(os.path.join(W, 'aiden_atlas.png')).convert('RGB')).astype(np.float32).reshape(-1, 3)
r, g, b = A[:, 0], A[:, 1], A[:, 2]
def med(m, fb):
    return np.median(A[m], 0) if m.sum() > 50 else np.array(fb, np.float32)
GOLD = med((r > 200) & (g > 150) & (g < 215) & (b < 90), [235, 180, 50])
TEAL = med((r < 60) & (g > 70) & (g < 130) & (b > 70) & (b < 130) & (g - r > 30), [20, 95, 95])
BROWN = med((r > 100) & (r < 170) & (g > 50) & (g < 100) & (b < 70) & (r - g > 40), [140, 75, 45])
WHITE = med((r > 225) & (g > 225) & (b > 215), [240, 240, 235])
print('COLS gold', GOLD, 'teal', TEAL, 'brown', BROWN, 'white', WHITE)
IVORY = WHITE*0.82+GOLD*0.18
T = np.zeros((256, 256, 3), np.float32)
grad = np.linspace(0, 1, 32)[None, :, None]
T[:, 0:32] = IVORY*0.86*(1-grad)+IVORY*1.0*grad
T[:, 32:64] = BROWN*0.9
T[:, 64:96] = GOLD
T[:, 96:128] = GOLD*0.68
T[:, 128:160] = WHITE
T[:, 160:192] = np.array([230, 120, 20.])*(1-grad)+np.array([255, 225, 120.])*grad
T[:, 192:224] = np.array([255, 245, 200.])
T[:, 224:256] = TEAL
Image.fromarray(np.clip(T, 0, 255).astype(np.uint8)).save(os.path.join(W, 'aiden_staff.png'))
