"""Vitrine: a fonte Snide Asides PT aplicada na janela de corda, no bilhete e no contrato animado.
Texto renderizado no tamanho NATIVO (pixel perfeito) e só depois tudo é ampliado."""
import os, subprocess
from PIL import Image
from fontTools.ttLib import TTFont
import previa_fonte as P
import ui_janela as J
import ui_pergaminho as PG

FONT = TTFont(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'fontes', 'SnideAsidesPT.ttf'))
OUT = J.OUT; S = 4
CREAM, INK, TAG = (236, 224, 204), (60, 36, 22), (40, 24, 16)
LH = 15                                                      # altura de linha (px nativos)

def text_layer(size, lines, ink, x, y, lh=LH):
    lay = Image.new('RGBA', size, (0, 0, 0, 0))
    for i, s in enumerate(lines): P.render_line(FONT, s, ink + (255,), lay, x, y + i * lh)
    return lay

def width(s):
    lay = Image.new('RGBA', (400, 30), (0, 0, 0, 0)); return int(P.render_line(FONT, s, (0, 0, 0, 255), lay, 0, 20))

def wrap(text, maxw):
    """Quebra por palavra medindo a largura real em pixels — mantém o texto dentro da área segura."""
    out = []
    for para in text.split('\n'):
        line = ''
        for w in para.split(' '):
            t = (line + ' ' + w).strip()
            if line and width(t) > maxw: out.append(line); line = w
            else: line = t
        out.append(line)
    return out

def backdrop(w, h):
    try:
        b = Image.open(os.path.join(OUT, '..', 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA')
        return b.resize((w, w), Image.NEAREST).crop((0, w - h, w, w))
    except Exception: return Image.new('RGBA', (w, h), (50, 40, 44, 255))

def big(im): return im.resize((im.width * S, im.height * S), Image.NEAREST)

M = 14                                                   # margem de conteúdo (área segura)

if __name__ == '__main__':
    W = 232
    # 1) janela de corda com placa de nome
    DLG = wrap("Bem-vindo à guilda, aventureiro! O quadro de contratos está vazio hoje… mas a sopa ainda está quente.", W - 2 * M)
    H = 22 + len(DLG) * LH + 8
    win = J.window(W, H); plate = J.name_plate(width("Mira") + 14, 14)
    scene = backdrop(W + 16, H + 26); scene.alpha_composite(win, (8, 20))
    scene.alpha_composite(plate, (16, 13))
    scene.alpha_composite(text_layer(plate.size, ["Mira"], TAG, (plate.width - width("Mira")) // 2, 12), (16, 13))
    lay = text_layer((W, H), DLG, CREAM, M, 22)
    bb = lay.getbbox(); dy = (H - (bb[3] - bb[1])) // 2 - bb[1]        # centraliza no eixo Y pelos pixels reais
    scene.alpha_composite(lay, (8, 20 + dy))
    scene.alpha_composite(J.arrow(), (8 + W - 18, 20 + H - 15))
    big(scene).convert('RGB').save(os.path.join(OUT, '_vitrine_dialogo.png'))

    # 2) bilhete rasgado
    W2 = 220; NOTE = wrap("“Volto em três dias. Guardem minha caneca e não deixem o Bob beber o hidromel.”\u00a0—\u00a0Kael", W2 - 2 * M)
    H2 = 20 + len(NOTE) * LH + 8
    note = PG.parchment(W2, H2); sc2 = backdrop(W2 + 16, H2 + 16); sc2.alpha_composite(note, (8, 8))
    sc2.alpha_composite(text_layer((W2, H2), NOTE, INK, M, 20), (8, 8))
    big(sc2).convert('RGB').save(os.path.join(OUT, '_vitrine_bilhete.png'))

    # 3) contrato enrolado animado
    import ui_pergaminho_anim as A
    A.W = 196
    LINES = sum((wrap(t, A.W - 34) if t else [''] for t in ["Rank: E", "Local: Moinho velho", "Alvo: ratos gigantes (12)", "Prazo: 2 dias", "",
                 "Recompensa:", "40 moedas de prata", "+15 de fama"]), [])
    A.H = 56 + len(LINES) * LH + 26
    A.PAPER = PG.parchment(A.W - 8, A.H - 2 * A.RH + 4, r=2, tear=1.0, seed=8)
    title = "CONTRATO"
    def framed(img, n_lines, seal=False):
        canvas = Image.new('RGBA', (A.W + 20, A.H + 10), (34, 26, 30, 255)); canvas.alpha_composite(img, (10, 5))
        if n_lines:
            canvas.alpha_composite(text_layer(canvas.size, [title], INK, (canvas.width - width(title)) // 2, 32), (0, 0))
            for x in range(26, canvas.width - 26): canvas.putpixel((x, 38), (150, 110, 70, 255))
            canvas.alpha_composite(text_layer(canvas.size, LINES[:n_lines - 1], INK, 22, 56), (0, 0))
        if seal: canvas.alpha_composite(PG.seal(), (A.W - 18, A.H - 20))
        return big(canvas).convert('RGB')
    frames, dur = [], []
    for _ in range(6): frames.append(framed(A.frame(0, 0, True), 0)); dur.append(120)
    for k in (1, 2): frames.append(framed(A.frame(0, 0, True, k), 0)); dur.append(110)
    N = 12
    for i in range(1, N + 1): frames.append(framed(A.frame(A.ease_out(i / N), i), 0)); dur.append(55)
    for n in range(1, len(LINES) + 2): frames.append(framed(A.frame(1, N), n)); dur.append(80)
    frames.append(framed(A.frame(1, N), len(LINES) + 1, True)); dur.append(2400)
    for i in range(N - 1, -1, -1): frames.append(framed(A.frame(A.ease_in(i / N), i), 0)); dur.append(45)
    frames.append(framed(A.frame(0, 0, True), 0)); dur.append(900)
    gif = os.path.join(OUT, '_vitrine_contrato.gif')
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=dur, loop=0)
    frames[len(frames) - N - 2].save(os.path.join(OUT, '_vitrine_contrato.png'))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', gif, '-movflags', 'faststart', '-pix_fmt', 'yuv420p',
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', gif.replace('.gif', '.mp4')])
    print('ok')
