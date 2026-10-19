"""Janela de diálogo pixel art com borda de corda trançada e cantos arredondados.
Gera: janela_dialogo_9slice.png (nativo, para NinePatchRect no Godot), placa de nome, seta de continuar,
e uma prévia ampliada com texto. Saída: ../ui/"""
import os, math
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ui'); os.makedirs(OUT, exist_ok=True)
OUTL = (28, 18, 16)
ROPE_L, ROPE_M, ROPE_D = (214, 176, 118), (166, 124, 74), (104, 72, 42)
IN_1, IN_2, IN_3 = (40, 30, 34), (48, 36, 40), (30, 22, 26)    # interior madeira escura
SHADOW = (18, 12, 12)

def rr_param(x, y, x0, y0, x1, y1, r):
    """Distância ao contorno central de um retângulo arredondado + posição ao longo dele."""
    cx = min(max(x, x0 + r), x1 - r); cy = min(max(y, y0 + r), y1 - r)
    dx, dy = x - cx, y - cy
    inner = (x0 + r <= x <= x1 - r) or (y0 + r <= y <= y1 - r)
    if (x0 + r <= x <= x1 - r):      # bordas de cima/baixo
        d = min(abs(y - y0), abs(y - y1)); along = x
    elif (y0 + r <= y <= y1 - r):    # bordas laterais
        d = min(abs(x - x0), abs(x - x1)); along = y
    else:                            # cantos
        dist = math.hypot(dx, dy); d = abs(dist - r); along = math.atan2(dy, dx) * r
    return d, along

def window(w, h, rope=6, r=7):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); px = im.load()
    m = rope // 2 + 1; x0, y0, x1, y1 = m, m, w - 1 - m, h - 1 - m
    for y in range(h):
        for x in range(w):
            d, along = rr_param(x, y, x0, y0, x1, y1, r)
            # dentro do contorno?
            cx = min(max(x, x0 + r), x1 - r); cy = min(max(y, y0 + r), y1 - r)
            inside_shape = (x0 <= x <= x1 and y0 <= y <= y1) and math.hypot(x - cx, y - cy) <= r + 0.5 if not (x0 + r <= x <= x1 - r or y0 + r <= y <= y1 - r) else (x0 <= x <= x1 and y0 <= y <= y1)
            if d <= rope / 2 + 0.5:
                if d > rope / 2 - 0.5: px[x, y] = OUTL + (255,); continue
                across = d if inside_shape else -d
                k = int(math.floor(along + across * 1.2)) % 6       # trança diagonal: fio claro→médio→sombra→vinco
                px[x, y] = ((ROPE_L, ROPE_L, ROPE_M, ROPE_M, ROPE_D, OUTL)[k]) + (255,)
            elif inside_shape:
                # interior com veio de madeira + sombra interna
                depth = d - rope / 2
                col = IN_1 if (y // 3 + (x // 17)) % 5 else IN_2
                if (x * 7 + y * 13) % 29 == 0: col = IN_3
                if depth < 2.5: col = SHADOW
                px[x, y] = col + (255,)
    return im

def name_plate(w=44, h=11):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=3, fill=ROPE_M + (255,), outline=OUTL + (255,))
    d.line([2, 1, w - 3, 1], fill=ROPE_L + (255,)); d.line([2, h - 2, w - 3, h - 2], fill=ROPE_D + (255,))
    for x in (2, w - 3): d.point((x, h // 2), fill=(217, 164, 65, 255))
    return im

def arrow(f=0):
    im = Image.new('RGBA', (7, 6), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(0, 0), (6, 0), (3, 4)], fill=ROPE_L + (255,), outline=OUTL + (255,))
    return im

if __name__ == '__main__':
    W, H = 160, 52
    win = window(W, H); win.save(os.path.join(OUT, 'janela_dialogo.png'))
    nine = window(36, 36); nine.save(os.path.join(OUT, 'janela_dialogo_9slice.png'))   # margens: 13 px
    plate = name_plate(); plate.save(os.path.join(OUT, 'placa_nome.png'))
    arrow().save(os.path.join(OUT, 'seta_continuar.png'))
    # prévia
    S = 5; bgw, bgh = W + 20, H + 26
    try: bg = Image.open(os.path.join(OUT, '..', 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA').resize((bgw * S, bgw * S)).crop((0, bgw * S - bgh * S, bgw * S, bgw * S))
    except Exception: bg = Image.new('RGBA', (bgw * S, bgh * S), (60, 50, 50, 255))
    big = win.resize((W * S, H * S), Image.NEAREST); bg.alpha_composite(big, (10 * S, 20 * S))
    bg.alpha_composite(plate.resize((plate.width * S, plate.height * S), Image.NEAREST), (18 * S, 14 * S))
    bg.alpha_composite(arrow().resize((7 * S, 6 * S), Image.NEAREST), ((10 + W - 20) * S, (20 + H - 16) * S))
    d = ImageDraw.Draw(bg)
    fb = ImageFont.truetype("DejaVuSerif-Bold.ttf", 26); fr = ImageFont.truetype("DejaVuSerif.ttf", 26)
    d.text(((18 + 22) * S, (14 + 5.5) * S), "Mira", font=fb, fill=(40, 24, 16), anchor='mm')
    d.multiline_text((22 * S, 32 * S), "Bem-vindo à guilda, aventureiro.\nO quadro de contratos está vazio hoje…\nmas a sopa ainda está quente.",
                     font=fr, fill=(236, 224, 204), spacing=10)
    bg.convert('RGB').save(os.path.join(OUT, '_previa_janela.png'))
    # 9-slice ampliado para conferência
    nine.resize((36 * 8, 36 * 8), Image.NEAREST).save(os.path.join(OUT, '_9slice_ampliado.png'))
    print('ok')
