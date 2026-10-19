"""Demonstração de um evento de fala no Guild Dungeon (tela de celular em pé, 180×320 nativo → 720×1280).
Mira aparece → janela abre → falas com troca de expressão → contrato desenrola → Aceitar (spark) → carimbo →
contrato fecha → última fala → janela fecha. Saída: ../ui/_evento_demo.mp4"""
import os, glob, shutil, subprocess
from PIL import Image, ImageDraw
import ui_janela as J, ui_vitrine_fonte as V, ui_pergaminho as PG, ui_spark as SP
import ui_pergaminho_anim as A

GW, GH, S, FPS = 180, 320, 4, 25
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
TMP = '/tmp/claude-1000/-mnt-d/4365d6fb-bcb6-4e9c-a147-153f605c82cc/scratchpad/evento'
shutil.rmtree(TMP, ignore_errors=True); os.makedirs(TMP)

# ---------- cena ----------
bg = Image.open(os.path.join(ROOT, 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA').resize((GH, GH), Image.LANCZOS)
BG = bg.crop(((GH - GW) // 2, 0, (GH - GW) // 2 + GW, GH))
PORT = {}
for f in glob.glob(os.path.join(ROOT, 'personagens', 'mira', 'recortes', '*.png')):
    k = os.path.basename(f)[3:-4]; im = Image.open(f).convert('RGBA')
    PORT[k] = im.resize((150, int(im.height * 150 / im.width)), Image.LANCZOS)

DW, M, LH = GW - 16, 14, V.LH
DH = 22 + 3 * LH + 8; DX, DY = 8, GH - 8 - DH
_ref = V.text_layer((DW, DH), ["Ág"] * 3, V.CREAM, M, 22).getbbox(); TY = (DH - (_ref[3] - _ref[1])) // 2 - _ref[1]
SPARK = [SP.frame(*f) for f in SP.FRAMES]

def scene(expr=None, alpha=255, dy=0):
    c = BG.copy()
    if expr:
        p = PORT[expr].copy()
        if alpha < 255: p.putalpha(p.getchannel('A').point(lambda v: v * alpha // 255))
        c.alpha_composite(p, ((GW - p.width) // 2, DY + 14 - p.height + dy))
    return c

def dialog(c, lines=(), shown=0, ind=None, ph=0, size=1.0, name="Mira", plate=True):
    w, h = int(16 + (DW - 16) * min(1, size * 1.4)), max(16, int(DH * size))
    win = J.window(min(w, DW + 4), h); c.alpha_composite(win, (DX + DW // 2 - win.width // 2, DY + DH // 2 - h // 2))
    if size < 1: return
    if plate:
        pl = J.name_plate(V.width(name) + 14, 14); c.alpha_composite(pl, (DX + 8, DY - 7))
        c.alpha_composite(V.text_layer(pl.size, [name], V.TAG, (pl.width - V.width(name)) // 2, 12), (DX + 8, DY - 7))
    vis, left = [], shown
    for ln in lines: vis.append(ln[:max(0, left)]); left -= len(ln)
    c.alpha_composite(V.text_layer((DW, DH), vis, V.CREAM, M, 22), (DX, DY + TY))
    if ind == 'mais': c.alpha_composite(J.arrow(), (DX + DW - 18, DY + DH - 16 + [0, 0, 1, 2, 2, 1][ph % 6]))
    if ind == 'fim' and ph % 8 < 5:
        d = ImageDraw.Draw(c); x, y = DX + DW - 17, DY + DH - 14
        d.rectangle([x, y, x + 4, y + 4], fill=J.OUTL); d.rectangle([x + 1, y + 1, x + 3, y + 3], fill=J.ROPE_L)

def button(c, x, y, label, pressed=False):
    w = V.width(label) + 20; win = J.window(w, 24, rope=4, r=5)
    if pressed: win = win.point(lambda v: int(v * 0.8)); y += 1
    c.alpha_composite(win, (x, y)); c.alpha_composite(V.text_layer((w, 24), [label], V.CREAM, 10, 17), (x, y))
    return (x, y, w, 24)

frames = []
def emit(c, n=1, spark=None):
    for _ in range(n):
        img = c.copy()
        if spark: (sx, sy, k) = spark; img.alpha_composite(SPARK[k], (sx - SP.R, sy - SP.R))
        frames.append(img)

def tap(builder, x, y):
    for k in range(len(SPARK)): emit(builder(), 1, (x, y, k))

def speak(expr, text, last=False, enter=False):
    pages = [V.wrap(text, DW - 2 * M)[i:i + 3] for i in range(0, len(V.wrap(text, DW - 2 * M)), 3)]
    for pi, pg in enumerate(pages):
        tot = sum(len(l) for l in pg)
        for ch in range(0, tot + 1, 2):
            c = scene(expr); dialog(c, pg, ch); emit(c)
        final = last and pi == len(pages) - 1
        for ph in range(30):
            c = scene(expr); dialog(c, pg, tot, 'fim' if final else 'mais', ph // 2); emit(c)
        def b(): c = scene(expr); dialog(c, pg, tot, 'fim' if final else 'mais', 0); return c
        tap(b, GW - 40, DY + 40)

# 1) Mira aparece
for i in range(8): emit(scene())
for a in range(0, 256, 32): emit(scene('neutra', a, 6 - a * 6 // 255))
# 2) janela abre
for i in range(1, 9):
    c = scene('neutra'); t = i / 8; e = 1 + 2.6 * (t - 1) ** 3 + 1.6 * (t - 1) ** 2
    dialog(c, size=max(0.05, e) if i < 8 else 1.0); emit(c)
speak('feliz', "Ah, você chegou! Bem na hora. O reino mandou um contrato novo pra gente.")
speak('pensativa', "Ratos gigantes no moinho velho. Doze deles. Nada que um novato não resolva… eu acho.")
speak('neutra', "Dá uma olhada e me diz se aceita.")

# 3) contrato
A.W = 150
LINES = sum((V.wrap(t, A.W - 34) if t else [''] for t in ["Rank: E", "Local: Moinho velho", "Alvo: ratos gigantes (12)",
            "Prazo: 2 dias", "", "Recompensa:", "40 moedas de prata", "+15 de fama"]), [])
A.H = 56 + len(LINES) * LH + 50
A.PAPER = PG.parchment(A.W - 8, A.H - 2 * A.RH + 4, r=2, tear=1.0, seed=8)
CX = (GW - A.W) // 2; CY = 22
def contract_layer(open_frac, phase, sealed=False, crack=0, text=False, stamp=False):
    im = A.frame(open_frac, phase, sealed, crack)
    if text:
        im.alpha_composite(V.text_layer(im.size, ["CONTRATO"], V.INK, (A.W - V.width("CONTRATO")) // 2, 28))
        for x in range(16, A.W - 16): im.putpixel((x, 34), (150, 110, 70, 255))
        im.alpha_composite(V.text_layer(im.size, LINES, V.INK, 14, 52))
    if stamp:
        st = Image.new('RGBA', (90, 30), (0, 0, 0, 0)); d = ImageDraw.Draw(st)
        d.rectangle([0, 0, 89, 29], outline=(170, 30, 30, 255), width=2)
        st.alpha_composite(V.text_layer(st.size, ["ACEITO"], (170, 30, 30), (90 - V.width("ACEITO")) // 2, 21))
        st = st.rotate(12, expand=True, resample=Image.NEAREST); im.alpha_composite(st, (A.W - st.width - 8, A.H - st.height - 12))
    return im
def cscene(layer, dim=140, buttons=None):
    c = scene('neutra'); dialog(c, ["Dá uma olhada e me diz se aceita."], 99)
    c.alpha_composite(Image.new('RGBA', c.size, (0, 0, 0, dim)))
    c.alpha_composite(layer, (CX, CY))
    rects = {}
    if buttons is not None:
        by = CY + A.H + 8
        rects['ok'] = button(c, 22, by, "Aceitar", buttons == 'ok')
        rects['no'] = button(c, GW - 22 - (V.width("Recusar") + 20), by, "Recusar", buttons == 'no')
    return c, rects
for k in range(6): emit(cscene(contract_layer(0, 0, True), dim=k * 23)[0])
for cr in (1, 2): emit(cscene(contract_layer(0, 0, True, cr))[0], 3)
for i in range(1, 13): emit(cscene(contract_layer(A.ease_out(i / 12), i))[0])
emit(cscene(contract_layer(1, 12, text=True), buttons='')[0], 45)
c, R = cscene(contract_layer(1, 12, text=True), buttons='')
bx, by, bw, bh = R['ok']
tap(lambda: cscene(contract_layer(1, 12, text=True), buttons='ok')[0], bx + bw // 2, by + bh // 2)
for k in range(10): emit(cscene(contract_layer(1, 12, text=True, stamp=k >= 2))[0])
emit(cscene(contract_layer(1, 12, text=True, stamp=True))[0], 30)
for i in range(11, -1, -1): emit(cscene(contract_layer(A.ease_in(i / 12), i), dim=140)[0])
for k in range(6): emit(cscene(contract_layer(0, 0, True), dim=140 - k * 23)[0])

# 4) última fala e fim
speak('determinada', "Ótimo! Assinado e carimbado. Volte inteiro, ouviu? Não quero acender vela pra ninguém.", last=True)
for i in range(6, -1, -1):
    c = scene('feliz'); dialog(c, size=max(0.05, i / 6) if i else 0.05) if i else None; emit(c)
for a in range(255, -1, -40): emit(scene('feliz', a))
for i in range(12): emit(scene())

for i, f in enumerate(frames):
    f.resize((GW * S, GH * S), Image.NEAREST).convert('RGB').save(os.path.join(TMP, f'{i:05d}.png'))
out = os.path.join(ROOT, 'ui', '_evento_demo.mp4')
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', os.path.join(TMP, '%05d.png'),
                '-pix_fmt', 'yuv420p', '-movflags', 'faststart', '-crf', '20', out])
for i in (60, len(frames) // 2, len(frames) * 2 // 3, len(frames) - 60):
    frames[i].resize((GW * 2, GH * 2), Image.NEAREST).save(f'{TMP}/_amostra_{i}.png')
print(len(frames), 'quadros,', round(len(frames) / FPS, 1), 's ->', out)
