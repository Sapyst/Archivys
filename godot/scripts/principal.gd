## Cena principal: HUD superior, área central (abas), HUD inferior com barra de 5 abas,
## gavetas, popups (retorno de missão, "Enquanto você esteve fora…"), abertura (lore + nome da guilda),
## aviso de rush (borda dourada) e os mini-games como camada por cima (servir / cozinhar).
## Toda a UI é montada por código.
extends Control

const ABAS := [
	{"id": "guilda", "rotulo": "tab_guild", "icone": "guilda", "script": "res://scripts/abas/aba_guilda.gd"},
	{"id": "herois", "rotulo": "tab_heroes", "icone": "aventureiros", "script": "res://scripts/abas/aba_herois.gd"},
	{"id": "quadro", "rotulo": "tab_board", "icone": "contratos", "script": "res://scripts/abas/aba_quadro.gd"},
	{"id": "bar", "rotulo": "tab_bar", "icone": "bar", "script": "res://scripts/abas/aba_bar.gd"},
	{"id": "obras", "rotulo": "tab_works", "icone": "melhorias", "script": "res://scripts/abas/aba_obras.gd"},
]
const K := Estilo.K
const LARGURA_FURO_N := 14.0         # meia-largura (px nativos) reservada ao furo da câmera no centro do topo
const RESULTADOS := {
	"brilhante": ["res_brilhante", Estilo.COR_OURO],
	"sucesso": ["res_sucesso", Estilo.COR_VERDE],
	"parcial": ["res_parcial", Estilo.COR_LARANJA],
	"falha": ["res_falha", Estilo.COR_VERMELHO],
}

var aba_ativa := ""
var em_evento := false
var margem_topo := 40.0
var margem_baixo := 24.0
var altura_topo := 0.0
var altura_baixo := 0.0

var _abas := {}            # id -> AbaBase
var _botoes_aba := {}      # id -> {icone, rotulo, alerta}
var _hud := {}             # nome -> Label
var _placa: NinePatchRect
var _placa_y := 0.0
var _placa_txt := ""
var _conteudo: Control
var _camada: Control       # gavetas e popups
var _gaveta: Control
var _gaveta_corpo: VBoxContainer
var _gaveta_montar: Callable
var _retornos_mostrados := {}
var _sujo := true
var _aviso: PanelContainer         # aviso de rush (acima do HUD inferior)
var _aviso_titulo: Label
var _aviso_sub: Label
var _aviso_auto: Button
var _toasts: VBoxContainer
var _minigame: CanvasLayer         # camada do mini-game aberto (null = nenhum)

signal nome_definido(nome: String)

const NOME_MAX := 18

# ---------------------------------------------------------------- montagem
func _ready() -> void:
	theme = Estilo.tema()
	_calcular_areas_seguras()
	var fundo := TextureRect.new()                 # tábuas escuras (como na prévia)
	fundo.texture = Estilo.ui("fundo_tabuas")
	fundo.stretch_mode = TextureRect.STRETCH_TILE
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_montar_conteudo()
	_montar_hud_topo()
	_montar_hud_baixo()
	_montar_aviso_rush()
	_toasts = VBoxContainer.new()            # avisos curtos ficam abaixo de gavetas e popups
	_toasts.add_theme_constant_override("separation", 2 * K)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = altura_topo + 2 * K
	_toasts.offset_left = 10 * K
	_toasts.offset_right = -10 * K
	add_child(_toasts)
	_camada = Control.new()
	_camada.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_camada)
	Jogo.mudou.connect(_marcar_sujo)
	Jogo.rush_resolvido.connect(_ao_resolver_rush)
	Salvar.voltou.connect(_aplicar_ausencia)
	_iniciar.call_deferred()

func _marcar_sujo() -> void:
	_sujo = true

