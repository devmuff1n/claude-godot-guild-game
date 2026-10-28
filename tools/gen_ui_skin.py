"""Генератор текстур оформления интерфейса (assets/ui/*.png) и перевод темы на StyleBoxTexture.

Запуск: python tools/gen_ui_skin.py
- рисует рамки панелей (фактура, двойная золотая кайма, уголки, запечённая тень);
- для кнопок берёт цвета из прежних StyleBoxFlat темы и рисует объёмный вариант (градиент, блик, фаска);
- заменяет нужные StyleBoxFlat в assets/theme/guild_theme.tres на StyleBoxTexture с теми же отступами.
Если положить в assets/ui/ свою картинку с тем же именем (например, из imagegen), тема подхватит её.
Повторный запуск берёт исходные StyleBoxFlat из tools/guild_theme.flat.tres (копия до первой замены).
"""
import os, re, random, shutil
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")
THEME = os.path.join(ROOT, "assets", "theme", "guild_theme.tres")
FLAT = os.path.join(ROOT, "tools", "guild_theme.flat.tres")
SS = 4  # суперсэмплинг
os.makedirs(OUT, exist_ok=True)

GOLD = (214, 168, 74)
GOLD_HI = (255, 222, 140)
GOLD_DK = (120, 90, 42)


def c255(c, a=255):
    return tuple(int(max(0, min(1, v)) * 255) for v in c[:3]) + (int(c[3] * 255) if len(c) > 3 else a,)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def shade(c, k):
    """k>0 светлее, k<0 темнее"""
    rgb = c[:3]
    if k >= 0:
        rgb = mix(rgb, (255, 255, 255), k)
    else:
        rgb = mix(rgb, (0, 0, 0), -k)
    return tuple(rgb) + tuple(c[3:])


