"""Evento ALARMANTE (v2): shake + "!" mangá, fundo desfoca e ela surge junto com a janela,
animação por humor no começo de cada fala, sai de cena ANTES da janela fechar.
Base: demonstração de um evento de fala no Guild Dungeon (tela de celular em pé, 180×320 nativo → 720×1280).
Mira aparece → janela abre → falas com troca de expressão → contrato desenrola → Aceitar (spark) → carimbo →
contrato fecha → última fala → janela fecha. Saída: ../ui/_evento_demo.mp4"""
import os, glob, shutil, subprocess
from PIL import Image, ImageDraw
import ui_janela as J, ui_vitrine_fonte as V, ui_pergaminho as PG, ui_spark as SP
import ui_pergaminho_anim as A

GW, GH, S, FPS = 180, 320, 4, 25
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
TMP = '/tmp/claude-1000/-mnt-d/4365d6fb-bcb6-4e9c-a147-153f605c82cc/scratchpad/evento2'
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
    spec = getattr(c, 'spec', None); bang = getattr(c, 'bang', None)
    for _ in range(n):
        img = c.copy()
        if spark: (sx, sy, k) = spark; img.alpha_composite(SPARK[k], (sx - SP.R, sy - SP.R))
        frames.append((img, spec, bang))

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