func _calcular_areas_seguras() -> void:
	# área segura real do aparelho convertida para o espaço da viewport; mínimo 40 px em cima (faixa do sistema)
	var seguro := DisplayServer.get_display_safe_area()
	var janela := DisplayServer.window_get_size()
	var vp := get_viewport_rect().size
	if janela.y > 0 and seguro.size.y > 0 and OS.get_environment("GD_CAPTURA").is_empty():
		var esc := vp.y / float(janela.y)
		margem_topo = maxf(40.0, seguro.position.y * esc)
		margem_baixo = maxf(24.0, (janela.y - seguro.end.y) * esc)
	else:
		margem_baixo = 24.0
	altura_topo = margem_topo - 40.0 + 46.0 * K      # o conteúdo começa logo abaixo da placa "Dia N"
	altura_baixo = 47.0 * K + margem_baixo           # recursos + corda + abas + barra de gestos

func _montar_conteudo() -> void:
	_conteudo = Control.new()
	_conteudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_conteudo.offset_top = altura_topo
	_conteudo.offset_bottom = -altura_baixo
	add_child(_conteudo)
	for a in ABAS:
		var aba: AbaBase = (load(String(a.script)) as GDScript).new()
		aba.principal = self
		aba.set_anchors_preset(Control.PRESET_FULL_RECT)
		aba.hide()
		_conteudo.add_child(aba)
		_abas[a.id] = aba

## Ícone 12 px nativos (24 ×2) + número na fonte técnica, 2 px de folga (como na prévia).
func _item_hud(chave: String, icone: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2 * K)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Estilo.icone_rect(icone, 24, 2))
	var l := Estilo.rotulo_px("0", "t4")
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var m := MarginContainer.new()                   # letra começa 3 px abaixo do topo do ícone (−2 da linha de acento)
	m.add_theme_constant_override("margin_top", 1 * K)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(l)
	h.add_child(m)
	_hud[chave] = l
	return h

## Coloca `c` numa âncora horizontal (0 / 0.5 / 1) crescendo para o lado `cresce`.
func _ancorar(c: Control, pai: Control, ancora: float, x: float, y: float, cresce: int) -> void:
	c.anchor_left = ancora; c.anchor_right = ancora
	c.offset_left = x; c.offset_right = x
	c.offset_top = y; c.offset_bottom = y
	c.grow_horizontal = cresce
	pai.add_child(c)

func _montar_hud_topo() -> void:
	var y0 := margem_topo - 40.0
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = y0 + 48.0 * K
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	if y0 > 0.0:
		var extra := ColorRect.new()
		extra.color = Color8(30, 21, 24)
		extra.set_anchors_preset(Control.PRESET_TOP_WIDE)
		extra.offset_bottom = y0
		extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(extra)
	var fundo := TextureRect.new()               # madeira + faixa do sistema vazia + corda + degradê
	fundo.texture = Estilo.ui("hud_topo_fundo")
	fundo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fundo.offset_top = y0
	fundo.offset_bottom = y0 + 48.0 * K
	fundo.stretch_mode = TextureRect.STRETCH_TILE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fundo)
	var cy := y0 + 12.0 * K
	# esquerda: moedas + fama | centro livre (furo da câmera) | direita: honra + relógio
	_ancorar(_item_hud("moedas", "moedas"), hud, 0.0, 3.0 * K, cy, Control.GROW_DIRECTION_END)
	_ancorar(_item_hud("fama", "fama"), hud, 0.5, -(LARGURA_FURO_N + 4.0) * K, cy, Control.GROW_DIRECTION_BEGIN)
	_ancorar(_item_hud("honra", "honra"), hud, 0.5, (LARGURA_FURO_N + 4.0) * K, cy, Control.GROW_DIRECTION_END)
	_ancorar(_item_hud("relogio", "relogio"), hud, 1.0, -6.0 * K, cy, Control.GROW_DIRECTION_BEGIN)
	# placa "Dia N 60×" centralizada logo abaixo da corda (toque troca a velocidade: 30/60/120/240×)
	_placa = Estilo.placa(Relogio.texto_placa(), "l4", 13)
	_placa.mouse_filter = Control.MOUSE_FILTER_STOP
	_placa.gui_input.connect(func(e: InputEvent) -> void:
		if Estilo.e_toque(e):
			Relogio.alternar_velocidade())
	_placa_y = y0 + 32.0 * K
	hud.add_child(_placa)
	_posicionar_placa()

