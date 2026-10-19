"""Recorta os retratos da Mira: remove o fundo cinza liso (preenchimento a partir das bordas, com tolerância)
e corta o balcão de madeira na base. Padroniza tamanho/enquadramento. Saída: ../personagens/mira/recortes/"""
import os, glob
import numpy as np
from PIL import Image
from scipy import ndimage

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'personagens', 'mira')
OUT = os.path.join(BASE, 'recortes'); os.makedirs(OUT, exist_ok=True)
TOL = 22

def cut(path):
    im = Image.open(path).convert('RGB').resize((1024, 1024), Image.LANCZOS); a = np.asarray(im).astype(int)
    bg = np.median(np.concatenate([a[:20, :].reshape(-1, 3), a[:, :20].reshape(-1, 3), a[:, -20:].reshape(-1, 3)]), axis=0)
    near = (np.abs(a - bg).max(axis=2) <= TOL) & ((a.max(axis=2) - a.min(axis=2)) <= 7)   # cinza neutro (colete é azulado)
    # balcão: linhas de baixo predominantemente marrons
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    brown = (r > g + 12) & (g > b) & (r > 60)
    top = 1024
    for y in range(1023, 700, -1):
        if brown[y].mean() > 0.55: top = y
        elif top < 1024 and y < top - 3: break
    near[top - 2:, :] = True
    lab, _ = ndimage.label(near)
    seeds = set(np.unique(np.concatenate([lab[0], lab[:, 0], lab[:, -1], lab[-1]]))) - {0}
    bgmask = np.isin(lab, list(seeds))
    # vãos fechados (entre braço e corpo): componentes grandes da cor do fundo também saem
    sizes = ndimage.sum(near, lab, range(1, lab.max() + 1))
    holes = [i + 1 for i, sz in enumerate(sizes) if sz > 600 and (i + 1) not in seeds
             and np.abs(a[lab == i + 1].mean(axis=0) - bg).max() < 10]
    bgmask |= np.isin(lab, holes)
    alpha = np.where(bgmask, 0, 255).astype(np.uint8)
    alpha = ndimage.binary_opening(alpha > 0, iterations=1).astype(np.uint8) * 255    # tira farelos soltos
    keep, n = ndimage.label(alpha > 0)
    if n > 1:                                                                     # mantém só a maior peça + vizinhas grandes
        sizes = ndimage.sum(alpha > 0, keep, range(1, n + 1)); big = [i + 1 for i, s in enumerate(sizes) if s > 400]
        alpha = np.where(np.isin(keep, big), 255, 0).astype(np.uint8)
    rgba = np.dstack([np.asarray(im), alpha])
    return Image.fromarray(rgba, 'RGBA'), top

if __name__ == '__main__':
    files = sorted(glob.glob(os.path.join(BASE, 'original', '*.jpg'))); cuts = []
    for f in files:
        img, top = cut(f); cuts.append((os.path.splitext(os.path.basename(f))[0], img, top))
    # enquadramento comum: união das caixas
    boxes = [c[1].getbbox() for c in cuts]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    for name, img, top in cuts:
        img.crop(box).save(os.path.join(OUT, name + '.png'))
    # folha de conferência sobre fundo xadrez e sobre a recepção
    w, h = box[2] - box[0], box[3] - box[1]; tw = 300; th = int(h * tw / w)
    sheet = Image.new('RGBA', (tw * 4, th * 3), (0, 0, 0, 255))
    chk = Image.new('RGBA', (tw, th))
    for y in range(th):
        for x in range(tw): chk.putpixel((x, y), (200, 60, 200, 255) if ((x // 15) + (y // 15)) % 2 else (60, 200, 90, 255))
    for i, (name, img, _) in enumerate(cuts):
        cell = chk.copy(); cell.alpha_composite(img.crop(box).resize((tw, th), Image.LANCZOS)); sheet.paste(cell, ((i % 4) * tw, (i // 4) * th))
    sheet.convert('RGB').save(os.path.join(BASE, '_conferencia_recorte.png'))
    print(box, len(cuts))
