import sys
from PIL import Image
out, files = sys.argv[1], sys.argv[2:]
n = len(files); cols = min(n, 3); rows = (n + cols - 1) // cols; c = 560
sh = Image.new("RGB", (cols * c, rows * c), "white")
for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA"); im.thumbnail((c, c))
    bg = Image.new("RGBA", im.size, "white"); bg.alpha_composite(im)
    sh.paste(bg.convert("RGB"), ((i % cols) * c, (i // cols) * c))
sh.save(out, quality=88)
