"""Ícone do app (Archivys): o orbe azul da recepção num medalhão de bronze.
48×48 px nativos → ×4 NEAREST = 192×192 (godot/icon.png). Também gera os ícones de prato do HUD
(godot/assets/ui/icones/pratos_{18,24,28}.png) a partir da versão pixel do Roast Chicken.
Rodar: /mnt/d/pixelart/.venv/bin/python arte/geradores/icone_app.py
"""
import math
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
GODOT = RAIZ / "godot"

CONTORNO = (20, 12, 16, 255)
ARO = [(255, 224, 130), (217, 164, 65), (140, 96, 34), (92, 60, 24)]   # luz → sombra (metal dourado do jogo)
FUNDO = [(34, 30, 58), (26, 22, 44), (20, 16, 32)]
ORBE = [(214, 244, 255), (120, 210, 250), (52, 150, 235), (30, 92, 200), (22, 52, 140), (16, 30, 84)]


def icone(n=48):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c = (n - 1) / 2.0
    r_ext, r_aro = 23.0, 18.5
    for y in range(n):
        for x in range(n):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            if d > r_ext + 0.5:
                continue
            if d > r_ext - 0.6:
                px[x, y] = CONTORNO
                continue
            if d > r_aro:
                # aro com 12 dentes (entalhes escuros) e luz vinda de cima/esquerda
                luz = -(dx + dy) / (d + 1e-6)          # +1 em cima/esquerda, −1 embaixo/direita
                k = 1 if luz > 0.35 else (2 if luz > -0.35 else 3)
                if d > r_ext - 1.8 and luz > 0.2:
                    k = 0
                dente = (ang / (2 * math.pi) * 12) % 1.0
                if 0.42 < dente < 0.58 and d > r_aro + 1.5:
                    k = 3
                px[x, y] = ARO[k] + (255,)
                continue
            if d > r_aro - 1.0:
                px[x, y] = CONTORNO
                continue
            # interior: pedra azul-escura com juntas (como a parede da recepção)
            linha = (y // 5) % 2
            junta = (y % 5 == 0) or ((x + linha * 4) % 8 == 0)
            px[x, y] = (FUNDO[2] if junta else FUNDO[1]) + (255,)
    # suporte dourado do orbe
    oc_x, oc_y, r_o = c, c - 2.0, 10.5
    for y in range(n):
        for x in range(n):
            if 31 <= y <= 35 and abs(x - c) <= 7 - (y - 31) * 0.0 and abs(x - c) <= 3 + (y - 31):
                px[x, y] = (ARO[1] if y < 34 else ARO[2]) + (255,)
            if y == 36 and abs(x - c) <= 8.5:
                px[x, y] = CONTORNO
            if y == 35 and abs(x - c) <= 8:
                px[x, y] = ARO[2] + (255,)
    # orbe: aro de bronze + esfera azul com brilho no alto à esquerda
    for y in range(n):
        for x in range(n):
            dx, dy = x - oc_x, y - oc_y
            d = math.hypot(dx, dy)
            if d > r_o + 2.5:
                continue
            if d > r_o + 1.5:
                px[x, y] = CONTORNO
            elif d > r_o:
                px[x, y] = (ARO[0] if dy < 0 else ARO[2]) + (255,)
            elif d > r_o - 0.8:
                px[x, y] = CONTORNO
            else:
                hx, hy = dx + 3.5, dy + 3.5            # centro do brilho
                t = math.hypot(hx, hy) / (r_o * 1.25)
                k = min(5, int(t * 6))
                if d > r_o - 1.8:
                    k = max(k, 4)
                px[x, y] = ORBE[k] + (255,)
    # brilho especular (2×2 + ponto) e reflexo inferior
    for (x, y) in [(int(oc_x) - 4, int(oc_y) - 5), (int(oc_x) - 3, int(oc_y) - 5),
                   (int(oc_x) - 4, int(oc_y) - 4), (int(oc_x) - 1, int(oc_y) - 6)]:
        px[x, y] = (255, 255, 255, 255)
    for x in range(int(oc_x) + 1, int(oc_x) + 5):
        px[x, int(oc_y) + 7] = ORBE[2] + (255,)
    return img


def prato_hud(origem, tam):
    im = Image.open(origem).convert("RGBA")
    im = im.crop(im.getbbox())
    alvo = tam - 2
    esc = alvo / max(im.size)
    im = im.resize((max(1, round(im.width * esc)), max(1, round(im.height * esc))), Image.BOX)
    rgb = im.convert("RGB").quantize(colors=14, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    ox, oy = (tam - im.width) // 2, (tam - im.height) // 2
    a = im.getchannel("A")
    for y in range(im.height):
        for x in range(im.width):
            if a.getpixel((x, y)) > 120:
                out.putpixel((ox + x, oy + y), rgb.getpixel((x, y)) + (255,))
    # contorno 1 px por fora
    base = out.copy()
    for y in range(tam):
        for x in range(tam):
            if base.getpixel((x, y))[3]:
                continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < tam and 0 <= yy < tam and base.getpixel((xx, yy))[3]:
                    out.putpixel((x, y), CONTORNO)
                    break
    return out


if __name__ == "__main__":
    ic = icone()
    ic.resize((192, 192), Image.NEAREST).save(GODOT / "icon.png")
    ic.resize((480, 480), Image.NEAREST).save(RAIZ / "arte" / "ui" / "_icone_app_previa.png")
    for t in (18, 24, 28):
        prato_hud(GODOT / "assets/pratos/px/roast_chicken_32.png", t).save(GODOT / f"assets/ui/icones/pratos_{t}.png")
    print("ok")
