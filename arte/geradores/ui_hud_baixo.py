"""HUD inferior: faixa de recursos consumíveis + barra de navegação (5 abas), corda separando,
degradê para cima, área segura da barra de gestos do celular embaixo."""
import os
from PIL import Image, ImageDraw
import ui_janela as J, ui_hud as H, fonte_tecnica as FT

GW, GH, S = H.GW, H.GH, H.S
GEST = 6            # barra de gestos (px nativos = 24 finais)
NAV = 26            # altura da barra de abas
RES = 13            # faixa de recursos
O = J.OUTL + (255,)

def ico(kind):
    im = Image.new('RGBA', (11, 11), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if kind == 'provisoes':   # pão
        d.ellipse([0, 3, 10, 9], fill=(196, 140, 70, 255), outline=O); d.line([3, 4, 4, 6], fill=(240, 200, 130, 255)); d.line([6, 4, 7, 6], fill=(240, 200, 130, 255))
    elif kind == 'bebida':    # caneca
        d.rectangle([1, 2, 7, 10], fill=(150, 104, 60, 255), outline=O); d.rectangle([2, 2, 6, 4], fill=(250, 240, 210, 255)); d.arc([6, 4, 10, 8], 270, 90, fill=O)
    elif kind == 'materiais': # lingote
        d.polygon([(0, 8), (3, 4), (10, 4), (8, 8)], fill=(150, 156, 180, 255), outline=O); d.line([3, 5, 8, 5], fill=(220, 225, 240, 255))
    elif kind == 'favores':   # selo de cera Rhosanim
        d.ellipse([1, 1, 9, 9], fill=(232, 220, 190, 255), outline=O); d.ellipse([3, 3, 7, 7], outline=(200, 160, 60, 255))
    elif kind == 'guilda':    # casa
        d.polygon([(5, 0), (10, 5), (0, 5)], fill=(166, 124, 74, 255), outline=O); d.rectangle([1, 5, 9, 10], fill=(120, 84, 52, 255), outline=O); d.rectangle([4, 7, 6, 10], fill=(40, 28, 26, 255))
    elif kind == 'aventureiros':  # elmo
        d.chord([1, 1, 9, 11], 180, 360, fill=(150, 156, 180, 255), outline=O); d.rectangle([1, 6, 9, 9], fill=(150, 156, 180, 255), outline=O); d.line([5, 6, 5, 9], fill=O)
    elif kind == 'contratos': # pergaminho
        d.rectangle([2, 1, 8, 9], fill=(232, 210, 166, 255), outline=O); d.line([3, 4, 7, 4], fill=(120, 80, 50, 255)); d.line([3, 6, 7, 6], fill=(120, 80, 50, 255)); d.ellipse([6, 7, 9, 10], fill=(170, 40, 40, 255))
    elif kind == 'bar':       # barril
        d.ellipse([1, 0, 9, 10], fill=(150, 104, 60, 255), outline=O); d.line([1, 3, 9, 3], fill=(92, 97, 124, 255)); d.line([1, 7, 9, 7], fill=(92, 97, 124, 255))
    elif kind == 'melhorias': # martelo
        d.rectangle([4, 4, 6, 10], fill=(120, 84, 52, 255), outline=O); d.rectangle([1, 1, 9, 4], fill=(150, 156, 180, 255), outline=O)
    return im

RECURSOS = [('provisoes', 42, 60), ('bebida', 18, 40), ('materiais', 7, None), ('favores', 2, None)]
ABAS = [('guilda', 'GUILDA'), ('aventureiros', 'HEROIS'), ('contratos', 'QUADRO'), ('bar', 'BAR'), ('melhorias', 'OBRAS')]

def layer(ativa=0, alerta=(2,)):
    lay = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); p = lay.load()
    top = GH - GEST - NAV - RES - 8
    for y in range(top - H.FADE, GH):
        a = 255 if y >= top else int(255 * (1 - (top - y) / H.FADE) ** 2)
        for x in range(GW): p[x, y] = H.WOOD + (a,)
    # recursos
    ry = top + 2; x = 4
    for k, v, cap in RECURSOS:
        f = os.path.join(H.ICDIR, k + '.png')
        if os.path.exists(f): H.HI.append(f); H.HIPOS.append((x - 1, ry - 1))
        else: lay.alpha_composite(ico(k), (x, ry))
        t = f"{v}" if cap is None else f"{v}/{cap}"
        low = cap and v / cap < 0.35
        FT.draw(lay, x + 13, ry + 2, t, (230, 90, 70, 255) if low else H.TXT, H.SHD)
        x += 13 + FT.width(t) + 8
    # corda
    cy = top + RES + 2; lay.alpha_composite(H.rope_h(GW), (0, cy))
    # abas
    ny = cy + 7; w = GW // len(ABAS)
    for i, (k, nome) in enumerate(ABAS):
        x0 = i * w
        f = os.path.join(H.ICDIR, k + '.png'); up = 1 if i == ativa else 0
        if os.path.exists(f):
            H.HISZ[len(H.HI)] = 14; H.HIDIM[len(H.HI)] = (i != ativa); H.HI.append(f); H.HIPOS.append((x0 + (w - 14) // 2, ny + 2 - up))
        else: lay.alpha_composite(ico(k), (x0 + (w - 11) // 2, ny + 3 - up))
        col = J.ROPE_L + (255,) if i == ativa else (170, 156, 140, 255)
        FT.mdraw(lay, x0 + (w - FT.mwidth(nome)) // 2, ny + 17, nome, col)
        if i in alerta:
            d = ImageDraw.Draw(lay); bx = x0 + w // 2 + 6; d.ellipse([bx, ny + 1, bx + 5, ny + 6], fill=(214, 38, 30, 255), outline=O)
    return lay

if __name__ == '__main__':
    ROOT = H.ROOT
    bg = Image.open(os.path.join(ROOT, 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA').resize((GH * S, GH * S), Image.LANCZOS)
    bg = bg.crop(((GH - GW) * S // 2, 0, (GH - GW) * S // 2 + GW * S, GH * S))
    ui = H.hud_layer(1240, 35, 12, 17, "08:40"); ui.alpha_composite(layer())
    out = bg.copy(); out.alpha_composite(ui.resize((GW * S, GH * S), Image.NEAREST)); out = H.hires_icons(out); out = H.phone_overlay(out)
    d = ImageDraw.Draw(out); d.rounded_rectangle([GW * S // 2 - 70, GH * S - 16, GW * S // 2 + 70, GH * S - 10], 3, fill=(230, 230, 230))
    out.convert('RGB').save(os.path.join(ROOT, 'ui', '_previa_hud_completo.png')); print('ok')
