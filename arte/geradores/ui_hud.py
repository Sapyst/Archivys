"""HUD superior (celular em pé, 180×320 nativo → 720×1280).
- Faixa do sistema (status bar + furo da câmera no centro): só gradiente escuro, nada desenhado ali.
- Linha de recursos: moedas · fama | (zona do furo livre) | honra · relógio.
- Fundo do HUD = madeira escura que cai em degradê sobre a cena; corda horizontal separando."""
import os
from PIL import Image, ImageDraw
import ui_janela as J, ui_vitrine_fonte as V
import fonte_tecnica as FT
TXT, SHD = (240, 230, 212, 255), (12, 8, 10, 255)

GW, GH, S = 180, 320, 4
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SAFE = 10            # faixa do sistema (status bar) em px nativos = 40 px finais
ROW = 16             # linha de recursos
ROPE_Y = SAFE + ROW + 1
FADE = 14            # degradê abaixo da corda
CAM = 14             # meia-largura reservada ao furo da câmera (px nativos)
WOOD = (30, 21, 24)

def rope_h(w, th=5):
    im = Image.new('RGBA', (w, th + 2), (0, 0, 0, 0)); p = im.load()
    for x in range(w):
        p[x, 0] = J.OUTL + (255,); p[x, th + 1] = J.OUTL + (255,)
        for y in range(th):
            k = (x + y) % 6
            p[x, y + 1] = (J.ROPE_L, J.ROPE_L, J.ROPE_M, J.ROPE_M, J.ROPE_D, J.OUTL)[k] + (255,)
    return im

HI, HIPOS, HISZ, HIDIM = [], [], {}, {}
ICDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ui', 'icones')
def icon(kind):
    f = os.path.join(ICDIR, {'moeda': 'moedas'}.get(kind, kind) + '.png')
    if os.path.exists(f):
        HI.append(f); return Image.new('RGBA', (12, 12), (0, 0, 0, 0))   # desenhado em alta resolução depois
    g = J.__dict__  # paleta
    im = Image.new('RGBA', (9, 9), (0, 0, 0, 0)); d = ImageDraw.Draw(im); O = J.OUTL + (255,)
    if kind == 'moeda':
        d.ellipse([0, 0, 8, 8], fill=(217, 164, 65, 255), outline=O); d.ellipse([2, 2, 6, 6], outline=(255, 222, 130, 255))
        d.point((3, 3), fill=(255, 245, 200, 255))
    elif kind == 'fama':
        pts = [(4, 0), (5, 3), (8, 3), (6, 5), (7, 8), (4, 6), (1, 8), (2, 5), (0, 3), (3, 3)]
        d.polygon(pts, fill=(240, 200, 80, 255), outline=O)
    elif kind == 'honra':
        d.polygon([(1, 0), (7, 0), (7, 4), (4, 8), (1, 4)], fill=(150, 160, 190, 255), outline=O)
        d.line([4, 1, 4, 6], fill=(220, 225, 240, 255))
    elif kind == 'relogio':
        d.ellipse([0, 0, 8, 8], fill=(232, 210, 166, 255), outline=O); d.line([4, 4, 4, 1], fill=O); d.line([4, 4, 6, 5], fill=O)
    return im

def hud_layer(moedas, fama, honra, dia, hora, aberto=True, fechado_mult=False):
    lay = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); p = lay.load()
    top = ROPE_Y + 7
    for y in range(top + FADE):                                  # madeira sólida → degradê
        a = 255 if y < top else int(255 * (1 - (y - top) / FADE) ** 2)
        for x in range(GW): p[x, y] = WOOD + (a,)
    for x in range(GW):                                          # veio sutil da madeira
        for y in range(SAFE, top):
            if (x // 23 + y) % 7 == 0: p[x, y] = (36, 26, 29, 255)
    lay.alpha_composite(rope_h(GW), (0, ROPE_Y))
    cy = SAFE + 2
    def item(x, kind, txt):
        lay.alpha_composite(icon(kind), (x, cy)); HIPOS.append((x, cy)) if len(HIPOS) < len(HI) else None; FT.draw(lay, x + 14, cy + 3, txt, TXT, SHD)
        return x + 14 + FT.width(txt)
    item(4, 'moeda', f"{moedas}")
    item(GW // 2 - CAM - 4 - 14 - FT.width(f"{fama}"), 'fama', f"{fama}")
    item(GW // 2 + CAM + 4, 'honra', f"{honra}")
    t = f"{hora}"; item(GW - 6 - 14 - FT.width(t), 'relogio', t)
    # data + velocidade logo abaixo da corda (pequena placa)
    sub = f"Dia {dia}  {'60×' if aberto else '4×'}"
    PH = 13; pl = J.name_plate(FT.width(sub) + 12, PH); x = (GW - pl.width) // 2; y = ROPE_Y + 5
    lay.alpha_composite(pl, (x, y))
    FT.draw(lay, x + 6, y + (PH - 7) // 2, sub, J.OUTL + (255,))        # centralizado no Y: (13-7)/2 = 3 px acima e abaixo
    return lay

def phone_overlay(big):
    """Simula status bar e furo da câmera (só para a prévia)."""
    d = ImageDraw.Draw(big); W = big.width
    d.ellipse([W // 2 - 18, 10, W // 2 + 18, 46], fill=(0, 0, 0))
    d.text((28, 12), "10:42", fill=(255, 255, 255)); d.text((W - 70, 12), "▮▮▮ 87%", fill=(255, 255, 255))
    return big

if __name__ == '__main__':
    bg = Image.open(os.path.join(ROOT, 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA').resize((GH * S, GH * S), Image.LANCZOS)
    bg = bg.crop(((GH - GW) * S // 2, 0, (GH - GW) * S // 2 + GW * S, GH * S))
    hud = hud_layer(1240, 35, 12, 17, "08:40")
    out = bg.copy(); out.alpha_composite(hud.resize((GW * S, GH * S), Image.NEAREST))
    phone_overlay(out).convert('RGB').save(os.path.join(ROOT, 'ui', '_previa_hud.png'))
    hud.save(os.path.join(ROOT, 'ui', 'hud_topo.png'))
    print('ok')

def hires_icons(big, S=4, size=12):
    """Ícones do Gemini em resolução final (12 px nativos = 48 px finais), sem virar borrão."""
    for i, (f, (x, y)) in enumerate(zip(HI, HIPOS)):
        sz = HISZ.get(i, size); grid = sz * 2
        pf = os.path.join(os.path.dirname(f), 'px', os.path.basename(f)[:-4] + f'_{grid}.png')
        im = Image.open(pf if os.path.exists(pf) else f).convert('RGBA').resize((sz * S, sz * S), Image.NEAREST)
        a = im.getchannel('A').point(lambda v: 255 if v > 110 else 0); im.putalpha(a)
        if HIDIM.get(i):                                   # aba inativa: dessatura 70% e escurece 35%
            from PIL import ImageEnhance
            al = im.getchannel('A'); im = ImageEnhance.Brightness(ImageEnhance.Color(im.convert('RGB')).enhance(0.3)).enhance(0.65).convert('RGBA'); im.putalpha(al)
        big.alpha_composite(im, (x * S, y * S))
    return big
