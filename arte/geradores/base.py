"""Base do pixel art procedural do Guild Dungeon: grade com contorno automático, paleta,
personagem em camadas (pernas → tronco/peitoral → arma → cabeça → cabelo → capacete)."""
import math
from PIL import Image

OUT_COL = (42, 29, 34)
P = {
    'o': OUT_COL, 'k': (30, 22, 28),
    's': (234, 191, 152), 'S': (196, 146, 108), 'r': (226, 140, 120), 'e': (42, 29, 34), 'E': (246, 242, 234),
    'h': (178, 58, 58), 'H': (122, 36, 48),                       # cabelo
    '1': (168, 50, 50), '!': (110, 31, 40), '2': (230, 220, 200), '@': (170, 160, 140),  # roupa
    'b': (107, 74, 47), 'B': (61, 47, 42), 'g': (217, 164, 65), 'G': (160, 112, 40),
    'w': (226, 232, 242), 'W': (150, 162, 184), 'm': (150, 156, 180), 'M': (92, 97, 124), 'v': (235, 240, 250),
    'L': (122, 82, 50), 'l': (160, 112, 70),
    'y': (214, 180, 96), 'Y': (170, 135, 65),
    # madeira (props)
    'q': (196, 146, 94), 't': (163, 112, 67), 'T': (128, 84, 50), 'd': (88, 56, 36),
    'a': (80, 140, 215), 'A': (45, 95, 170), 'n': (232, 224, 208), 'N': (190, 178, 158),
    'c': (168, 50, 50), 'C': (110, 31, 40), 'x': (250, 140, 40), 'X': (255, 235, 150),
    '3': (61, 47, 42), '#': (40, 30, 28), 'p': (217, 164, 65),
}

def shade(c, k=(0.72, 0.64, 0.78)):
    return tuple(int(v * f) for v, f in zip(c, k))

class G:
    """Grade de pixels por letra; img() aplica contorno automático."""
    def __init__(s): s.m = {}
    def set(s, x, y, k): s.m[(int(x), int(y))] = k
    def rect(s, x, y, w, h, k):
        for yy in range(y, y + h):
            for xx in range(x, x + w): s.m[(xx, yy)] = k
    def ell(s, cx, cy, rx, ry, k, ring=None):
        for y in range(math.floor(cy - ry) - 1, math.ceil(cy + ry) + 2):
            for x in range(math.floor(cx - rx) - 1, math.ceil(cx + rx) + 2):
                v = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if v <= 1: s.m[(x, y)] = ring if (ring and v > 0.55) else k
    def rows(s, rows, x0=0, y0=0, mirror=False):
        if mirror: rows = [r + r[::-1] for r in rows]
        for y, r in enumerate(rows):
            for x, k in enumerate(r):
                if k not in '. ': s.m[(x0 + x, y0 + y)] = k
    def img(s, pal=None, outline=True):
        pal = {**P, **(pal or {})}; m = dict(s.m)
        if outline:
            for (x, y), k in s.m.items():
                if k in 'ok': continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) not in s.m: m[(x + dx, y + dy)] = 'o'
        xs = [x for x, _ in m]; ys = [y for _, y in m]
        x0, y0 = min(xs), min(ys)
        im = Image.new('RGBA', (max(xs) - x0 + 1, max(ys) - y0 + 1), (0, 0, 0, 0))
        for (x, y), k in m.items(): im.putpixel((x - x0, y - y0), pal[k] + (255,))
        return im, (x0, y0)

def paste(c, im, x, y): c.paste(im, (int(x), int(y)), im)

# ---------------- ARMAS ----------------
TIERS = {
    'Bronze':    {'w': (236, 178, 118), 'W': (184, 115, 60), 'g': (140, 90, 50), 'p': (140, 90, 50)},
    'Ferro':     {'w': (226, 232, 242), 'W': (150, 162, 184), 'g': (217, 164, 65), 'p': (217, 164, 65)},
    'Mithril':   {'w': (225, 252, 255), 'W': (110, 196, 222), 'g': (235, 235, 245), 'p': (235, 235, 245)},
    'Obsidiana': {'w': (176, 146, 226), 'W': (72, 50, 112), 'g': (200, 60, 80), 'p': (200, 60, 80)},
}
ELEM = {'fogo': ((200, 60, 30), (250, 140, 40), (255, 235, 150)),
        'agua': ((40, 90, 200), (90, 170, 240), (215, 240, 255)),
        'eletrico': ((210, 170, 30), (250, 235, 90), (255, 255, 240)),
        'vento': ((50, 140, 90), (130, 215, 150), (225, 255, 230))}
