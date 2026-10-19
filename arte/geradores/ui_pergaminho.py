"""Variante pergaminho da janela pixel art (técnica SDF da skill pixel-ui-procedural).
- pergaminho rasgado: borda irregular (ruído aplicado à distância), queimado nas bordas, manchas de idade.
- pergaminho enrolado: mesmo papel + rolos em cima e embaixo (para cartas, contratos, editais).
Saída: ../ui/"""
import os, math
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ui'); os.makedirs(OUT, exist_ok=True)
OUTL = (52, 34, 22)
BURN = (120, 78, 42); EDGE = (186, 146, 96)
PAPER = (232, 210, 166); PAPER_2 = (220, 194, 148); STAIN = (204, 172, 124)
ROLL_L, ROLL_M, ROLL_D = (224, 198, 150), (190, 158, 110), (138, 104, 66)

def h1(i, seed=0):
    x = math.sin(i * 127.1 + seed * 311.7) * 43758.5453
    return x - math.floor(x)
def noise1(t, seed=0):                      # ruído suave 1D
    i = math.floor(t); f = t - i; f = f * f * (3 - 2 * f)
    return h1(i, seed) * (1 - f) + h1(i + 1, seed) * f
def noise2(x, y, seed=0):                   # ruído de valor 2D (manchas)
    xi, yi = math.floor(x), math.floor(y); xf, yf = x - xi, y - yi
    xf, yf = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    def v(a, b): return h1(a * 57 + b * 131, seed)
    top = v(xi, yi) * (1 - xf) + v(xi + 1, yi) * xf; bot = v(xi, yi + 1) * (1 - xf) + v(xi + 1, yi + 1) * xf
    return top * (1 - yf) + bot * yf

def sd_rr(x, y, w, h, r, m):
    """Distância com sinal até um retângulo arredondado (negativa dentro) + posição ao longo do contorno."""
    cx, cy = (w - 1) / 2, (h - 1) / 2; hx, hy = (w - 1) / 2 - m, (h - 1) / 2 - m
    qx, qy = abs(x - cx) - (hx - r), abs(y - cy) - (hy - r)
    d = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r
    along = (x if qy > qx else y) if (qx <= 0 or qy <= 0) else math.atan2(y - cy, x - cx) * r
    return d, along

def parchment(w, h, r=5, tear=4.0, seed=3):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); px = im.load(); inside = {}
    for y in range(h):
        for x in range(w):
            d, along = sd_rr(x, y, w, h, r, 3)
            rag = (noise1(along * 0.35, seed) * 0.6 + noise1(along * 1.3, seed + 1) * 0.4) * tear   # rasgado
            inside[(x, y)] = d + rag
    for y in range(h):
        for x in range(w):
            e = inside[(x, y)]
            if e > 0:
                if any(inside.get((x + dx, y + dy), 1) <= 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px[x, y] = OUTL + (255,)
                continue
            depth = -e
            if depth < 1.2: col = BURN
            elif depth < 2.6: col = EDGE
            else:
                n = noise2(x / 9, y / 7, seed)
                col = STAIN if n > 0.78 else PAPER_2 if n > 0.6 or (x * 3 + y * 5) % 23 == 0 else PAPER
                if depth < 4.5 and (x + y) % 3 == 0: col = PAPER_2                   # escurece perto da borda
            px[x, y] = col + (255,)
    return im

def roll(w, hgt=7):
    im = Image.new('RGBA', (w, hgt), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, hgt - 1], radius=3, fill=ROLL_M + (255,), outline=OUTL + (255,))
    d.line([3, 1, w - 4, 1], fill=ROLL_L + (255,)); d.line([3, 2, w - 4, 2], fill=ROLL_L + (255,))
    d.line([3, hgt - 2, w - 4, hgt - 2], fill=ROLL_D + (255,))
    for x in (2, w - 3): d.line([x, 1, x, hgt - 2], fill=ROLL_D + (255,))   # espiral nas pontas
    return im

def scroll(w, h):
    paper = parchment(w - 6, h - 6, r=2, tear=1.0, seed=8)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); im.alpha_composite(paper, (3, 3))
    rl = roll(w); im.alpha_composite(rl, (0, 0)); im.alpha_composite(rl, (0, h - rl.height))
    return im

def seal(sz=11):
    im = Image.new('RGBA', (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, sz - 1, sz - 1], fill=(150, 34, 34, 255), outline=(70, 16, 16, 255))
    d.ellipse([3, 3, sz - 4, sz - 4], outline=(196, 70, 60, 255)); d.point((sz // 2 - 1, sz // 2 - 2), fill=(230, 120, 100, 255))
    return im

if __name__ == '__main__':
    S = 5; F = ImageFont.truetype("DejaVuSerif.ttf", 25); FB = ImageFont.truetype("DejaVuSerif-Bold.ttf", 28)
    INK = (60, 36, 22)
    try: base = Image.open(os.path.join(OUT, '..', 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA')
    except Exception: base = Image.new('RGBA', (1024, 1024), (60, 50, 50, 255))

    # 1) rasgado — caixa de diálogo
    W, H = 160, 52; p = parchment(W, H); p.save(os.path.join(OUT, 'pergaminho_dialogo.png'))
    parchment(36, 36, r=4, tear=1.6).save(os.path.join(OUT, 'pergaminho_9slice.png'))
    bg = base.resize((180 * S, 180 * S)).crop((0, 180 * S - 78 * S, 180 * S, 180 * S))
    bg.alpha_composite(p.resize((W * S, H * S), Image.NEAREST), (10 * S, 20 * S))
    d = ImageDraw.Draw(bg)
    d.multiline_text((24 * S, 31 * S), "Um aventureiro deixou este bilhete:\n“Volto em três dias. Guardem minha\ncaneca. — Kael”", font=F, fill=INK, spacing=10)
    bg.convert('RGB').save(os.path.join(OUT, '_previa_pergaminho.png'))

    # 2) enrolado — contrato com selo
    W2, H2 = 110, 130; sc = scroll(W2, H2); sc.save(os.path.join(OUT, 'pergaminho_contrato.png'))
    bg2 = base.resize((140 * S, 140 * S)).crop((0, 0, 140 * S, 140 * S))
    bg2.alpha_composite(sc.resize((W2 * S, H2 * S), Image.NEAREST), (15 * S, 5 * S))
    bg2.alpha_composite(seal().resize((11 * S, 11 * S), Image.NEAREST), ((15 + W2 - 22) * S, (5 + H2 - 24) * S))
    d2 = ImageDraw.Draw(bg2)
    d2.text(((15 + W2 / 2) * S, 20 * S), "CONTRATO", font=FB, fill=INK, anchor='mm')
    d2.line([(30 * S, 26 * S), ((15 + W2 - 15) * S, 26 * S)], fill=(150, 110, 70), width=S)
    d2.multiline_text((27 * S, 31 * S), "Rank: E\nLocal: Moinho velho\nAlvo: ratos gigantes (12)\nPrazo: 2 dias\n\nRecompensa:\n  40 moedas de prata\n  +15 de fama", font=F, fill=INK, spacing=12)
    bg2.convert('RGB').save(os.path.join(OUT, '_previa_contrato.png'))
    print('ok')
