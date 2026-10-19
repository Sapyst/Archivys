"""Janela de diálogo com LIMITADOR: altura fixa de N linhas; texto que não cabe vira páginas.
Cada página digita letra a letra; ao terminar, a seta pulsa ("clique para continuar").
Clicar durante a digitação completa a página; clicar com a página completa avança.
Na última página a seta vira um quadradinho piscando (fim). Gera prévia MP4."""
import os, subprocess
from PIL import Image, ImageDraw
import ui_vitrine_fonte as V           # fonte, wrap, text_layer, backdrop
import ui_janela as J

MAX_LINES = 3; W = 232; M = V.M; LH = V.LH
H = 22 + MAX_LINES * LH + 8           # altura FIXA — o texto jamais passa disso
S = V.S; OUT = V.OUT

def paginate(text, maxw=W - 2 * M, max_lines=MAX_LINES):
    lines = V.wrap(text, maxw)
    return [lines[i:i + max_lines] for i in range(0, len(lines), max_lines)]

# deslocamento Y fixo calculado com um bloco CHEIO (todas as páginas ficam na mesma altura, sem pular)
_ref = V.text_layer((W, H), ["Ág"] * MAX_LINES, V.CREAM, M, 22).getbbox()
DY = (H - (_ref[3] - _ref[1])) // 2 - _ref[1]

ARROW_BOB = [0, 0, 1, 2, 2, 1]        # seta sobe/desce (px nativos)
def end_mark(phase):
    im = Image.new('RGBA', (5, 5), (0, 0, 0, 0))
    if phase % 8 < 5:
        d = ImageDraw.Draw(im); d.rectangle([0, 0, 4, 4], fill=J.OUTL + (255,)); d.rectangle([1, 1, 3, 3], fill=J.ROPE_L + (255,))
    return im

WIN = J.window(W, H)
def render(page_lines, shown_chars, indicator=None, phase=0, tap=None, name="Mira"):
    plate = J.name_plate(V.width(name) + 14, 14)
    sc = V.backdrop(W + 16, H + 26); sc.alpha_composite(WIN, (8, 20)); sc.alpha_composite(plate, (16, 13))
    sc.alpha_composite(V.text_layer(plate.size, [name], V.TAG, (plate.width - V.width(name)) // 2, 12), (16, 13))
    vis, left = [], shown_chars
    for ln in page_lines:
        vis.append(ln[:max(0, left)]); left -= len(ln)
    sc.alpha_composite(V.text_layer((W, H), vis, V.CREAM, M, 22), (8, 20 + DY))
    if indicator == 'mais': sc.alpha_composite(J.arrow(), (8 + W - 18, 20 + H - 16 + ARROW_BOB[phase % len(ARROW_BOB)]))
    if indicator == 'fim':  sc.alpha_composite(end_mark(phase), (8 + W - 17, 20 + H - 14))
    big = sc.resize((sc.width * S, sc.height * S), Image.NEAREST)
    if tap:                                                     # marca do toque na prévia
        d = ImageDraw.Draw(big); x, y, r = tap; d.ellipse([x - r, y - r, x + r, y + r], outline=(255, 255, 255), width=3)
    return big.convert('RGB')

if __name__ == '__main__':
    TEXT = ("Bem-vindo à guilda, aventureiro! O quadro de contratos está vazio hoje… mas a sopa ainda está quente. "
            "Se quiser se registrar, preciso do seu nome, da sua classe e de duas moedas de prata. "
            "Ah, e não ligue para o Bob. Ele só morde quem não paga a conta.")
    pages = paginate(TEXT); frames, dur = [], []
    tapxy = ((W - 30) * S, (20 + H // 2) * S)
    for pi, pg in enumerate(pages):
        total = sum(len(l) for l in pg); last = pi == len(pages) - 1
        for c in range(0, total + 1, 2):                          # digitação (2 letras por quadro)
            frames.append(render(pg, c)); dur.append(40)
        for ph in range(18):                                      # esperando o clique: seta pulsa
            frames.append(render(pg, total, 'fim' if last else 'mais', ph)); dur.append(110)
        if not last:
            for k in range(3): frames.append(render(pg, total, 'mais', 0, tapxy + (14 + 10 * k,))); dur.append(60)
    frames[0].save(os.path.join(OUT, '_dialogo_paginado.gif'), save_all=True, append_images=frames[1:], duration=dur, loop=0)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(OUT, '_dialogo_paginado.gif'), '-movflags', 'faststart',
                    '-pix_fmt', 'yuv420p', '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', os.path.join(OUT, '_dialogo_paginado.mp4')])
    print(len(pages), 'páginas,', len(frames), 'quadros')