# arma vertical, ponta para cima; grip = (coluna, linha) onde vai a mão
WEAPONS = {
    'Adaga':   (["..w..", ".wW..", ".wW..", ".wW..", ".wW..", ".ggg.", "..b..", "..b..", "..p.."], (2, 6)),
    'Espada':  (["..w.."] + [".wW.."] * 9 + ["ggggg", "..b..", "..b..", "..p.."], (2, 11)),
    'Espadão': (["..w.."] + [".wwW."] * 14 + ["ggggg", "..b..", "..b..", "..b..", "..p.."], (2, 16)),
    'Machado': (["...bW..", "...bWW.", "...bWWw", "...bWWw", "...bWWw", "...bWW.", "...bW.."] + ["...b..."] * 8 + ["...p..."], (3, 12)),
    'Maça':    (["..w..", ".WwW.", "wWWWw", ".WWW.", "..W.."] + ["..b.."] * 9 + ["..p.."], (2, 11)),
    'Lança':   (["..w..", ".ww..", ".wW..", ".wW..", "..W..", ".g.g."] + ["..b.."] * 14 + ["..p.."], (2, 14)),
    'Cajado':  (["..x..", ".xXx.", "bxXxb", ".bxb.", "..b.."] + ["..b.."] * 14 + ["..p.."], (2, 14)),
}
def weapon_grid(name, hand=True):
    rows, (gx, gy) = WEAPONS[name]; g = G(); g.rows(rows)
    if hand:
        for dx, k in ((-1, 's'), (0, 'S'), (1, 's')):
            g.set(gx + dx, gy, k); g.set(gx + dx, gy + 1, k)
    return g, (gx, gy)

def bow_grid(hand=True):
    g = G()
    for y in range(17): g.set(round(3 * math.sin(math.pi * y / 16)), y, 'b')
    g.set(3, 4, 'g'); g.set(3, 12, 'g')
    if hand:
        for x, k in zip(range(2, 5), "sSs"): g.set(x, 8, k); g.set(x, 9, k)
    return g, (3, 8)

def weapon_sprite(name, tier='Ferro', elem='fogo', hand=True):
    """Devolve (img, pivô) — pivô = mão, para girar o golpe em volta dela."""
    pal = dict(TIERS[tier])
    if name == 'Arco':
        g, (gx, gy) = bow_grid(hand); pal['b'] = {'Bronze': (140, 90, 50), 'Ferro': (107, 74, 47), 'Mithril': (200, 210, 225), 'Obsidiana': (72, 50, 112)}[tier]
    else:
        g, (gx, gy) = weapon_grid(name, hand)
    if name == 'Cajado':
        d, m, l = ELEM[elem]; pal.update({'x': m, 'X': l})
    im, (x0, y0) = g.img(pal)
    return im, (gx - x0, gy - y0)

def place(c, sprite, pivot, pos, ang, mirror=False):
    R = 48; big = Image.new('RGBA', (R * 2, R * 2), (0, 0, 0, 0)); big.paste(sprite, (R - pivot[0], R - pivot[1]))
    big = big.rotate(-ang if mirror else ang, resample=Image.NEAREST)
    if mirror: big = big.transpose(Image.FLIP_LEFT_RIGHT).transform(big.size, Image.AFFINE, (1, 0, -1, 0, 1, 0))
    c.paste(big, (int(pos[0]) - R, int(pos[1]) - R), big)

def rot(v, ang):
    a = math.radians(ang)
    return (v[0] * math.cos(a) + v[1] * math.sin(a), -v[0] * math.sin(a) + v[1] * math.cos(a))

# ---------------- CORPO / EQUIPAMENTO ----------------
def mirror(h): return [r + r[::-1] for r in h]
FACE = mirror([".....ooooo", "...oosssss", "..osssssss", ".ossssssss", "osssssssss", "osssssssss", "osssssssss",
               "osssssEess", "osssssEess", "osssssssss", "osssrrssss", ".oSsssssss", ".ossssssss", "..oSSSSSSS", "...ooooooo"])
