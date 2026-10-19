## Serving mini-game (Breakfast / Lunch / Supper Rush): orders fall down 4 table columns; drag the right dish
## from the tray onto the column's counter. When the order reaches the counter: same dish = match (coins + tip),
## otherwise miss. Speeds up as the guild gets busy.
## In the game (principal.gd): configurar({titulo, clientes, cardapio:[{id,n,preco}]}) BEFORE add_child; uses the
## REAL dish stock (customers only order what is in stock); emits rush_done(result) and, on Continue, closed.
## Standalone: godot --path . res://cenas/teste_servir.tscn  (GD_AUTOPLAY=1 plays by itself)
extends Control

signal rush_done(result: Dictionary)
signal closed

const FRAME := Rect2(24, 140, 672, 1010)
const INNER := Rect2(48, 164, 624, 962)
const COLS := 4
const COUNTER_Y := 830.0          # linha do balcão (onde o pedido "chega")
const TRAY := Rect2(56, 916, 608, 196)
const CARD := Vector2(128, 150)
const SPAWN_Y := 270.0           # centro da comanda ao nascer (abaixo das placas do HUD), relativo a INNER

const DISHES := [
	{"id": "bread_butter", "price": 3, "pop": 5},
	{"id": "steak_rice", "price": 6, "pop": 4},
	{"id": "roast_chicken", "price": 10, "pop": 3},
	{"id": "sundae", "price": 13, "pop": 2},
	{"id": "roast_pig_feast", "price": 22, "pop": 1},
]
const CLASSES := ["warrior", "mage", "hunter", "guardian", "berserker", "druid"]
const EMBLEM := 64.0              # emblema de classe no topo da comanda (32 px nativos × 2, nearest)

var stock: Array[int] = [8, 6, 5, 3, 2]
var prices: Array[int] = [3, 6, 10, 13, 22]
var customers := 24               # clientes deste rush
var spawned := 0
var turned_away := 0
var served_by: Array[int] = [0, 0, 0, 0, 0]
var rush_time := 60.0
var title := "LUNCH RUSH"
var game_mode := false            # aberto pelo jogo (estoque real; Continue fecha)
var tex_class: Array[Texture2D] = []
var orders: Array = []            # {col, y, dish, cls}
var counter: Array = [-1, -1, -1, -1]   # prato parado no balcão de cada coluna
var state := "intro"              # intro, playing, result
var t := 0.0
var time_left := 60.0
var spawn_t := 0.0
var served := 0; var missed := 0; var coins := 0; var tips := 0; var combo := 0; var best_combo := 0
var drag_dish := -1; var drag_pos := Vector2.ZERO
var floaters: Array = []          # [pos, texto, cor, t]
var glitter: Array = []           # [pos, t, vida]
var shake := 0.0
var shown_coins := 0.0            # contador rola até o valor real
var coin_bump := 0.0; var combo_bump := 0.0
var flyers: Array = []            # moedas voando do balcão ao contador: [de, t, valor]
var misses: Array = []            # comanda errada caindo: [rect, dish, t]
var pops: Array = []              # comanda certa estourando: [rect, dish, t]
const SC := 4.0                   # escala do pixel nativo
var T := {}                       # texturas das peças (assets/minigames/servir)
var _tray_box: StyleBox
var _dark_box: StyleBox
var _shake_off := Vector2.ZERO
var autoplay := false

