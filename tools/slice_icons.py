"""Режет листы иконок из imagegen (assets/ui/source/) на отдельные PNG 128×128 в assets/ui/icons/.
Запуск: python tools/slice_icons.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "ui", "source")
OUT = os.path.join(ROOT, "assets", "ui", "icons")
os.makedirs(OUT, exist_ok=True)

SHEETS = {
    "item_icons.png": (4, 4, [
        "sword", "mace", "dagger", "bow",
        "staff_amber", "staff_amethyst", "shield_wood", "shield_iron",
        "hood", "tunic", "gloves", "belt",
        "boots", "ring", "amulet", "chainmail",
    ]),
    "cons_icons.png": (4, 3, [
        "potion_hp", "potion_mp", "kit", "apple",
        "berries", "wine", "bread", "tea",
        "book", "material", "purse", "gift",
    ]),
}
SIZE = 128

for fname, (cols, rows, names) in SHEETS.items():
    path = os.path.join(SRC, fname)
    if not os.path.exists(path):
        continue
    sheet = Image.open(path).convert("RGBA")
    cw, ch = sheet.width / cols, sheet.height / rows
    for i, name in enumerate(names):
        cx, cy = i % cols, i // cols
        cell = sheet.crop((int(cx * cw), int(cy * ch), int((cx + 1) * cw), int((cy + 1) * ch)))
        bb = cell.split()[3].point(lambda v: 255 if v > 24 else 0).getbbox()
        if bb is None:
            continue
        cell = cell.crop(bb)
        side = int(max(cell.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
        sq.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
        print("icon", name)
