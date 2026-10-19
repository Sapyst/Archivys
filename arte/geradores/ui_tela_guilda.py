"""Aba GUILDA = painel da casa (sem mapa): vitrine + resumo do dia + áreas + acontecendo agora.
180×320 nativo → 720×1280. Imagens e ícones em alta resolução; UI em pixel nativo."""
import os
from PIL import Image, ImageDraw
import ui_metal as MT
import ui_janela as J, ui_hud as H, ui_hud_baixo as HB, fonte_tecnica as FT, ui_pergaminho as PG

GW, GH, S = H.GW, H.GH, H.S
ROOT = H.ROOT; IC = H.ICDIR
O = J.OUTL + (255,); CREAM = (240, 230, 212, 255); DIM = (170, 156, 140, 255); GOLD = J.ROPE_L + (255,)
RED = (230, 90, 70, 255); GREEN = (120, 200, 110, 255)
TOP, BOT = 48, 262               # área útil entre os HUDs (px nativos)

HIRES = []                       # (arquivo, x, y, tamanho nativo, escurecer)
def hicon(name, x, y, sz=10, dim=False):
    f = os.path.join(IC, name + '.png')
    if os.path.exists(f): HIRES.append((f, x, y, sz, dim))

def text(lay, x, y, s, col=CREAM, sh=True): return FT.draw(lay, x, y, s, col, H.SHD if sh else None)

