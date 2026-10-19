## Lista rolável para celular: arrastar com o dedo (ou mouse no PC) rola com inércia.
## - Um toque só vale como clique se o dedo andar menos que LIMIAR px (canvas 720×1280) entre press e release.
##   Passou disso, vira arraste: os botões da lista recebem NOTIFICATION_SCROLL_BEGIN (BaseButton cancela o
##   press) e os cartões tocáveis consultam Rolagem.clique_valido() antes de agir.
## - Só a lista que está de fato sob o dedo rola (teste de clique igual ao da GUI: gaveta/popup/diálogo por
##   cima bloqueiam a lista de baixo).
## - Indicador metálico fino (2 px nativos) que aparece só enquanto rola e some em 0,4 s.
## - Roda do mouse continua funcionando (ScrollContainer padrão).
class_name Rolagem
extends ScrollContainer

const LIMIAR := 12.0              # px do canvas
const ATRITO := 4.0               # 1/s: velocidade cai a e^(−4t) → ~63% em 0,25 s
const VEL_MIN := 30.0             # px/s: abaixo disso a inércia para
const VEL_MAX := 6000.0
const JANELA_VEL := 0.08          # s de amostras para estimar a velocidade ao soltar

static var _gesto_arrastado := false   # o gesto atual (press→release) virou arraste em alguma lista

var _seguindo := false
var _arrastando := false
var _p0 := Vector2.ZERO
var _s0 := 0.0
var _amostras: Array = []          # [tempo, y]
var _vel := 0.0
var _resto := 0.0                  # fração de px acumulada na inércia
var _indicador: Control
var _alfa_ind := 0.0
var _t_ind := 0.0

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_deadzone = int(LIMIAR)

func _ready() -> void:
	_indicador = Control.new()
	_indicador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador.top_level = true                                 # fora do layout/rolagem do ScrollContainer
	_indicador.draw.connect(_desenhar_indicador)
	add_child(_indicador, false, Node.INTERNAL_MODE_BACK)     # interno: o ScrollContainer não o trata como conteúdo
	get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _mostrar_indicador())

## Monta Rolagem → MarginContainer → `conteudo`. A margem direita (px nativos) é a calha do indicador
## (nunca sobre os painéis); a de baixo deixa o último item subir acima do degradê do HUD inferior.
static func envolver(conteudo: Control, calha_dir: int = 3, folga_baixo: int = 0) -> Rolagem:
	var r := Rolagem.new()
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_theme_constant_override("margin_left", 0)
	m.add_theme_constant_override("margin_top", 0)
	m.add_theme_constant_override("margin_right", calha_dir * Estilo.K)
	m.add_theme_constant_override("margin_bottom", folga_baixo * Estilo.K)
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(conteudo)
	r.add_child(m)
	return r

## O arraste é tratado em _input; aqui só impedimos o arraste nativo do ScrollContainer (no celular ele
## também rolaria → rolagem dobrada). A roda do mouse segue para o tratamento padrão.
func _gui_input(evento: InputEvent) -> void:
	var mb := evento as InputEventMouseButton
	if (mb != null and mb.button_index == MOUSE_BUTTON_LEFT) or evento is InputEventMouseMotion \
			or evento is InputEventScreenDrag or evento is InputEventScreenTouch:
		accept_event()

## Cartões que agem no release devem chamar isto: false se o gesto foi arraste.
static func clique_valido() -> bool:
	return not _gesto_arrastado

func _input(evento: InputEvent) -> void:
	# só eventos de mouse (o toque do celular é emulado como mouse) — evita tratar o mesmo dedo 2×
	var mb := evento as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_ao_apertar(mb.position)
		else:
			_ao_soltar()
		return
	var mm := evento as InputEventMouseMotion
	if mm != null and _seguindo:
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_ao_soltar()
			return
		_ao_mover(mm.position)
		if _arrastando:
			get_viewport().set_input_as_handled()      # nada de hover/realce nos botões enquanto rola

func _ao_apertar(pos: Vector2) -> void:
	if _seguindo and pos.distance_to(_p0) < 1.0:
		return                                           # press duplicado (mouse + toque emulado)
	_gesto_arrastado = false
	_seguindo = false
	_arrastando = false
	if not is_visible_in_tree() or _lista_sob(pos) != self:
		return
	var rolando_rapido := absf(_vel) > 200.0
	_vel = 0.0
	_resto = 0.0
	_seguindo = true
	_p0 = pos
	_s0 = scroll_vertical
	_amostras = [[_agora(), pos.y]]
	if rolando_rapido:                                   # toque que freia a inércia não é clique
		_gesto_arrastado = true
		propagate_notification.call_deferred(Control.NOTIFICATION_SCROLL_BEGIN)

func _ao_mover(pos: Vector2) -> void:
	if not _arrastando:
		if pos.distance_to(_p0) < LIMIAR:
			return
		_arrastando = true
		_gesto_arrastado = true
		_p0 = pos                                        # começa a rolar daqui (sem pulo de 12 px)
		_s0 = scroll_vertical
		_amostras.clear()
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		scroll_started.emit()
	scroll_vertical = int(roundf(_s0 - (pos.y - _p0.y)))
	var t := _agora()
	_amostras.append([t, pos.y])
	while _amostras.size() > 2 and t - float(_amostras[0][0]) > JANELA_VEL:
		_amostras.pop_front()

