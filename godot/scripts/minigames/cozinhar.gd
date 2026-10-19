## Cooking mini-game (stroke tracing). 5 seconds per dish, 1–5 strokes depending on the dish tier.
## Each stroke is a cooking gesture: Cut (line), Stir (spiral), Knead (zigzag), Pour (arc), Season (wave).
## Run standalone: godot --path . res://cenas/teste_gestos.tscn   (GD_AUTOPLAY=1 traces automatically for testing)
## In the game (principal.gd): set game_mode = true and call start_dish(i) after add_child; the result screen
## shows "Cook again" / "Done" (signals again / closed) and the note set with set_result_note().
extends Control

signal dish_done(stars: int, accuracy: float)
signal again
signal closed

const TIME_LIMIT := 5.0
const START_R := 46.0          # press radius on start/end circles (px, canvas 720×1280)
const PERFECT := 24.0          # finger-to-path distance for "perfect"
const MAX_DEV := 48.0          # beyond this for > GRACE seconds = stroke fails
const GRACE := 0.15
const STEP := 8.0              # path sample spacing
const FRAME := Rect2(24, 140, 672, 1010)   # janela do mini-game (borda metálica)
const INNER := Rect2(48, 164, 624, 962)
const SAFE := Rect2(110, 330, 500, 680)  # onde os traços nascem

const DISHES := [
	{"name": "Simple", "strokes": 1, "example": "Buttered Bread", "img": "bread_butter"},
	{"name": "Hearty", "strokes": 2, "example": "Steak & Rice", "img": "steak_rice"},
	{"name": "Refined", "strokes": 3, "example": "Roast Chicken", "img": "roast_chicken"},
	{"name": "Complex", "strokes": 4, "example": "Frost Sundae", "img": "sundae"},
	{"name": "Banquet", "strokes": 5, "example": "Roast Boar Feast", "img": "roast_pig_feast"},
]
const GESTURES := ["Cut", "Stir", "Knead", "Pour", "Season"]

var dish := 0
var strokes: Array = []          # Array[PackedVector2Array]
var gesture_names: PackedStringArray = []
var cur := 0                     # current stroke index
var progress := 0                # index of furthest reached sample
var tracing := false
var dev_time := 0.0
var errors: Array[float] = []    # per-sample distance (accuracy)
var time_left := TIME_LIMIT
var state := "menu"              # menu, playing, result
var stars := 0
var accuracy := 0.0
var sparks: Array = []           # [pos, t]
var tada_t := 0.0                 # tempo desde o fim (anima o pop-up)
var confetti: Array = []          # [pos, vel, cor, rot]
var dish_tex: Texture2D
var dish_rect: TextureRect
var confetti_layer: Control
var glitter: Array = []          # [pos, t, life, size]
var finger := Vector2(-999, -999)
var autoplay := false
var _auto_t := 0.0
var game_mode := false
var can_again := true

var font: Font
var _frame_box: StyleBox = Estilo.caixa_9("metal_9slice", 6)
var _inner_clear := true
var bg_tex: Texture2D = load("res://assets/minigames/cozinha_fundo_blur.png")   # Gaussian 2.5 px em 1024 px = 0,24% da altura

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	theme = Estilo.tema()
	_build_ui()
	autoplay = not OS.get_environment("GD_AUTOPLAY").is_empty()
	if autoplay and not game_mode: start_dish(int(OS.get_environment("GD_AUTOPLAY")) - 1 if OS.get_environment("GD_AUTOPLAY").is_valid_int() else 4)