var tex_dish: Array[Texture2D] = []
var bg_tex: Texture2D
var font: Font
var font4: Font                    # técnica lisa ×4 (tamanho 48) — nunca escalar a ×3 para 48
var _frame_box: StyleBox
var _gold_box: StyleBox

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST     # pratos pequenos em pixel art (versões px/_32)
	theme = Estilo.tema()
	font4 = Estilo.fonte("l4")
	font = Estilo.fonte("l3")                               # técnica sem sombra embutida (a sombra é desenhada aqui)
	_frame_box = Estilo.caixa_9("metal_9slice", 6)
	_gold_box = Estilo.caixa_9("metal_dourado", 6)      # destaque = borda de metal dourada
	for n in ["balcao", "balcao_alvo", "rebaixo", "chip", "chip_cinza", "comanda", "barra_moldura", "ampulheta", "chama_0", "chama_1", "chama_2", "seta"]:
		T[n] = load("res://assets/minigames/servir/%s.png" % n)
	T["moeda"] = load("res://assets/ui/icones/moedas_24.png")   # ícone pixel 24 px → 48 (×2 NEAREST)
	var tb := StyleBoxTexture.new(); tb.texture = load("res://assets/minigames/servir/bandeja_9slice_x4.png"); tb.set_texture_margin_all(24)
	_tray_box = tb
	_dark_box = Estilo.caixa_9("metal_escuro", 6)
	for d in DISHES: tex_dish.append(load("res://assets/pratos/px/%s_32.png" % d["id"]))
	for c in CLASSES: tex_class.append(Estilo.emblema_classe(c))
	bg_tex = load("res://assets/minigames/servir_fundo_blur.png") if ResourceLoader.exists("res://assets/minigames/servir_fundo_blur.png") \
		else load("res://assets/minigames/cozinha_fundo_blur.png")
	autoplay = not OS.get_environment("GD_AUTOPLAY").is_empty()
	_build_ui()
	if autoplay and not game_mode: _start()

## Configuração vinda do jogo: {titulo, clientes, cardapio: [{id, n, preco}] na ordem de DISHES}.
func configurar(d: Dictionary) -> void:
	game_mode = true
	title = String(d.get("titulo", title)).to_upper()
	customers = int(d.get("clientes", customers))
	var menu: Array = d.get("cardapio", [])
	for i in mini(menu.size(), DISHES.size()):
		stock[i] = int(menu[i].n)
		prices[i] = int(menu[i].preco)

func _total_stock() -> int:
	var n := 0
	for i in DISHES.size(): n += stock[i]
	return n

# ---------------- UI (placas e botões no estilo do jogo) ----------------
var plate: NinePatchRect; var ui_intro: Control; var ui_result: Control
var lb_res: Label; var lb_turned: Label; var lb_info: Label; var lb_stock: Label

func _build_ui() -> void:
	plate = Estilo.placa(title, "l4"); add_child(plate)
	plate.position = Vector2(roundf(FRAME.get_center().x - plate.size.x / 2), FRAME.position.y - plate.size.y / 2)
	ui_intro = Control.new(); ui_intro.set_anchors_preset(PRESET_FULL_RECT); ui_intro.mouse_filter = MOUSE_FILTER_IGNORE; add_child(ui_intro)
	lb_info = Estilo.rotulo_px(Txt.t("mg_rush_intro", [customers]), "t3", Estilo.COR_TEXTO, true)
	lb_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_info.position = INNER.position + Vector2(40, 250); lb_info.size = Vector2(INNER.size.x - 80, 160); ui_intro.add_child(lb_info)
	lb_stock = Estilo.rotulo_px(Txt.t("mg_rush_stock", [_total_stock()]), "t3", Estilo.COR_DOURADO, true)
	lb_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_stock.position = INNER.position + Vector2(40, 420); lb_stock.size = Vector2(INNER.size.x - 80, 80); ui_intro.add_child(lb_stock)
	var go := Estilo.botao(Txt.t("mg_open_doors"), _start)
	go.position = INNER.position + Vector2(INNER.size.x / 2 - 200, 540); go.size = Vector2(400, 100); ui_intro.add_child(go)
	ui_result = Control.new(); ui_result.set_anchors_preset(PRESET_FULL_RECT); ui_result.mouse_filter = MOUSE_FILTER_IGNORE; add_child(ui_result)
	lb_res = Estilo.rotulo_px("", "t4", Estilo.COR_TEXTO, true)
	lb_res.position = INNER.position + Vector2(40, 300); lb_res.size = Vector2(INNER.size.x - 80, 300)
	lb_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui_result.add_child(lb_res)
	lb_turned = Estilo.rotulo_px("", "t3", Estilo.COR_LARANJA, true)
	lb_turned.position = INNER.position + Vector2(40, 620); lb_turned.size = Vector2(INNER.size.x - 80, 80)
	lb_turned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui_result.add_child(lb_turned)
	var again := Estilo.botao(Txt.t("mg_continue"), _on_continue)
	again.position = INNER.position + Vector2(INNER.size.x / 2 - 160, 760); again.size = Vector2(320, 96); ui_result.add_child(again)

