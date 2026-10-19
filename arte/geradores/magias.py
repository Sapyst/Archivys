"""Sistema de magias dos cajados.
- bolt(alvo): projétil sai da esfera do cajado e viaja até QUALQUER ponto do campo (velocidade fixa, não alcance fixo).
  fogo = bola com rastro e explosão · água = orbe que espirra · elétrico = raio instantâneo que encadeia
  · vento = lâmina que atravessa tudo até sair do campo.
- area(centro, raio): a magia vai até o ponto e cobre uma elipse de raio variável.
  fogo = meteoro · água = gêiseres + onda · elétrico = tempestade de raios · vento = tornado.
Saída: ../itens/magias/*.gif"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont
from base import *

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'itens', 'magias'); os.makedirs(OUT, exist_ok=True)
W, H = 200, 120; S = 3
FONT = ImageFont.truetype("DejaVuSans-Bold.ttf", 13)
SMOKE = ((120, 110, 110), (90, 82, 84), (150, 140, 136))
DUST = ((165, 140, 110), (130, 108, 84), (190, 170, 140))

def px(c, x, y, col, a=255):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H:
        if a >= 255: c.putpixel((x, y), tuple(col[:3]) + (255,))
        else:
            r, g, b, _ = c.getpixel((x, y)); t = a / 255
            c.putpixel((x, y), (int(r + (col[0] - r) * t), int(g + (col[1] - g) * t), int(b + (col[2] - b) * t), 255))
def line(c, x0, y0, x1, y1, col, a=255):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(int(n) + 1): px(c, x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, col, a)
def disc(c, x, y, r, col, a=255):
    for yy in range(-int(r) - 1, int(r) + 2):
        for xx in range(-int(r) - 1, int(r) + 2):
            if xx * xx + yy * yy <= r * r + r * 0.8: px(c, x + xx, y + yy, col, a)
def ring(c, x, y, r, col, a=255, ry=0.5, dash=0, phase=0):
    n = int(2 * math.pi * r) + 8
    for s in range(n):
        if dash and (s // dash + phase) % 2: continue
        t = 2 * math.pi * s / n; px(c, x + r * math.cos(t), y + r * ry * math.sin(t), col, a)
def bolt_line(c, x0, y0, x1, y1, e, seed, jag=3):
    d, m, l = ELEM[e]; rnd = random.Random(seed)
    L = max(1, math.hypot(x1 - x0, y1 - y0)); n = max(2, int(L / 5)); nx, ny = -(y1 - y0) / L, (x1 - x0) / L
    pts = [(x0, y0)] + [(x0 + (x1 - x0) * k / n + nx * rnd.uniform(-jag, jag), y0 + (y1 - y0) * k / n + ny * rnd.uniform(-jag, jag)) for k in range(1, n)] + [(x1, y1)]
    for (a, b), (p, q) in zip(pts, pts[1:]): line(c, a + 1, b, p + 1, q, m); line(c, a, b + 1, p, q + 1, d)
    for (a, b), (p, q) in zip(pts, pts[1:]): line(c, a, b, p, q, l)
def in_area(p, cx, cy, R): return ((p[0] - cx) / R) ** 2 + ((p[1] - cy) / (R * 0.5)) ** 2 <= 1

# ---------------- motor de linha do tempo ----------------
class Timeline:
    def __init__(s, elem, dummies):
        s.e = elem; s.fx = []; s.hits = {}; s.pose = []; s.labels = []; s.dummies = dummies; s.t = 0
    def effect(s, start, dur, fn, layer='air'): s.fx.append((start, dur, fn, layer))
    def hit(s, i, start, dur=4):
        for f in range(start, start + dur): s.hits.setdefault(f, set()).add(i)
    def hold(s, n, pose=(-15, (0, 0), 0, 0), label=None):
        for _ in range(n): s.pose.append(pose); s.labels.append(label or s.labels[-1] if s.labels else label)
        s.t += n

CASTER = (28, 84)
EQ = dict(skin=(234, 191, 152), hair='Longo', hairC=(220, 220, 230), chest='Manto', helmet='Chapéu de mago', pants=(60, 50, 90))
def hand_R(t=0): return (CASTER[0] + 8, CASTER[1] - 4 - 8 + 6 + t)
def orb_at(pose):
    ang, off, t, _ = pose; hx, hy = hand_R(t); v = rot((0, -12), ang)
    return (hx + off[0] + v[0], hy + off[1] + v[1])
def aim(target, t=0):
    hx, hy = hand_R(t); return math.degrees(math.atan2(-(target[1] - (hy - 6)), target[0] - hx)) - 90

def charge_fx(tl, start, n, pose):
    d, m, l = ELEM[tl.e]
    def f(c, k):
        ox, oy = orb_at(pose)
        for j in range(6):
            a = math.radians(j * 60 + k * 25); r = max(1, 6 - 2 * k)
            px(c, ox + r * math.cos(a), oy + r * math.sin(a), l if j % 2 else m)
        disc(c, ox, oy, 1 + k % 2, l, 120)
    tl.effect(start, n, f)

def impact(tl, start, x, y, big=1.0):
    d, m, l = ELEM[tl.e]; e = tl.e
    if e == 'fogo':
        def f(c, k):
            if k < 4: disc(c, x, y, (2 + k * 1.6) * big, [l, m, m, d][k]); disc(c, x, y, (1 + k) * big * .6, l)
            rnd = random.Random(k)
            for j in range(8): a = rnd.uniform(0, 6.3); r = (2 + k * 1.8) * big; px(c, x + r * math.cos(a), y + r * math.sin(a) * .7 - k, SMOKE[j % 3] if k > 2 else m, 255 - k * 25)
        tl.effect(start, 8, f)
        tl.effect(start, 28, lambda c, k: [px(c, x + dx, y + 3 + dy, (50, 38, 32), 160 - k * 5) for dx in range(-3, 4) for dy in (-1, 0, 1) if dx * dx + 4 * dy * dy <= 10], 'ground')
    elif e == 'agua':
        def f(c, k):
            ring(c, x, y + 2, 2 + k * 1.5 * big, l if k % 2 else m, 255 - k * 30)
            for j in range(8):
                a = j * math.pi / 4; r = (2 + k * 1.3) * big
                px(c, x + r * math.cos(a), y - 4 * math.sin(math.pi * k / 7) + r * .4 * math.sin(a) - (3 if j % 2 else 0), l if j % 2 else m)
        tl.effect(start, 7, f)
        tl.effect(start, 30, lambda c, k: [px(c, x + dx, y + 3 + dy, ELEM['agua'][0], 140 - k * 4) for dx in range(-4, 5) for dy in (-1, 0, 1) if dx * dx + 6 * dy * dy <= 16], 'ground')
    elif e == 'eletrico':
        def f(c, k):
            rnd = random.Random(k + 70)
            for j in range(10): a = rnd.uniform(0, 6.3); r = rnd.uniform(1, 3 + k * 1.5) * big; px(c, x + r * math.cos(a), y + r * math.sin(a) * .8, rnd.choice((l, m, (255, 255, 255))))
            if k < 2: disc(c, x, y, 2, l)
        tl.effect(start, 5, f)
    else:
        def f(c, k):
            for j in range(3):
                a = math.radians(k * 60 + j * 120); r = 2 + k
                px(c, x + r * math.cos(a), y + r * .5 * math.sin(a), l); px(c, x + (r - 1) * math.cos(a + .4), y + (r - 1) * .5 * math.sin(a + .4), m)
            for j in range(4): px(c, x + random.Random(k * 5 + j).randint(-5, 5), y + 4, DUST[j % 3])
        tl.effect(start, 6, f)

def draw_projectile(c, e, x, y, dx, dy, k):
    d, m, l = ELEM[e]
    if e == 'fogo':
        for j in range(1, 8):
            jx = random.Random(k * 13 + j).uniform(-1, 1)
            px(c, x - dx * j * 1.6 - dy * jx, y - dy * j * 1.6 + dx * jx, (m if j < 3 else d if j < 5 else SMOKE[j % 3]), 255 - j * 25)
        disc(c, x, y, 2, m); disc(c, x, y, 1, l); px(c, x + dx * 2, y + dy * 2, d)
    elif e == 'agua':
        for j in range(3): px(c, x - dx * (4 + 3 * j) - dy * (j % 2 * 2 - 1), y - dy * (4 + 3 * j) + dx * (j % 2 * 2 - 1), m)
        disc(c, x, y, 2, m); px(c, x - 1, y - 1, l); px(c, x, y - 1, l)
    elif e == 'vento':
        nx, ny = -dy, dx
        for a in range(-70, 71, 12):
            aa = math.radians(a); cs, sn = math.cos(aa), math.sin(aa)
            px(c, x + (dx * cs + nx * sn) * 4 - dx * 2, y + (dy * cs + ny * sn) * 4 - dy * 2, m)
            px(c, x + (dx * cs + nx * sn) * 3 - dx * 2, y + (dy * cs + ny * sn) * 3 - dy * 2, l)
        for s in (-2, 2): line(c, x - dx * 9 + nx * s, y - dy * 9 + ny * s, x - dx * 5 + nx * s, y - dy * 5 + ny * s, l, 180)

def cast_bolt(tl, foot, label):
    target = (foot[0], foot[1] - 8)
    up = (10, (-1, -3), 0, 0)
    charge_fx(tl, tl.t, 3, up); tl.hold(3, up, label)
    rel = (aim(target), (2, -1), 0, 0); start = tl.t; sx, sy = orb_at(rel)
    tx, ty = target; L = math.hypot(tx - sx, ty - sy); dx, dy = (tx - sx) / L, (ty - sy) / L
    if tl.e == 'eletrico':
        # raio instantâneo + corrente para os 2 bonecos mais próximos do alvo
        chain = [foot]; rest = [p for p in tl.dummies if p != foot]
        for _ in range(2):
            if not rest: break
            nxt = min(rest, key=lambda p: math.hypot(p[0] - chain[-1][0], p[1] - chain[-1][1]))
            if math.hypot(nxt[0] - chain[-1][0], nxt[1] - chain[-1][1]) > 70: break
            chain.append(nxt); rest.remove(nxt)
        pts = [(sx, sy)] + [(p[0], p[1] - 8) for p in chain]
        for j, (a, b) in enumerate(zip(pts, pts[1:])):
            tl.effect(start + j * 2, 3, lambda c, k, a=a, b=b, j=j: bolt_line(c, a[0], a[1], b[0], b[1], 'eletrico', k * 7 + j))
            impact(tl, start + j * 2, b[0], b[1]); tl.hit(tl.dummies.index(chain[j]), start + j * 2)
        tl.hold(3, rel); tl.hold(4 + 2 * len(chain)); return
    speed = 9 if tl.e == 'vento' else 7
    if tl.e == 'vento':
        # atravessa: segue até sair do campo, acertando quem estiver no caminho
        n = 0; x, y = sx, sy
        while -10 < x < W + 10 and -10 < y < H + 10: x += dx * speed; y += dy * speed; n += 1
        tl.effect(start, n, lambda c, k: draw_projectile(c, 'vento', sx + dx * speed * k, sy + dy * speed * k, dx, dy, k))
        for i, p in enumerate(tl.dummies):
            q = (p[0], p[1] - 8); proj = (q[0] - sx) * dx + (q[1] - sy) * dy
            if proj > 0 and abs((q[0] - sx) * dy - (q[1] - sy) * dx) < 6:
                f0 = start + int(proj / speed); tl.hit(i, f0); impact(tl, f0, q[0], q[1])
        tl.hold(3, rel); tl.hold(max(2, n - 3) + 3); return
    n = max(1, math.ceil(L / speed))
    tl.effect(start, n, lambda c, k: draw_projectile(c, tl.e, sx + dx * speed * k, sy + dy * speed * k, dx, dy, k))
    impact(tl, start + n, tx, ty)
    for i, p in enumerate(tl.dummies):
        if math.hypot(p[0] - tx, p[1] - 8 - ty) < 7: tl.hit(i, start + n)
    tl.hold(3, rel); tl.hold(n - 3 + 8 if n > 3 else 8)

def cast_area(tl, center, R, label):
    d, m, l = ELEM[tl.e]; cx, cy = center; e = tl.e
    up = (0, (0, -5), 0, 0)
    charge_fx(tl, tl.t, 4, up)
    tl.effect(tl.t, 4, lambda c, k: ring(c, cx, cy, R * min(1, (k + 1) / 3), m, 140 + 30 * (k % 2), dash=3, phase=k), 'ground')
    tl.hold(4, up, label)
    rel = (aim(center), (2, -2), 0, 0); s = tl.t; N = 14
    tl.effect(s, N, lambda c, k: ring(c, cx, cy, R, d, 120, dash=2, phase=k), 'ground')
    rnd = random.Random(int(R * 10 + cx))
    if e == 'fogo':
        # meteoro cai na área; explosão preenche a elipse; tufos de fogo queimam
        sx, sy = cx - 40, -10
        tl.effect(s, 4, lambda c, k: (draw_projectile(c, 'fogo', sx + (cx - sx) * k / 4, sy + (cy - sy) * k / 4, .71, .71, k), disc(c, sx + (cx - sx) * k / 4, sy + (cy - sy) * k / 4, 3 + R / 12, m)))
        pts = [(cx + rnd.uniform(-1, 1) * R, cy + rnd.uniform(-1, 1) * R * .5) for _ in range(int(R * R * 1.2))]
        pts = [p for p in pts if in_area(p, cx, cy, R)]
        def boom(c, k):
            fr = min(1, (k + 1) / 3)
            for j, (x, y) in enumerate(pts):
                if in_area((x, y), cx, cy, R * fr):
                    col = (l, m, d)[(j + k) % 3] if k < 5 else SMOKE[j % 3]
                    px(c, x, y - (k % 3 == j % 3), col, 255 - max(0, k - 5) * 40)
        tl.effect(s + 4, 9, boom)
        flames = pts[::4]
        def burn(c, k):
            for j, (x, y) in enumerate(flames):
                hgt = 1 + (j + k) % 3
                for z in range(hgt): px(c, x, y - z, (l, m, d)[min(2, z)])
        tl.effect(s + 8, 14, burn)
        tl.effect(s + 4, 40, lambda c, k: [px(c, x, y + 1, (50, 38, 32), 150 - k * 3) for x, y in pts], 'ground')
        hit_from, hit_len = s + 4, 10
    elif e == 'agua':
        nG = max(2, int(R / 6)); gs = []
        while len(gs) < nG:
            p = (cx + rnd.uniform(-1, 1) * R * .8, cy + rnd.uniform(-1, 1) * R * .4)
            if in_area(p, cx, cy, R): gs.append((p, rnd.randint(0, 3)))
        def geysers(c, k):
            for (x, y), off in gs:
                kk = k - off
                if 0 <= kk < 9:
                    h = int((R / 2 + 6) * math.sin(math.pi * kk / 9))
                    for z in range(h):
                        for ddx in (-1, 0, 1): px(c, x + ddx, y - z, l if ddx == 0 else m)
                    for j in range(6):
                        a = j * math.pi / 3; px(c, x + (2 + kk) * math.cos(a), y - h + kk * .8 + abs(math.sin(a)) * 2, l if j % 2 else m)
        tl.effect(s, 13, geysers)
        tl.effect(s, 10, lambda c, k: (ring(c, cx, cy, R * (k + 1) / 10, l, 255 - k * 15), ring(c, cx, cy, R * (k + 1) / 10 - 2, m, 200 - k * 15)))
        tl.effect(s, 45, lambda c, k: [px(c, cx + x, cy + y * .5, d, 120 - k * 2) for x in range(-int(R), int(R) + 1, 2) for y in range(-int(R), int(R) + 1, 2) if x * x + y * y <= R * R * .8], 'ground')
        hit_from, hit_len = s, 11
    elif e == 'eletrico':
        strikes = []
        for k in range(12):
            for _ in range(1 + int(R / 14)):
                while True:
                    p = (cx + rnd.uniform(-1, 1) * R, cy + rnd.uniform(-1, 1) * R * .5)
                    if in_area(p, cx, cy, R): break
                strikes.append((k, p))
        def storm(c, k):
            for kk, (x, y) in strikes:
                if kk == k: bolt_line(c, x + rnd.uniform(-6, 6) if False else x + ((k * 7) % 9 - 4), 0, x, y, 'eletrico', k * 11 + int(x), 2.5); disc(c, x, y, 1, l)
                elif kk == k - 1:
                    for j in range(5): px(c, x + ((j * 37 + k) % 7 - 3), y + ((j * 13) % 3 - 1), (l, m, (255, 255, 255))[j % 3])
        tl.effect(s, 13, storm)
        tl.effect(s, 13, lambda c, k: [px(c, x, y + 1, (60, 50, 40), 160) for kk, (x, y) in strikes if kk <= k], 'ground')
        hit_from, hit_len = s, 12
    else:
        Hh = int(R * 1.3 + 10)
        def tornado(c, k):
            grow = min(1, (k + 1) / 4); fade = 1 if k < 11 else (14 - k) / 3
            for z in range(0, int(Hh * grow), 2):
                y = cy - z; rx = (1.5 + z * (R / Hh) * .7) * fade + 1
                for j in range(4):
                    a = math.radians(k * 55 + z * 18 + j * 90)
                    px(c, cx + rx * math.cos(a), y + .4 * rx * math.sin(a), l if math.sin(a) > 0 else m)
            for j in range(int(R)):
                a = math.radians(j * 360 / R + k * 25); r = R * (0.6 + 0.4 * ((j * 7) % 5) / 5)
                px(c, cx + r * math.cos(a), cy + r * .5 * math.sin(a), DUST[j % 3])
        tl.effect(s, 14, tornado)
        hit_from, hit_len = s + 2, 11
    for i, p in enumerate(tl.dummies):
        if in_area(p, cx, cy, R + 2): tl.hit(i, hit_from, hit_len)
    tl.hold(4, rel); tl.hold(N + 2)

# ---------------- render ----------------
DUMMY = G(); DUMMY.rows(["..yyy..", ".yYyyy.", ".yyyyy.", "..yyy..", "bbbbbbb", "..yyy..", "..yYy..", "..yyy..", "...b...", "...b...", "...b..."])
DIM, _ = DUMMY.img(); DFL, _ = DUMMY.img({k: (255, 255, 255) for k in 'ybY'})
NAMES = {'fogo': 'Cajado de fogo', 'agua': 'Cajado de água', 'eletrico': 'Cajado elétrico', 'vento': 'Cajado de vento'}

def build(e):
    dummies = [(70, 78), (176, 46), (104, 104), (150, 74), (124, 40)]
    tl = Timeline(e, dummies); tl.hold(6, label=f'{NAMES[e]} · parado')
    cast_bolt(tl, dummies[0], 'Bolt · alvo perto')
    cast_bolt(tl, dummies[1], 'Bolt · alvo longe')
    cast_area(tl, (104, 102), 10, 'Área · raio 10')
    cast_area(tl, (156, 62), 28, 'Área · raio 28')
    tl.hold(6, label='')
    return tl

def render(tl):
    bg = ground(W, H, 3); frames = []; staff, pv = weapon_sprite('Cajado', 'Ferro', tl.e)
    for f in range(tl.t):
        c = bg.copy(); active = [(fn, f - st, lay) for st, du, fn, lay in tl.fx if st <= f < st + du]
        for fn, k, lay in active:
            if lay == 'ground': fn(c, k)
        actors = [(p[1], 'd', i, p) for i, p in enumerate(tl.dummies)] + [(CASTER[1], 'c', 0, CASTER)]
        for _, kind, i, p in sorted(actors):
            if kind == 'd':
                hit = i in tl.hits.get(f, ())
                im = DFL if hit and f % 2 == 0 else DIM; sh = (1 if f % 2 else -1) if hit else 0
                for x in range(-3, 4): px(c, p[0] + x, p[1] + 1, (0, 0, 0), 60)
                c.paste(im, (p[0] - 4 + sh, p[1] - im.height + 1), im)
            else:
                ang, off, t, h = tl.pose[f]
                draw_char(c, p[0], p[1], {**EQ, 'elem': tl.e, 'c1': {'fogo': (150, 50, 40), 'agua': (40, 80, 150), 'eletrico': (90, 60, 140), 'vento': (50, 110, 70)}[tl.e]},
                          t=t, h=h, weapon=(staff, pv, ang, off, False))
        for fn, k, lay in active:
            if lay == 'air': fn(c, k)
        im = c.convert('RGB').resize((W * S, H * S), Image.NEAREST); d = ImageDraw.Draw(im)
        if tl.labels[f]: d.text((8, 6), tl.labels[f], font=FONT, fill=(245, 235, 220), stroke_width=2, stroke_fill=(30, 22, 25))
        frames.append(im)
    return frames

if __name__ == '__main__':
    for e in ELEM:
        fr = render(build(e))
        fr[0].save(os.path.join(OUT, f'magia_{e}.gif'), save_all=True, append_images=fr[1:], duration=70, loop=0)
        print(e, len(fr))
