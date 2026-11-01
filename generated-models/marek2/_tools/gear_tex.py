# Gear texture (1024x512) for sword + shield, colours sampled from Marek's atlas.
# Left 512x512: heater shield face (blue field, gold rim, gold fleur-de-lis cut from the tabard emblem).
# Right 512x512: 8 vertical swatch bands: 0 steel gradient, 1 steel dark, 2 gold, 3 gold dark, 4 leather, 5 blue, 6 red, 7 back wood.
import os, numpy as np
from PIL import Image, ImageFilter
W = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '_work')
A = np.asarray(Image.open(os.path.join(W, 'marek_atlas.png')).convert('RGB')).astype(np.float32)
crop = A[1755:1900, 38:130]             # fleur on red (PIL coords, top-left origin)
r, g, b = crop[..., 0], crop[..., 1], crop[..., 2]
gold_m = (r > 170) & (g > 110) & (b < 120)
red_m = (r > 110) & (g < 70)
GOLD = np.median(crop[gold_m], 0); RED = np.median(crop[red_m], 0)
# armour blue: bluish pixels of the whole atlas
fl = A.reshape(-1, 3); bl = fl[(fl[:, 2] > fl[:, 0]+25) & (fl[:, 2] > 90)]
BLUE = np.median(bl, 0)
br = fl[(fl[:, 0] > fl[:, 2]+25) & (fl[:, 1] > fl[:, 2]+5) & (fl[:, 0] < 120) & (fl[:, 0] > 60)]
LEATHER = np.median(br, 0)
print('COLS', GOLD, RED, BLUE, LEATHER)
T = np.zeros((512, 1024, 3), np.float32)
# --- shield face: normalised x,y in [-1,1] (y up)
ys, xs = np.mgrid[0:512, 0:512]
X = (xs+0.5)/256-1; Y = 1-(ys+0.5)/256
def half_w(y):
    t = np.clip((0.1-y)/1.1, 0, 1)
    return np.where(y > 0.1, 1.0, 1-t**2.2)
inside = (Y <= 1) & (Y >= -1) & (np.abs(X) <= half_w(Y))
# distance-ish to the border: shrink test
def inside_s(s):
    yy = (Y-0.03)/s+0.03; xx = X/s
    return (yy <= 1) & (yy >= -1) & (np.abs(xx) <= half_w(yy))
inner = inside_s(0.86)
line = inside_s(0.80) & ~inside_s(0.77)
face = np.where(inside[..., None], GOLD, GOLD)
face = np.where(inner[..., None], BLUE, face)
face = np.where(line[..., None], GOLD*0.92, face)
# subtle vertical shading
face = face*(0.92+0.08*np.clip(Y, -1, 1)[..., None])
# fleur: scale crop gold mask into the centre
from PIL import ImageDraw
fm = Image.fromarray((gold_m*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
seed = (fm.width//2, fm.height//2)
while fm.getpixel(seed) < 128: seed = (seed[0], seed[1]+1)
ImageDraw.floodfill(fm, seed, 77)   # keep only the fleur (component through the centre)
fm = fm.point(lambda v: 255 if v == 77 else 0)
bb = fm.getbbox(); fm = fm.crop(bb)
H = 250; Wd = int(fm.width*H/fm.height)
fm = np.asarray(fm.resize((Wd, H), Image.LANCZOS)).astype(np.float32)/255
y0 = 256-H//2-20; x0 = 256-Wd//2
a = fm[..., None]
face[y0:y0+H, x0:x0+Wd] = face[y0:y0+H, x0:x0+Wd]*(1-a)+GOLD*a
T[:, :512] = face
# --- swatches
cols = [None, np.array([88, 96, 108.]), GOLD, GOLD*0.7, LEATHER, BLUE, RED, LEATHER*0.6]
for i, c in enumerate(cols):
    x = 512+i*64
    if c is None:
        grad = np.linspace(0, 1, 64)[None, :, None]
        T[:, x:x+64] = np.array([110, 118, 130.])*(1-grad)+np.array([222, 228, 236.])*grad
    else:
        T[:, x:x+64] = c
Image.fromarray(np.clip(T, 0, 255).astype(np.uint8)).save(os.path.join(W, 'marek_gear.png'))
print('GEAR ok')
