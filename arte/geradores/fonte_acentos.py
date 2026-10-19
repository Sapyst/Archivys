"""Acrescenta acentos do português à fonte Snide Asides (CC BY 3.0, por caffinate).
Método: renderiza a letra base no tamanho nativo (16 px = 1 pixel por 64 unidades), soma os pixels do acento
desenhado à mão e converte o bitmap de volta em glifo de quadradinhos. Saída: ../fontes/SnideAsidesPT.ttf"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'fontes'); os.makedirs(OUT, exist_ok=True)
PX, SIZE = 64, 16
pil = ImageFont.truetype(SRC, SIZE)

ACC = {  # acentos em pixel (linhas de cima para baixo); traço inclinado como a fonte
    'agudo': ["..##", ".##."], 'grave': ["##..", ".##."], 'circ': ["..#..", ".#.#."],
    'til': [".##.#", "#.##."], 'trema': ["#..#"],
}
MAP = {}
for base, acc in (('a', 'agudo'), ('a', 'grave'), ('a', 'circ'), ('a', 'til'), ('e', 'agudo'), ('e', 'circ'),
                  ('i', 'agudo'), ('o', 'agudo'), ('o', 'circ'), ('o', 'til'), ('u', 'agudo'), ('u', 'trema')):
    for b in (base, base.upper()):
        ch = {'agudo': '́', 'grave': '̀', 'circ': '̂', 'til': '̃', 'trema': '̈'}[acc]
        import unicodedata; MAP[unicodedata.normalize('NFC', b + ch)] = (b, acc)
MAP['ç'] = ('c', 'cedilha'); MAP['Ç'] = ('C', 'cedilha')

def bitmap(ch):
    W, H, ox, base = 40, 40, 8, 26
    im = Image.new('L', (W, H), 0); ImageDraw.Draw(im).text((ox, base), ch, font=pil, fill=255, anchor='ls')
    pts = {(x - ox, base - y) for y in range(H) for x in range(W) if im.getpixel((x, y)) > 127}   # (x, altura acima da base)
    return pts

def strip_dot(pts):
    """Remove o pingo do i: tudo acima da primeira linha vazia vindo de cima."""
    ys = sorted({y for _, y in pts}, reverse=True)
    for a, b in zip(ys, ys[1:]):
        if a - b > 1: return {(x, y) for x, y in pts if y <= b}
    return pts

def compose(base, acc):
    pts = bitmap(base)
    if base == 'i': pts = strip_dot(pts)
    if acc == 'cedilha':
        bottom = [x for x, y in pts if y == min(yy for _, yy in pts)]
        cx = round(sum(bottom) / len(bottom))
        return pts | {(cx, -1), (cx - 1, -2), (cx, -2)}
    top = max(y for _, y in pts); xs = [x for x, y in pts if y >= top - 1]
    cx = (min(xs) + max(xs)) / 2 + 1                       # +1 acompanha a inclinação
    rows = ACC[acc]; w = len(rows[0]); x0 = round(cx - w / 2)
    gap = 2
    for i, r in enumerate(rows):
        for j, c in enumerate(r):
            if c == '#': pts.add((x0 + j, top + gap + (len(rows) - 1 - i)))
    return pts

def glyph_from(pts):
    pen = TTGlyphPen(None)
    for y in sorted({y for _, y in pts}):
        xs = sorted(x for x, yy in pts if yy == y); run = [xs[0]]
        for x in xs[1:] + [None]:
            if x is not None and x == run[-1] + 1: run.append(x); continue
            x0, x1 = run[0] * PX, (run[-1] + 1) * PX; y0, y1 = (y - 1) * PX, y * PX
            pen.moveTo((x0, y0)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y0)); pen.closePath()
            if x is not None: run = [x]
    return pen.glyph()


# ---------- extras: pontuação e símbolos do português ----------
def adv_of(pts): return (max(x for x, _ in pts) + 2) * PX if pts else 4 * PX
def shift(pts, dx=0, dy=0): return {(x + dx, y + dy) for x, y in pts}
def flip_v(pts, mid): return {(x, 2 * mid - y + 1) for x, y in pts}
def flip_hv(pts):
    mx = max(x for x, _ in pts); my = max(y for _, y in pts); mn = min(y for _, y in pts)
    return {(mx - x, my + mn - y - 1) for x, y in pts}
def hand(rows, top):
    return {(j, top - i) for i, r in enumerate(rows) for j, c in enumerate(r) if c == '#'}
EXTRA = {}
dash = bitmap('-'); hy = min(y for _, y in dash); hx0 = min(x for x, _ in dash)
EXTRA['\u2013'] = {(hx0 + i, hy) for i in range(5)}                       # –
EXTRA['\u2014'] = {(hx0 + i, hy) for i in range(9)}                       # —
dot = bitmap('.'); w = max(x for x, _ in dot) + 2
EXTRA['\u2026'] = dot | shift(dot, w) | shift(dot, 2 * w)                 # …
q = bitmap("'"); qq = bitmap('"')
EXTRA['\u2018'] = flip_hv(q) | set(); EXTRA['\u2018'] = shift(flip_hv(q), 0, max(y for _, y in q) - max(y for _, y in flip_hv(q)))
EXTRA['\u2019'] = q; EXTRA['\u201C'] = shift(flip_hv(qq), 0, max(y for _, y in qq) - max(y for _, y in flip_hv(qq))); EXTRA['\u201D'] = qq
ex = bitmap('!'); EXTRA['\u00A1'] = shift(flip_hv(ex), 0, -2)            # ¡
qu = bitmap('?'); EXTRA['\u00BF'] = shift(flip_hv(qu), 0, -2)            # ¿
EXTRA['\u00B0'] = shift(hand([".##.", "#..#", "#..#", ".##."], 10), 2, 0)               # °
EXTRA['\u00AB'] = hand(["..#..#", ".#..#.", "#..#..", ".#..#.", "..#..#"], 5)   # «
EXTRA['\u00BB'] = hand(["#..#..", ".#..#.", "..#..#", ".#..#.", "#..#.."], 5)   # »
for ch, base in (('\u00AA', 'a'), ('\u00BA', 'o')):                      # ª º
    b = bitmap(base); small = {(x // 2 + 2, y // 2) for x, y in b}
    small = shift(small, 0, 10 - max(y for _, y in small)); low = min(y for _, y in small) - 2
    EXTRA[ch] = small | {(x, low) for x in range(min(x for x, _ in small), max(x for x, _ in small) + 1)}

f = TTFont(SRC); cmap = f.getBestCmap(); order = f.getGlyphOrder()
glyf, hmtx = f['glyf'], f['hmtx']
for ch, (base, acc) in MAP.items():
    name = 'uni%04X' % ord(ch); bname = cmap[ord(base)]
    g = glyph_from(compose(base, acc)); glyf[name] = g; g.recalcBounds(glyf)
    hmtx[name] = (hmtx[bname][0], g.xMin if hasattr(g, 'xMin') else 0)
    pass
    for t in f['cmap'].tables:
        if t.isUnicode(): t.cmap[ord(ch)] = name
for ch, pts in EXTRA.items():
    name = 'uni%04X' % ord(ch)
    if ord(ch) in cmap: continue
    g = glyph_from(pts); glyf[name] = g; g.recalcBounds(glyf); hmtx[name] = (adv_of(pts), g.xMin)
    for t in f['cmap'].tables:
        if t.isUnicode(): t.cmap[ord(ch)] = name
for n in list(hmtx.metrics):                                   # corrige avanços negativos do original (.notdef)
    a, l = hmtx[n]
    if a > 32767: hmtx[n] = (448, 0)
f.setGlyphOrder(glyf.glyphOrder); f["maxp"].numGlyphs = len(glyf.glyphOrder)
for rec in f['name'].names:
    if rec.nameID in (1, 4, 6):
        rec.string = {1: 'Snide Asides PT', 4: 'Snide Asides PT', 6: 'SnideAsidesPT'}[rec.nameID]
f['head'].yMax = max(f['head'].yMax, 14 * PX); f['hhea'].ascent = max(f['hhea'].ascent, 14 * PX)
f['OS/2'].usWinAscent = max(f['OS/2'].usWinAscent, 14 * PX)
path = os.path.join(OUT, 'SnideAsidesPT.ttf'); f.save(path)
open(os.path.join(OUT, 'CREDITOS.txt'), 'w').write(
    "Snide Asides — fonte original de caffinate (https://caffinate.itch.io), licença CC BY 3.0.\n"
    "Versão PT: acentos do português acrescentados para Guild Dungeon. Não revender a fonte.\n")
print('ok', len(MAP) + len(EXTRA), 'glifos novos ->', path)
