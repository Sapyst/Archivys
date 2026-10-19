"""Gera props (caixas, barris, mesas, cadeiras), armas equipáveis (ícone + na mão) e armaduras
(capacete + peitoral, mostrados no personagem). Saída em ../itens/."""
import os, math
from PIL import Image, ImageDraw, ImageFont
from base import *

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'itens')
for d in ('props', 'armas', 'armaduras'): os.makedirs(os.path.join(ROOT, d), exist_ok=True)
FONT = ImageFont.truetype("DejaVuSans-Bold.ttf", 12)
BG = (40, 32, 38)

def label_sheet(cells, cols, cw, ch, S, path, bg=BG, title=None):
    """cells: [(img, label)] → folha com cada item centrado e legenda embaixo."""
    rows = (len(cells) + cols - 1) // cols; top = 24 if title else 0
    sheet = Image.new('RGB', (cols * cw * S, rows * (ch * S + 18) + top), bg); d = ImageDraw.Draw(sheet)
    if title: d.text((8, 5), title, font=FONT, fill=(232, 160, 74))
    for i, (im, lab) in enumerate(cells):
        x, y = (i % cols) * cw * S, (i // cols) * (ch * S + 18) + top
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        sheet.paste(big, (x + (cw * S - big.width) // 2, y + (ch * S - big.height) // 2), big)
        d.text((x + cw * S // 2, y + ch * S + 8), lab, font=FONT, fill=(236, 226, 214), anchor='mm')
    sheet.save(path); return sheet

# ================= PROPS =================
def crate(w=14, h=14, top=4, metal=False):
    g = G(); g.rect(0, 0, w, top, 'q')
    for x in range(3, w - 1, 4): g.rect(x, 0, 1, top, 't')
    g.rect(0, top, w, h - top, 't')
    for x0, x1 in ((0, w), ):
        g.rect(0, top, w, 1, 'd'); g.rect(0, h - 1, w, 1, 'd'); g.rect(0, top, 1, h - top, 'd'); g.rect(w - 1, top, 1, h - top, 'd')
    n = h - top - 3
    for i in range(n + 1): g.set(1 + round(i * (w - 3) / n), top + 1 + i, 'T')
    if metal:
        for cx, cy in ((0, top), (w - 2, top), (0, h - 2), (w - 2, h - 2)): g.rect(cx, cy, 2, 2, 'm')
        for cx in (0, w - 2): g.rect(cx, 0, 2, 1, 'M')
    return g

def barrel(w=12, h=16, kind='fechado'):
    g = G(); cx = (w - 1) / 2
    for y in range(2, h):
        half = w / 2 - (1 if y < 4 or y > h - 3 else 0)
        for x in range(round(cx - half + .5), round(cx + half - .5) + 1):
            rel = (x - cx) / half; g.set(x, y, 'q' if rel < -0.45 else 't' if rel < 0.4 else 'T')
    for by in (4, h - 4):
        for x in range(0, w):
            if (x, by) in g.m: g.set(x, by, 'm' if x < cx - 2 else 'M')
    top = {'fechado': ('T', 'd'), 'agua': ('a', 'd'), 'vinho': ('C', 'd'), 'polvora': ('T', 'd')}[kind]
    g.ell(cx, 2, w / 2 - 1, 2, top[0], ring=top[1])
    if kind == 'fechado': g.rect(round(cx) - 1, 1, 1, 3, 't')
    if kind == 'agua': g.set(cx - 2, 2, 'n')
    if kind == 'polvora':
        g.ell(cx, 9, 2.2, 2.2, 'c'); g.set(round(cx), 9, 'n')
    return g

def table(tw=20, td=8, kind='retangular'):
    g = G()
    if kind == 'redonda':
        g.rect(tw // 2 - 1, td, 3, 7, 'd'); g.rect(tw // 2 - 3, td + 6, 7, 1, 'd')
        g.ell(tw / 2 - .5, td / 2 + 1, tw / 2, td / 2 + .5, 'T'); g.ell(tw / 2 - .5, td / 2, tw / 2, td / 2, 'q')
        for x in range(3, tw - 3, 4): g.set(x, td // 2, 't')
        return g
    if kind == 'toalha':
        g.rect(1, td + 4, 2, 3, 'd'); g.rect(tw - 3, td + 4, 2, 3, 'd')
        g.rect(0, 0, tw, td, 'n'); g.rect(0, td, tw, 4, 'n')
        for x in range(1, tw, 3): g.rect(x, td, 1, 4, 'N')
        g.rect(2, 2, tw - 4, 1, 'c'); return g
    g.rect(1, td + 2, 2, 5, 'd'); g.rect(tw - 3, td + 2, 2, 5, 'd')
    g.rect(0, 0, tw, td, 'q')
    for x in range(4, tw - 1, 5): g.rect(x, 0, 1, td, 't')
    g.rect(0, td, tw, 2, 'T')
    if kind == 'banquete': g.set(4, 3, 'g'); g.set(tw - 5, 4, 'a'); g.rect(tw // 2 - 2, 2, 4, 3, 'n')
    return g

def chair(kind='cadeira'):
    g = G()
    if kind == 'banquinho':
        g.rect(1, 3, 1, 6, 'd'); g.rect(7, 3, 1, 6, 'd'); g.rect(4, 4, 1, 6, 'd')
        g.ell(4, 2, 4.5, 2, 'q'); g.rect(0, 3, 9, 1, 'T'); return g
    if kind == 'banco':
        g.rect(0, 0, 22, 3, 'q'); g.rect(0, 3, 22, 1, 'T')
        for x in (1, 19): g.rect(x, 4, 2, 4, 'd'); return g
    g.rect(1, 0, 8, 7, 't')
    for x in (3, 6): g.rect(x, 1, 1, 6, 'T')
    g.rect(1, 0, 8, 1, 'q')
    seat = 'c' if kind == 'acolchoada' else 'q'
    g.rect(0, 7, 10, 3, seat); g.rect(0, 10, 10, 1, 'C' if kind == 'acolchoada' else 'T')
    g.rect(0, 11, 2, 4, 'd'); g.rect(8, 11, 2, 4, 'd')
    if kind == 'trono':
        g.rect(0, -3, 10, 3, 'g'); g.set(4, -4, 'g'); g.set(5, -4, 'g'); g.set(4, -2, 'c'); g.set(5, -2, 'c')
    return g

PROPS = [
    ('Caixa pequena', crate(10, 10, 3)), ('Caixa', crate()), ('Caixa grande', crate(18, 16, 5)), ('Caixa reforçada', crate(14, 14, 4, True)),
    ('Barril', barrel()), ('Barril de água', barrel(kind='agua')), ('Barril de vinho', barrel(kind='vinho')), ('Barril de pólvora', barrel(kind='polvora')),
    ('Mesa', table()), ('Mesa redonda', table(16, 9, 'redonda')), ('Mesa com toalha', table(20, 7, 'toalha')), ('Mesa de banquete', table(28, 9, 'banquete')),
    ('Cadeira', chair()), ('Cadeira acolchoada', chair('acolchoada')), ('Banquinho', chair('banquinho')), ('Banco', chair('banco')),
]
for name, g in PROPS:
    im, _ = g.img(); im.save(os.path.join(ROOT, 'props', name.lower().replace(' ', '_') + '.png'))
label_sheet([(g.img()[0], n) for n, g in PROPS], 4, 34, 24, 5, os.path.join(ROOT, 'props', '_folha_props.png'), title='Props')

# ================= ARMAS =================
NAMES = ['Adaga', 'Espada', 'Espadão', 'Machado', 'Maça', 'Lança', 'Arco']
def icon(name, tier, elem='fogo'):
    im, _ = weapon_sprite(name, tier, elem, hand=False)
    im = im.rotate(-45 if name != 'Arco' else -20, resample=Image.NEAREST, expand=True)
    slot = Image.new('RGBA', (30, 30), (0, 0, 0, 0)); d = ImageDraw.Draw(slot)
    d.rectangle([0, 0, 29, 29], fill=(58, 46, 54, 255), outline=(90, 74, 82, 255))
    bb = im.getbbox(); im = im.crop(bb)
    if im.width > 28 or im.height > 28: im = im.resize((min(28, im.width), min(28, im.height)), Image.NEAREST)
    slot.paste(im, ((30 - im.width) // 2, (30 - im.height) // 2), im); return slot
cells = []
for tier in TIERS:
    for n in NAMES: cells.append((icon(n, tier), f'{n}'))
label_sheet(cells, 7, 32, 32, 4, os.path.join(ROOT, 'armas', '_icones_armas.png'), title='Armas · linhas: Bronze, Ferro, Mithril, Obsidiana')
cells = [(icon('Cajado', 'Ferro', e), f'Cajado {n}') for e, n in (('fogo', 'de fogo'), ('agua', 'de água'), ('eletrico', 'elétrico'), ('vento', 'de vento'))]
label_sheet(cells, 4, 34, 32, 4, os.path.join(ROOT, 'armas', '_icones_cajados.png'), title='Cajados')
for tier in TIERS:
    for n in NAMES:
        im, _ = weapon_sprite(n, tier); im.save(os.path.join(ROOT, 'armas', f'{n.lower()}_{tier.lower()}.png'))
for e in ELEM:
    im, _ = weapon_sprite('Cajado', 'Ferro', e); im.save(os.path.join(ROOT, 'armas', f'cajado_{e}.png'))

# armas equipadas (na mão)
HERO = dict(skin=(234, 191, 152), hair='Rabo', hairC=(178, 58, 58), chest='Couro', pants=(80, 70, 90), c1=(120, 50, 50))
cells = []
for n in NAMES + ['Cajado']:
    c = Image.new('RGBA', (48, 50), (0, 0, 0, 0)); spr, pv = weapon_sprite(n, 'Ferro', 'fogo')
    ang = 0 if n in ('Arco',) else (-15 if n in ('Cajado', 'Lança') else -45)
    draw_char(c, 22, 44, HERO, weapon=(spr, pv, ang, (2, -2) if n == 'Arco' else (0, 0), n not in ('Arco', 'Cajado', 'Machado')))
    cells.append((c, n))
label_sheet(cells, 4, 48, 50, 4, os.path.join(ROOT, 'armas', '_armas_equipadas.png'), title='Armas equipadas (mão = pegada)')

# ================= ARMADURAS =================
CHESTS = ['Túnica', 'Couro', 'Malha', 'Placas', 'Manto']
HELMS = [None, 'Capuz de couro', 'Elmo de ferro', 'Elmo fechado', 'Capuz', 'Chapéu de mago']
BASE = dict(skin=(214, 168, 128), hair='Curto', hairC=(74, 46, 34), pants=(70, 60, 80), c1=(60, 90, 150), c2=(230, 220, 200), elem='fogo')
cells = []
for ch in CHESTS:
    for hm in HELMS:
        c = Image.new('RGBA', (40, 50), (0, 0, 0, 0)); draw_char(c, 20, 45, {**BASE, 'chest': ch, 'helmet': hm})
        cells.append((c, ''))
sheet = label_sheet(cells, 6, 40, 50, 3, os.path.join(ROOT, 'armaduras', '_combinacoes.png'))
# rótulos de linha/coluna
lab = Image.new('RGB', (sheet.width + 110, sheet.height + 26), BG); lab.paste(sheet, (110, 26)); d = ImageDraw.Draw(lab)
for j, hm in enumerate(HELMS): d.text((110 + j * 120 + 60, 13), hm or 'Sem capacete', font=FONT, fill=(232, 160, 74), anchor='mm')
for i, ch in enumerate(CHESTS): d.text((8, 26 + i * (150 + 18) + 75), ch, font=FONT, fill=(232, 160, 74), anchor='lm')
lab.save(os.path.join(ROOT, 'armaduras', '_combinacoes.png'))
# tiers de metal
cells = []
for tier in TIERS:
    c = Image.new('RGBA', (40, 50), (0, 0, 0, 0)); draw_char(c, 20, 45, {**BASE, 'chest': 'Placas', 'helmet': 'Elmo fechado', 'tier': tier})
    cells.append((c, tier))
label_sheet(cells, 4, 40, 50, 4, os.path.join(ROOT, 'armaduras', '_placas_por_material.png'), title='Placas + elmo fechado por material')
# ícones de item (peça solta)
cells = []
for ch in CHESTS[1:]:
    im, _ = chest_grid(ch).img(BASE and {'1': BASE['c1'], '!': shade(BASE['c1']), 'X': ELEM['fogo'][1]}); cells.append((im, ch))
for hm in HELMS[1:]:
    im, _ = helmet_grid(hm)[0].img({'1': BASE['c1'], '!': shade(BASE['c1'])}); cells.append((im, hm))
label_sheet(cells, 5, 28, 28, 4, os.path.join(ROOT, 'armaduras', '_icones_armaduras.png'), title='Peças (ícones)')

# ================= CENA =================
W, H = 200, 120
scene = Image.new('RGBA', (W, H), (0, 0, 0, 255)); d = ImageDraw.Draw(scene)
for y in range(H):
    for x in range(W):
        plank = (y // 6) % 2; seam = (x + (y // 6) * 7) % 23 == 0 or y % 6 == 0
        col = (110, 74, 46) if plank else (120, 82, 52)
        if seam: col = (80, 52, 34)
        scene.putpixel((x, y), col + (255,))
def put(g, x, y, pal=None):
    im, _ = g.img(pal); scene.paste(im, (x, y - im.height), im)
items = [(crate(18, 16, 5), 8, 34), (crate(), 26, 36), (crate(10, 10, 3), 14, 44), (barrel(), 176, 32), (barrel(kind='agua'), 186, 40),
         (barrel(kind='polvora'), 166, 44), (chair(), 66, 62), (table(28, 9, 'banquete'), 76, 70), (chair(), 108, 62),
         (table(16, 9, 'redonda'), 140, 96), (chair('banquinho'), 134, 104), (chair('banquinho'), 156, 104), (chair('banco'), 30, 110), (chair('trono'), 96, 26)]
for g, x, y in sorted(items, key=lambda i: i[2]): put(g, x, y)
heroes = [({**BASE, 'chest': 'Placas', 'helmet': 'Elmo de ferro', 'hairC': (40, 34, 40)}, 60, 92, 'Espadão'),
          ({**BASE, 'chest': 'Manto', 'helmet': 'Chapéu de mago', 'c1': (70, 50, 120), 'elem': 'eletrico', 'hair': 'Longo', 'hairC': (220, 220, 230)}, 120, 112, 'Cajado'),
          ({**BASE, 'chest': 'Couro', 'helmet': 'Capuz', 'c1': (50, 100, 60), 'skin': (138, 90, 59)}, 180, 82, 'Arco')]
for eq, x, y, wn in heroes:
    spr, pv = weapon_sprite(wn, 'Ferro', eq.get('elem', 'fogo'))
    draw_char(scene, x, y, eq, weapon=(spr, pv, 0 if wn == 'Arco' else -15 if wn == 'Cajado' else -50, (2, -2) if wn == 'Arco' else (0, 0), wn == 'Espadão'))
scene.convert('RGB').resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(ROOT, '_cena_taverna.png'))
print('itens ok')
