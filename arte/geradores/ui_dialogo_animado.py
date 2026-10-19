"""Janela de diálogo abrindo e fechando. Como a janela é procedural (9-slice), cada quadro é
regerado no tamanho exato — a corda nunca estica nem borra. Abre do centro com leve "pulo" (overshoot),
a placa de nome cai no lugar, o texto digita, e fecha encolhendo."""
import os, subprocess
from PIL import Image
import ui_janela as J
import ui_vitrine_fonte as V
import ui_dialogo_paginado as D

W, H, S, OUT = D.W, D.H, D.S, D.OUT
BW, BH = W + 16, H + 26                    # tamanho do quadro (fundo)
BG = V.backdrop(BW, BH)
CX, CY = 8 + W // 2, 20 + H // 2

def ease_out_back(t, k=1.6): t -= 1; return 1 + (k + 1) * t ** 3 + k * t ** 2
def ease_in(t): return t * t

def shell(w, h, plate_dy=None, alpha=255):
    sc = BG.copy()
    if w >= 16 and h >= 16:
        win = J.window(int(w), int(h))
        if alpha < 255: win.putalpha(win.getchannel('A').point(lambda a: a * alpha // 255))
        sc.alpha_composite(win, (CX - int(w) // 2, CY - int(h) // 2))
    if plate_dy is not None:
        plate = J.name_plate(V.width("Mira") + 14, 14)
        sc.alpha_composite(plate, (16, 13 + plate_dy))
        sc.alpha_composite(V.text_layer(plate.size, ["Mira"], V.TAG, (plate.width - V.width("Mira")) // 2, 12), (16, 13 + plate_dy))
    return sc

def big(sc): return sc.resize((BW * S, BH * S), Image.NEAREST).convert('RGB')

if __name__ == '__main__':
    frames, dur = [], []
    for _ in range(4): frames.append(big(BG.copy())); dur.append(120)
    N = 9                                                     # ABRIR
    for i in range(1, N + 1):
        t = i / N; e = ease_out_back(t)
        w = 40 + (W - 40) * min(1.0, t * 1.6)                  # largura chega antes
        h = max(16, H * e)                                     # altura com pulo
        frames.append(big(shell(min(w, W + 6), h, alpha=min(255, int(80 + 175 * t))))); dur.append(35)
    for dy in (-8, -4, 1, 0):                                 # placa cai no lugar
        frames.append(big(shell(W, H, dy))); dur.append(45)
    pg = D.paginate("Bem-vindo à guilda, aventureiro! O quadro de contratos está vazio hoje… mas a sopa ainda está quente.")[0]
    total = sum(len(l) for l in pg)
    for c in range(0, total + 1, 2): frames.append(D.render(pg, c)); dur.append(40)
    for ph in range(14): frames.append(D.render(pg, total, 'fim', ph)); dur.append(110)
    M = 6                                                     # FECHAR
    for i in range(1, M + 1):
        t = ease_in(i / M); frames.append(big(shell(W - (W - 40) * t, max(16, H * (1 - t)), alpha=int(255 * (1 - t * 0.7))))); dur.append(35)
    for _ in range(6): frames.append(big(BG.copy())); dur.append(120)
    gif = os.path.join(OUT, '_dialogo_abrindo.gif')
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=dur, loop=0)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', gif, '-movflags', 'faststart', '-pix_fmt', 'yuv420p',
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', gif.replace('.gif', '.mp4')])
    print(len(frames), 'quadros')