from PIL import ImageFilter
import math
SRC = Image.open(os.path.join(ROOT, 'conceito', 'final', 'canto_2_recepcao.png')).convert('RGBA').resize((GH * S, GH * S), Image.LANCZOS)
BGH = SRC.crop(((GH - GW) * S // 2, 0, (GH - GW) * S // 2 + GW * S, GH * S))
BLURH = Image.blend(BGH.filter(ImageFilter.GaussianBlur(5)), Image.new('RGBA', BGH.size, (10, 6, 12, 255)), 0.22)
PORTH = {}
for f in glob.glob(os.path.join(ROOT, 'personagens', 'mira', 'recortes', '*.png')):
    im = Image.open(f).convert('RGBA'); PORTH[os.path.basename(f)[3:-4]] = im.resize((150 * S, int(im.height * 150 * S / im.width)), Image.LANCZOS)
BX, BY = GW // 2, 108                      # centro do "!"
def speed_lines(k):
    lay = Image.new('RGBA', (GW * S, GH * S), (0, 0, 0, 0)); d = ImageDraw.Draw(lay); cx, cy = BX * S, BY * S
    for i in range(30):
        a = i * math.tau / 30 + (0.05 if k % 2 else 0) + (i * 0.37 % 0.1)
        r0 = (150 + (i * 53 % 70)) ; r1 = 1400; w = 10 + (i * 7 % 12)
        ux, uy = math.cos(a), math.sin(a); px, py = -uy, ux
        d.polygon([(cx + ux * r0, cy + uy * r0), (cx + ux * r1 + px * w, cy + uy * r1 + py * w), (cx + ux * r1 - px * w, cy + uy * r1 - py * w)],
                  fill=(255, 255, 255, 170))
    return lay
def build_back(spec, bang):
    expr, blur, off, shake, sink = spec
    if isinstance(blur, float): c = Image.blend(BGH, BLURH, blur)
    else: c = (BLURH if blur else BGH).copy()
    if bang is not None: c.alpha_composite(speed_lines(bang))
    if expr:
        p = PORTH[expr]; x = (GW * S - p.width) // 2 + off[0] * S; y = (DY + 14) * S - p.height + (off[1] + sink) * S
        lay = Image.new('RGBA', c.size, (0, 0, 0, 0)); lay.alpha_composite(p, (x, y))
        c.alpha_composite(lay.crop((0, 0, GW * S, (DY + 10) * S)), (0, 0))
    return c, shake
BG = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); BLUR = BG

# humor → animação no começo de cada fala (dx, dy por quadro)
MOOD = {
    'surpresa':    [(0, -6), (0, -10), (0, -7), (0, -3), (0, 0), (0, -2), (0, 0)],
    'preocupada':  [(1, 0), (-1, 0), (1, 0), (-1, 0), (1, 0), (0, 0)],
    'brava':       [(4, 0), (-4, 0), (3, 0), (-3, 0), (2, 0), (-2, 0), (1, 0), (0, 0)],
    'pensativa':   [(0, 0), (1, 0), (1, 0), (2, 0), (2, 0), (2, 0), (1, 0), (1, 0), (0, 0)],
    'determinada': [(0, 2), (0, 3), (0, 1), (0, -3), (0, -2), (0, 0)],
    'feliz':       [(0, -3), (0, 0), (0, -2), (0, 0)],
    'neutra':      [(0, 0)],
}
def stage(expr=None, blur=True, off=(0, 0), shake=(0, 0), sink=0):
    """Camada de UI nativa (transparente) + especificação do fundo/personagem em alta resolução."""
    c = Image.new('RGBA', (GW, GH), (0, 0, 0, 0)); c.spec = (expr, blur, off, shake, sink); return c

def manga_bang(c, k):
    """Balão de grito espetado + "!" em pixel art; linhas de foco em alta resolução no fundo."""
    c.bang = k; d = ImageDraw.Draw(c); sc = [1.35, 1.12, 1.0, 1.0, 1.0][min(k, 4)]
    spikes = 13; pts_o, pts_i = [], []
    for i in range(spikes * 2):
        a = i * math.pi / spikes - math.pi / 2; r = (30 if i % 2 == 0 else 19) * sc * (1 + (i * 0.13 % 0.18))
        pts_o.append((BX + math.cos(a) * (r + 2), BY + math.sin(a) * (r + 2) * 0.9)); pts_i.append((BX + math.cos(a) * r, BY + math.sin(a) * r * 0.9))
    d.polygon(pts_o, fill=(28, 14, 16, 255)); d.polygon(pts_i, fill=(255, 250, 236, 255))
    def bar(g, col):
        w0, w1, h = 6 * sc + g, 3.5 * sc + g, 15 * sc + g
        d.polygon([(BX - w0, BY - h), (BX + w0, BY - h), (BX + w1, BY + 6 * sc + g), (BX - w1, BY + 6 * sc + g)], fill=col)
        r = 3.6 * sc + g; d.rectangle([BX - r, BY + 10 * sc - g, BX + r, BY + 10 * sc + 2 * r - g], fill=col)
    bar(2, (28, 14, 16, 255)); bar(0, (214, 38, 30, 255))
    d.line([(BX - 4 * sc, BY - 13 * sc), (BX - 2.5 * sc, BY + 3 * sc)], fill=(255, 120, 96, 255), width=max(1, int(sc)))
    d.point((int(BX - 2 * sc), int(BY + 11 * sc)), fill=(255, 120, 96, 255))

def speak2(expr, text, last=False):
    lines = V.wrap(text, DW - 2 * M); pages = [lines[i:i + 3] for i in range(0, len(lines), 3)]
    for pi, pg in enumerate(pages):
        tot = sum(len(l) for l in pg); mv = MOOD.get(expr, [(0, 0)]) if pi == 0 else [(0, 0)]
        for fi, ch in enumerate(range(0, tot + 1, 2)):
            c = stage(expr, off=mv[min(fi, len(mv) - 1)]); dialog(c, pg, ch); emit(c)
        final = last and pi == len(pages) - 1
        for ph in range(28):
            c = stage(expr); dialog(c, pg, tot, 'fim' if final else 'mais', ph // 2); emit(c)
        if not final:
            tap(lambda: (lambda c: (dialog(c, pg, tot, 'mais', 0), c)[1])(stage(expr)), GW - 40, DY + 40)
    return pages[-1]

# 1) cena calma → shake + "!"
for _ in range(14): emit(stage(blur=False))
SHK = [(5, -3), (-6, 4), (4, 2), (-3, -3), (2, 1), (-1, 0), (0, 0), (0, 0)]
for k, s in enumerate(SHK):
    c = stage(blur=False, shake=s); manga_bang(c, k); emit(c, 2)
for k in range(6):
    c = stage(blur=False); manga_bang(c, 4); emit(c)
# 2) no mesmo instante: fundo desfoca + Mira surge junto com a janela
for i in range(1, 7):
    t = i / 6; e = 1 + 2.6 * (t - 1) ** 3 + 1.6 * (t - 1) ** 2
    c = stage('surpresa', sink=int(30 * (1 - t))); dialog(c, size=max(0.3, e) if i < 6 else 1.0, plate=i == 6); emit(c)
speak2('surpresa', "Ei, você! Graças aos deuses! Temos um problema sério!")
speak2('preocupada', "Um grupo de novatos sumiu no moinho velho. Ratos gigantes… e alguma coisa bem maior.")
speak2('brava', "E o Conselho quer isso resolvido até amanhã. Como se fosse fácil!")
lastpg = speak2('pensativa', "Preciso de alguém de confiança. Dá uma olhada nisso:")

# 3) contrato (mesmo fluxo da v1, com fundo desfocado)
A.W = 150
LINES = sum((V.wrap(t, A.W - 34) if t else [''] for t in ["Rank: D", "Local: Moinho velho", "Alvo: resgatar 3 novatos",
            "Ameaça: ratos gigantes + ???", "Prazo: 1 dia", "", "Recompensa:", "90 moedas de prata", "+40 de fama"]), [])
A.H = 56 + len(LINES) * LH + 50
A.PAPER = PG.parchment(A.W - 8, A.H - 2 * A.RH + 4, r=2, tear=1.0, seed=8)
CX, CY = (GW - A.W) // 2, 14
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
    c = stage('pensativa'); dialog(c, lastpg, 99)
    c.alpha_composite(Image.new('RGBA', c.size, (0, 0, 0, dim))); c.alpha_composite(layer, (CX, CY)); R = {}
    if buttons is not None:
        by = CY + A.H + 6
        R['ok'] = button(c, 22, by, "Aceitar", buttons == 'ok')
        R['no'] = button(c, GW - 22 - (V.width("Recusar") + 20), by, "Recusar", buttons == 'no')
    return c, R
for k in range(6): emit(cscene(contract_layer(0, 0, True), dim=k * 23)[0])
for cr in (1, 2): emit(cscene(contract_layer(0, 0, True, cr))[0], 3)
for i in range(1, 13): emit(cscene(contract_layer(A.ease_out(i / 12), i))[0])
emit(cscene(contract_layer(1, 12, text=True), buttons='')[0], 50)
_, R = cscene(contract_layer(1, 12, text=True), buttons=''); bx, by, bw, bh = R['ok']
tap(lambda: cscene(contract_layer(1, 12, text=True), buttons='ok')[0], bx + bw // 2, by + bh // 2)
for k in range(10): emit(cscene(contract_layer(1, 12, text=True, stamp=k >= 2))[0])
emit(cscene(contract_layer(1, 12, text=True, stamp=True))[0], 26)
for i in range(11, -1, -1): emit(cscene(contract_layer(A.ease_in(i / 12), i))[0])
for k in range(6): emit(cscene(contract_layer(0, 0, True), dim=140 - k * 23)[0])

# 4) determinada e suportiva
speak2('determinada', "Eu sabia que podia contar com você. Traga todos de volta inteiros!")
pg = speak2('feliz', "Eu seguro as pontas aqui na guilda. A sopa vai estar quente quando voltarem.", last=True)
tot = sum(len(l) for l in pg)
tap(lambda: (lambda c: (dialog(c, pg, tot, 'fim', 0), c)[1])(stage('feliz')), GW - 40, DY + 40)
# 5) ela sai PRIMEIRO (afunda atrás da janela) → depois a janela fecha → fundo volta ao foco
for i in range(1, 8):
    c = stage('feliz', sink=int(6 * i * i * 0.5)); dialog(c, pg, tot); emit(c)
c = stage(); dialog(c, pg, tot); emit(c, 4)
for i in range(6, -1, -1):
    c = stage(); dialog(c, size=max(0.05, i / 6)) if i else None; emit(c)
for a in (0.75, 0.5, 0.25, 0.0):
    emit(stage(blur=a))
emit(stage(blur=False), 14)

for i, (ui, spec, bang) in enumerate(frames):
    back, shake = build_back(spec, bang)
    back.alpha_composite(ui.resize((GW * S, GH * S), Image.NEAREST))
    if shake != (0, 0):
        sh = Image.new('RGBA', back.size, (0, 0, 0, 255)); sh.alpha_composite(back, (shake[0] * S, shake[1] * S)); back = sh
    back.convert('RGB').save(os.path.join(TMP, f'{i:05d}.png'))
out = os.path.join(ROOT, 'ui', '_evento_alarme.mp4')
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', os.path.join(TMP, '%05d.png'),
                '-pix_fmt', 'yuv420p', '-movflags', 'faststart', '-crf', '20', out])
for i in (16, 22, 40, 120, 300):
    Image.open(os.path.join(TMP, f'{i:05d}.png')).resize((GW * 2, GH * 2), Image.LANCZOS).save(f'{TMP}/_a{i:05d}.png')
print(len(frames), 'quadros,', round(len(frames) / FPS, 1), 's ->', out)