def rrect_mask(w, h, r, inset=0):
    m = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([inset * SS, inset * SS, (w - inset) * SS - 1, (h - inset) * SS - 1], radius=max(0, r - inset) * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def vgrad(w, h, top, bot):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        c = mix(top, bot, y / max(1, h - 1))
        for x in range(w):
            px[x, y] = c
    return im


def grain(im, amt, seed=7):
    rnd = random.Random(seed)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            n = rnd.uniform(-amt, amt)
            px[x, y] = (int(max(0, min(255, r + n))), int(max(0, min(255, g + n * 0.9))), int(max(0, min(255, b + n * 0.75))), a)
    return im


def layer_rect(w, h, r, inset, color, width=1):
    """кольцо-рамка толщиной width на отступе inset"""
    outer = rrect_mask(w, h, r, inset)
    inner = rrect_mask(w, h, r, inset + width)
    ring = Image.eval(Image.merge("LA", (outer, inner)).split()[0], lambda v: v)
    from PIL import ImageChops
    ring = ImageChops.subtract(outer, inner)
    lay = Image.new("RGBA", (w, h), color[:3] + (0,))
    a = ring.point(lambda v: v * (color[3] if len(color) > 3 else 255) // 255)
    lay.putalpha(a)
    return lay


def ornament_corners(w, h, inset, length, color, diamond=4, thick=2):
    lay = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    t = thick * SS
    for (cx, cy, sx, sy) in [(inset, inset, 1, 1), (w - inset, inset, -1, 1), (inset, h - inset, 1, -1), (w - inset, h - inset, -1, -1)]:
        X, Y = cx * SS, cy * SS
        L = length * SS
        # уголок-скобка
        d.line([(X, Y), (X + sx * L, Y)], fill=color, width=t)
        d.line([(X, Y), (X, Y + sy * L)], fill=color, width=t)
        # засечки на концах
        d.line([(X + sx * L, Y - sy * 2 * SS), (X + sx * L, Y + sy * 3 * SS)], fill=color, width=max(1, t // 2) + SS)
        d.line([(X - sx * 2 * SS, Y + sy * L), (X + sx * 3 * SS, Y + sy * L)], fill=color, width=max(1, t // 2) + SS)
        # ромб в углу
        D = diamond * SS
        DX, DY = X + sx * 7 * SS, Y + sy * 7 * SS
        # второй, короткий уголок внутри
        L2 = int(L * 0.45)
        X2, Y2 = X + sx * 4 * SS, Y + sy * 4 * SS
        d.line([(X2 + sx * 8 * SS, Y2), (X2 + sx * (8 * SS + L2), Y2)], fill=color[:3] + (150,), width=max(SS, t // 2))
        d.line([(X2, Y2 + sy * 8 * SS), (X2, Y2 + sy * (8 * SS + L2))], fill=color[:3] + (150,), width=max(SS, t // 2))
        d.polygon([(DX, DY - D), (DX + D, DY), (DX, DY + D), (DX - D, DY)], fill=GOLD_HI + (255,))
    return lay.resize((w, h), Image.LANCZOS)


def shadow_layer(w, h, r, pad, alpha, blur):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([pad, pad + 2, w - pad - 1, h - pad - 1 + 2], radius=r, fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    lay.putalpha(m)
    return lay


def panel(name, size, pad, r, bg_top, bg_bot, bg_alpha, border, inner_line, corners, shadow_a, grain_amt, corner_len=22):
    """size — размер самой панели без тени; pad — поле под тень вокруг"""
    W = size + 2 * pad
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    if shadow_a:
        base = Image.alpha_composite(base, shadow_layer(W, W, r, pad, shadow_a, pad * 0.45))
    # центр тайлится, поэтому фон без градиента (иначе полосы)
    body = vgrad(size, size, mix(bg_top, bg_bot, 0.5) + (bg_alpha,), mix(bg_top, bg_bot, 0.5) + (bg_alpha,))
    grain(body, grain_amt)
    # лёгкая виньетка к краям
    vig = Image.new("L", (size, size), 0)
    ImageDraw.Draw(vig).rectangle([0, 0, size - 1, size - 1], outline=60, width=6)
    vig = vig.filter(ImageFilter.GaussianBlur(5))
    dark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dark.putalpha(vig)
    body = Image.alpha_composite(body, dark)
    body.putalpha(Image.eval(Image.merge("L", [rrect_mask(size, size, r)]), lambda v: v * bg_alpha // 255))
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    lay.paste(body, (pad, pad))
    base = Image.alpha_composite(base, lay)
    deco = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    deco = Image.alpha_composite(deco, layer_rect(size, size, r, 0, (10, 7, 4, 230), 1))
    for (ins, col, wd) in border:
        deco = Image.alpha_composite(deco, layer_rect(size, size, r, ins, col, wd))
    # блик сверху
    hl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(r + 2, 2), (size - r - 3, 2)], fill=(255, 230, 170, 40), width=1)
    deco = Image.alpha_composite(deco, hl)
    if inner_line:
        deco = Image.alpha_composite(deco, layer_rect(size, size, max(0, r - inner_line[0]), inner_line[0], inner_line[1], 1))
    if corners:
        deco = Image.alpha_composite(deco, ornament_corners(size, size, corners, corner_len, GOLD + (255,)))
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    lay.paste(deco, (pad, pad))
    base = Image.alpha_composite(base, lay)
    base.save(os.path.join(OUT, name + ".png"))


def button(name, bg, bd, r, bw, glow=None, w=40, h=40):
    pad = 3
    W, H = w + 2 * pad, h + 2 * pad
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if bg[3] > 0:
        base = Image.alpha_composite(base, shadow_layer(W, H, r, pad, 110 if bg[3] > 200 else 50, 1.6))
    if glow:
        g = Image.new("L", (W, H), 0)
        ImageDraw.Draw(g).rounded_rectangle([pad, pad, W - pad - 1, H - pad - 1], radius=r, fill=glow[3])
        g = g.filter(ImageFilter.GaussianBlur(2.2))
        gl = Image.new("RGBA", (W, H), glow[:3] + (0,))
        gl.putalpha(g)
        base = Image.alpha_composite(base, gl)
    body = vgrad(w, h, shade(bg, 0.10), shade(bg, -0.22))
    body.putalpha(Image.eval(rrect_mask(w, h, r), lambda v: v * bg[3] // 255))
    deco = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    deco = Image.alpha_composite(deco, body)
    # внутренний блик сверху и тень снизу
    hl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.line([(r, bw), (w - r - 1, bw)], fill=shade(bd, 0.25)[:3] + (int(110 * bg[3] / 255),), width=1)
    hd.line([(r, h - bw - 1), (w - r - 1, h - bw - 1)], fill=(0, 0, 0, int(90 * bg[3] / 255)), width=1)
    deco = Image.alpha_composite(deco, hl)
    if bw > 0 and bd[3] > 0:
        # кайма с вертикальным переходом: сверху светлее
        ring = layer_rect(w, h, r, 0, (255, 255, 255, 255), bw)
        grad = vgrad(w, h, shade(bd, 0.18), shade(bd, -0.25))
        grad.putalpha(Image.eval(ring.split()[3], lambda v: v * bd[3] // 255))
        deco = Image.alpha_composite(deco, grad)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lay.paste(deco, (pad, pad))
    base = Image.alpha_composite(base, lay)
    base.save(os.path.join(OUT, name + ".png"))
    return pad


# ---------- разбор темы ----------
if not os.path.exists(FLAT):
    shutil.copy(THEME, FLAT)
src = open(FLAT, encoding="utf-8").read()


def block(sid):
    m = re.search(r'\[sub_resource type="StyleBoxFlat" id="%s"\]\n(.*?)(?=\n\n|\n\[)' % sid, src, re.S)
    return m.group(1) if m else None


def props(text):
    p = {}
    for line in text.splitlines():
        k, _, v = line.partition(" = ")
        p[k.strip()] = v.strip()
    return p


def col(v):
    if not v:
        return None
    nums = [float(x) for x in re.findall(r"[-\d.]+", v)]
    return c255(nums)


def styles_of(var):
    """{состояние: id} для вариации"""
    out = {}
    for m in re.finditer(r'^%s/styles/(\w+) = SubResource\("(StyleBoxFlat_\d+)"\)' % re.escape(var), src, re.M):
        out[m.group(1)] = m.group(2)
    return out


replacements = {}  # id -> текст нового sub_resource
textures = {}  # имя -> путь


def tex_box(sid, tex, margin, pad, p, tile=False, extra=""):
    lines = ['[sub_resource type="StyleBoxTexture" id="%s"]' % sid]
    for side in ("left", "top", "right", "bottom"):
        k = "content_margin_" + side
        if k in p:
            lines.append("%s = %s" % (k, p[k]))
    lines.append('texture = ExtResource("ui_%s")' % tex)
    for side in ("left", "top", "right", "bottom"):
        lines.append("texture_margin_%s = %.1f" % (side, margin + pad))
    for side in ("left", "top", "right", "bottom"):
        lines.append("expand_margin_%s = %.1f" % (side, pad))
    if tile:
        lines.append("axis_stretch_horizontal = 1")
        lines.append("axis_stretch_vertical = 1")
    if extra:
        lines.append(extra)
    replacements[sid] = "\n".join(lines)
    textures[tex] = "res://assets/ui/%s.png" % tex


# Кнопки: объёмный вариант прежних цветов
BUTTON_VARS = ["Button", "ButtonSmall", "ButtonBig", "ButtonSelected", "ButtonPrimary", "ButtonChip", "ButtonList", "ButtonIcon", "ButtonCommand", "OptionButton"]
done = set()
for var in BUTTON_VARS:
    for state, sid in styles_of(var).items():
        if sid in done:
            continue
        b = block(sid)
        if b is None:
            continue
        p = props(b)
        bg = col(p.get("bg_color", "Color(0,0,0,0)"))
        bd = col(p.get("border_color", "Color(0,0,0,0)"))
        bw = int(p.get("border_width_top", "0"))
        r = int(p.get("corner_radius_top_left", "0"))
        glow = None
        if "shadow_color" in p and var == "ButtonPrimary" and state in ("hover", "hover_pressed"):
            glow = col(p["shadow_color"])
            glow = glow[:3] + (120,)
        name = "btn_%s_%s" % (var.lower(), state)
        pad = button(name, bg, bd, r, bw, glow)
        tex_box(sid, name, max(r, bw) + 3, pad, p)
        done.add(sid)

# Панели
PANELS = {
    # вариация: (имя, размер, тень, радиус, верх, низ, альфа, каймы, внутренняя линия, уголки, тень-альфа, зерно)
    "PanelDark": ("panel_dark", 96, 12, 7, (30, 24, 18), (19, 15, 11), 242,
                  [(1, (150, 116, 58, 255), 1)], (5, (214, 168, 74, 70)), 3, 150, 5),
    "PanelModal": ("panel_modal", 112, 20, 8, (34, 27, 19), (20, 16, 11), 250,
                   [(1, (190, 148, 66, 255), 2)], (6, (214, 168, 74, 110)), 4, 190, 5),
    "PanelDialog": ("panel_dialog", 112, 20, 8, (32, 25, 18), (19, 15, 11), 246,
                    [(1, (190, 148, 66, 255), 2)], (6, (214, 168, 74, 110)), 4, 170, 5),
    "PanelHud": ("panel_hud", 64, 8, 6, (22, 18, 14), (13, 10, 8), 214,
                 [(1, (120, 94, 52, 230), 1)], None, 0, 110, 3),
    "PanelTracker": ("panel_tracker", 64, 6, 6, (14, 11, 9), (10, 8, 6), 175,
                     [(1, (110, 86, 48, 120), 1)], None, 0, 0, 2),
    "TooltipPanel": ("panel_tooltip", 64, 8, 5, (24, 19, 14), (16, 12, 9), 250,
                     [(1, (170, 132, 62, 255), 1)], None, 0, 140, 3),
    "PanelToast": ("panel_toast", 64, 8, 6, (32, 25, 16), (22, 17, 11), 248,
                   [(1, (214, 168, 74, 255), 1)], None, 0, 140, 3),
}
for var, a in PANELS.items():
    st = styles_of(var).get("panel")
    if not st:
        continue
    b = block(st)
    p = props(b)
    name, size, pad, r, top, bot, alpha, border, inner, corners, sh, gr = a
    panel(name, size, pad, r, top, bot, alpha, border, inner, corners, sh, gr)
    margin = max(r, (corners + 22 + 8) if corners else 0, (inner[0] + 2) if inner else 0)
    tex_box(st, name, margin, pad, p, tile=True)

# Верхняя полоса экранов: тёмный градиент и золотая кромка снизу
def topbar(name, h=64, w=32):
    im = vgrad(w, h, (20, 16, 12, 246), (9, 7, 5, 240))
    grain(im, 3, seed=11)
    d = ImageDraw.Draw(im)
    d.line([(0, h - 4), (w, h - 4)], fill=(0, 0, 0, 200), width=1)
    d.line([(0, h - 3), (w, h - 3)], fill=(150, 116, 58, 255), width=1)
    d.line([(0, h - 2), (w, h - 2)], fill=(214, 168, 74, 255), width=1)
    d.line([(0, h - 1), (w, h - 1)], fill=(60, 44, 20, 200), width=1)
    im.save(os.path.join(OUT, name + ".png"))


st = styles_of("PanelTop").get("panel")
if st:
    p = props(block(st))
    topbar("panel_top")
    lines = ['[sub_resource type="StyleBoxTexture" id="%s"]' % st]
    for side in ("left", "top", "right", "bottom"):
        k = "content_margin_" + side
        if k in p:
            lines.append("%s = %s" % (k, p[k]))
    lines += ['texture = ExtResource("ui_panel_top")', "texture_margin_left = 4.0", "texture_margin_right = 4.0", "texture_margin_top = 4.0", "texture_margin_bottom = 6.0", "axis_stretch_horizontal = 1"]
    replacements[st] = "\n".join(lines)
    textures["panel_top"] = "res://assets/ui/panel_top.png"

# Врезки (карточки внутри панелей): утопленные, с фаской
def inset(name, bg, bd, r, alpha=255):
    w = h = 48
    im = vgrad(w, h, shade(bg, -0.18), shade(bg, 0.04))
    grain(im, 3, seed=3)
    im.putalpha(Image.eval(rrect_mask(w, h, r), lambda v: v * alpha // 255))
    # внутренняя тень сверху
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.line([(r, 1), (w - r - 1, 1)], fill=(0, 0, 0, 120), width=2)
    sh = Image.alpha_composite(im, sh)
    ring_dark = layer_rect(w, h, r, 0, bd, 1)
    out = Image.alpha_composite(sh, ring_dark)
    # светлая фаска снизу
    hl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(r, h - 1), (w - r - 1, h - 1)], fill=shade(bd, 0.3)[:3] + (90,), width=1)
    out = Image.alpha_composite(out, hl)
    out.save(os.path.join(OUT, name + ".png"))


for var, name in [("PanelInset", "inset"), ("PanelInsetLocked", "inset_locked"), ("PanelChosen", "inset_chosen"), ("PanelCard", "card"), ("PanelCardActive", "card_active"), ("PanelPill", "pill")]:
    st = styles_of(var).get("panel")
    if not st:
        continue
    p = props(block(st))
    bg = col(p.get("bg_color"))
    bd = col(p.get("border_color", "Color(0,0,0,0)"))
    r = int(p.get("corner_radius_top_left", "0"))
    bw = int(p.get("border_width_top", "0"))
    if var in ("PanelChosen", "PanelCardActive"):
        pad = button("inset_" + var.lower(), bg, bd, r, bw, glow=GOLD + (90,), w=48, h=48)
        tex_box(st, "inset_" + var.lower(), max(r, bw) + 3, pad, p)
    else:
        inset("inset_" + var.lower(), bg, bd, max(r, 3), bg[3])
        tex_box(st, "inset_" + var.lower(), max(r, 3) + 2, 0, p)

# ---------- картинки из imagegen (assets/ui/source/) ----------
SRC = os.path.join(OUT, "source")


def tex_box2(sid, tex, mx, my, pad, p, cm=None):
    """StyleBoxTexture с разными полями по осям; cm — свои отступы содержимого (x, y)"""
    lines = ['[sub_resource type="StyleBoxTexture" id="%s"]' % sid]
    for side in ("left", "top", "right", "bottom"):
        k = "content_margin_" + side
        if cm is not None:
            lines.append("%s = %.1f" % (k, cm[0] if side in ("left", "right") else cm[1]))
        elif k in p:
            lines.append("%s = %s" % (k, p[k]))
    lines.append('texture = ExtResource("ui_%s")' % tex)
    for side in ("left", "right"):
        lines.append("texture_margin_%s = %.1f" % (side, mx + pad))
    for side in ("top", "bottom"):
        lines.append("texture_margin_%s = %.1f" % (side, my + pad))
    for side in ("left", "top", "right", "bottom"):
        lines.append("expand_margin_%s = %.1f" % (side, pad))
    replacements[sid] = "\n".join(lines)
    textures[tex] = "res://assets/ui/%s.png" % tex


def with_shadow(im, pad, alpha=150):
    W, H = im.width + 2 * pad, im.height + 2 * pad
    base = shadow_layer(W, H, 10, pad, alpha, pad * 0.45)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lay.paste(im, (pad, pad))
    return Image.alpha_composite(base, lay)


def darken_inside(im, inset, k, feather):
    """затемнить середину рамки, чтобы текст читался"""
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rectangle([inset, inset, im.width - inset, im.height - inset], fill=int(255 * k))
    m = m.filter(ImageFilter.GaussianBlur(feather))
    dark = Image.new("RGBA", im.size, (8, 5, 3, 0))
    dark.putalpha(m)
    a = im.split()[3]
    out = Image.alpha_composite(im, dark)
    out.putalpha(a)
    return out


def src_frame(fname, out_name, scale, var_ids, margin_src, cm, crest=None, dark=0.45):
    path = os.path.join(SRC, fname)
    if not os.path.exists(path):
        return
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.split()[3].getbbox())
    if crest:
        # убрать украшение посередине верхней кромки: при растяжении оно бы поплыло
        x0, x1, h = crest
        donor = im.crop((x0 - (x1 - x0) - 40, 0, x0 - 40, h))
        im.paste(donor, (x0, 0))
    im = darken_inside(im, int(margin_src * 0.9), dark, 25)
    w, h = int(im.width * scale), int(im.height * scale)
    im = im.resize((w, h), Image.LANCZOS)
    pad = 12
    im = with_shadow(im, pad)
    im.save(os.path.join(OUT, out_name + ".png"))
    m = int(margin_src * scale)
    for var in var_ids:
        st = styles_of(var).get("panel")
        if st:
            tex_box2(st, out_name, m, m, pad, props(block(st)), cm)


src_frame("frame_panel.png", "frame_panel", 0.36, ["PanelDark"], 100, (30, 30))
src_frame("frame_modal.png", "frame_modal", 0.36, ["PanelModal", "PanelDialog"], 100, (40, 38), crest=(420, 560, 110))

# Кнопки: 4 полосы сверху вниз — обычная, наведение, нажатая, главная (золотая)
bpath = os.path.join(SRC, "buttons.png")
if os.path.exists(bpath):
    from PIL import ImageEnhance
    sheet = Image.open(bpath).convert("RGBA")
    a = sheet.split()[3]
    rows, inside, s0 = [], False, 0
    for y in range(sheet.height):
        v = sum(1 for x in range(0, sheet.width, 4) if a.getpixel((x, y)) > 40)
        if v > 5 and not inside:
            s0, inside = y, True
        elif v <= 5 and inside:
            rows.append((s0, y))
            inside = False
    if inside:
        rows.append((s0, sheet.height))
    rows = [r for r in rows if r[1] - r[0] > 40][:4]
    crops = []
    for (y0, y1) in rows:
        c = sheet.crop((0, y0, sheet.width, y1))
        c = c.crop(c.split()[3].point(lambda v: 255 if v > 40 else 0).getbbox())
        TH = 48
        c = c.resize((int(c.width * TH / c.height), TH), Image.LANCZOS)
        crops.append(c)

    def adj(im, bright=1.0, sat=1.0):
        rgb = im.convert("RGB")
        rgb = ImageEnhance.Brightness(rgb).enhance(bright)
        rgb = ImageEnhance.Color(rgb).enhance(sat)
        out = rgb.convert("RGBA")
        out.putalpha(im.split()[3])
        return out

    if len(crops) == 4:
        normal, hover, pressed, gold = crops
        sets = {
            "wood": {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": adj(pressed, 1.15), "disabled": adj(normal, 0.55, 0.3)},
            "gold": {"normal": gold, "hover": adj(gold, 1.12), "pressed": adj(gold, 0.82), "hover_pressed": adj(gold, 0.95), "disabled": adj(gold, 0.45, 0.15)},
        }
        for fam, states in sets.items():
            for stn, im in states.items():
                im.save(os.path.join(OUT, "btn_%s_%s.png" % (fam, stn)))
        for var, fam in [("Button", "wood"), ("ButtonBig", "wood"), ("ButtonPrimary", "gold")]:
            for stn, sid in styles_of(var).items():
                if stn in sets[fam]:
                    tex_box2(sid, "btn_%s_%s" % (fam, stn), 18, 14, 0, props(block(sid)))

# ---------- запись темы ----------
out = src
for sid, txt in replacements.items():
    out = re.sub(r'\[sub_resource type="StyleBoxFlat" id="%s"\]\n.*?(?=\n\n|\n\[)' % sid, lambda m: txt, out, flags=re.S)
    out = out.replace('SubResource("%s")' % sid, 'SubResource("%s")' % sid)
ext = "".join('[ext_resource type="Texture2D" path="%s" id="ui_%s"]\n' % (path, n) for n, path in sorted(textures.items()))
out = out.replace('[sub_resource type="FontVariation" id="FontVariation_001"]', ext + '[sub_resource type="FontVariation" id="FontVariation_001"]', 1)
n_steps = len(re.findall(r"^\[(ext|sub)_resource", out, re.M)) + 1
out = re.sub(r"load_steps=\d+", "load_steps=%d" % n_steps, out, count=1)
open(THEME, "w", encoding="utf-8", newline="\n").write(out)
print("styleboxes:", len(replacements), "textures:", len(textures))
