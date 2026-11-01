# -*- coding: utf-8 -*-
"""Textures for the prologue kit (build_prologue_kit.py).

Tileable references from ChatGPT (Desktop/prologue_refs, files 26-31) are downscaled to 512 px;
small flat/noisy colour textures for glow, bark and cloth are painted procedurally.
Usage: python gen_prologue_textures.py
"""
import os, random
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "_textures")
REFS = os.path.join(os.path.expanduser("~"), "Desktop", "prologue_refs")

FROM_REFS = {
    "cave_rock_ref": "26_tex_cave_rock.png",
    "cave_floor_ref": "27_tex_cave_floor.png",
    "ash_ground": "28_tex_ash_ground.png",
    "forest_floor_cursed": "29_tex_cursed_forest_floor.png",
    "thatch_ref": "30_tex_thatch.png",
    "burnt_wood": "31_tex_burnt_wood.png",
}

# name: (base colour, noise amount 0..1, speckle colour or None)
PAINT = {
    "rune_glow": ((255, 60, 30), 0.08, (255, 170, 90)),
    "ember": ((255, 120, 30), 0.15, (255, 220, 120)),
    "mushroom_glow": ((70, 170, 255), 0.1, (190, 235, 255)),
    "obelisk_glow": ((230, 50, 200), 0.1, (255, 150, 240)),
    "obelisk_stone": ((38, 34, 44), 0.25, (70, 62, 80)),
    "bark_cursed": ((58, 44, 46), 0.35, (34, 26, 30)),
    "bark_burnt": ((30, 24, 22), 0.35, (60, 40, 30)),
    "leaves_sick": ((150, 120, 52), 0.3, (110, 86, 40)),
    "needles_dead": ((52, 66, 46), 0.35, (90, 78, 50)),
    "moss_grey": ((118, 122, 98), 0.3, (90, 96, 76)),
    "thorn_stem": ((62, 30, 58), 0.25, (40, 18, 38)),
    "berry_red": ((170, 20, 30), 0.1, (230, 80, 80)),
    "canvas_dirty": ((150, 132, 100), 0.25, (118, 100, 74)),
    "canvas_patch": ((120, 96, 70), 0.25, (90, 70, 50)),
    "ribbon_red": ((168, 30, 32), 0.15, (120, 18, 20)),
    "straw_dummy": ((206, 168, 92), 0.3, (160, 120, 60)),
    "limestone": ((176, 162, 138), 0.25, (140, 128, 108)),
    "target_paint": ((178, 40, 36), 0.1, (230, 220, 200)),
    "mask_wood": ((150, 110, 70), 0.2, (110, 80, 50)),
}


def paint(name, base, amt, speck, size=256, seed=0):
    rnd = random.Random(hash(name) & 0xffff)
    im = Image.new("RGB", (size, size), base)
    px = im.load()
    for y in range(size):
        for x in range(size):
            k = 1 + (rnd.random() - .5) * amt
            r, g, b = base
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))
    if speck:
        for _ in range(size * size // 60):
            x, y = rnd.randrange(size), rnd.randrange(size)
            for dx in range(rnd.randint(1, 3)):
                px[(x + dx) % size, y] = speck
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in FROM_REFS.items():
        src = os.path.join(REFS, fn)
        if not os.path.exists(src):
            print("missing", src)
            continue
        im = Image.open(src).convert("RGB").resize((512, 512), Image.LANCZOS)
        im.save(os.path.join(OUT, name + ".png"))
    for name, (base, amt, speck) in PAINT.items():
        paint(name, base, amt, speck)
    print("textures:", len(FROM_REFS) + len(PAINT))


if __name__ == "__main__":
    main()
