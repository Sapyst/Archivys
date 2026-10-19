"""Exporta para o Godot as peças de UI das prévias aprovadas (_tela_guilda.png / _previa_hud_completo.png):
- fontes bitmap BMFont (.fnt + .png): técnica 5×7 com sombra (×3, ×4) e mini 3×5 (×3, ×4)
- 9-slices NATIVOS (o Godot amplia por escala inteira, nearest): janela de corda (centro tileável),
  painel metálico, moldura da vitrine (vazada), botões, balão (corpo + rabicho), placas
- faixas dos HUDs (madeira + corda horizontal + degradê) e a corda horizontal tileável.
Saída: ../../godot/assets/ui/ e ../../godot/assets/fontes/"""
import os, math
from PIL import Image, ImageDraw
import ui_janela as J, ui_metal as MT, ui_hud as H, fonte_tecnica as FT

AQUI = os.path.dirname(os.path.abspath(__file__))
GD = os.path.join(AQUI, '..', '..', 'godot', 'assets')
UI = os.path.join(GD, 'ui'); FON = os.path.join(GD, 'fontes')
os.makedirs(UI, exist_ok=True); os.makedirs(FON, exist_ok=True)

# ------------------------------------------------------------------ fontes
EXTRA = {
    '"': ["101", "101", "000", "000", "000", "000", "000"], "'": ["1", "1", "0", "0", "0", "0", "0"],
    '[': ["11", "10", "10", "10", "10", "10", "11"], ']': ["11", "01", "01", "01", "01", "01", "11"],
    '•': ["000", "000", "010", "111", "010", "000", "000"], '·': ["0", "0", "0", "1", "0", "0", "0"],
    '…': ["00000", "00000", "00000", "00000", "00000", "00000", "10101"],
    '—': ["0000000", "0000000", "0000000", "1111111", "0000000", "0000000", "0000000"],
    '–': ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    '−': ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    '=': ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
    '<': ["0001", "0010", "0100", "1000", "0100", "0010", "0001"], '>': ["1000", "0100", "0010", "0001", "0010", "0100", "1000"],
    '*': ["00000", "10101", "01110", "11111", "01110", "10101", "00000"], '_': ["0000", "0000", "0000", "0000", "0000", "0000", "1111"],
    ';': ["00", "01", "01", "00", "01", "01", "10"], '✕': ["00000", "00000", "10001", "01010", "00100", "01010", "10001"],
    '°': ["010", "101", "010", "000", "000", "000", "000"], 'º': ["010", "101", "010", "000", "111", "000", "000"],
    'ª': ["110", "001", "111", "101", "111", "000", "000"], '#': ["01010", "11111", "01010", "01010", "11111", "01010", "00000"],
    '&': ["01100", "10010", "10100", "01000", "10101", "10010", "01101"], '|': ["1"] * 7,
    'è': ["01000", "00100"] + FT.G['e'][2:], 'ì': ["01000", "00100"] + FT.G['ı'][2:], 'ò': ["01000", "00100"] + FT.G['o'][2:],
    'î': ["00100", "01010"] + FT.G['ı'][2:], 'û': ["00100", "01010"] + FT.G['u'][2:],
}
for k, v in EXTRA.items(): FT.G.setdefault(k, v)


