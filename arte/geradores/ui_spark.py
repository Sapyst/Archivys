"""Efeito de clique: "spark" pixel art de 8 direções, animado.
Flash no centro → 8 raios saem (N, NE, L, SE, S, SO, O, NO) → raios se soltam do centro e afinam → viram pontinhos e somem.
Diagonais em escada (dx = dy) com comprimento visual compensado. Saída: ../ui/spark_sheet.png (+ frames) e prévia MP4."""
import os, subprocess
from PIL import Image
import ui_vitrine_fonte as V

OUT = V.OUT; R = 9; SZ = 2 * R + 1
WHITE, GOLD, ORANGE, EMBER = (255, 252, 230), (255, 214, 92), (240, 140, 40), (170, 70, 30)
DIRS = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]

# (início do raio, fim do raio, cor da cabeça, cor da cauda, tamanho do flash central)
FRAMES = [
    (0, 0, WHITE, WHITE, 2),
    (1, 3, WHITE, GOLD, 1),
    (2, 5, WHITE, GOLD, 0),
    (4, 7, GOLD, ORANGE, 0),
    (6, 8, GOLD, ORANGE, 0),
    (8, 8, ORANGE, ORANGE, 0),
    (9, 9, EMBER, EMBER, 0),
]

def frame(r0, r1, head, tail, core):
    im = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0)); c = R
    if core:
        for dx in range(-core + 1, core):
            for dy in range(-core + 1, core): im.putpixel((c + dx, c + dy), WHITE + (255,))
        for dx, dy in DIRS[::2]: im.putpixel((c + dx * core, c + dy * core), GOLD + (255,))
    for dx, dy in DIRS:
        diag = dx and dy
        a, b = (r0, r1) if not diag else (round(r0 * 0.75), round(r1 * 0.75))   # diagonal: compensar comprimento
        for r in range(a, b + 1):
            if r == 0: continue
            col = head if r == b else tail
            x, y = c + dx * r, c + dy * r
            if 0 <= x < SZ and 0 <= y < SZ: im.putpixel((x, y), col + (255,))
    return im

if __name__ == '__main__':
    fr = [frame(*f) for f in FRAMES]
    sheet = Image.new('RGBA', (SZ * len(fr), SZ), (0, 0, 0, 0))
    for i, f in enumerate(fr): sheet.alpha_composite(f, (i * SZ, 0))
    sheet.save(os.path.join(OUT, 'spark_sheet.png'))
    sheet.resize((sheet.width * 10, SZ * 10), Image.NEAREST).save(os.path.join(OUT, '_spark_quadros.png'))
    # prévia: toques sobre a janela de diálogo
    import ui_dialogo_paginado as D
    pg = D.paginate("Bem-vindo à guilda, aventureiro! O quadro de contratos está vazio hoje… mas a sopa ainda está quente.")[0]
    total = sum(len(l) for l in pg); S = D.S
    taps = [(170, 52), (60, 70), (205, 40)]
    frames, dur = [], []
    for k, (tx, ty) in enumerate(taps):
        for _ in range(6): frames.append(D.render(pg, total, 'mais', len(frames))); dur.append(90)
        for f in fr:
            base = D.render(pg, total, 'mais', len(frames)).convert('RGBA')
            sp = f.resize((SZ * S, SZ * S), Image.NEAREST)
            base.alpha_composite(sp, (tx * S - R * S, ty * S - R * S)); frames.append(base.convert('RGB')); dur.append(45)
    gif = os.path.join(OUT, '_spark_clique.gif')
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=dur, loop=0)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', gif, '-movflags', 'faststart', '-pix_fmt', 'yuv420p',
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', gif.replace('.gif', '.mp4')])
    print('ok')
