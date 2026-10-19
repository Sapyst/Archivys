"""Recorte por chroma key magenta com desmistura (unmix) + despill + alfa duro (pixel art).
Uso: recorte_chroma.py entrada  -> devolve lista de (bbox, RGBA) por objeto."""
import numpy as np
from PIL import Image
from scipy import ndimage

def key_alpha(a, K):
    # distância ao magenta, normalizada: 0 = fundo puro, 1 = longe do fundo
    d = np.sqrt(((a - K) ** 2).sum(axis=2))
    return np.clip((d - 60) / 90.0, 0, 1)

def cutout(path, min_area=4000, soft=False):
    a = np.asarray(Image.open(path).convert('RGB')).astype(float)
    border = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    K = np.median(border, axis=0)
    al = key_alpha(a, K)
    # unmix: C = α·F + (1-α)·K  →  F = (C - (1-α)K) / α
    with np.errstate(divide='ignore', invalid='ignore'):
        F = (a - (1 - al)[..., None] * K) / np.maximum(al, 0.05)[..., None]
    F = np.clip(F, 0, 255)
    # despill: qualquer tom magenta residual (r e b bem acima de g) é neutralizado
    r, g, b = F[..., 0], F[..., 1], F[..., 2]
    spill = np.minimum(r, b) - g
    m = spill > 18
    F[m, 0] -= spill[m] * 0.9; F[m, 2] -= spill[m] * 0.9
    F = np.clip(F, 0, 255)
    solid = al > 0.5
    solid = ndimage.binary_opening(solid, iterations=1)
    lab, n = ndimage.label(ndimage.binary_closing(solid, iterations=4))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        sl = tuple(slice(max(0, x.start - 2), x.stop + 2) for x in sl)
        mk = (lab[sl] == i + 1) & solid[sl]
        if mk.sum() < min_area: continue
        rgb = F[sl].copy()
        pm = np.pad(mk, 8, constant_values=False)
        band = (ndimage.binary_dilation(~pm, iterations=8) & pm)[8:-8, 8:-8]   # faixa de 8 px junto da borda
        sp = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
        bm = band & (sp > 4)
        rgb[bm, 0] -= sp[bm]; rgb[bm, 2] -= sp[bm]                        # borda: zera qualquer viés magenta
        rgb = np.round(rgb)
        if soft:   # antialiasing: alfa contínuo da chave, só no contorno (1 px para fora, 2 px para dentro), suavizado
            ring = ndimage.binary_dilation(mk, iterations=1)
            inner = ndimage.binary_erosion(mk, iterations=2)
            A = np.where(inner, 1.0, np.where(ring, al[sl], 0.0))
            A = ndimage.gaussian_filter(A, 0.6); A = np.where(inner, 1.0, A)
            rgb = np.where(ring[..., None] & ~mk[..., None], F[sl], rgb)    # cor desmisturada no pixel extra
            alpha = (np.clip(A, 0, 1) * 255).round()
            edge = alpha < 250                                                # pixels de transição: tom do contorno escuro
            lum = (0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2])
            dark = np.stack([lum * 0.55 + 6, lum * 0.45 + 4, lum * 0.45 + 5], axis=-1)   # marrom-escuro neutro, sem verde/rosa
            rgb = np.where(edge[..., None], dark, rgb)
        else:
            alpha = np.where(mk, 255, 0)
        rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
        out.append((sl, Image.fromarray(rgba, 'RGBA')))
    return out

def square(im):
    sd = max(im.size); sq = Image.new('RGBA', (sd, sd), (0, 0, 0, 0))
    sq.alpha_composite(im, ((sd - im.width) // 2, (sd - im.height) // 2)); return sq