def bmfont(nome, glifos, k, sombra, linhas_acima, altura_letra, linhas_abaixo, espaco=1):
    """glifos: {ch: [linhas]}; um glifo com mais linhas que altura_letra sobe (acento acima)."""
    base_n = linhas_acima + altura_letra
    lh_n = base_n + linhas_abaixo + (1 if sombra else 0) + 2
    itens = []
    for ch, g in glifos.items():
        w = len(g[0]); h = len(g)
        y0 = linhas_acima - (h - altura_letra) if h > altura_letra else linhas_acima
        if ch in ('Ç', 'ç'): y0 = linhas_acima
        im = Image.new('RGBA', ((w + (1 if sombra else 0)) * k, (h + (1 if sombra else 0)) * k), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for camada in ((1, (12, 8, 10, 255)), (0, (255, 255, 255, 255))) if sombra else ((0, (255, 255, 255, 255)),):
            off, cor = camada
            for yy, row in enumerate(g):
                for xx, v in enumerate(row):
                    if v == '1':
                        d.rectangle([(xx + off) * k, (yy + off) * k, (xx + off + 1) * k - 1, (yy + off + 1) * k - 1], fill=cor)
        itens.append((ch, im, y0 * k, (w + espaco) * k))
    # empacota em linhas
    W = 512; x = y = 1; alt = 0; pos = []
    for ch, im, yo, adv in itens:
        if x + im.width + 1 > W: x = 1; y += alt + 1; alt = 0
        pos.append((x, y)); x += im.width + 1; alt = max(alt, im.height)
    Hh = y + alt + 1; Hh = 1 << (Hh - 1).bit_length()
    atlas = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    linhas = [f'info face="{nome}" size={lh_n * k} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
              f'common lineHeight={lh_n * k} base={base_n * k} scaleW={W} scaleH={Hh} pages=1 packed=0',
              f'page id=0 file="{nome}.png"', f'chars count={len(itens)}']
    for (ch, im, yo, adv), (px, py) in zip(itens, pos):
        atlas.alpha_composite(im, (px, py))
        linhas.append(f'char id={ord(ch)} x={px} y={py} width={im.width} height={im.height} xoffset=0 yoffset={yo} xadvance={adv} page=0 chnl=15')
    atlas.save(os.path.join(FON, nome + '.png'))
    open(os.path.join(FON, nome + '.fnt'), 'w', encoding='utf-8').write('\n'.join(linhas) + '\n')
    print(nome, 'tamanho', lh_n * k)


def fontes():
    g = {}
    for ch, rows in FT.G.items():
        if ch == 'ı': continue
        g[ch] = rows
    g['ı'] = FT.G['ı']
    for k in (3, 4): bmfont(f'tecnica_{k}x', g, k, True, 2, 7, 0)
    bmfont('tecnica_4x_lisa', g, 4, False, 2, 7, 1)          # sem sombra (balão, placas)
    bmfont('tecnica_3x_lisa', g, 3, False, 2, 7, 1)
    m = {}
    for ch, rows in FT.M.items():
        m[ch] = rows
    for ch in list(m):                               # minúsculas → mesmas maiúsculas (a mini só tem caixa alta)
        lo = ch.lower()
        if lo != ch and lo not in m: m[lo] = m[ch]
    m['!'] = ["1", "1", "1", "0", "1"]; m['?'] = ["110", "001", "010", "000", "010"]; m['%'] = ["101", "001", "010", "100", "101"]
    m['×'] = ["000", "101", "010", "101", "000"]; m[','] = ["0", "0", "0", "1", "1"]; m['('] = ["01", "10", "10", "10", "01"]
    m[')'] = ["10", "01", "01", "01", "10"]; m["'"] = ["1", "1", "0", "0", "0"]; m['·'] = ["0", "0", "1", "0", "0"]
    m['—'] = ["0000", "0000", "1111", "0000", "0000"]; m['−'] = m['-']; m['•'] = m['·']
    for c in "ãáàâéêíóôõúç": m.setdefault(c, m[c.upper()])
    m['Ç'] = FT.M['Ç']; m['ç'] = FT.M['Ç']
    for k in (3, 4): bmfont(f'mini_{k}x', m, k, False, 1, 5, 1)

# ------------------------------------------------------------------ 9-slices
def janela_corda():
    """56×56, margem 13, centro de 30 px TILEÁVEL (corda período 6, veio período 15/30)."""
    n = 56; im = J.window(n, n); p = im.load()
    madeira = {J.IN_1, J.IN_2, J.IN_3}
    for y in range(n):
        for x in range(n):
            r, g, b, a = p[x, y]
            if a and (r, g, b) in madeira:
                p[x, y] = (J.IN_2 if (y // 3 + (x // 15) % 2) % 5 == 0 else J.IN_1) + (255,)
    im.save(os.path.join(UI, 'janela_corda_9slice.png'))


def placa(w, h, nome):
    J.name_plate(w, h).save(os.path.join(UI, nome))


def uniforme(im, m):
    """Faixas esticáveis do 9-slice com cor única: metade de cima/esquerda copia a 1ª coluna/linha do miolo,
    metade de baixo/direita copia a última (evita a borda meio clara/meio escura ao esticar)."""
    w, h = im.size; p = im.load(); a, b = m, w - m - 1
    for y in range(h):
        for x in range(a, w - m):
            p[x, y] = p[a if y < h // 2 else b, y]
    a, b = m, h - m - 1
    for x in range(w):
        for y in range(a, h - m):
            p[x, y] = p[x, a if x < w // 2 else b]
    return im


def metal():
    _panel = MT.panel
    MT_panel = lambda *aa, **kk: uniforme(_panel(*aa, **kk), 6)
    MT_panel(16, 16, r=4).save(os.path.join(UI, 'metal_9slice.png'))                       # margem 6
    MT_panel(16, 16, r=4, fill=(46, 37, 40)).save(os.path.join(UI, 'metal_botao.png'))
    MT_panel(16, 16, r=4, fill=(60, 48, 50)).save(os.path.join(UI, 'metal_botao_hover.png'))
    MT_panel(16, 16, r=4, fill=(22, 17, 19)).save(os.path.join(UI, 'metal_botao_apertado.png'))
    MT_panel(16, 16, r=4, fill=(20, 15, 17)).save(os.path.join(UI, 'metal_escuro.png'))
    # moldura vazada da vitrine (20×20, margem 8)
    fr = uniforme(MT.panel(20, 20, r=5), 8)
    furo = Image.new('L', fr.size, 0); ImageDraw.Draw(furo).rounded_rectangle([4, 4, 15, 15], 3, fill=255)
    fr.paste((0, 0, 0, 0), (0, 0), furo); fr.save(os.path.join(UI, 'moldura_vitrine.png'))
    # selo / chip (verde) e barra
    chip = Image.new('RGBA', (8, 9), (0, 0, 0, 0)); ImageDraw.Draw(chip).rectangle([0, 0, 7, 8], fill=(40, 90, 50, 255), outline=J.OUTL + (255,))
    chip.save(os.path.join(UI, 'chip_verde.png'))
    chip2 = Image.new('RGBA', (8, 9), (0, 0, 0, 0)); ImageDraw.Draw(chip2).rectangle([0, 0, 7, 8], fill=(90, 40, 36, 255), outline=J.OUTL + (255,))
    chip2.save(os.path.join(UI, 'chip_vermelho.png'))


def balao():
    """Corpo 9-slice (16×16, r=5, margem 6) + rabicho que encaixa na borda esquerda (contorno contínuo)."""
    T = 8; w = h = 16; r = 5; FILL = (236, 226, 206)
    def corpo_in(x, y): return MT.sd(x, y, w, h, r) <= 0
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); p = im.load()
    for y in range(h):
        for x in range(w):
            if not corpo_in(x, y): continue
            edge = any(not (0 <= x + dx < w and 0 <= y + dy < h and corpo_in(x + dx, y + dy)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            p[x, y] = (MT.OUTL if edge else FILL) + (255,)
    im.save(os.path.join(UI, 'balao_9slice.png'))
    # rabicho: gera um balão grande e recorta a ponta + 3 colunas do corpo
    big, ox = MT.bubble(40, 40, 'left', tail_y=20, r=r, fill=FILL)
    big.crop((0, 15, ox + 3, 26)).save(os.path.join(UI, 'balao_rabicho.png'))     # ponta em y=5 do recorte
    print('rabicho ox', ox)


def huds():
    # corda horizontal tileável (período 6 → 12 px)
    H.rope_h(12).save(os.path.join(UI, 'corda_h.png'))
    # fundo do HUD de cima: madeira (faixa do sistema vazia + linha de recursos), corda, degradê
    top = H.ROPE_Y + 7; alt = top + H.FADE
    im = Image.new('RGBA', (H.GW, alt), (0, 0, 0, 0)); p = im.load()
    for y in range(alt):
        a = 255 if y < top else int(255 * (1 - (y - top) / H.FADE) ** 2)
        for x in range(H.GW): p[x, y] = H.WOOD + (a,)
    for x in range(H.GW):
        for y in range(H.SAFE, top):
            if (x // 23 + y) % 7 == 0: p[x, y] = (36, 26, 29, 255)
    im.alpha_composite(H.rope_h(H.GW), (0, H.ROPE_Y))
    im.save(os.path.join(UI, 'hud_topo_fundo.png'))
    # fundo do HUD de baixo: degradê (14) + recursos (15) + corda (7) + abas/gestos
    import ui_hud_baixo as HB
    corpo = HB.GEST + HB.NAV + HB.RES + 8; alt = corpo + H.FADE
    im = Image.new('RGBA', (H.GW, alt), (0, 0, 0, 0)); p = im.load()
    for y in range(alt):
        yy = y - H.FADE
        a = 255 if yy >= 0 else int(255 * (1 - (-yy) / H.FADE) ** 2)
        for x in range(H.GW): p[x, y] = H.WOOD + (a,)
    im.alpha_composite(H.rope_h(H.GW), (0, H.FADE + HB.RES + 2))
    im.save(os.path.join(UI, 'hud_baixo_fundo.png'))
    print('hud topo alt', top + H.FADE, 'corda', H.ROPE_Y, '| baixo corpo', corpo, 'corda em', HB.RES + 2)


def extras():
    # tábua de fundo do meio (como na prévia), tile 31×18
    t = Image.new('RGBA', (31, 18), (24, 17, 20, 255)); p = t.load()
    for y in range(18):
        for x in range(31):
            if x % 31 == 0 or y % 9 == 0: p[x, y] = (19, 13, 16, 255)
            elif (y // 9) % 2 == 0: p[x, y] = (27, 19, 22, 255)
    t.save(os.path.join(UI, 'fundo_tabuas.png'))
    # ícones 18 px (resumo da guilda: 9 px nativos ×2)
    src = os.path.join(AQUI, '..', 'ui', 'icones'); dst = os.path.join(UI, 'icones')
    for f in os.listdir(src):
        if not f.endswith('.png') or '_' in f: continue
        im = Image.open(os.path.join(src, f)).convert('RGBA').resize((18, 18), Image.LANCZOS)
        im.putalpha(im.getchannel('A').point(lambda v: 255 if v > 110 else 0))
        im.save(os.path.join(dst, f[:-4] + '_18.png'))


if __name__ == '__main__':
    extras()
    fontes(); janela_corda(); placa(20, 13, 'placa_13.png'); placa(20, 14, 'placa_14.png')
    metal(); balao(); huds(); print('ok')
