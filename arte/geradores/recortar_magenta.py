"""Recorta par parado/falando com fundo magenta. Uso: recortar_magenta.py <pasta_personagem> parado.webp falando.webp"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage
D = sys.argv[1]; os.makedirs(f'{D}/recortes', exist_ok=True); outs = {}
for src in sys.argv[2:]:
    n = os.path.splitext(os.path.basename(src))[0]
    a = np.asarray(Image.open(src).convert('RGB')).astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 170) & (b > 170) & (g < 110) & (np.abs(r - b) < 70)
    lab, _ = ndimage.label(mag); seeds = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(seeds)); sizes = ndimage.sum(mag, lab, range(1, lab.max() + 1))
    bg |= np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 300])
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    a[edge, 0] = np.minimum(a[edge, 0], a[edge, 1] + 40); a[edge, 2] = np.minimum(a[edge, 2], a[edge, 1] + 40)
    outs[n] = Image.fromarray(np.dstack([a.clip(0, 255), np.where(bg, 0, 255)]).astype(np.uint8), 'RGBA')
bb = [o.getbbox() for o in outs.values()]
box = (min(x[0] for x in bb), min(x[1] for x in bb), max(x[2] for x in bb), max(x[3] for x in bb))
w, h = box[2] - box[0], box[3] - box[1]; sh = Image.new('RGBA', (w * len(outs), h), (40, 60, 45, 255))
for i, (n, o) in enumerate(outs.items()): o.crop(box).save(f'{D}/recortes/{n}.png'); sh.alpha_composite(o.crop(box), (i * w, 0))
sh.convert('RGB').resize((w * len(outs) // 2, h // 2)).save(f'{D}/_conferencia.png'); print(box)