func _posicionar_placa() -> void:
	_placa.position = Vector2(roundi((get_viewport_rect().size.x - _placa.size.x) / (2.0 * K)) * K, _placa_y)

func _montar_hud_baixo() -> void:
	var extra := margem_baixo - 6.0 * K               # gestos além dos 6 px nativos do desenho
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_top = -(altura_baixo + 14.0 * K)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var fundo := TextureRect.new()
	fundo.texture = Estilo.ui("hud_baixo_fundo")
	fundo.position = Vector2.ZERO
	fundo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fundo.offset_bottom = 67.0 * K
	fundo.stretch_mode = TextureRect.STRETCH_TILE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fundo)
	if extra > 0.0:
		var e := ColorRect.new()
		e.color = Color8(30, 21, 24)
		e.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		e.offset_top = -extra
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(e)
	var topo := 14.0 * K                              # corpo começa depois do degradê
	var recursos := HBoxContainer.new()
	recursos.add_theme_constant_override("separation", 7 * K)
	recursos.position = Vector2(3.0 * K, topo + 1.0 * K)
	recursos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["provisoes", "pratos", "materiais", "favores"]:
		recursos.add_child(_item_hud(k, k))
	hud.add_child(recursos)
	# abas: 5 colunas de 36 px nativos, sem caixa de fundo
	var ny := topo + 22.0 * K
	var larg := get_viewport_rect().size.x / ABAS.size()
	for i in ABAS.size():
		var a: Dictionary = ABAS[i]
		var id := String(a.id)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.position = Vector2(i * larg, ny - 2.0 * K)
		b.size = Vector2(larg, 25.0 * K)
		b.pressed.connect(trocar_aba.bind(id))
		var ic := Estilo.icone_rect(String(a.icone), 28, 2)
		ic.size = ic.custom_minimum_size
		ic.position = Vector2(roundi((larg - ic.size.x) / (2.0 * K)) * K, 4.0 * K)
		b.add_child(ic)
		var l := Estilo.rotulo_px(Txt.t(String(a.rotulo)), "m4", Estilo.COR_FRACO)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 18.0 * K)            # mini: 1 px de acento acima → letra em ny+17
		l.size = Vector2(larg, 8.0 * K)
		b.add_child(l)
		var bola := TextureRect.new()                 # bolinha de alerta 6×6 nativa
		bola.texture = _bolinha()
		bola.size = Vector2(6 * K, 6 * K)
		bola.position = Vector2(roundi(larg / (2.0 * K) + 6.0) * K, 3.0 * K)
		bola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bola.hide()
		b.add_child(bola)
		hud.add_child(b)
		_botoes_aba[id] = {"icone": ic, "rotulo": l, "alerta": bola}