# olho: coluna branca (E, fixa) + coluna de íris (e)
FACE = [r.replace('Ee', 'Ee') for r in FACE]
BANGS = [".....ooooo", "...oohhhhh", "..ohhhhhhh", ".ohhhhhhhh", "ohhhhhHhhh", "ohhhH.....", "ohh.......", "ohh.......", "oh........", "oh........"]
HAIR = {
    'Curto': (mirror(BANGS), None),
    'Longo': (mirror(BANGS[:6] + ["ohh......."] * 7 + [".oh......."]),
              lambda g: [g.set(x, y, 'H' if x == 3 else 'h') or g.set(19 - x, y, 'H' if x == 3 else 'h') for y in range(6, 22) for x in range(-1, 4)]),
    'Rabo': (mirror(BANGS), lambda g: [(g.set(20 + round(math.sin((y - 4) / 15 * math.pi) * 1.5), y, 'h'),
                                        g.set(21 + round(math.sin((y - 4) / 15 * math.pi) * 1.5), y, 'H')) for y in range(4, 20)]),
}

def chest_grid(kind, elem='fogo'):
    """Peitoral (camada do tronco). Núcleo 10×8 espelhado; ombreiras saem da silhueta."""
    g = G()
    if kind == 'Túnica':
        g.rows(["..111", "11111", "1!111", "11111", "bbbbg", "11111", "1!111", "!1111"], mirror=True)
    elif kind == 'Couro':
        g.rows(["..LLL", "LLlLL", "LLLLL", "LlLLL", "bbbbg", "LLLLL", "LLlLL", "LLLLl"], mirror=True)
    elif kind == 'Malha':
        rows = []
        for y in range(4): rows.append(''.join('m' if (x + y) % 2 else 'M' for x in range(5)))
        rows = ["..mMm"] + rows[1:] + ["bbbbg", "11111", "1!111", "!1111"]
        g.rows(rows, mirror=True)
        for x in (0, 9): g.set(x, 0, 'M')
    elif kind == 'Placas':
        g.rows(["..mmm", "Mmmmv", "Mmmvv", "Mmmmv", "bbbbg", "MmmmW", "MmMmm", "Mmmmm"], mirror=True)
        for sx in (0, 9):
            g.ell(sx, 1.2, 2.2, 1.8, 'm'); g.set(sx, 0, 'v')
    elif kind == 'Manto':
        g.rows(["..11X", "1111X", "1!11X", "1111X", "1111X", "1111X", "1!11X", "!111X"], mirror=True)
    return g

def helmet_grid(kind):
    """Capacete em coordenadas da cabeça (20×15). Devolve (grid, esconde_cabelo)."""
    g = G()
    if kind == 'Capuz de couro':
        g.rows([".....LLLLL", "...LLLLLLL", "..LLLLLLLL", ".LLLlLLLLL", "LLLLLLLLLL", "LL........", "LL........", "L........."], 0, 0, True)
        return g, False
    if kind == 'Elmo de ferro':
        g.rows([".....mmmmm", "...mmmmvvm", "..mmmmmvvm", ".mmmmmmmmm", "mmmmmmmmmm", "MMMMMMMMMM", "m........M", "m........M", "m........."], 0, 0, True)
        for y in range(5, 10): g.set(9, y, 'm'); g.set(10, y, 'M')
        return g, False
    if kind == 'Elmo fechado':
        g.rows([".....mmmmm", "...mmmmvvm", "..mmmmmvvm", ".mmmmmmmmm", "mmmmmmmmmm", "mmmmmmmmmm", "mmmmmmmmmm",
                "mmmkkkkkkm", "mmmmmmmmmm", "mmmmmmmmmm", "mmmmmMmmmm", ".mmmmmmmmm", ".mmmmmmmmm", "..MMMMMMMM"], 0, 0, True)
        for y in range(-4, 1): g.set(9, y, 'c'); g.set(10, y, 'C')
        return g, True
    if kind == 'Capuz':
        for y in range(0, 15):
            for x in range(-1, 21):
                v = ((x - 9.5) / 11) ** 2 + ((y - 7) / 8.5) ** 2
                face = 3 <= x <= 16 and 5 <= y <= 14
                if v <= 1 and not face: g.set(x, y, '!' if (x < 2 or x > 17) else '1')
        return g, True
    if kind == 'Chapéu de mago':
        for x in range(-2, 22): g.set(x, 3, '1'); g.set(x, 4, '!')
        for y in range(-9, 3):
            half = max(0, (y + 9) * 0.55)
            for x in range(round(9.5 - half), round(9.5 + half) + 1): g.set(x + (1 if y < -5 else 0), y, '1')
        for x in range(4, 16): g.set(x, 2, 'g')
        return g, False
    return None, False