# ---------------- path generation ----------------
func _gesture(kind: String, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := SAFE.get_center() + Vector2(rng.randf_range(-30, 30), rng.randf_range(-60, 60))
	var ang := rng.randf_range(-0.5, 0.5)
	match kind:
		"Cut":
			var L := rng.randf_range(430, 520)
			for i in 2: pts.append(c + Vector2(-L / 2 + L * i, 0).rotated(ang))
		"Stir":
			var turns := 1.25
			for i in 60:
				var t := float(i) / 59.0
				var r := lerpf(55.0, 205.0, t)
				pts.append(c + Vector2(cos(t * TAU * turns), sin(t * TAU * turns)) * r)
		"Knead":
			var W := rng.randf_range(460, 520); var H := rng.randf_range(140, 190); var n := 4
			for i in n + 1: pts.append(c + Vector2(-W / 2 + W * i / n, (H / 2) * (1 if i % 2 == 0 else -1)).rotated(ang))
		"Pour":
			var R := rng.randf_range(220, 260)
			for i in 40:
				var t := lerpf(PI * 1.05, PI * 1.95, float(i) / 39.0)
				pts.append(c + Vector2(cos(t), sin(t) + 0.6) * R)
		"Season":
			var W2 := rng.randf_range(460, 520)
			for i in 60:
				var t := float(i) / 59.0
				pts.append(c + Vector2(-W2 / 2 + W2 * t, sin(t * TAU * 1.5) * 100).rotated(ang))
	return _resample(_clamp_safe(pts))

func _clamp_safe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts: out.append(Vector2(clampf(p.x, SAFE.position.x, SAFE.end.x), clampf(p.y, SAFE.position.y, SAFE.end.y)))
	return out

func _resample(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]]); var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]; var b := pts[i]; var seg := a.distance_to(b); var d := STEP - carry
		while d <= seg:
			out.append(a.lerp(b, d / seg)); d += STEP
		carry = seg - (d - STEP)
	if out[-1].distance_to(pts[-1]) > 2.0: out.append(pts[-1])
	return out

func start_dish(i: int) -> void:
	var mus := get_node_or_null("/root/Musica")
	if mus: mus.tocar("kitchen")
	dish = i; strokes.clear(); gesture_names.clear()
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var order := GESTURES.duplicate(); order.shuffle()
	if i == 0: order = ["Cut"]
	for k in DISHES[i]["strokes"]:
		var g: String = order[k % order.size()]
		gesture_names.append(g); strokes.append(_gesture(g, rng))
	cur = 0; progress = 0; tracing = false; dev_time = 0.0; errors.clear()
	time_left = TIME_LIMIT; state = "playing"; sparks.clear(); _auto_t = 0.0

# ---------------- input ----------------
func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.ZERO; var press := false; var release := false; var move := false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position; press = e.pressed; release = not e.pressed
	elif e is InputEventMouseMotion:
		pos = e.position; move = true
	elif e is InputEventScreenTouch:
		pos = e.position; press = e.pressed; release = not e.pressed
	elif e is InputEventScreenDrag:
		pos = e.position; move = true
	else:
		return
	if state != "playing": return
	_handle(pos, press, release, move)

func _handle(pos: Vector2, press: bool, release: bool, move: bool) -> void:
	finger = pos
	var path: PackedVector2Array = strokes[cur]
	if press and pos.distance_to(path[0]) <= START_R:
		tracing = true; progress = 0; dev_time = 0.0
	elif tracing and move:
		_advance(pos, path)
	elif tracing and release:
		tracing = false
		if progress >= path.size() - 3 and pos.distance_to(path[-1]) <= START_R:
			_stroke_done(path[-1])
		else:
			progress = 0          # released early: restart this stroke

func _advance(pos: Vector2, path: PackedVector2Array) -> void:
	# look only a little ahead: progress is monotonic (no skipping, no going backwards)
	var best := progress; var bd := INF
	for j in range(progress, mini(progress + 10, path.size())):
		var d := pos.distance_to(path[j])
		if d < bd: bd = d; best = j
	errors.append(bd)
	if bd > MAX_DEV:
		dev_time += get_process_delta_time()
		if dev_time > GRACE:
			tracing = false; progress = 0; dev_time = 0.0   # slipped off: restart stroke
		return
	dev_time = 0.0
	progress = maxi(progress, best)

func _emit_glitter(n: int) -> void:
	var path: PackedVector2Array = strokes[cur]
	for k in n:
		var j := randi_range(maxi(0, progress - 6), progress)
		var p := path[mini(j, path.size() - 1)] + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		glitter.append([p, 0.0, randf_range(0.25, 0.45), 4.0])

