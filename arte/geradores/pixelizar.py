"""Converte ilustração em pixel art no estilo da Mira: reduz para N px de largura, quantiza a paleta,
remove o fundo magenta e desenha contorno preto de 1 px nativo. Uso: pixelizar.py entrada.png saida.png [largura=200] [cores=40]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def pixelize(src, w=200, cores=40, tol=70):
    im = Image.open(src).convert('RGB'); h = round(im.height * w / im.width)
    a = np.asarray(im).astype(int)
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    small = im.resize((w, h), Image.LANCZOS)
    s = np.asarray(small).astype(int)
    near = np.abs(s - bg).max(axis=2) < tol
    lab, _ = ndimage.label(near)
    seeds = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(seeds))
    fg = ndimage.binary_opening(fg, iterations=1)
    q = small.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = np.dstack([np.asarray(q), np.where(fg, 255, 0)]).astype(np.uint8)
    edge = fg & ~ndimage.binary_erosion(fg)                       # contorno preto 1 px
    out[edge, :3] = (22, 14, 18)
    return Image.fromarray(out, 'RGBA')

if __name__ == '__main__':
    w = int(sys.argv[3]) if len(sys.argv) > 3 else 200; c = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    p = pixelize(sys.argv[1], w, c); p.save(sys.argv[2])
    p.resize((p.width * 5, p.height * 5), Image.NEAREST).save(sys.argv[2].replace('.png', '_x5.png'))