func _bolinha() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var mapa := ["..OO..", ".ORRO.", "ORRRRO", "ORRRRO", ".ORRO.", "..OO.."]
	for y in 6:
		for x in 6:
			var ch: String = mapa[y][x]
			if ch == "O":
				img.set_pixel(x, y, Color8(28, 18, 16))
			elif ch == "R":
				img.set_pixel(x, y, Color8(214, 38, 30))
	img.resize(6 * K, 6 * K, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- fluxo
func _iniciar() -> void:
	trocar_aba("guilda")
	if Salvar.carregar():
		var h := Relogio.horas_ausencia(Salvar.timestamp_salvo)
		if h >= 0.25:                  # menos de 15 min de jogo fora: sem resumo
			_aplicar_ausencia(h)
	else:
		Jogo.novo_jogo()
	if not Jogo.primeira_vez_feita:
		await _evento_inicial()
	Relogio.ativo = true
	Salvar.salvar()

## Abertura: lore curta (corda) → nome da guilda (campo de texto) → registro + dica do primeiro rush.
func _evento_inicial() -> void:
	em_evento = true
	var cena := CenaDialogo.new()
	add_child(cena)
	await cena.rodar(EventoInicial.falas())
	_pedir_nome()
	var nome: String = await nome_definido
	Jogo.nome_guilda = nome
	Jogo.mudou.emit()
	var cena2 := CenaDialogo.new()
	add_child(cena2)
	await cena2.rodar(EventoInicial.falas_registro(nome))
	Jogo.primeira_vez_feita = true
	em_evento = false
	var mus := get_node_or_null("/root/Musica")
	if mus: mus.tocar("idle")
	trocar_aba("guilda")
	_sujo = true

## Popup com o campo de nome (máx. 18 letras; só caracteres que a fonte técnica desenha).
func _pedir_nome() -> void:
	var montar := func(corpo: VBoxContainer, fechar: Callable) -> void:
		corpo.add_theme_constant_override("separation", 4 * K)
		var ajuda := Estilo.rotulo(Txt.t("name_help", [NOME_MAX]), 18, Estilo.COR_SUB, true)
		ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		corpo.add_child(ajuda)
		var campo := LineEdit.new()
		campo.text = Txt.t("guild_name")
		campo.max_length = NOME_MAX
		campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
		campo.custom_minimum_size = Vector2(0, 19 * K)
		campo.select_all_on_focus = true
		campo.context_menu_enabled = false
		campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
		corpo.add_child(campo)
		var contador := Estilo.rotulo_px(Txt.t("name_count", [campo.text.length(), NOME_MAX]), "m4", Estilo.COR_FRACO)
		contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		corpo.add_child(contador)
		campo.text_changed.connect(func(t: String) -> void:
			var limpo := _filtrar_nome(t)
			if limpo != t:
				var c := campo.caret_column
				campo.text = limpo
				campo.caret_column = mini(c, limpo.length())
			contador.text = Txt.t("name_count", [campo.text.length(), NOME_MAX]))
		var registrar := func() -> void:
			var nome := campo.text.strip_edges()
			while nome.contains("  "):
				nome = nome.replace("  ", " ")
			if nome.is_empty():
				nome = Txt.t("guild_name")
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_hide()
			fechar.call()
			nome_definido.emit(nome)
		campo.text_submitted.connect(func(_t: String) -> void: registrar.call())
		var b := Estilo.botao(Txt.t("name_register"), registrar)
		corpo.add_child(b)
	abrir_popup(Txt.t("name_title"), montar)

const _NOME_OK := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-.&áàâãéêíóôõúüçÇÁÀÂÃÉÊÍÓÔÕÚèìòîû"
static func _filtrar_nome(t: String) -> String:
	var r := ""
	for ch in t:
		if _NOME_OK.contains(ch):
			r += ch
	return r.substr(0, NOME_MAX)

func _aplicar_ausencia(h: float) -> void:
	var antes := {"moedas": Jogo.moedas, "fama": Jogo.fama, "provisoes": int(Jogo.provisoes), "pratos": Jogo.total_porcoes()}
	Jogo.iniciar_coleta()
	Jogo.avancar(h)
	var eventos := Jogo.terminar_coleta()
	Salvar.salvar()
	var montar := func(corpo: VBoxContainer, fechar: Callable) -> void:
		corpo.add_child(Estilo.rotulo(Txt.t("away_passed", [Estilo.texto_horas(h)]), 20, Estilo.COR_FRACO, true))
		corpo.add_child(Estilo.linha_icone("moedas", Txt.t("away_coins", [Jogo.moedas - int(antes.moedas)])))
		corpo.add_child(Estilo.linha_icone("fama", Txt.t("away_fame", [Jogo.fama - int(antes.fama)])))
		corpo.add_child(Estilo.linha_icone("provisoes", Txt.t("away_food", [int(Jogo.provisoes) - int(antes.provisoes)])))
		corpo.add_child(Estilo.linha_icone("pratos", Txt.t("away_dishes", [Jogo.total_porcoes() - int(antes.pratos)])))
		var ultimos: Array = eventos.slice(maxi(0, eventos.size() - 10))
		for e in ultimos:
			corpo.add_child(Estilo.rotulo("• " + String(e), 18, Estilo.COR_TEXTO, true))
		if eventos.size() > ultimos.size():
			corpo.add_child(Estilo.rotulo(Txt.t("away_more", [eventos.size() - ultimos.size()]), 16, Estilo.COR_FRACO, true))
		corpo.add_child(Estilo.botao(Txt.t("ok_excl"), fechar))
	abrir_popup(Txt.t("away_title"), montar)

func trocar_aba(id: String) -> void:
	aba_ativa = id
	for k in _abas:
		_abas[k].visible = k == id
	for k in _botoes_aba:
		var info: Dictionary = _botoes_aba[k]
		var ativo: bool = k == id
		var ic := info.icone as TextureRect
		ic.material = null if ativo else Estilo.material_cinza()     # inativas: 30% sat, 65% brilho
		ic.position.y = (3.0 if ativo else 4.0) * K                   # ativa sobe 1 px
		(info.rotulo as Label).add_theme_color_override("font_color", Estilo.COR_DOURADO if ativo else Estilo.COR_FRACO)
	fechar_gaveta()
	_sujo = true

func _process(_delta: float) -> void:
	_atualizar_hud()
	if _sujo:
		_sujo = false
		if _abas.has(aba_ativa):
			_abas[aba_ativa].atualizar()
		_atualizar_alertas()
		_atualizar_aviso_rush()
		if not em_evento and _minigame == null:
			_verificar_retornos()

func _atualizar_hud() -> void:
	_hud.moedas.text = str(Jogo.moedas)
	_hud.fama.text = str(Jogo.fama)
	_hud.honra.text = str(int(Jogo.honra))
	_hud.relogio.text = Jogo.texto_hora()
	_hud.provisoes.text = "%d/%d" % [int(Jogo.provisoes), Jogo.cap_provisoes()]
	_hud.pratos.text = str(Jogo.total_porcoes())
	_hud.materiais.text = str(Jogo.materiais)
	_hud.favores.text = str(Jogo.favores)
	# vermelho abaixo de 35% (provisões) / menos de 6 porções
	_hud.provisoes.add_theme_color_override("font_color", Estilo.COR_VERMELHO if Jogo.provisoes < 0.35 * Jogo.cap_provisoes() else Estilo.COR_TEXTO)
	_hud.pratos.add_theme_color_override("font_color", Estilo.COR_VERMELHO if Jogo.total_porcoes() < 6 else Estilo.COR_TEXTO)
	var t := Relogio.texto_placa()
	if t != _placa_txt:
		_placa_txt = t
		Estilo.ajustar_placa(_placa, t)
		_posicionar_placa()

func _atualizar_alertas() -> void:
	var com_alerta := {}
	for a in Jogo.alertas():
		if int(a.prioridade) >= 40:
			com_alerta[String(a.aba)] = true
	for k in _botoes_aba:
		(_botoes_aba[k].alerta as Control).visible = com_alerta.has(k) and k != aba_ativa

# ---------------------------------------------------------------- gaveta (folha que sobe de baixo)
func abrir_gaveta(titulo: String, montar: Callable) -> void:
	fechar_gaveta()
	_gaveta = Control.new()
	_gaveta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gaveta.mouse_filter = Control.MOUSE_FILTER_STOP
	_camada.add_child(_gaveta)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.55)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.gui_input.connect(func(e: InputEvent) -> void:
		if Estilo.e_toque(e):
			fechar_gaveta())
	_gaveta.add_child(escuro)
	var painel := PanelContainer.new()
	var caixa := Estilo.caixa_painel(Estilo.COR_PAINEL, 18, 24)
	caixa.content_margin_bottom += margem_baixo          # o painel vai até a borda; o conteúdo fica fora da barra de gestos
	painel.add_theme_stylebox_override("panel", caixa)
	painel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	painel.offset_top = -get_viewport_rect().size.y * 0.66
	painel.offset_left = 6
	painel.offset_right = -6
	_gaveta.add_child(painel)
	var v := VBoxContainer.new()
	painel.add_child(v)
	var cab := HBoxContainer.new()
	var t := Estilo.rotulo(titulo, 28, Estilo.COR_DOURADO, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(t)
	var x := Estilo.botao("✕", fechar_gaveta)
	x.custom_minimum_size = Vector2(64, 64)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cab.add_child(x)
	v.add_child(cab)
	_gaveta_corpo = VBoxContainer.new()
	_gaveta_corpo.add_theme_constant_override("separation", 12)
	var rol := Rolagem.envolver(_gaveta_corpo, 3, 2)
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rol)
	# entra deslizando
	painel.position.y += 80.0
	painel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(painel, "position:y", painel.position.y - 80.0, 0.16)
	tw.tween_property(painel, "modulate:a", 1.0, 0.12)
	_gaveta_montar = montar
	montar.call(_gaveta_corpo)