func _on_continue() -> void:
	if game_mode: closed.emit()
	else: state = "intro"

func _start() -> void:
	var mus := get_node_or_null("/root/Musica")
	if mus: mus.tocar("rush")
	orders.clear(); counter = [-1, -1, -1, -1]; floaters.clear(); glitter.clear()
	served = 0; missed = 0; coins = 0; tips = 0; combo = 0; best_combo = 0
	flyers.clear(); misses.clear(); pops.clear(); shown_coins = 0.0
	spawned = 0; turned_away = 0; served_by = [0, 0, 0, 0, 0]
	if not game_mode: stock = [8, 6, 5, 3, 2]
	rush_time = clampf(14.0 + customers * 2.6, 30.0, 75.0)
	t = 0.0; time_left = rush_time; spawn_t = 0.6; state = "playing"

# ---------------- regras ----------------
func _busy() -> float:
	# movimento da guilda: acelera com o tempo do rush, com o combo e com o tamanho do rush
	return clampf(t / rush_time, 0.0, 1.0) * 0.6 + minf(combo, 10) * 0.03 + clampf((customers - 6) / 30.0, 0.0, 0.3)

func _fall_speed() -> float: return 70.0 + 110.0 * _busy()          # px/s: 70 → ~200
## Intervalo entre pedidos: os clientes cabem em (rush_time − 8) s, mais apertado no fim (×1,25 → ×0,75).
func _spawn_every() -> float: return (rush_time - 8.0) / maxf(1.0, customers) * lerpf(1.25, 0.75, clampf(t / rush_time, 0.0, 1.0))

## Porções ainda livres de cada prato = bandeja + balcões − pedidos já caindo.
func _free_stock(i: int) -> int:
	var n := stock[i]
	for c in COLS: if counter[c] == i: n += 1
	for o in orders: if o["dish"] == i: n -= 1
	return n

func _col_x(c: int) -> float: return INNER.position.x + 16 + (INNER.size.x - 32) / COLS * (c + 0.5)

func _spawn() -> void:
	var free_cols := []
	for c in COLS:
		var busy := false
		for o in orders: if o["col"] == c and o["y"] < INNER.position.y + 400: busy = true
		if not busy: free_cols.append(c)
	if free_cols.is_empty(): return
	var avail := []
	for i in DISHES.size():
		if _free_stock(i) <= 0: continue                              # cliente só pede o que existe
		for k in int(DISHES[i]["pop"]): avail.append(i)              # pratos simples saem mais
	if avail.is_empty(): return
	spawned += 1
	orders.append({"col": free_cols.pick_random(), "y": INNER.position.y + SPAWN_Y, "dish": avail.pick_random(),
		"cls": randi() % CLASSES.size()})

func _any_free_stock() -> bool:
	for i in DISHES.size():
		if _free_stock(i) > 0: return true
	return false