func _stroke_done(at: Vector2) -> void:
	sparks.append([at, 0.0])
	for k in 10:
		var a := randf() * TAU
		glitter.append([at + Vector2(cos(a), sin(a)) * randf_range(10, 44), 0.0, randf_range(0.25, 0.45), 4.0])
	cur += 1; progress = 0
	if cur >= strokes.size(): _finish(true)

func _finish(ok: bool) -> void:
	var mus2 := get_node_or_null("/root/Musica")
	if mus2: mus2.tocar("idle")
	state = "result"
	var mean := 0.0
	for d in errors: mean += d
	mean = mean / maxf(1.0, errors.size())
	accuracy = clampf(1.0 - mean / MAX_DEV, 0.0, 1.0) if ok else 0.0
	stars = 0 if not ok else (3 if accuracy >= 0.75 else 2 if accuracy >= 0.5 else 1)
	tada_t = 0.0; confetti.clear()
	dish_tex = load("res://assets/pratos/%s%s.png" % [DISHES[dish]["img"], "" if stars > 0 else "_burnt"])
	if stars > 0: _burst_confetti(70)
	if autoplay: print("RESULT dish=%d ok=%s stars=%d acc=%.2f time_left=%.2f" % [dish, ok, stars, accuracy, time_left])
	dish_done.emit(stars, accuracy)

const CONF_COLS := [Color8(230, 70, 60), Color8(255, 214, 92), Color8(120, 200, 110), Color8(90, 160, 230), Color8(236, 226, 206), Color8(200, 110, 210)]
func _burst_confetti(n: int) -> void:
	var c := INNER.get_center() + Vector2(0, -120)
	for k in n:
		var a := randf_range(-PI, 0.0)                     # explode para cima e para os lados
		var sp := randf_range(380, 900)
		confetti.append([c, Vector2(cos(a), sin(a)) * sp, CONF_COLS[randi() % CONF_COLS.size()], randf() * TAU, randf_range(4.0, 9.0)])

# ---------------- loop ----------------
func _process(delta: float) -> void:
	if state == "playing":
		time_left -= delta
		if autoplay and not OS.has_environment("GD_QUEIMAR"): _autoplay(delta)
		if time_left <= 0.0: time_left = 0.0; _finish(false)
	for s in sparks: s[1] += delta
	sparks = sparks.filter(func(s): return s[1] < 0.35)
	if state == "result":
		tada_t += delta
		if stars > 0 and int(tada_t / 0.9) != int((tada_t - delta) / 0.9) and tada_t < 3.0: _burst_confetti(25)
		for c in confetti:
			c[1].y += 1100.0 * delta; c[1].x *= 0.985; c[1].y = minf(c[1].y, 260.0 + 40.0 * sin(c[3]))   # gravidade + resistência do ar
			c[0] += c[1] * delta; c[3] += c[4] * delta
		confetti = confetti.filter(func(c): return c[0].y < INNER.end.y)
	if state == "playing" and tracing and Engine.get_process_frames() % 3 == 0: _emit_glitter(1)   # ~20 brilhos/s
	for g in glitter: g[1] += delta; g[0].y -= 18.0 * delta
	glitter = glitter.filter(func(g): return g[1] < g[2])
	_sync_ui()
	queue_redraw()
	if confetti_layer: confetti_layer.queue_redraw()

func _autoplay(delta: float) -> void:
	var path: PackedVector2Array = strokes[cur]
	if not tracing:
		_handle(path[0], true, false, false); return
	_auto_t += delta
	var j := mini(progress + (1 if OS.has_environment("GD_LENTO") else 4), path.size() - 1)
	var p := path[j] + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	_handle(p, false, false, true)
	if progress >= path.size() - 3: _handle(path[-1], false, true, false)

# ---------------- drawing (pixel-style blocks) ----------------
const C_BG := Color8(24, 17, 20); const C_TRAIL := Color8(120, 104, 92); const C_DONE := Color8(255, 214, 92)
const C_START := Color8(120, 200, 110); const C_END := Color8(217, 164, 65); const C_TXT := Color8(240, 230, 212)

func _block(p: Vector2, s: float, c: Color) -> void:
	draw_rect(Rect2((p / 4.0).floor() * 4.0 - Vector2(s, s) / 2, Vector2(s, s)), c)