func atualizar_gaveta() -> void:
	_atualizar_gaveta_agora.call_deferred()     # adiado: o botão que chamou ainda está emitindo sinal

func _atualizar_gaveta_agora() -> void:
	if _gaveta == null or not is_instance_valid(_gaveta):
		return
	Estilo.limpar(_gaveta_corpo)
	_gaveta_montar.call(_gaveta_corpo)

func fechar_gaveta() -> void:
	if _gaveta != null and is_instance_valid(_gaveta):
		_gaveta.queue_free()
	_gaveta = null
	_sujo = true

# ---------------------------------------------------------------- popup central
## montar(corpo: VBoxContainer, fechar: Callable)
func abrir_popup(titulo: String, montar: Callable, cor_titulo: Color = Estilo.COR_DOURADO) -> Control:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_camada.add_child(raiz)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.6)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(escuro)
	var centro := CenterContainer.new()                # centralizado entre os HUDs (nada fica sob eles)
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.offset_top = altura_topo
	centro.offset_bottom = -altura_baixo
	raiz.add_child(centro)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Estilo.caixa_painel(Estilo.COR_PAINEL, 16, 24))
	painel.custom_minimum_size = Vector2(640, 0)
	centro.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	painel.add_child(v)
	var t := Estilo.rotulo(titulo, 30, cor_titulo, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var corpo := VBoxContainer.new()
	var rol := Rolagem.envolver(corpo, 3, 0)          # corpo longo rola dentro do popup
	v.add_child(rol)
	# altura do corpo = a do conteúdo, limitada ao que cabe entre os HUDs
	var ajustar := func() -> void:
		if not is_instance_valid(rol):
			return
		var livre := (get_viewport_rect().size.y - altura_topo - altura_baixo) - 2 * 4 * K \
			- painel.get_theme_stylebox("panel").get_minimum_size().y - t.size.y - 12
		rol.custom_minimum_size.y = minf(corpo.get_combined_minimum_size().y, livre)
	corpo.minimum_size_changed.connect(ajustar)
	t.resized.connect(ajustar)
	ajustar.call_deferred()
	var fechar := func() -> void:
		raiz.queue_free()
		_sujo = true
	montar.call(corpo, fechar)
	painel.pivot_offset = Vector2(320, 0)
	painel.scale = Vector2(0.9, 0.9)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(painel, "scale", Vector2.ONE, 0.18)
	return raiz

# ---------------------------------------------------------------- retorno de missão
func _verificar_retornos() -> void:
	for r in Jogo.retornos_pendentes:
		var id := int(r.id)
		if _retornos_mostrados.has(id):
			continue
		_retornos_mostrados[id] = true
		var info: Array = RESULTADOS.get(String(r.resultado), ["?", Estilo.COR_TEXTO])
		var montar := func(corpo: VBoxContainer, fechar: Callable) -> void:
			_montar_retorno(corpo, id, fechar)
		abrir_popup(Txt.t(String(info[0])), montar, info[1])

func _montar_retorno(corpo: VBoxContainer, id: int, fechar: Callable) -> void:
	Estilo.limpar(corpo)
	var r := Jogo.retorno_por_id(id)
	if r.is_empty():
		fechar.call()
		return
	corpo.add_child(Estilo.rotulo("[%s] %s" % [r.rank, r.contrato], 20, Estilo.COR_TEXTO, true))
	corpo.add_child(Estilo.linha_icone("moedas", Txt.t("ret_coins", [int(r.moedas)])))
	if int(r.materiais) > 0:
		corpo.add_child(Estilo.linha_icone("materiais", Txt.t("ret_mats", [int(r.materiais)])))
	if int(r.favores) > 0:
		corpo.add_child(Estilo.linha_icone("favores", Txt.t("ret_favors", [int(r.favores)])))
	corpo.add_child(Estilo.linha_icone("fama", Txt.t("ret_fame", [int(r.fama)])))
	if not r.feridos.is_empty():
		corpo.add_child(Estilo.rotulo(Txt.t("ret_wounded", [", ".join(PackedStringArray(r.feridos))]), 18, Estilo.COR_LARANJA, true))
	if bool(r.grupo_perdido):
		corpo.add_child(Estilo.rotulo(Txt.t("ret_lost", [int(r.get("perda_total", 0))]),
			20, Estilo.COR_VERMELHO, true))
		corpo.add_child(Estilo.rotulo(Txt.t("ret_mira_rro"), 18, Estilo.COR_FRACO, true))
		# TODO: Expedição de Honra / Missão de Vingança aparecerem no quadro.
	else:
		for i in r.mortos.size():
			var mo: Dictionary = r.mortos[i]
			var p := Estilo.painel(Estilo.COR_PAINEL_ESCURO)
			var v := VBoxContainer.new()
			v.add_child(Estilo.linha_icone("morte", Txt.t("ret_died", [mo.nome])))
			if bool(mo.resolvido):
				var txt := Txt.t("ret_burial_done", [int(round(int(mo.P) * 0.2)), int(0.8 * int(mo.P))]) \
					if bool(mo.digno) else Txt.t("ret_noburial_done", [int(mo.P)])
				v.add_child(Estilo.rotulo(txt, 18, Estilo.COR_FRACO, true))
			else:
				v.add_child(Estilo.rotulo(Txt.t("ret_burial_choice", [int(mo.P),
					int(round(int(mo.P) * 0.2)), int(0.8 * int(mo.P))]), 16, Estilo.COR_FRACO, true))
				var h := HBoxContainer.new()
				var idx: int = i
				var f_digno := func() -> void:
					Jogo.decidir_enterro(id, idx, true)
					_montar_retorno.call_deferred(corpo, id, fechar)
				var f_sem := func() -> void:
					Jogo.decidir_enterro(id, idx, false)
					_montar_retorno.call_deferred(corpo, id, fechar)
				var b1 := Estilo.botao(Txt.t("btn_burial", [int(mo.custo)]), f_digno, Jogo.moedas >= int(mo.custo))
				var b2 := Estilo.botao(Txt.t("btn_noburial"), f_sem)
				b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(b1); h.add_child(b2)
				v.add_child(h)
			p.add_child(v)
			corpo.add_child(p)
	var ok := func() -> void:
		Jogo.dispensar_retorno(id)
		fechar.call()
	corpo.add_child(Estilo.botao(Txt.t("ok"), ok, Jogo.retorno_resolvido(r)))

# ---------------------------------------------------------------- aviso de rush (destaque = metal dourado)
func _montar_aviso_rush() -> void:
	_aviso = PanelContainer.new()
	_aviso.add_theme_stylebox_override("panel", Estilo.caixa_9("metal_dourado", 6, Vector4(7, 5, 7, 6)))
	_aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_aviso.offset_left = 6 * K
	_aviso.offset_right = -6 * K
	_aviso.offset_bottom = -(altura_baixo + 3 * K)
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aviso.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2 * K)
	_aviso.add_child(v)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 3 * K)
	cab.add_child(Estilo.icone_rect("pratos", 28, 2))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso_titulo = Estilo.rotulo_px("", "t4", Estilo.COR_OURO)
	_aviso_sub = Estilo.rotulo_px("", "t3", Estilo.COR_SUB)
	tv.add_child(_aviso_titulo)
	tv.add_child(_aviso_sub)
	cab.add_child(tv)
	v.add_child(cab)
	var bts := HBoxContainer.new()
	bts.add_theme_constant_override("separation", 3 * K)
	var serve := Estilo.botao(Txt.t("rush_serve"), abrir_servir)
	serve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	serve.size_flags_stretch_ratio = 1.4
	_aviso_auto = Estilo.botao("", func() -> void: Jogo.resolver_rush_auto())
	_aviso_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bts.add_child(serve)
	bts.add_child(_aviso_auto)
	v.add_child(bts)
	_aviso.hide()
	add_child(_aviso)