func _arrive(o: Dictionary) -> void:
	var c: int = o["col"]; var at := Vector2(_col_x(c), COUNTER_Y)
	if counter[c] == o["dish"]:
		counter[c] = -1
		combo += 1; best_combo = maxi(best_combo, combo); served += 1; served_by[o["dish"]] += 1
		var price: int = prices[o["dish"]]; var tip := int(round(price * minf(0.1 * combo, 0.5)))
		coins += price; tips += tip
		floaters.append([at + Vector2(0, -60), "+%d" % (price + tip), Color8(255, 214, 92), 0.0])
		pops.append([_card_rect(o), o["dish"], 0.0, o["cls"]]); combo_bump = 0.25
		for k in mini(1 + (price + tip) / 8, 6): flyers.append([at + Vector2(randf_range(-30, 30), -20), -0.08 * k, (price + tip) / float(mini(1 + (price + tip) / 8, 6))])
		for k in 14: glitter.append([at + Vector2(randf_range(-60, 60), randf_range(-70, 10)), 0.0, randf_range(0.3, 0.6)])
	else:
		combo = 0; missed += 1; shake = 0.25
		misses.append([_card_rect(o), o["dish"], 0.0, o["cls"]])
		floaters.append([at + Vector2(0, -60), Txt.t("mg_miss"), Color8(230, 90, 70), 0.0])

func _finish() -> void:
	var mus2 := get_node_or_null("/root/Musica")
	if mus2: mus2.tocar("idle")
	state = "result"
	turned_away = maxi(0, customers - spawned)
	lb_res.text = Txt.t("mg_rush_result", [served, customers, coins, tips, best_combo])
	lb_turned.text = Txt.t("mg_rush_turned", [turned_away]) if turned_away > 0 else ""
	if autoplay: print("RUSH served=%d/%d missed=%d turned=%d coins=%d tips=%d combo=%d" % [served, customers, missed, turned_away, coins, tips, best_combo])
	var by_id := {}
	for i in DISHES.size():
		if served_by[i] > 0: by_id[DISHES[i]["id"]] = served_by[i]
	rush_done.emit({"servidos": by_id, "perdidos": missed, "recusados": turned_away, "gorjetas": tips, "combo": best_combo,
		"served": served, "missed": missed, "coins": coins, "tips": tips})

func _process(delta: float) -> void:
	if state == "playing":
		t += delta; time_left -= delta
		spawn_t -= delta
		if spawn_t <= 0.0 and spawned < customers: _spawn(); spawn_t = _spawn_every()
		var sp := _fall_speed()
		for o in orders.duplicate():
			o["y"] += sp * delta
			if o["y"] + CARD.y * 0.5 >= COUNTER_Y - 50:
				_arrive(o); orders.erase(o)
		if autoplay: _autoplay()
		time_left = maxf(time_left, 0.0)
		if orders.is_empty() and (spawned >= customers or not _any_free_stock()): _finish()
	for f in floaters: f[3] += delta; f[0].y -= 50 * delta
	floaters = floaters.filter(func(f): return f[3] < 0.9)
	for g in glitter: g[1] += delta
	glitter = glitter.filter(func(g): return g[1] < g[2])
	shake = maxf(0.0, shake - delta)
	coin_bump = maxf(0.0, coin_bump - delta); combo_bump = maxf(0.0, combo_bump - delta)
	for f in flyers:
		f[1] += delta
		if f[1] >= 0.55 and f.size() == 3: shown_coins += f[2]; coin_bump = 0.18; f.append(true)
	flyers = flyers.filter(func(f): return f[1] < 0.55)
	if state == "playing" and flyers.is_empty(): shown_coins = move_toward(shown_coins, coins + tips, 200 * delta)
	for m in misses: m[2] += delta
	misses = misses.filter(func(m): return m[2] < 0.7)
	for q in pops: q[2] += delta
	pops = pops.filter(func(q): return q[2] < 0.3)
	ui_intro.visible = state == "intro"; ui_result.visible = state == "result"
	queue_redraw()

func _autoplay() -> void:
	for o in orders:
		var c: int = o["col"]
		if counter[c] == -1 and o["y"] > COUNTER_Y - 420 and stock[o["dish"]] > 0:
			counter[c] = o["dish"]; stock[o["dish"]] -= 1

