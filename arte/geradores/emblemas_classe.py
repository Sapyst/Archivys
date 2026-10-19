"""Emblemas de classe em pixel art (medalhão redondo de bronze, fundo escuro, símbolo no centro), 32×32 nativo.
Inspirados nos medalhões do autor (Warrior, Mage, Hunter, Guardian, Berserker, Druid). Saída: godot/assets/classes/"""
import os, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot', 'assets', 'classes'); os.makedirs(OUT, exist_ok=True)
N = 32; C = 15.5
O = (16, 12, 14); BR1, BR2, BR3 = (176, 128, 80), (130, 90, 56), (86, 58, 36)
STEEL, STEEL_D, STEEL_L = (160, 166, 180), (96, 100, 116), (220, 226, 236)
WOOD, WOOD_D = (140, 96, 58), (92, 60, 36)

def medal(inner):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0)); p = im.load()
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - C, y - C)
            if d > 15.6: continue
            if d > 14.6: p[x, y] = O + (255,); continue
            if d > 12.0:                                                   # aro de bronze com luz em cima/esquerda
                t = ((x - C) + (y - C)) / 30
                p[x, y] = (BR1 if t < -0.15 else BR2 if t < 0.2 else BR3) + (255,)
                if abs(d - 13.3) < 0.5 and (x + y) % 5 == 0: p[x, y] = BR3 + (255,)   # rebites/textura
                continue
            if d > 11.0: p[x, y] = O + (255,); continue
            p[x, y] = inner + (255,)
    return im, ImageDraw.Draw(im)

def px(d, pts, c):
    for x, y in pts: d.point((x, y), fill=c + (255,))

def warrior():
    im, d = medal((40, 30, 32))
    for i in range(-7, 8):                                                # espada diagonal
        px(d, [(C + i, C + i), (C + i + 1, C + i)], STEEL if i < 5 else WOOD)
    d.polygon([(10, 12), (16, 9), (22, 12), (22, 18), (16, 24), (10, 18)], fill=(150, 44, 40, 255), outline=O + (255,))   # escudo
    d.line([16, 11, 16, 22], fill=(220, 180, 90, 255)); d.line([12, 15, 20, 15], fill=(220, 180, 90, 255))
    return im

def mage():
    im, d = medal((34, 32, 52))
    d.line([16, 11, 16, 25], fill=WOOD + (255,), width=2); d.line([15, 11, 15, 25], fill=WOOD_D + (255,))
    d.ellipse([12, 5, 20, 13], fill=(250, 140, 40, 255), outline=O + (255,)); d.ellipse([14, 7, 18, 11], fill=(255, 235, 150, 255))
    px(d, [(9, 9), (23, 8), (22, 14), (10, 15)], (170, 200, 255))
    return im

def hunter():
    im, d = medal((30, 40, 32))
    d.arc([7, 6, 21, 26], 270, 90, fill=WOOD + (255,), width=2)           # arco
    d.line([14, 6, 14, 26], fill=(220, 214, 196, 255))                    # corda
    d.line([8, 16, 25, 16], fill=WOOD_D + (255,)); d.polygon([(25, 14), (28, 16), (25, 18)], fill=STEEL + (255,))
    px(d, [(8, 14), (9, 15), (8, 18), (9, 17)], (90, 170, 80))
    return im

def guardian():
    im, d = medal((40, 40, 46))
    d.rectangle([11, 12, 21, 24], fill=(120, 120, 130, 255), outline=O + (255,))     # torre
    for x in (11, 15, 19): d.rectangle([x, 9, x + 2, 12], fill=(120, 120, 130, 255), outline=O + (255,))
    d.rectangle([14, 18, 18, 24], fill=O + (255,)); d.point((16, 15), fill=O + (255,))
    px(d, [(12, 13), (12, 14), (12, 15)], (170, 170, 180))
    px(d, [(13, 6), (15, 5), (17, 5), (19, 6), (14, 6), (16, 6), (18, 6)], (217, 164, 65))   # coroa
    return im

def berserker():
    im, d = medal((44, 26, 28))
    for i in range(-8, 9):                                                # cabos cruzados
        px(d, [(C + i, C + i)], WOOD); px(d, [(C + i, C - i)], WOOD_D)
    d.polygon([(6, 6), (12, 5), (11, 11)], fill=STEEL + (255,), outline=O + (255,))           # lâmina do machado
    d.ellipse([20, 5, 27, 12], fill=STEEL_D + (255,), outline=O + (255,))                      # cabeça da maça
    px(d, [(19, 8), (28, 8), (23, 4), (23, 13)], STEEL_L)
    return im

def druid():
    im, d = medal((30, 38, 30))
    d.rectangle([15, 16, 17, 24], fill=WOOD + (255,)); d.line([12, 24, 20, 24], fill=WOOD_D + (255,))   # tronco
    d.ellipse([9, 7, 23, 18], fill=(70, 130, 60, 255), outline=O + (255,)); d.ellipse([12, 8, 18, 13], fill=(110, 170, 80, 255))
    d.arc([20, 19, 26, 25], 60, 260, fill=(236, 226, 190, 255), width=2)   # lua
    return im

if __name__ == '__main__':
    fx = {'warrior': warrior, 'mage': mage, 'hunter': hunter, 'guardian': guardian, 'berserker': berserker, 'druid': druid}
    prev = Image.new('RGBA', (6 * 34 + 2, 36), (40, 32, 34, 255))
    for i, (k, f) in enumerate(fx.items()):
        im = f(); im.save(os.path.join(OUT, k + '.png')); prev.alpha_composite(im, (2 + i * 34, 2))
    prev.resize((prev.width * 5, prev.height * 5), Image.NEAREST).convert('RGB').save('/tmp/claude-1000/-mnt-d/4365d6fb-bcb6-4e9c-a147-153f605c82cc/scratchpad/emblemas.png')
    print('ok')
