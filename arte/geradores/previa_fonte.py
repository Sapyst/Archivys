"""Prévia exata de fonte pixel: amostra o centro de cada pixel contra os contornos do glyf (par-ímpar),
sem o auto-hinting do FreeType que desloca detalhes de 1 px."""
from PIL import Image
PX = 64
def _inside(px, py, contours):
    c = False
    for poly in contours:
        n = len(poly)
        for i in range(n):
            (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
            if (y1 > py) != (y2 > py) and px < x1 + (py - y1) * (x2 - x1) / (y2 - y1): c = not c
    return c
def render_line(t, text, ink, img, x0, base):
    cmap = t.getBestCmap(); glyf = t['glyf']; hmtx = t['hmtx']; x = x0
    for ch in text:
        n = cmap.get(ord(ch))
        if n is None: x += 4; continue
        g = glyf[n]
        if g.numberOfContours > 0:
            c, ends, _ = g.getCoordinates(glyf); start = 0; polys = []
            for e in ends: polys.append([(a / PX, b / PX) for a, b in c[start:e + 1]]); start = e + 1
            xs = [p[0] for q in polys for p in q]; ys = [p[1] for q in polys for p in q]
            for gy in range(int(min(ys)) - 1, int(max(ys)) + 1):
                for gx in range(int(min(xs)) - 1, int(max(xs)) + 1):
                    if _inside(gx + .5, gy + .5, polys):
                        X, Y = int(x) + gx, base - gy - 1
                        if 0 <= X < img.width and 0 <= Y < img.height: img.putpixel((X, Y), ink)
        adv = hmtx[n][0]; x += (adv if adv < 32768 else 0) / PX
    return x