func _atualizar_aviso_rush() -> void:
	var r: Dictionary = Jogo.rush_atual
	var mostrar := not r.is_empty() and String(r.status) == "aguardando" and _minigame == null and not em_evento
	_aviso.visible = mostrar
	if not mostrar:
		return
	var def := Jogo.rush_def(String(r.id))
	_aviso_titulo.text = Txt.t("rush_" + String(r.id))
	_aviso_sub.text = Txt.t("rush_banner_sub", [int(r.clientes), Jogo.texto_hora_de(float(def.get("fim", 0.0)))])
	_aviso_auto.text = Txt.t("rush_auto", [int(round(Jogo.eficiencia_auto() * 100.0))])

# ---------------------------------------------------------------- mini-games (camada por cima do jogo)
func _abrir_camada(no: Control) -> void:
	fechar_gaveta()
	Relogio.ativo = false              # o tempo de jogo para enquanto o mini-game está aberto
	_minigame = CanvasLayer.new()
	_minigame.layer = 30
	_minigame.add_child(no)
	add_child(_minigame)
	no.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sujo = true

func _fechar_minigame() -> void:
	if _minigame != null and is_instance_valid(_minigame):
		_minigame.queue_free()
	_minigame = null
	if Jogo.primeira_vez_feita:
		Relogio.ativo = true
	Salvar.salvar()
	_sujo = true

