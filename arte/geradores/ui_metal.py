"""Painel metálico minimalista (SDF de retângulo arredondado): contorno escuro, aro de metal com luz no
canto superior esquerdo e sombra no inferior direito, filete interno escuro, interior chapado. Para MENUS
(a corda fica só para conversa)."""
import math
from PIL import Image
OUTL = (16, 12, 14); RIM_L, RIM_M, RIM_D = (176, 172, 168), (118, 114, 112), (66, 62, 62)
INNER = (36, 28, 30); FILL = (28, 22, 24)

def sd(x, y, w, h, r):
    cx, cy = (w - 1) / 2, (h - 1) / 2; qx, qy = abs(x - cx) - (cx - r), abs(y - cy) - (cy - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r

def panel(w, h, r=4, rim=2, fill=FILL, alpha=255):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); p = im.load()
    for y in range(h):
        for x in range(w):
            d = sd(x, y, w, h, r)
            if d > 0.5: continue
            if d > -0.5: p[x, y] = OUTL + (255,); continue
            if d > -0.5 - rim:                                  # aro: luz pela direção (cima/esquerda claro)
                t = (x / max(w - 1, 1) + y / max(h - 1, 1)) / 2
                c = RIM_L if t < 0.35 else RIM_M if t < 0.7 else RIM_D
                if y <= 1 + rim: c = RIM_L
                p[x, y] = c + (255,); continue
            if d > -1.5 - rim: p[x, y] = INNER + (255,); continue
            p[x, y] = fill + (alpha,)
    return im

def bubble(w, h, tail_side='left', tail_y=None, r=5, fill=(236, 226, 206)):
    """Balão simples: retângulo arredondado + rabicho, contorno fino 1 px contínuo (o rabicho faz parte da borda)."""
    T = 8; W = w + T; im = Image.new('RGBA', (W, h), (0, 0, 0, 0)); p = im.load()
    ty = tail_y if tail_y is not None else h // 2; ox = T if tail_side == 'left' else 0
    def inside(x, y):
        if sd(x - ox, y, w, h, r) <= 0: return True
        tx = x if tail_side == 'left' else W - 1 - x            # triângulo: ponta em tx=0, base em tx=T+2
        if 0 <= tx <= T + 2:
            half = 4 * tx / (T + 2)
            return abs(y - ty) <= half
        return False
    for y in range(h):
        for x in range(W):
            if not inside(x, y): continue
            edge = any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            p[x, y] = (OUTL if edge else fill) + (255,)
    return im, ox