# ---------------- input: arrastar prato da bandeja ----------------
const TRAY_PAD := 28.0                 # aro do metal (6 px nativos × 4) + respiro
func _slot_rect(i: int) -> Rect2:
	var inner := TRAY.grow(-TRAY_PAD)
	var w := inner.size.x / DISHES.size()
	return Rect2(inner.position.x + w * i, inner.position.y, w, inner.size.y)

func _gui_input(e: InputEvent) -> void:
	if state != "playing": return
	var pos: Vector2; var press := false; var release := false; var move := false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT: pos = e.position; press = e.pressed; release = not e.pressed
	elif e is InputEventMouseMotion: pos = e.position; move = true
	elif e is InputEventScreenTouch: pos = e.position; press = e.pressed; release = not e.pressed
	elif e is InputEventScreenDrag: pos = e.position; move = true
	else: return
	if press:
		for i in DISHES.size():
			if _slot_rect(i).has_point(pos) and stock[i] > 0: drag_dish = i; drag_pos = pos
		for c in COLS:                                            # tocar no balcão devolve o prato à bandeja
			if counter[c] != -1 and Rect2(_col_x(c) - 70, COUNTER_Y - 70, 140, 120).has_point(pos):
				stock[counter[c]] += 1; counter[c] = -1
	elif move and drag_dish >= 0:
		drag_pos = pos
	elif release and drag_dish >= 0:
		if pos.y < TRAY.position.y and pos.y > INNER.position.y:
			var c := clampi(int((pos.x - INNER.position.x - 16) / ((INNER.size.x - 32) / COLS)), 0, COLS - 1)
			if counter[c] != -1: stock[counter[c]] += 1             # troca o prato que estava lá
			counter[c] = drag_dish; stock[drag_dish] -= 1
		drag_dish = -1

func _card_rect(o: Dictionary) -> Rect2:
	var sz := Vector2(34, 41) * SC
	return Rect2(Vector2(_col_x(o["col"]) - sz.x / 2, o["y"] - sz.y / 2), sz)

func _px(p: Vector2) -> Vector2: return (p / SC).floor() * SC

func _tex(name: String, pos: Vector2, k := SC, mod := Color.WHITE) -> void:
	var tx: Texture2D = T[name]
	draw_texture_rect(tx, Rect2(_px(pos), tx.get_size() * k), false, mod)

