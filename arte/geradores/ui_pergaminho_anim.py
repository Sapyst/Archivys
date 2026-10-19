"""Animação do rolo de pergaminho: fechado (lacrado) → selo rompe → abre a partir do centro com os rolos
girando → texto aparece → fecha de volta. Saída: ../ui/pergaminho_abrindo.gif + spritesheet para Godot."""
import os, math
from PIL import Image, ImageDraw, ImageFont
from ui_pergaminho import parchment, OUTL, ROLL_L, ROLL_M, ROLL_D, OUT, seal

W, H = 110, 130          # tamanho do pergaminho aberto (nativo)
RH = 8                   # altura do rolo
S = 5
INK = (60, 36, 22)
PAPER = parchment(W - 8, H - 2 * RH + 4, r=2, tear=1.0, seed=8)

def roll(w, phase, RH=RH):
    """Rolo com listras que deslizam conforme 'phase' → parece girar. RH maior = mais papel enrolado."""
    im = Image.new('RGBA', (w, RH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, RH - 1], radius=3, fill=ROLL_M + (255,), outline=OUTL + (255,))
    rows = [ROLL_L, ROLL_L, ROLL_M, ROLL_M, ROLL_D, ROLL_M]            # bandas de luz em volta do cilindro
    for y in range(1, RH - 1):
        col = rows[(y + phase) % len(rows)]
        d.line([3, y, w - 4, y], fill=col + (255,))
    for x in (2, w - 3): d.line([x, 1, x, RH - 2], fill=ROLL_D + (255,))   # pontas em espiral
    d.line([1, RH // 2, 1, RH // 2], fill=(217, 164, 65, 255)); d.line([w - 2, RH // 2, w - 2, RH // 2], fill=(217, 164, 65, 255))
    return im

def ribbon_closed(img, cx, cy):
    d = ImageDraw.Draw(img)
    d.rectangle([cx - 2, cy - RH - 6, cx + 2, cy + RH + 6], fill=(150, 34, 34, 255), outline=(70, 16, 16, 255))

def frame(open_frac, phase, sealed=False, seal_crack=0):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cy = H // 2; ph = int((PAPER.height) * open_frac)                   # papel visível, aberto do centro
    if ph > 0:
        top = (PAPER.height - ph) // 2
        img.alpha_composite(PAPER.crop((0, top, PAPER.width, top + ph)), (4, cy - ph // 2))
    rh = RH + round(6 * (1 - open_frac))          # rolo engorda quando fechado (papel enrolado)
    r1 = roll(W, phase, rh); r2 = roll(W, -phase, rh)
    y1 = cy - ph // 2 - rh + 2; y2 = cy + (ph - ph // 2) - 2
    img.alpha_composite(r1, (0, y1)); img.alpha_composite(r2, (0, y2))
    if sealed:
        ribbon_closed(img, W // 2, cy)
        sl = seal(); img.alpha_composite(sl, (W // 2 - 5, cy - 5))
        if seal_crack:
            d = ImageDraw.Draw(img); d.line([W // 2 - 4, cy - 3, W // 2 + 3, cy + 4], fill=(40, 10, 10, 255))
            if seal_crack > 1:
                for dx, dy in ((-7, -6), (7, 5), (-6, 7)): d.point((W // 2 + dx, cy + dy), fill=(150, 34, 34, 255))
    return img

def ease_out(t): return 1 - (1 - t) ** 3
def ease_in(t): return t ** 3

TEXT = ["CONTRATO", "", "Rank: E", "Local: Moinho velho", "Alvo: ratos gigantes (12)", "Prazo: 2 dias", "",
        "Recompensa:", "  40 moedas de prata", "  +15 de fama"]
F = ImageFont.truetype("DejaVuSerif.ttf", 24); FB = ImageFont.truetype("DejaVuSerif-Bold.ttf", 28)

def upscale(img, lines=0, show_seal=False):
    big = Image.new('RGBA', ((W + 20) * S, (H + 10) * S), (34, 26, 30, 255))
    big.alpha_composite(img.resize((W * S, H * S), Image.NEAREST), (10 * S, 5 * S))
    d = ImageDraw.Draw(big); y = 22 * S
    for i, t in enumerate(TEXT[:lines]):
        if i == 0: d.text(((10 + W / 2) * S, y), t, font=FB, fill=INK, anchor='mm'); y += 8 * S
        else: d.text((22 * S, y), t, font=F, fill=INK); y += 6 * S
    if show_seal: big.alpha_composite(seal().resize((55, 55), Image.NEAREST), ((10 + W - 24) * S, (5 + H - 26) * S))
    return big.convert('RGB')

if __name__ == '__main__':
    frames, dur, sheet = [], [], []
    for i in range(6): frames.append(upscale(frame(0, 0, True))); dur.append(120)           # fechado e lacrado
    for k in (1, 2):   frames.append(upscale(frame(0, 0, True, k))); dur.append(110)        # selo racha
    N = 12
    for i in range(1, N + 1):                                                               # abre (rolos giram)
        f = frame(ease_out(i / N), i); frames.append(upscale(f)); dur.append(55); sheet.append(f)
    for n in range(1, len(TEXT) + 1): frames.append(upscale(frame(1, N), n)); dur.append(70)  # texto aparece
    frames.append(upscale(frame(1, N), len(TEXT), True)); dur.append(2200)                  # leitura (selo no pé)
    for i in range(N - 1, -1, -1):                                                          # fecha
        frames.append(upscale(frame(ease_in(i / N), i))); dur.append(45)
    frames.append(upscale(frame(0, 0, True))); dur.append(900)
    frames[0].save(os.path.join(OUT, 'pergaminho_abrindo.gif'), save_all=True, append_images=frames[1:], duration=dur, loop=0)
    # spritesheet nativo da abertura (para AnimatedSprite2D no Godot), + quadro fechado no início
    sheet = [frame(0, 0, True)] + sheet
    ss = Image.new('RGBA', (W * len(sheet), H), (0, 0, 0, 0))
    for i, f in enumerate(sheet): ss.alpha_composite(f, (i * W, 0))
    ss.save(os.path.join(OUT, 'pergaminho_abrindo_sheet.png'))
    print(len(frames), 'quadros')