func _ring(p: Vector2, r: float, c: Color, w := 6.0) -> void:
	for k in 36:
		var a := TAU * k / 36.0
		_block(p + Vector2(cos(a), sin(a)) * r, w, c)

func _draw_bg(dim: float) -> void:
	# cover: preenche a tela cortando as laterais (mantém o caldeirão no centro)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.02, 0.78))       # o jogo atrás fica escurecido
	var ts := bg_tex.get_size(); var sc := maxf(INNER.size.x / ts.x, INNER.size.y / ts.y)
	var w := INNER.size.x / sc; var h := INNER.size.y / sc
	draw_style_box(_frame_box, FRAME)
	draw_texture_rect_region(bg_tex, INNER, Rect2((ts.x - w) / 2, (ts.y - h) / 2, w, h))
	draw_rect(INNER, Color(0.06, 0.04, 0.05, dim))

func _draw_confetti() -> void:
	if state != "result": return
	for cf in confetti:                                 # confete: retângulos girando (achata = efeito de giro)
		var w := 14.0; var h := 8.0 * absf(cos(cf[3]))
		confetti_layer.draw_rect(Rect2((cf[0] / 4.0).floor() * 4.0 - Vector2(w, h) / 2, Vector2(w, maxf(4.0, h))), cf[2])

func _draw_tada() -> void:
	if dish_tex == null: dish_rect.visible = false; return
	var c := INNER.get_center() + Vector2(0, -150)
	# raios de luz girando atrás (fatias alternadas, em blocos)
	var rot := tada_t * 0.6
	if stars == 0:
		for k in 14:                                   # fumaça: blocos cinza subindo e sumindo
			var ph := fmod(tada_t * 0.7 + k * 0.137, 1.0)
			var p := c + Vector2(sin(k * 2.3 + tada_t) * 70.0 + (k - 7) * 14.0, 60.0 - ph * 300.0)
			draw_rect(Rect2((p / 4.0).floor() * 4.0, Vector2(12, 12) * (1.0 + ph)), Color(0.45, 0.42, 0.42, 0.5 * (1.0 - ph)))
	for k in (12 if stars > 0 else 0):
		var a0 := rot + TAU * k / 12.0; var a1 := a0 + TAU / 24.0
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 1600, c + Vector2(cos(a1), sin(a1)) * 1600])
		var box := PackedVector2Array([INNER.position, Vector2(INNER.end.x, INNER.position.y), INNER.end, Vector2(INNER.position.x, INNER.end.y)])
		for poly in Geometry2D.intersect_polygons(pts, box):      # raios até a borda da janela, recortados nela
			draw_colored_polygon(poly, Color(1.0, 0.86, 0.45, 0.13))
	for r in ([200, 150, 110] if stars > 0 else []):                         # halo em anéis pixelados
		draw_circle(c, r, Color(1.0, 0.85, 0.4, 0.07))
	# prato entra com pulo (ease-out-back) e respira
	var t := clampf(tada_t / 0.45, 0.0, 1.0); var k2 := 1.70158
	var e := 1.0 + (k2 + 1.0) * pow(t - 1.0, 3) + k2 * pow(t - 1.0, 2)
	var sc := (0.2 + 0.8 * e) * (1.0 + 0.03 * sin(tada_t * 3.0))
	var sz := Vector2(380, 380) * sc
	dish_rect.texture = dish_tex; dish_rect.position = c - sz / 2; dish_rect.size = sz; dish_rect.visible = true