func _text_c(p: Vector2, s: String, col: Color, sz := 36) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(font, _px(p - Vector2(w / 2, 0)) + Vector2(3, 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color8(12, 8, 10))
	draw_string(font, _px(p - Vector2(w / 2, 0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _text_l(p: Vector2, s: String, col: Color, sz := 36) -> void:
	draw_string(font, _px(p) + Vector2(3, 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color8(12, 8, 10))
	draw_string(font, _px(p), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _coin_hud_pos() -> Vector2: return INNER.position + Vector2(52, 88)

# ---------------- desenho ----------------
func _draw_hud() -> void:
	# barra de tempo: ampulheta + moldura metálica + preenchimento em segmentos de 1 px nativo com degradê por urgência
	var y0 := INNER.position.y + 28
	_tex("ampulheta", Vector2(INNER.position.x + 28, y0 - 4))
	var fx := INNER.position.x + 76; _tex("barra_moldura", Vector2(fx, y0))
	var inner := Rect2(fx + 2 * SC, y0 + 2 * SC, (130 - 4) * SC, 5 * SC)
	var frac := clampf(time_left / rush_time, 0.0, 1.0)
	var cA := Color8(255, 214, 92); var cB := Color8(217, 120, 50); var cC := Color8(200, 50, 40)
	var col := cA if frac > 0.5 else cA.lerp(cB, (0.5 - frac) / 0.25) if frac > 0.25 else cB.lerp(cC, (0.25 - frac) / 0.25)
	if time_left < 10.0 and int(t * 6.0) % 2 == 0: col = col.lightened(0.25)          # pisca nos 10 s finais
	var cells := int(inner.size.x / SC * frac)
	for k in cells:
		var x := inner.position.x + k * SC
		draw_rect(Rect2(x, inner.position.y, SC, inner.size.y), col if k % 8 != 7 else col.darkened(0.18))   # divisão a cada 8 px nativos
		draw_rect(Rect2(x, inner.position.y, SC, SC), col.lightened(0.35))          # brilho na linha de cima
		draw_rect(Rect2(x, inner.end.y - SC, SC, SC), col.darkened(0.3))            # sombra embaixo
	for k in range(1, 6):                                                          # marcas a cada 10 s
		var mx := inner.position.x + floorf(inner.size.x * k / 6.0 / SC) * SC
		draw_rect(Rect2(mx, inner.position.y - SC, SC, SC), Color8(16, 12, 14))
	# linha de placas: conteúdo centralizado em X e Y pela altura REAL da letra (7 px nativos × escala), não pela linha de base
	var row_y := INNER.position.y + 76; var ph := 76.0
	var lp := Rect2(INNER.position.x + 28, row_y, 236, ph)
	draw_style_box(_dark_box, lp)
	var num := "%d" % int(round(shown_coins))
	var nw := font4.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
	var icn := Vector2(48, 48); var gap := 16.0
	var x0 := lp.get_center().x - (icn.x + gap + nw) / 2                             # bloco [ícone + número] centralizado em X
	var cy := lp.get_center().y
	var b := 1.0 + 0.2 * (coin_bump / 0.18)
	draw_texture_rect(T["moeda"], Rect2(_px(Vector2(x0 + icn.x / 2, cy) - icn * b / 2), icn * b), false)
	_text_base(font4, Vector2(x0 + icn.x + gap, cy + 7 * 4 / 2.0), num, Color8(255, 214, 92), 48)
	var rp := Rect2(INNER.end.x - 28 - 236, row_y, 236, ph)
	var active := combo >= 2
	draw_style_box(_gold_box if active else _dark_box, rp)
	var label := "COMBO x%d" % combo if active else "COMBO"
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var block := 7 * 3 + 12 + 16.0                                                     # letra 21 + espaço 12 + pips 16 (com contorno)
	var top := rp.get_center().y - block / 2 + 4                                     # +4: compensa o aro claro mais grosso em cima
	var cb := 1.0 + 0.15 * (combo_bump / 0.25)
	draw_set_transform(_shake_off + Vector2(rp.get_center().x, top + 10.5), 0.0, Vector2.ONE * cb)
	_text_base(font, Vector2(-tw / 2, 10.5), label, Color8(255, 236, 160) if active else Color8(150, 136, 120), 36)
	draw_set_transform(_shake_off)
	for k in 5:
		var on := active and k < mini(combo - 1, 5)
		var pr := Rect2(_px(Vector2(rp.get_center().x - 68 + k * 28, top + 21 + 12 + 4)), Vector2(20, 8))
		draw_rect(pr.grow(4), Color8(16, 12, 14)); draw_rect(pr, Color8(255, 170, 60) if on else Color8(60, 44, 40))

func _text_base(f: Font, p: Vector2, s: String, col: Color, sz: int) -> void:
	## p.y = LINHA DE BASE; a letra ocupa 7 px nativos acima dela.
	var q := Vector2(roundf(p.x), roundf(p.y))
	f.draw_string(get_canvas_item(), q + Vector2(sz / 12.0, sz / 12.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color8(12, 8, 10))
	f.draw_string(get_canvas_item(), q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw_lanes() -> void:
	var top := INNER.position.y + 170
	for c in COLS:
		var x := _px(Vector2(_col_x(c), 0)).x
		var hot := drag_dish >= 0 and _col_at(drag_pos.x) == c and drag_pos.y < TRAY.position.y
		# trilho: duas linhas tracejadas que descem (rolam com o tempo) até o balcão
		var phase := fmod(t * _fall_speed(), 32.0)
		for side in [-1, 1]:
			var lx: float = x + side * 64.0
			var y := top + phase - 32.0
			while y < COUNTER_Y - 60:
				if y > top: draw_rect(Rect2(lx - 2, _px(Vector2(0, y)).y, 4, 16), Color(1, 0.85, 0.5, 0.22 if hot else 0.10))
				y += 32.0
		# setas pulsando acima do balcão (descem 1 px nativo a cada pulso)
		var a := 0.25 + 0.25 * sin(t * 6.0 + c)
		for k in 2:
			draw_texture_rect(T["seta"], Rect2(_px(Vector2(x - 14, COUNTER_Y - 96 + k * 24 + (4 if sin(t * 6.0 + c) > 0 else 0))), Vector2(28, 16)), false, Color(1, 1, 1, a))
		# balcão de madeira com bandejinha; dourado quando é o alvo do arraste
		var bt: Texture2D = T["balcao_alvo" if hot else "balcao"]
		draw_texture_rect(bt, Rect2(_px(Vector2(x - 17 * SC, COUNTER_Y - 6 * SC)), bt.get_size() * SC), false)
		if counter[c] != -1: draw_texture_rect(tex_dish[counter[c]], Rect2(_px(Vector2(x - 54, COUNTER_Y - 52)), Vector2(108, 108)), false)   # assenta no rebaixo

func _col_at(px_x: float) -> int:
	return clampi(int((px_x - INNER.position.x - 16) / ((INNER.size.x - 32) / COLS)), 0, COLS - 1)

func _draw_ticket(r: Rect2, dish: int, prog: float, mod := Color.WHITE, urgent := false, cls := -1) -> void:
	if urgent:                                                                      # destaque = moldura de metal dourada
		draw_style_box(_gold_box, r.grow(10))
	draw_texture_rect(T["comanda"], r, false, mod)
	if cls >= 0:                                                                    # emblema do cliente preso no topo (no lugar do alfinete)
		draw_texture_rect(tex_class[cls], Rect2(_px(Vector2(r.get_center().x - EMBLEM / 2, r.position.y - 30)), Vector2(EMBLEM, EMBLEM)), false, mod)
	draw_texture_rect(tex_dish[dish], Rect2(_px(r.position + Vector2((r.size.x - 108) / 2, 34)), Vector2(108, 108)), false, mod)
	# relogiozinho de paciência no canto: anel que vai ficando vermelho
	var cc := r.position + Vector2(r.size.x - 26, r.size.y - 26)       # relógio de paciência no pé da comanda
	draw_circle(cc, 14, Color8(16, 12, 14, int(255 * mod.a))); draw_circle(cc, 11, Color8(236, 226, 206, int(255 * mod.a)))
	var pc := Color8(120, 200, 110).lerp(Color8(220, 60, 40), prog); pc.a = mod.a
	var pts := PackedVector2Array([cc])
	for k in 17: var ang := -PI / 2 + TAU * prog * k / 16.0; pts.append(cc + Vector2(cos(ang), sin(ang)) * 11)
	if prog > 0.02: draw_colored_polygon(pts, pc)

func _draw_tray() -> void:
	draw_style_box(_tray_box, TRAY)
	for i in DISHES.size():
		var s := _slot_rect(i)
		var cx := s.get_center().x
		var has := stock[i] > 0
		var mod := Color.WHITE if has else Color(0.45, 0.42, 0.42, 0.7)
		draw_texture_rect(T["rebaixo"], Rect2(_px(Vector2(cx - 15 * 3, s.position.y + 44)), Vector2(30, 20) * 3), false)
		if not (drag_dish == i and stock[i] == 1):
			draw_texture_rect(tex_dish[i], Rect2(_px(Vector2(cx - 54, s.position.y - 6)), Vector2(108, 108)), false, mod)
		var chip: Texture2D = T["chip" if has else "chip_cinza"]
		var cr := Rect2(_px(Vector2(cx - 7 * SC, s.end.y - 9 * SC + 8)), chip.get_size() * SC)
		draw_texture_rect(chip, cr, false)
		_text_c(Vector2(cr.get_center().x, cr.position.y + 26), "%d" % stock[i], Color8(240, 230, 212) if has else Color8(230, 90, 70))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.02, 0.85))
	var off := Vector2(randf_range(-6, 6), randf_range(-4, 4)) if shake > 0.0 else Vector2.ZERO
	_shake_off = off
	draw_set_transform(off)
	draw_style_box(_frame_box, FRAME)
	var ts := bg_tex.get_size(); var sc := maxf(INNER.size.x / ts.x, INNER.size.y / ts.y)
	draw_texture_rect_region(bg_tex, INNER, Rect2((ts.x - INNER.size.x / sc) / 2, (ts.y - INNER.size.y / sc) / 2, INNER.size.x / sc, INNER.size.y / sc))
	draw_rect(INNER, Color(0.05, 0.035, 0.04, 0.55))
	if state != "playing": draw_set_transform(Vector2.ZERO); return
	draw_rect(Rect2(INNER.position, Vector2(INNER.size.x, 172)), Color(0.04, 0.03, 0.035, 0.55))   # faixa do HUD
	_draw_hud()
	_draw_lanes()
	for o in orders:
		var r := _card_rect(o)
		var prog := clampf((o["y"] - (INNER.position.y + SPAWN_Y)) / (COUNTER_Y - 50 - CARD.y * 0.5 - (INNER.position.y + SPAWN_Y)), 0.0, 1.0)
		_draw_ticket(r, o["dish"], prog, Color.WHITE, prog > 0.62, o["cls"])
	for m in misses:                                                                 # errou: comanda cai girando e some em vermelho
		var u: float = m[2] / 0.7
		var r: Rect2 = m[0]; r.position.y += 220.0 * u * u
		draw_set_transform(off + r.get_center(), 0.6 * u, Vector2.ONE)
		_draw_ticket(Rect2(-r.size / 2, r.size), m[1], 1.0, Color(1.0, 0.5, 0.45, 1.0 - u), false, m[3])
		draw_set_transform(off)
	for q in pops:                                                                   # acertou: comanda estoura e some
		var u: float = q[2] / 0.3; var r: Rect2 = q[0]
		draw_set_transform(off + r.get_center(), 0.0, Vector2.ONE * (1.0 + 0.4 * u))
		_draw_ticket(Rect2(-r.size / 2, r.size), q[1], 0.0, Color(1, 1, 1, 1.0 - u), false, q[3])
		draw_set_transform(off)
	_draw_tray()
	for g in glitter:
		var u: float = g[1] / g[2]; var col := Color8(255, 252, 230).lerp(Color8(255, 200, 90), u); col.a = 1.0 - u
		var p := _px(g[0])
		draw_rect(Rect2(p, Vector2(4, 4)), col)
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]: draw_rect(Rect2(p + dir * 4, Vector2(4, 4)), col)
	for f in flyers:                                                                 # moedas voando em arco até o contador
		var u := clampf(f[1] / 0.55, 0.0, 1.0)
		if f[1] < 0.0: continue
		var a: Vector2 = f[0]; var b := _coin_hud_pos() + Vector2(24, 16)
		var mid := (a + b) / 2 + Vector2(120, -160)
		var pnt := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
		draw_texture_rect(T["moeda"], Rect2(_px(pnt - Vector2(18, 18)), Vector2(36, 36)), false)
	for f in floaters:
		var c: Color = f[2]; c.a = 1.0 - f[3] / 0.9
		_text_c(f[0], f[1], c, 48)
	if drag_dish >= 0:
		draw_texture_rect(tex_dish[drag_dish], Rect2(_px(drag_pos - Vector2(54, 64)), Vector2(108, 108)), false)
	draw_set_transform(Vector2.ZERO)
