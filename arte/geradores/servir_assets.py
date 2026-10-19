"""Peças pixel art do mini-game de servir (nativo; o Godot amplia ×4 NEAREST). Saída: godot/assets/minigames/servir/"""
import os, math, random
from PIL import Image, ImageDraw
import ui_pergaminho as PG

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot', 'assets', 'minigames', 'servir'); os.makedirs(OUT, exist_ok=True)
O = (16, 12, 14, 255)
W1, W2, W3, W4 = (150, 104, 64), (122, 84, 52), (96, 64, 40), (70, 46, 30)      # madeira clara → escura
G1, G2, G3 = (255, 224, 130), (217, 164, 65), (140, 96, 34)                      # ouro
M1, M2, M3 = (176, 172, 168), (118, 114, 112), (66, 62, 62)                      # metal

def wood_panel(w, h, seed=1, nails=True):
    """Tábuas horizontais com veio, contorno escuro, borda de luz em cima e sombra embaixo, pregos nos cantos."""
    rnd = random.Random(seed); im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); p = im.load()
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1) or y in (0, h - 1): p[x, y] = O; continue
            plank = (y - 1) // 5
            c = [W1, W2, W2, W3][(plank + (x + plank * 7) // 23) % 4]
            if (y - 1) % 5 == 4: c = W4                                   # junta entre tábuas
            elif rnd.random() < 0.04: c = W3
            if y == 1: c = (186, 136, 88)
            if y >= h - 3: c = W4
            p[x, y] = c + (255,)
    if nails:
        for (x, y) in ((3, 3), (w - 4, 3), (3, h - 5), (w - 4, h - 5)): p[x, y] = M1 + (255,); p[x + 1, y + 1] = M3 + (255,)
    return im

def counter_mat():
    """Balcão de cada mesa: tábua com bandejinha redonda (alvo do prato). 34×18 nativo."""
    im = wood_panel(34, 18, 3, nails=False); d = ImageDraw.Draw(im)
    d.ellipse([5, 3, 28, 15], fill=(52, 36, 26, 255), outline=O)         # rebaixo da bandeja
    d.ellipse([7, 5, 26, 13], outline=(84, 58, 40, 255))
    return im

def counter_mat_glow():
    im = counter_mat(); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 33, 17], outline=G2 + (255,)); d.rectangle([1, 1, 32, 16], outline=G1 + (255,))
    return im

def slot_mat():
    """Rebaixo redondo da bandeja (onde fica cada prato). 30×20."""
    im = Image.new('RGBA', (30, 20), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([0, 4, 29, 19], fill=(40, 28, 22, 255), outline=O); d.ellipse([3, 7, 26, 17], fill=(52, 36, 28, 255))
    d.arc([3, 7, 26, 17], 200, 340, fill=(30, 20, 16, 255))
    return im

def chip(w=14, h=9, gold=True):
    """Selinho de contagem (fundo escuro + aro dourado)."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], 3, fill=(28, 20, 22, 255), outline=O)
    d.rounded_rectangle([1, 1, w - 2, h - 2], 2, outline=(G2 if gold else M2) + (255,))
    return im

def ticket():
    """Comanda de papel com alfinete (9-slice: margens 4). 30×36."""
    paper = PG.parchment(30, 34, r=2, tear=1.6, seed=11)
    im = Image.new("RGBA", (30, 37), (0, 0, 0, 0)); im.alpha_composite(paper, (0, 3))
    d = ImageDraw.Draw(im); d.ellipse([12, 0, 17, 5], fill=(176, 50, 44, 255), outline=O); d.point((13, 1), fill=(240, 140, 120, 255))
    return im

def bar_frame(w=130, h=9):
    """Moldura da barra de tempo: metal com trilho escuro. O preenchimento é desenhado no Godot."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], 3, fill=M2 + (255,), outline=O)
    d.line([3, 1, w - 4, 1], fill=M1 + (255,)); d.line([3, h - 2, w - 4, h - 2], fill=M3 + (255,))
    d.rectangle([2, 2, w - 3, h - 3], fill=(24, 18, 20, 255))
    return im

def hourglass():
    im = Image.new('RGBA', (9, 11), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 8, 1], fill=W2 + (255,), outline=O); d.rectangle([0, 9, 8, 10], fill=W2 + (255,), outline=O)
    d.polygon([(1, 2), (7, 2), (4, 5), (7, 8), (1, 8), (4, 5)], fill=(200, 220, 235, 255), outline=O)
    d.polygon([(2, 3), (6, 3), (4, 5)], fill=G1 + (255,)); d.polygon([(3, 8), (5, 8), (4, 6)], fill=G2 + (255,))
    return im

def flame(level):
    """Chama do combo (3 tamanhos)."""
    s = [9, 11, 13][level]; im = Image.new('RGBA', (s, s + 2), (0, 0, 0, 0)); p = im.load()
    cx = (s - 1) / 2
    for y in range(s + 2):
        for x in range(s):
            v = abs(x - cx) / (s / 2) + (1 - y / (s + 1)) ** 1.6 * 0.9
            if v < 1.0:
                p[x, y] = ((255, 236, 160) if v < 0.45 else (255, 170, 60) if v < 0.75 else (210, 70, 40)) + (255,)
    edge = [(x, y) for y in range(s + 2) for x in range(s) if p[x, y][3] == 0 and any(
        0 <= x + dx < s and 0 <= y + dy < s + 2 and p[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge: p[x, y] = O
    return im

if __name__ == '__main__':
    wood_panel(40, 24, 7).save(os.path.join(OUT, 'bandeja_9slice.png'))          # 9-slice margem 6
    counter_mat().save(os.path.join(OUT, 'balcao.png')); counter_mat_glow().save(os.path.join(OUT, 'balcao_alvo.png'))
    slot_mat().save(os.path.join(OUT, 'rebaixo.png')); chip().save(os.path.join(OUT, 'chip.png')); chip(gold=False).save(os.path.join(OUT, 'chip_cinza.png'))
    ticket().save(os.path.join(OUT, 'comanda.png')); bar_frame().save(os.path.join(OUT, 'barra_moldura.png'))
    hourglass().save(os.path.join(OUT, 'ampulheta.png'))
    for i in range(3): flame(i).save(os.path.join(OUT, f'chama_{i}.png'))
    prev = Image.new('RGBA', (220, 60), (40, 32, 34, 255)); x = 2
    for f in ['balcao.png', 'balcao_alvo.png', 'rebaixo.png', 'chip.png', 'comanda.png', 'ampulheta.png', 'chama_0.png', 'chama_1.png', 'chama_2.png']:
        im = Image.open(os.path.join(OUT, f)); prev.alpha_composite(im, (x, 2)); x += im.width + 3
    prev.alpha_composite(Image.open(os.path.join(OUT, 'barra_moldura.png')), (2, 45))
    prev.resize((prev.width * 5, prev.height * 5), Image.NEAREST).convert('RGB').save('/tmp/claude-1000/-mnt-d/4365d6fb-bcb6-4e9c-a147-153f605c82cc/scratchpad/servir_assets.png')
    print('ok')