func _draw() -> void:
	if bg_tex: _draw_bg(0.62 if state != "playing" else 0.45)
	else: draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	if state == "result": _draw_tada(); return
	dish_rect.visible = false
	if state != "playing": return
	# barra de tempo (pixel): fundo escuro + preenchimento em blocos de 4 px
	var bar := Rect2(INNER.position.x + 32, INNER.position.y + 112, INNER.size.x - 64, 24)
	draw_rect(bar.grow(4), Color8(16, 10, 12)); draw_rect(bar, Color8(40, 30, 32))
	var fw := floorf(bar.size.x * time_left / TIME_LIMIT / 4.0) * 4.0
	draw_rect(Rect2(bar.position, Vector2(fw, bar.size.y)), Color8(230, 90, 70) if time_left < 1.5 else C_END)
	draw_rect(Rect2(bar.position, Vector2(fw, 4)), Color8(255, 236, 170) if time_left >= 1.5 else Color8(255, 150, 130))
	var path: PackedVector2Array = strokes[cur]
	for j in path.size():
		if j % 2 == 0:
			_block(path[j], 12, Color8(16, 10, 12))
			_block(path[j], 8, C_DONE if j <= progress and tracing else Color8(236, 226, 206))
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 120.0)
	_ring(path[0], START_R * pulse, Color8(16, 10, 12), 10.0); _ring(path[-1], START_R, Color8(16, 10, 12), 10.0)
	_ring(path[0], START_R * pulse, C_START); _ring(path[-1], START_R, C_END)
	for g in glitter:
		var u: float = g[1] / g[2]; var tw := absf(sin(u * PI))          # cresce e some
		var arm := 1 if tw < 0.6 else 2            # estrela pequena: braço de 1–2 blocos de 4 px
		var col := Color8(255, 252, 230).lerp(Color8(255, 200, 90), u)
		col.a = 0.85 * tw + 0.15
		_block(g[0], 4, col)
		for k in range(1, arm + 1):
			for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]: _block(g[0] + dir * 4 * k, 4, col if k < arm else col.darkened(0.25))
	for s in sparks:
		var t: float = s[1] / 0.35
		for k in 8:
			var a := TAU * k / 8.0
			_block(s[0] + Vector2(cos(a), sin(a)) * lerpf(10, 70, t), 8, C_DONE.lerp(Color8(170, 70, 30), t))

# ---------------- UI nodes (fonte técnica, placas e botões no estilo do jogo) ----------------
var ui_menu: Control; var ui_play: Control; var ui_result: Control
var lb_gesture: Label; var lb_count: Label; var plate_play: NinePatchRect
var plate_res: NinePatchRect; var lb_res_title: Label; var lb_res_acc: Label; var lb_res_bonus: Label; var stars_box: HBoxContainer

func _plate_at(text: String, parent: Control) -> NinePatchRect:
	var pl := Estilo.placa(text, "l4")
	parent.add_child(pl)
	pl.position = Vector2(FRAME.get_center().x - pl.size.x / 2, FRAME.position.y - pl.size.y / 2)
	return pl