func _ao_soltar() -> void:
	if not _seguindo:
		return
	_seguindo = false
	if not _arrastando:
		return
	_arrastando = false
	_vel = 0.0
	if _amostras.size() >= 2:
		var a: Array = _amostras[0]
		var b: Array = _amostras[_amostras.size() - 1]
		var dt := float(b[0]) - float(a[0])
		if dt > 0.0 and _agora() - float(b[0]) < 0.1:   # dedo parado antes de soltar = sem inércia
			_vel = clampf(-(float(b[1]) - float(a[1])) / dt, -VEL_MAX, VEL_MAX)
	propagate_notification(Control.NOTIFICATION_SCROLL_END)
	scroll_ended.emit()

func _process(delta: float) -> void:
	if not _seguindo and absf(_vel) > VEL_MIN:
		var antes := scroll_vertical
		_resto += _vel * delta
		var passo := int(_resto)
		_resto -= passo
		scroll_vertical = antes + passo
		if scroll_vertical == antes and passo != 0:      # bateu no começo/fim
			_vel = 0.0
		_vel *= exp(-ATRITO * delta)
	elif not _seguindo:
		_vel = 0.0
	# indicador some 0,4 s depois de parar
	if _alfa_ind > 0.0:
		_t_ind += delta
		if _t_ind > 0.4:
			_alfa_ind = maxf(0.0, _alfa_ind - delta / 0.25)
		_alinhar_indicador()
		_indicador.queue_redraw()

func _alinhar_indicador() -> void:
	_indicador.global_position = global_position
	_indicador.size = size

func _agora() -> float:
	return Time.get_ticks_usec() / 1000000.0

func _mostrar_indicador() -> void:
	_alfa_ind = 1.0
	_t_ind = 0.0
	if _indicador != null:
		_alinhar_indicador()
		_indicador.queue_redraw()

## Indicador metálico: 2 px nativos de largura (luz | meio-tom), pontas em sombra; colado à borda direita.
func _desenhar_indicador() -> void:
	if _alfa_ind <= 0.0:
		return
	var barra := get_v_scroll_bar()
	var total := barra.max_value - barra.min_value
	var pagina := barra.page
	if total <= pagina + 1.0:
		return
	var k := Estilo.K
	var alt_util := size.y - 2 * k
	var h := maxf(10.0 * k, roundf(alt_util * pagina / total / k) * k)
	var y := k + roundf((alt_util - h) * scroll_vertical / maxf(1.0, total - pagina) / k) * k
	var x := size.x - 2 * k                              # dentro da calha direita (margem de 3 px nativos)
	var a := _alfa_ind * 0.85
	_indicador.draw_rect(Rect2(x, y, k, h), Color8(176, 172, 168, int(255 * a)))
	_indicador.draw_rect(Rect2(x + k, y, k, h), Color8(118, 114, 112, int(255 * a)))
	_indicador.draw_rect(Rect2(x, y, 2 * k, k), Color8(66, 62, 62, int(255 * a)))
	_indicador.draw_rect(Rect2(x, y + h - k, 2 * k, k), Color8(66, 62, 62, int(255 * a)))

# ---------------------------------------------------------------- teste de clique (como a GUI)
## Lista rolável mais interna sob o ponto, considerando o que está desenhado por cima (camadas, ordem).
func _lista_sob(pos: Vector2) -> Rolagem:
	var c := _controle_em(get_tree().root, pos)
	while c != null:
		if c is Rolagem:
			return c
		c = c.get_parent() as Control
	return null

static var _cache_quadro := -1
static var _cache_pos := Vector2.INF
static var _cache_res: Control

static func _controle_em(raiz: Node, pos: Vector2) -> Control:
	# um teste por press (todas as listas perguntam no mesmo quadro)
	var q := Engine.get_process_frames()
	if q == _cache_quadro and pos == _cache_pos and is_instance_valid(_cache_res):
		return _cache_res
	# camadas (CanvasLayer) mais altas primeiro; dentro da mesma camada, o último filho está por cima
	var grupos := {}
	_coletar(raiz, 0, grupos)
	var camadas := grupos.keys()
	camadas.sort()
	camadas.reverse()
	var achado: Control = null
	for cam in camadas:
		var lista: Array = grupos[cam]
		for i in range(lista.size() - 1, -1, -1):
			achado = _achar(lista[i], pos)
			if achado != null:
				break
		if achado != null:
			break
	_cache_quadro = q
	_cache_pos = pos
	_cache_res = achado
	return achado

## Controles-raiz de cada camada; CanvasLayers aninhadas (ex.: diálogo dentro da cena principal) viram grupo próprio.
static func _coletar(no: Node, camada: int, grupos: Dictionary, raiz_da_camada := true) -> void:
	for f in no.get_children():
		if f is CanvasLayer:
			if (f as CanvasLayer).visible:
				_coletar(f, (f as CanvasLayer).layer, grupos)
		elif f is Control:
			if raiz_da_camada:
				if not grupos.has(camada):
					grupos[camada] = []
				grupos[camada].append(f)
			_coletar(f, camada, grupos, false)          # só procura CanvasLayers lá dentro
		elif not (f is CanvasItem):
			_coletar(f, camada, grupos, raiz_da_camada)

static func _achar(c: Control, pos: Vector2) -> Control:
	if not c.visible:
		return null
	var dentro := c.get_global_rect().has_point(pos)
	if c.clip_contents and not dentro:
		return null
	for i in range(c.get_child_count() - 1, -1, -1):
		var f := c.get_child(i) as Control
		if f == null or f.top_level:
			continue
		var r := _achar(f, pos)
		if r != null:
			return r
	if dentro and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return c
	return null