def build():
    lay = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    # ---------- 1) vitrine ----------
    VX, VY, VW, VH = 6, TOP + 6, GW - 12, 92
    frame = MT.panel(VW, VH, r=5)
    inner = Image.new('RGBA', frame.size, (0, 0, 0, 0)); ImageDraw.Draw(inner).rounded_rectangle([4, 4, VW - 5, VH - 5], 3, fill=(0, 0, 0, 255))
    fr = frame.copy(); fr.paste((0, 0, 0, 0), (0, 0), inner)                  # janela vazada (a imagem entra por baixo)
    lay.alpha_composite(fr, (VX, VY))
    vit = (VX + 4, VY + 4, VW - 8, VH - 8)
    # placa do nome + status
    nome = "Casa do Queixo"; pl = J.name_plate(FT.width(nome) + 12, 13); lay.alpha_composite(pl, (VX + 8, VY - 5)); FT.draw(lay, VX + 14, VY - 2, nome, O)
    chip = "ABERTA"; cw = FT.mwidth(chip) + 8
    d.rectangle([VX + VW - cw - 8, VY + VH - 14, VX + VW - 9, VY + VH - 6], fill=(40, 90, 50, 255), outline=O)
    FT.mdraw(lay, VX + VW - cw - 4, VY + VH - 12, chip, (200, 255, 200, 255))
    # balão da Mira (toque nela = reação + andamento)
    lines = ["O hidromel", "está", "acabando!"]; bw = max(FT.width(l) for l in lines) + 12; bh = 3 * 10 - 3 + 10
    bub, ox = MT.bubble(bw, bh, 'left', tail_y=bh // 2)
    bx = VX + VW - bw - 10 - ox; by = VY + 22
    lay.alpha_composite(bub, (bx, by))
    for k, l in enumerate(lines): FT.draw(lay, bx + ox + 6, by + 5 + k * 10, l, (40, 26, 22, 255))
    # ---------- 2) resumo do dia (pergaminho) ----------
    RY = VY + VH + 4; RH = 31
    lay.alpha_composite(MT.panel(GW - 12, RH, r=4), (6, RY))
    INK = CREAM
    cols = [('moedas', "+186", "renda", GREEN), ('aventureiros', "6/10", "na casa", INK), ('contratos', "2", "missão", INK), ('conforto', "157", "conforto", INK)]
    cw = (GW - 12) // 4
    for i, (ic, val, lab, vc) in enumerate(cols):
        cx = 6 + i * cw
        hicon(ic, cx + 4, RY + 6, 9)
        FT.draw(lay, cx + 15, RY + 7, val, vc, H.SHD)
        FT.mdraw(lay, cx + (cw - FT.mwidth(lab.upper())) // 2, RY + 19, lab.upper(), (160, 150, 140, 255))
    # ---------- 3) áreas ----------
    AY = RY + RH + 6
    text(lay, 8, AY, "Áreas da guilda", GOLD); AY += 10
    AREAS = [
        ('guilda', "Recepção", "Mira - 3 candidatos", 3, False, None),
        ('bar', "Salão", "8/12 mesas - sujo", 0, False, 0.62),
        ('provisoes', "Cozinha", "Ensopado - 18 min", 0, False, 0.4),
        ('bebida', "Despensa", "Hidromel acabando", 1, False, None),
        ('descanso', "Quartos", "Fama 4 para abrir", 0, True, None),
        ('melhorias', "Forja", "Fama 5 para abrir", 0, True, None),
    ]
    RHt = 25; LIMITE = 248
    for i, (ic, nm, info, alerta, lock, barra) in enumerate(AREAS):
        y = AY + i * (RHt + 2)
        if y + 6 > LIMITE: break
        row = MT.panel(GW - 12, RHt, r=4)
        if lock: row = Image.blend(Image.new('RGBA', row.size, (0, 0, 0, 0)), row, 0.75)
        lay.alpha_composite(row, (6, y))
        hicon(ic, 11, y + 6, 12, lock)
        text(lay, 29, y + 6, nm, DIM if lock else CREAM)
        FT.mdraw(lay, 29, y + 16, info.upper(), (205, 190, 170, 255) if not lock else (130, 120, 110, 255))
        if lock:                                    # cadeado
            lx = GW - 22; d.rectangle([lx, y + 11, lx + 7, y + 17], fill=(150, 140, 120, 255), outline=O); d.arc([lx + 1, y + 6, lx + 6, y + 14], 180, 360, fill=O, width=1)
        else:
            d.polygon([(GW - 17, y + 9), (GW - 13, y + 12), (GW - 17, y + 15)], fill=GOLD)   # seta ">"
        if alerta:
            bx = GW - 30; d.ellipse([bx, y + 8, bx + 8, y + 16], fill=(214, 38, 30, 255), outline=O); FT.mdraw(lay, bx + 3, y + 10, str(alerta) if alerta < 10 else "!", CREAM)
        if barra is not None:
            bx0, bw = GW - 70, 34; d.rectangle([bx0, y + 16, bx0 + bw, y + 18], fill=(20, 14, 16, 255))
            d.rectangle([bx0 + 1, y + 17, bx0 + 1 + int((bw - 2) * barra), y + 17], fill=(230, 180, 70, 255) if nm != "Salão" else RED)
    # recorte: a lista some antes do HUD de baixo (rolável)
    p = lay.load()
    for yy in range(LIMITE, GH):
        for xx in range(GW): p[xx, yy] = (0, 0, 0, 0)
    for k in range(10):
        for xx in range(GW):
            r_, g_, b_, a_ = p[xx, LIMITE - 10 + k]; p[xx, LIMITE - 10 + k] = (r_, g_, b_, int(a_ * (1 - k / 10)))
    global HIRES
    HIRES = [h for h in HIRES if h[2] < LIMITE - 8]
    return lay, vit

if __name__ == '__main__':
    H.HI.clear(); H.HIPOS.clear(); H.HISZ.clear(); H.HIDIM.clear()
    ui = H.hud_layer(1240, 35, 12, 17, "08:40"); ui.alpha_composite(HB.layer(ativa=0))
    mid, (vx, vy, vw, vh) = build()
    base = Image.new('RGBA', (GW * S, GH * S), (24, 17, 20, 255))
    # madeira sutil no fundo do meio
    bw = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); p = bw.load()
    for y in range(GH):
        for x in range(GW):
            if (y // 9) % 2 == 0 and x % 31 != 0: p[x, y] = (27, 19, 22, 255)
            elif x % 31 == 0 or y % 9 == 0: p[x, y] = (19, 13, 16, 255)
    base.alpha_composite(bw.resize(base.size, Image.NEAREST))
    rec = Image.open(os.path.join(ROOT, 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA')
    tw, th = vw * S, vh * S; sc = tw / rec.width
    rec = rec.resize((tw, int(rec.height * sc)), Image.LANCZOS); off = int(rec.height * 0.42) - th // 2
    base.alpha_composite(rec.crop((0, off, tw, off + th)), (vx * S, vy * S))
    mira = Image.open(os.path.join(ROOT, 'personagens', 'mira', 'recortes', '02_feliz.png')).convert('RGBA')
    mh = int(th * 0.98); mira = mira.resize((int(mira.width * mh / mira.height), mh), Image.LANCZOS)
    mx = vx * S + int(tw * 0.28) - mira.width // 2; my = vy * S + th - mira.height
    lay_m = Image.new('RGBA', base.size, (0, 0, 0, 0)); lay_m.alpha_composite(mira, (mx, my))
    base.alpha_composite(lay_m.crop((vx * S, vy * S, (vx + vw) * S, (vy + vh) * S)), (vx * S, vy * S))
    full = mid.copy(); full.alpha_composite(ui)
    base.alpha_composite(full.resize(base.size, Image.NEAREST))
    H.hires_icons(base)
    for f, x, y, sz, dim in HIRES:
        H.HI[:] = [f]; H.HIPOS[:] = [(x, y)]; H.HISZ.clear(); H.HISZ[0] = sz; H.HIDIM.clear(); H.HIDIM[0] = dim
        H.hires_icons(base)
    H.phone_overlay(base)
    ImageDraw.Draw(base).rounded_rectangle([GW * S // 2 - 70, GH * S - 16, GW * S // 2 + 70, GH * S - 10], 3, fill=(230, 230, 230))
    base.convert('RGB').save(os.path.join(ROOT, 'ui', '_tela_guilda.png')); print('ok')