func _build_ui() -> void:
	dish_rect = TextureRect.new(); dish_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # prato com antialiasing suave
	dish_rect.mouse_filter = MOUSE_FILTER_IGNORE; dish_rect.visible = false; add_child(dish_rect)
	confetti_layer = Control.new(); confetti_layer.set_anchors_preset(PRESET_FULL_RECT); confetti_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(confetti_layer); confetti_layer.draw.connect(_draw_confetti)
	ui_menu = Control.new(); ui_play = Control.new(); ui_result = Control.new()
	for c in [ui_menu, ui_play, ui_result]:
		c.set_anchors_preset(PRESET_FULL_RECT); c.mouse_filter = MOUSE_FILTER_IGNORE; add_child(c)
	# menu
	_plate_at(Txt.t("mg_kitchen"), ui_menu)
	var info := Estilo.rotulo_px(Txt.t("mg_cook_help"), "t3", Estilo.COR_TEXTO, true)
	info.position = INNER.position + Vector2(36, 70); info.size = Vector2(INNER.size.x - 72, 120); ui_menu.add_child(info)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 20)
	box.position = INNER.position + Vector2(36, 230); box.size = Vector2(INNER.size.x - 72, 600); ui_menu.add_child(box)
	for i in DISHES.size():
		var d: Dictionary = DISHES[i]
		var b := Estilo.botao("%s  -  %s  (%d)" % [Txt.t("dish_" + String(d["img"])), d["name"], d["strokes"]], start_dish.bind(i))
		b.custom_minimum_size = Vector2(0, 104); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(b)
	# jogando
	plate_play = _plate_at(Txt.t("mg_kitchen"), ui_play)
	lb_gesture = Estilo.rotulo_px("", "t4"); lb_gesture.position = INNER.position + Vector2(32, 40); ui_play.add_child(lb_gesture)
	lb_count = Estilo.rotulo_px("", "t4"); lb_count.position = Vector2(INNER.end.x - 150, INNER.position.y + 40)
	lb_count.size = Vector2(118, 48); lb_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; ui_play.add_child(lb_count)
	# resultado
	plate_res = _plate_at(Txt.t("mg_kitchen"), ui_result)
	lb_res_title = Estilo.rotulo_px("", "t4"); lb_res_title.position = INNER.position + Vector2(0, 580)
	lb_res_title.size = Vector2(INNER.size.x, 60); lb_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui_result.add_child(lb_res_title)
	stars_box = HBoxContainer.new(); stars_box.alignment = BoxContainer.ALIGNMENT_CENTER; stars_box.add_theme_constant_override("separation", 16)
	stars_box.position = INNER.position + Vector2(0, 640); stars_box.size = Vector2(INNER.size.x, 120); ui_result.add_child(stars_box)
	for k in 3:
		var st := Estilo.icone_rect("fama", 24, 4); stars_box.add_child(st)
	lb_res_acc = Estilo.rotulo_px("", "t3"); lb_res_acc.position = INNER.position + Vector2(0, 760)
	lb_res_acc.size = Vector2(INNER.size.x, 48); lb_res_acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui_result.add_child(lb_res_acc)
	lb_res_bonus = Estilo.rotulo_px("", "t3", Estilo.COR_TEXTO, true); lb_res_bonus.position = INNER.position + Vector2(48, 808)
	lb_res_bonus.size = Vector2(INNER.size.x - 96, 120); lb_res_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ui_result.add_child(lb_res_bonus)
	btn_done = Estilo.botao(Txt.t("mg_continue"), _on_done)
	btn_done.position = INNER.position + Vector2(INNER.size.x / 2 - 160, 860); btn_done.size = Vector2(320, 96); ui_result.add_child(btn_done)
	btn_again = Estilo.botao(Txt.t("mg_cook_again"), func(): again.emit())
	btn_again.position = INNER.position + Vector2(32, 860); btn_again.size = Vector2(INNER.size.x / 2 - 48, 96); ui_result.add_child(btn_again)
	btn_again.visible = false

var btn_done: Button; var btn_again: Button
var _note := ""

func set_result_note(txt: String) -> void:
	_note = txt

func _on_done() -> void:
	if game_mode: closed.emit()
	else: state = "menu"

func _sync_ui() -> void:
	ui_menu.visible = state == "menu"; ui_play.visible = state == "playing"; ui_result.visible = state == "result"
	if state == "playing":
		Estilo.ajustar_placa(plate_play, Txt.t("dish_" + String(DISHES[dish]["img"])).to_upper())
		plate_play.position.x = FRAME.get_center().x - plate_play.size.x / 2
		lb_gesture.text = Txt.t("gesture_" + gesture_names[cur]) if cur < gesture_names.size() else ""
		lb_count.text = "%d/%d" % [mini(cur + 1, strokes.size()), strokes.size()]
	elif state == "result":
		lb_res_title.text = Txt.t("mg_burnt") if stars == 0 else Txt.t("mg_q%d" % stars)
		Estilo.ajustar_placa(plate_res, Txt.t("dish_" + String(DISHES[dish]["img"])).to_upper())
		plate_res.position.x = FRAME.get_center().x - plate_res.size.x / 2
		for k in 3:
			var st := stars_box.get_child(k) as TextureRect
			st.material = null if k < stars else Estilo.material_cinza()
			st.modulate = Color.WHITE if k < stars else Color(1, 1, 1, 0.45)
		lb_res_acc.text = Txt.t("mg_accuracy", [int(accuracy * 100.0)])
		lb_res_bonus.text = _note if game_mode else ["No buff, fewer portions.", "Normal price, weak buff.", "+20% price, normal buff.", "+50% price, strong buff, tips."][stars]
		if game_mode:
			btn_again.visible = true
			btn_again.disabled = not can_again
			btn_done.text = Txt.t("mg_done")
			btn_done.position = INNER.position + Vector2(INNER.size.x / 2 + 16, 860); btn_done.size = Vector2(INNER.size.x / 2 - 48, 96)
