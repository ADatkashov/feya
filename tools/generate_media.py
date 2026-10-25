#!/usr/bin/env python3
"""Generates the FEYA development catalog artwork (original illustrations, no third-party imagery).

These are procedurally drawn bouquet renders used as development placeholders for the starter catalog.
Replace them with real photography before launch (see docs/DEVELOPMENT.md, "Product imagery").

Usage: python3 tools/generate_media.py [output_dir]
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 900, 1125  # 4:5 product images
SS = 2  # supersampling factor


def hex2rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(c, f):
    """f<1 darkens, f>1 lightens."""
    if f <= 1:
        return tuple(max(0, min(255, int(v * f))) for v in c)
    t = f - 1
    return tuple(max(0, min(255, int(v + (255 - v) * t))) for v in c)


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


# ------------------------------------------------------------------------------------------------
# Flowers — each returns an RGBA tile of size (2R+pad)^2 centred on the flower
# ------------------------------------------------------------------------------------------------

def petal(draw, cx, cy, ang, length, width, color, edge):
    pts = []
    n = 24
    for i in range(n + 1):
        t = i / n
        # teardrop profile along the petal axis
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
        pts.append((t * length, w))
    for i in range(n, -1, -1):
        t = i / n
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
        pts.append((t * length, -w))
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    draw.polygon(poly, fill=color + (255,), outline=edge + (255,))


def rose(R, base, rnd):
    pad = int(R * 0.5)
    S = 2 * R + 2 * pad
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    layers = 5
    for li in range(layers):
        t = li / (layers - 1)
        rad = R * (1.0 - 0.78 * t)
        count = 5 if li < layers - 1 else 3
        col = shade(base, 0.72 + 0.5 * t)
        edge = shade(base, 0.55 + 0.45 * t)
        off = rnd.uniform(0, math.tau)
        for k in range(count):
            a = off + k * math.tau / count + rnd.uniform(-0.12, 0.12)
            length = rad * 1.0
            width = rad * (0.62 if li < layers - 1 else 0.5)
            # petals radiate from near the centre, bulging outward
            sx = c + math.cos(a) * rad * 0.18
            sy = c + math.sin(a) * rad * 0.18
            petal(d, sx, sy, a, length, width, col, edge)
        # inner highlight ring
    # spiral heart
    for i in range(14):
        a = i * 0.9
        r = R * 0.22 * (1 - i / 16)
        col = shade(base, 1.05 + 0.02 * i)
        d.arc([c - r, c - r, c + r, c + r], a * 57.3, a * 57.3 + 220, fill=shade(col, 0.6) + (255,), width=max(1, R // 40))
    return img


def peony(R, base, rnd):
    pad = int(R * 0.5)
    S = 2 * R + 2 * pad
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    layers = 8
    for li in range(layers):
        t = li / (layers - 1)
        rad = R * (1.0 - 0.8 * t)
        count = 9 - li // 2
        col = shade(base, 0.8 + 0.42 * t)
        edge = shade(base, 0.62 + 0.4 * t)
        off = rnd.uniform(0, math.tau)
        for k in range(count):
            a = off + k * math.tau / count + rnd.uniform(-0.18, 0.18)
            width = rad * 0.55
            sx = c + math.cos(a) * rad * 0.12
            sy = c + math.sin(a) * rad * 0.12
            petal(d, sx, sy, a, rad, width, col, edge)
    # ruffled centre
    for i in range(26):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0, R * 0.14)
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        rr = R * rnd.uniform(0.05, 0.1)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=shade(base, 1.15 + rnd.uniform(0, .2)) + (255,),
                  outline=shade(base, 0.7) + (255,))
    return img


def tulip(R, base, rnd):
    """Side view cup; R is the cup width/2."""
    S = 4 * R
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    # back petals
    for dx, rot in ((-0.45, -0.18), (0.45, 0.18)):
        pts = []
        for i in range(31):
            t = i / 30
            ang = math.pi * t
            x = cx + dx * R + math.cos(ang + math.pi) * R * 0.55
            y = cy - math.sin(ang) * R * 1.5 + R * 0.5
            pts.append((x, y))
        d.polygon(pts + [(cx + dx * R * 0.4, cy + R)], fill=shade(base, 0.8) + (255,), outline=shade(base, 0.55) + (255,))
    # front petals
    for dx, col in ((-0.28, 1.0), (0.28, 1.0), (0.0, 1.12)):
        pts = []
        for i in range(31):
            t = i / 30
            x = cx + dx * R + math.cos(math.pi * (1 - t)) * R * 0.62
            y = cy + R * 0.6 - math.sin(math.pi * t) * R * 1.75 * (0.82 if dx else 1)
            pts.append((x, y))
        pts.append((cx + dx * R * 0.3, cy + R * 1.15))
        d.polygon(pts, fill=shade(base, col * 0.95) + (255,), outline=shade(base, 0.6) + (255,))
        d.line([(cx + dx * R * 0.3, cy + R * 1.0), (cx + dx * R * 0.2, cy - R * 0.9)],
               fill=shade(base, 1.18) + (160,), width=max(1, R // 18))
    return img


def filler(R, base, rnd):
    pad = R
    S = 2 * R + 2 * pad
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    for _ in range(16):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0, R)
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        rr = R * rnd.uniform(0.1, 0.2)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=shade(base, rnd.uniform(0.95, 1.1)) + (255,))
    return img


FLOWERS = {"rose": rose, "peony": peony, "tulip": tulip, "filler": filler}


# ------------------------------------------------------------------------------------------------
# Scene
# ------------------------------------------------------------------------------------------------

def background(w, h, tint, rnd):
    img = Image.new("RGB", (w, h))
    px = img.load()
    cx, cy = w * 0.5, h * 0.42
    top = shade(tint, 0.30)
    for y in range(h):
        for x in range(0, w):
            d = math.hypot((x - cx) / w, (y - cy) / h)
            t = min(1.0, d * 1.6)
            px[x, y] = mix(shade(tint, 0.55), (8, 9, 16), t)
    bok = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bok)
    for _ in range(14):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h * 0.8)
        r = rnd.uniform(18, 70) * w / 900
        bd.ellipse([x - r, y - r, x + r, y + r], fill=shade(tint, 1.4) + (rnd.randint(14, 34),))
    bok = bok.filter(ImageFilter.GaussianBlur(10 * w / 900))
    img = Image.alpha_composite(img.convert("RGBA"), bok)
    return img


def leaf(draw, x, y, ang, length, width, col):
    pts = []
    for i in range(21):
        t = i / 20
        pts.append((t * length, width * math.sin(math.pi * t) ** 0.9))
    for i in range(20, -1, -1):
        t = i / 20
        pts.append((t * length, -width * math.sin(math.pi * t) ** 0.9))
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]
    draw.polygon(poly, fill=col + (255,), outline=shade(col, 0.6) + (255,))
    draw.line([(x, y), (x + length * ca * 0.95, y + length * sa * 0.95)], fill=shade(col, 1.25) + (200,),
              width=max(1, int(width / 6)))


def drop_shadow(canvas, tile, pos, blur=14, opacity=120, offset=(6, 10)):
    alpha = tile.split()[-1]
    sh = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    sh.putalpha(alpha.point(lambda v: v * opacity // 255))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (int(pos[0] + offset[0]), int(pos[1] + offset[1])))


def render_bouquet(spec, seed, closeup=False, size=(W, H)):
    w, h = size[0] * SS, size[1] * SS
    rnd = random.Random(seed)
    canvas = background(w, h, hex2rgb(spec["bg"]), rnd).convert("RGBA")
    cx = w / 2
    scale = w / 900

    # ---- layout: dome of flower positions
    if closeup:
        dome_cx, dome_cy, rx, ry = cx, h * 0.46, w * 0.46, h * 0.40
        base_r = 120 * scale
    else:
        dome_cx, dome_cy, rx, ry = cx, h * 0.38, w * 0.33, h * 0.25
        base_r = 78 * scale
    gather = (cx, h * (0.96 if closeup else 0.80))  # where stems converge

    # stems and foliage first
    d = ImageDraw.Draw(canvas)
    foliage = hex2rgb(spec.get("leaf", "#2f6b46"))
    pts = []
    n = spec["count"]
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        a = i * golden + rnd.uniform(-0.2, 0.2)
        x = dome_cx + math.cos(a) * rx * r
        y = dome_cy + math.sin(a) * ry * r * 0.95 - (1 - r) * ry * 0.15
        pts.append((x, y, r))
    # leaves peeking from behind
    for _ in range(spec.get("leaves", 14) + 8):
        a = rnd.uniform(0, math.tau)
        sx, sy = dome_cx + math.cos(a) * rx * 0.5, dome_cy + math.sin(a) * ry * 0.5
        ln = rx * rnd.uniform(0.55, 0.8)
        leaf(d, sx, sy, a + rnd.uniform(-0.25, 0.25), ln, 30 * scale * rnd.uniform(0.8, 1.3),
             shade(foliage, rnd.uniform(0.8, 1.2)))
    for x, y, _ in pts:
        d.line([(x, y), gather], fill=shade(foliage, 0.75) + (255,), width=int(9 * scale))
        d.line([(x - 2 * scale, y), (gather[0] - 2 * scale, gather[1])], fill=shade(foliage, 1.1) + (120,), width=int(3 * scale))

    # wrapping paper cone (skip in close-up where it would just be a hint)
    paper = hex2rgb(spec["paper"])
    if not closeup:
        cone_top_y = h * 0.60
        apex = (cx, h * 0.97)
        left, right = cx - w * 0.30, cx + w * 0.30
        cone = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cone)
        top_curve = [(left + (right - left) * t / 20, cone_top_y + math.sin(math.pi * t / 20) * h * 0.05 + t / 20 * h * 0.02)
                     for t in range(21)]
        cd.polygon(top_curve + [apex], fill=paper + (255,))
        # folds
        for k in range(-3, 4):
            x1 = cx + k * w * 0.075
            cd.line([(x1, cone_top_y + h * 0.01), (cx + k * w * 0.012, h * 0.96)], fill=shade(paper, 0.7) + (170,), width=int(3 * scale))
            cd.line([(x1 + 6 * scale, cone_top_y + h * 0.01), (cx + k * w * 0.012 + 3 * scale, h * 0.96)],
                    fill=shade(paper, 1.25) + (110,), width=int(3 * scale))
        # lighter inner sheet
        cd.polygon([(left + w * 0.02, cone_top_y + h * 0.015), (cx + w * 0.03, cone_top_y + h * 0.045), (cx - w * 0.02, h * 0.93)],
                   fill=shade(paper, 1.15) + (200,))
        drop_shadow(canvas, cone, (0, 0), blur=22 * scale, opacity=150)
        canvas.alpha_composite(cone)

    # flowers (back to front: smaller r = centre = drawn last so the dome looks full)
    palette = [hex2rgb(c) for c in spec["colors"]]
    order = sorted(pts, key=lambda p: -p[2])
    kinds = spec["kinds"]
    for x, y, r in order:
        kind = rnd.choices(kinds, weights=[k[1] for k in kinds])[0][0]
        base = rnd.choice(palette)
        R = int(base_r * rnd.uniform(0.85, 1.15) * (1.0 - 0.18 * r))
        if kind == "tulip":
            tile = tulip(int(R * 0.8), base, rnd)
        else:
            tile = FLOWERS[kind](R, base, rnd)
        tile = tile.rotate(rnd.uniform(-35, 35), resample=Image.BICUBIC)
        pos = (x - tile.width / 2, y - tile.height / 2)
        drop_shadow(canvas, tile, pos, blur=12 * scale, opacity=130, offset=(4 * scale, 8 * scale))
        canvas.alpha_composite(tile, (int(pos[0]), int(pos[1])))

    # filler sprays on the rim
    if spec.get("filler"):
        fc = hex2rgb(spec["filler"])
        for _ in range(spec.get("filler_count", 12)):
            a = rnd.uniform(0, math.tau)
            rr = rnd.uniform(0.7, 1.05)
            x = dome_cx + math.cos(a) * rx * rr
            y = dome_cy + math.sin(a) * ry * rr
            tile = filler(int(30 * scale * rnd.uniform(0.8, 1.4)), fc, rnd)
            canvas.alpha_composite(tile, (int(x - tile.width / 2), int(y - tile.height / 2)))

    # ribbon bow
    if not closeup and spec.get("ribbon"):
        rc = hex2rgb(spec["ribbon"])
        bx, by = cx, h * 0.70
        bow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bow)
        for sgn in (-1, 1):
            bd.polygon([(bx, by), (bx + sgn * 120 * scale, by - 55 * scale), (bx + sgn * 130 * scale, by + 55 * scale)],
                       fill=rc + (255,), outline=shade(rc, 0.6) + (255,))
            bd.polygon([(bx, by), (bx + sgn * 40 * scale, by + 150 * scale), (bx + sgn * 12 * scale, by + 155 * scale)],
                       fill=shade(rc, 0.85) + (255,))
        bd.ellipse([bx - 24 * scale, by - 24 * scale, bx + 24 * scale, by + 24 * scale], fill=shade(rc, 1.1) + (255,),
                   outline=shade(rc, 0.6) + (255,))
        drop_shadow(canvas, bow, (0, 0), blur=8 * scale, opacity=140)
        canvas.alpha_composite(bow)

    # vignette + soft grain for a photographic feel
    vign = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vign)
    vd.ellipse([-w * 0.25, -h * 0.15, w * 1.25, h * 1.1], fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(90 * scale))
    dark = Image.new("RGBA", (w, h), (4, 4, 10, 255))
    out = Image.composite(canvas, Image.alpha_composite(canvas, Image.new("RGBA", (w, h), (4, 4, 10, 120))), vign)
    out = out.convert("RGB").resize(size, Image.LANCZOS)
    return out


def render_banner(spec, seed, size=(1200, 560)):
    rnd = random.Random(seed)
    bouquet = render_bouquet(spec, seed, closeup=False, size=(W, H))
    w, h = size
    canvas = background(w * SS, h * SS, hex2rgb(spec["bg"]), rnd).convert("RGB").resize(size, Image.LANCZOS)
    crop = bouquet.crop((0, int(H * 0.02), W, int(H * 0.86))).resize((int(W * h / (H * 0.84) * 1.08), int(h * 1.08)), Image.LANCZOS)
    mask = Image.new("L", crop.size, 255)
    ml = ImageDraw.Draw(mask)
    for i in range(160):
        ml.rectangle([i, 0, i + 1, crop.height], fill=int(255 * i / 160))
    canvas.paste(crop, (w - crop.width + 40, -int(h * 0.04)), mask)
    return canvas


# ------------------------------------------------------------------------------------------------
# Catalog specs
# ------------------------------------------------------------------------------------------------

PINK = ["#f04493", "#e8559e", "#f77bb5", "#d957ae"]
BLUSH = ["#f7c6d4", "#f2a9c0", "#fadde6"]
WHITE = ["#fbf4f1", "#f4e9e6", "#ffffff"]
RED = ["#b3122f", "#c81d3c", "#8f0b25"]
PEACH = ["#ffb38a", "#ff9f7a", "#ffd0a8"]
CORAL = ["#ff6f61", "#ff8a73", "#f9a090"]
LAV = ["#9b7fe0", "#b79af0", "#7e63c9"]
YELLOW = ["#ffd24a", "#ffe27a", "#f5b81c"]
BURG = ["#7d1b3a", "#a3294a", "#c25a2b"]

CATALOG = {
    "nezhnost": dict(bg="#3b1230", paper="#5a2d63", ribbon="#f04493", colors=PINK + BLUSH, kinds=[("rose", 5), ("peony", 3)], count=21, filler="#fbeaf3"),
    "magiya-chuvstv": dict(bg="#3a0f2e", paper="#3b1d57", ribbon="#f9a8d4", colors=PINK + ["#fb8fc3"], kinds=[("rose", 6), ("peony", 2)], count=25, filler="#ffe4f1", filler_count=16),
    "vdohnovenie": dict(bg="#3a1c10", paper="#7a4a2b", ribbon="#ffb38a", colors=PEACH + CORAL, kinds=[("rose", 5), ("peony", 2)], count=19, filler="#fff1de"),
    "romantika": dict(bg="#2b0610", paper="#14121a", ribbon="#c81d3c", colors=RED, kinds=[("rose", 1)], count=23, leaves=18),
    "pionovoe-oblako": dict(bg="#3a1630", paper="#d9b8c8", ribbon="#f7c6d4", colors=BLUSH + ["#f6b2c8"], kinds=[("peony", 1)], count=13),
    "belaya-klassika": dict(bg="#1c1c2a", paper="#e9e1d8", ribbon="#cfc6bb", colors=WHITE, kinds=[("rose", 5), ("peony", 1)], count=21, filler="#ffffff", filler_count=18),
    "tyulpany-vesennie": dict(bg="#241a3a", paper="#7aa56b", ribbon="#fff0a8", colors=["#ff8fb8", "#ffd24a", "#f04493", "#ffe7a1"], kinds=[("tulip", 1)], count=17, leaves=22),
    "lavandovyj-son": dict(bg="#20163f", paper="#4a3a82", ribbon="#cbb8ff", colors=LAV + ["#d9c8ff"], kinds=[("rose", 4), ("peony", 1)], count=19, filler="#e9deff", leaf="#4d7a64"),
    "alyj-barhat": dict(bg="#2a040c", paper="#0e0a10", ribbon="#8f0b25", colors=RED + ["#9d1030"], kinds=[("rose", 1)], count=31, leaves=10),
    "sad-fei": dict(bg="#2d1542", paper="#b79ad0", ribbon="#f7c6d4", colors=PINK[:2] + LAV[:2] + BLUSH + WHITE[:1], kinds=[("rose", 4), ("peony", 2), ("tulip", 1)], count=23, filler="#fff", filler_count=16),
    "korolevskij-pion": dict(bg="#3a0f28", paper="#2b1030", ribbon="#f04493", colors=["#e8438c", "#f26aa8", "#d62e7a"], kinds=[("peony", 1)], count=15),
    "podarochnyj-mini": dict(bg="#331238", paper="#f04493", ribbon="#ffffff", colors=PINK[:3] + BLUSH[:1], kinds=[("rose", 1)], count=9),
    "vesennij-miks": dict(bg="#1d2a3a", paper="#8fbf86", ribbon="#ffe27a", colors=YELLOW + ["#ff8fb8", "#ffffff"], kinds=[("tulip", 3), ("rose", 2)], count=19, filler="#fffbe0", leaves=20),
    "osennyaya-simfoniya": dict(bg="#2a1208", paper="#6b3a1d", ribbon="#c25a2b", colors=BURG + PEACH[:1] + YELLOW[2:], kinds=[("rose", 4), ("peony", 2)], count=19, filler="#f3d9a4", leaf="#6b6a2f"),
    "korallovyj-rassvet": dict(bg="#3a1410", paper="#f0b8a8", ribbon="#ff6f61", colors=CORAL + PEACH[:1], kinds=[("peony", 3), ("rose", 2)], count=15),
    "rozy-ekvador-25": dict(bg="#26050d", paper="#1a1118", ribbon="#b3122f", colors=["#b3122f", "#d1203f"], kinds=[("rose", 1)], count=25, leaves=12),
}

BANNERS = {
    "banner-spring": "magiya-chuvstv",
    "banner-peony": "pionovoe-oblako",
    "banner-gifts": "sad-fei",
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "backend", "src", "main", "resources", "media")
    prod = os.path.join(out, "bouquets")
    os.makedirs(prod, exist_ok=True)
    only = set(sys.argv[2:])
    for i, (slug, spec) in enumerate(CATALOG.items()):
        if only and slug not in only:
            continue
        render_bouquet(spec, 1000 + i).save(os.path.join(prod, f"{slug}-1.jpg"), quality=88, optimize=True, progressive=True)
        render_bouquet(spec, 2000 + i, closeup=True).save(os.path.join(prod, f"{slug}-2.jpg"), quality=88, optimize=True, progressive=True)
        print("rendered", slug, flush=True)
    ban = os.path.join(out, "banners")
    os.makedirs(ban, exist_ok=True)
    for i, (name, slug) in enumerate(BANNERS.items()):
        if only and name not in only:
            continue
        render_banner(CATALOG[slug], 3000 + i).save(os.path.join(ban, f"{name}.jpg"), quality=86, optimize=True, progressive=True)
        print("rendered", name, flush=True)


if __name__ == "__main__":
    main()