def draw_char(c, fx, fy, eq, t=0, h=0, lL=0, lR=0, weapon=None, rest=None):
    """Desenha o personagem com os pés em (fx, fy).
    eq: dict(skin, eyes, hair, hairC, chest, c1, c2, helmet, pants, elem)
    weapon: (sprite, pivô, ângulo, (dx,dy), espelhar) na mão direita. Devolve âncoras."""
    pal = dict(P)
    sk = eq.get('skin', P['s']); pal.update({'s': sk, 'S': shade(sk), 'r': tuple(int(a * .55 + b * .45) for a, b in zip(sk, (224, 100, 90)))})
    pal['e'] = eq.get('eyes', (60, 90, 150))
    hc = eq.get('hairC', P['h']); pal.update({'h': hc, 'H': shade(hc)})
    c1 = eq.get('c1', P['1']); c2 = eq.get('c2', P['2']); pal.update({'1': c1, '!': shade(c1), '2': c2, '@': shade(c2)})
    if 'tier' in eq: pal.update({'m': TIERS[eq['tier']]['W'], 'v': TIERS[eq['tier']]['w'], 'M': shade(TIERS[eq['tier']]['W'])})
    if eq.get('elem'): pal['X'] = ELEM[eq['elem']][1]
    legs_top = fy - 4; tor_top = legs_top - 8; head_top = tor_top - 11 + h; hx = fx - 10
    for x in range(fx - 8, fx + 8):
        for yy, a in ((fy, 60), (fy + 1, 40)): _blend(c, x, yy, (0, 0, 0), a)
    hel, hide_hair = helmet_grid(eq.get('helmet')) if eq.get('helmet') else (None, False)
    front, back = HAIR.get(eq.get('hair', 'Curto'))
    if back and not hide_hair:
        g = G(); back(g); im, (x0, y0) = g.img(pal); paste(c, im, hx + x0, head_top + y0)
    pc = eq.get('pants', P['1'])
    leg = ["o11o", "o!1o", "o11o", "o33o", "oooo"]
    lp = {**pal, '1': pc, '!': shade(pc)}
    for lx, ly in ((fx - 5, legs_top + lL), (fx + 1, legs_top + lR)):
        for y, r in enumerate(leg):
            for x, k in enumerate(r): c.putpixel((lx + x, ly + y), lp[k] + (255,))
    if eq.get('chest') == 'Manto':
        g = G(); g.rows([".111111111111.", "1111!11111!111", "111!1111111!11"])
        im, (x0, y0) = g.img(pal); paste(c, im, fx - 7 + x0, legs_top - 1 + t + y0)
    g = chest_grid(eq.get('chest', 'Túnica')); im, (x0, y0) = g.img(pal); paste(c, im, fx - 5 + x0, tor_top + 1 + t + y0)
    anch = {'L': (fx - 8, tor_top + 6 + t), 'R': (fx + 8, tor_top + 6 + t)}
    hand, _ = G(), None; hand.rows(["sSs", "sSs"]); him, _ = hand.img(pal)
    if weapon:
        spr, pv, ang, off, mir = weapon
        place(c, spr, pv, (anch['R'][0] + off[0], anch['R'][1] + off[1]), ang, mir)
    else:
        paste(c, him, anch['R'][0] - 2, anch['R'][1] - 2)
    paste(c, him, anch['L'][0] - 2, anch['L'][1] - 2)
    for y, r in enumerate(FACE):
        for x, k in enumerate(r):
            if k != '.': c.putpixel((hx + x, head_top + y), pal[k] + (255,))
    if not hide_hair:
        for y, r in enumerate(front):
            for x, k in enumerate(r):
                if k != '.': c.putpixel((hx + x, head_top + y), pal[k] + (255,))
    if hel:
        im, (x0, y0) = hel.img(pal); paste(c, im, hx + x0, head_top + y0)
    return anch

def _blend(c, x, y, col, a):
    if 0 <= x < c.width and 0 <= y < c.height:
        r, g, b, al = c.getpixel((x, y)); t = a / 255
        c.putpixel((x, y), (int(r + (col[0] - r) * t), int(g + (col[1] - g) * t), int(b + (col[2] - b) * t), max(al, a)))

def ground(w, h, seed=7, base=(96, 78, 60)):
    import random
    rnd = random.Random(seed); im = Image.new('RGBA', (w, h), base + (255,))
    for _ in range(w * h // 9):
        x, y = rnd.randrange(w), rnd.randrange(h); d = rnd.choice((-14, 14, -8))
        im.putpixel((x, y), tuple(max(0, v + d) for v in base) + (255,))
    return im