func abrir_servir() -> void:
	if _minigame != null or Jogo.rush_atual.is_empty():
		return
	var r := Jogo.jogar_rush()
	var mg: Control = (load("res://scripts/minigames/servir.gd") as GDScript).new()
	mg.configurar({"titulo": Txt.t("rush_" + String(r.id)), "clientes": int(r.clientes), "cardapio": Jogo.cardapio()})
	mg.rush_done.connect(func(res: Dictionary) -> void: Jogo.aplicar_rush(res, "player"))
	mg.closed.connect(_fechar_minigame)
	_abrir_camada(mg)

## Cozinhar um prato (gasta as provisões ao começar). `voltar` = reabrir a gaveta da cozinha ao terminar.
func abrir_cozinhar(id: String, voltar := true) -> void:
	if _minigame != null or not Jogo.iniciar_fornada(id):
		return
	var idx := Jogo.ORDEM_PRATOS.find(id)
	var cz: Control = (load("res://scripts/minigames/cozinhar.gd") as GDScript).new()
	cz.game_mode = true
	cz.dish_done.connect(func(estrelas: int, _acc: float) -> void:
		var n := Jogo.terminar_fornada(id, estrelas)
		cz.set_result_note(Txt.t("mg_portions", [n, Jogo.porcoes(id), Jogo.cap_prato()]))
		cz.can_again = Jogo.motivo_nao_cozinha(id).is_empty())
	cz.again.connect(func() -> void:
		if Jogo.iniciar_fornada(id):
			cz.start_dish(idx))
	cz.closed.connect(func() -> void:
		_fechar_minigame()
		if voltar and _abas.has("guilda"):
			_abas.guilda.abrir_cozinha())
	_abrir_camada(cz)
	cz.start_dish(idx)

func _ao_resolver_rush(resumo: Dictionary) -> void:
	if Jogo._coletando:                     # rushes da ausência já aparecem no resumo "Enquanto você esteve fora"
		return
	var nome := Txt.t("rush_" + String(resumo.id))
	var total := int(resumo.moedas) + int(resumo.gorjetas)
	match String(resumo.modo):
		"server":
			toast(Txt.t("toast_rush_auto_server", [nome, String(Jogo.funcionarios.get("server", {}).get("nome", "")),
				int(resumo.servidos), int(resumo.clientes), total]))
		"mira":
			toast(Txt.t("toast_rush_auto_mira", [nome, int(resumo.servidos), int(resumo.clientes), total]))

## Aviso curto abaixo da placa do dia (some em 4 s).
func toast(texto: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Estilo.caixa_9("metal_9slice", 6, Vector4(6, 4, 6, 4)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Estilo.rotulo_px(texto, "t3", Estilo.COR_TEXTO, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
