## Caixa de diálogo com limitador de linhas, páginas, digitação e indicador animado.
## Cena sugerida:
##   CaixaDialogo (Control, este script)
##     Janela (NinePatchRect: janela_dialogo_9slice.png, patch_margin 13)
##     Placa (NinePatchRect: placa_nome.png) / Nome (Label)
##     Texto (Label: fonte SnideAsidesPT 16, autowrap OFF, clip_text ON) — dentro da área segura
##     Seta (TextureRect: seta_continuar.png)
##     Fim (TextureRect: quadradinho de fim)
## Toque/clique em QUALQUER lugar da tela avança (usa _unhandled_input).
extends Control

signal terminou

@export var max_linhas := 3
@export var letras_por_segundo := 45.0
@export var quique := PackedInt32Array([0, 0, 1, 2, 2, 1])   # px que a seta desce, quadro a quadro
@export var escala := 1.0            # px do canvas por px nativo (a cena monta tudo já ampliado em escala inteira)
@export var fechar_no_fim := true    # false: a última página só emite `terminou` (a cena chama fechar() depois)
@export var folga_inclinacao := 3.0  # px nativos descontados da largura na paginação (a cursiva inclina para a direita)

@onready var janela: NinePatchRect = $Janela
@onready var placa: Control = $Placa
@onready var texto: Label = $Texto
@onready var nome: Label = $Nome
@onready var seta: TextureRect = $Seta
@onready var fim: TextureRect = $Fim

var _paginas: PackedStringArray = []
var _pagina := 0
var _mostrado := 0.0
var _total := 0
var _t := 0.0
var _seta_y := 0.0
var _janela_rect := Rect2()
var _placa_y := 0.0
var _abrindo := false

func _ready() -> void:
	_seta_y = seta.position.y
	_janela_rect = Rect2(janela.position, janela.size)
	_placa_y = placa.position.y
	hide()

func falar(quem: String, conteudo: String) -> void:
	nome.text = quem
	_paginas = _paginar(conteudo)
	_pagina = 0
	if not visible:
		show()
		await _animar_abrir()
	_abrir_pagina()

## Fecha a janela (quando fechar_no_fim = false).
func fechar() -> void:
	if visible:
		await _animar_fechar()

func _paginar(conteudo: String) -> PackedStringArray:
	## Quebra por palavra medindo a largura REAL (fonte e tamanho do próprio Label) e agrupa em páginas de
	## max_linhas. Largura útil = largura do Label (já descontadas as margens internas da janela) − folga
	## para a inclinação da cursiva. Palavra maior que a linha é partida letra a letra. Nunca passa da janela.
	var fonte := texto.get_theme_font("font")
	var tam := texto.get_theme_font_size("font_size")
	var largura := texto.size.x - folga_inclinacao * escala
	var cabe := func(s: String) -> bool:
		return fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= largura
	var linhas: PackedStringArray = []
	for paragrafo in conteudo.split("\n"):
		var linha := ""
		for palavra in paragrafo.split(" ", false):
			var tentativa := palavra if linha.is_empty() else linha + " " + palavra
			if cabe.call(tentativa):
				linha = tentativa
				continue
			if not linha.is_empty():
				linhas.append(linha)
			linha = palavra
			while not cabe.call(linha):              # palavra sozinha não cabe: parte no limite
				var n := linha.length() - 1
				while n > 1 and not cabe.call(linha.substr(0, n)):
					n -= 1
				linhas.append(linha.substr(0, n))
				linha = linha.substr(n)
		linhas.append(linha)
	var paginas: PackedStringArray = []
	for i in range(0, linhas.size(), max_linhas):
		paginas.append("\n".join(linhas.slice(i, i + max_linhas)))
	return paginas

func _abrir_pagina() -> void:
	_abrindo = false
	texto.text = _paginas[_pagina]
	texto.visible_characters = 0
	_total = texto.get_total_character_count()
	_mostrado = 0.0
	_t = 0.0
	seta.hide()
	fim.hide()

func _process(delta: float) -> void:
	if not visible or _abrindo:
		return
	if _mostrado < _total:
		_mostrado = min(_mostrado + letras_por_segundo * delta, _total)
		texto.visible_characters = int(_mostrado)
		return
	_t += delta
	var ultima := _pagina == _paginas.size() - 1
	seta.visible = not ultima
	seta.position.y = _seta_y + quique[int(_t * 9.0) % quique.size()] * escala
	fim.visible = ultima and int(_t * 4.0) % 2 == 0

func _unhandled_input(evento: InputEvent) -> void:
	if not visible or _abrindo:
		return
	var toque: bool = (evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT) \
		or (evento is InputEventScreenTouch and evento.pressed)
	if toque:
		get_viewport().set_input_as_handled()
		_avancar()

func _avancar() -> void:
	if _mostrado < _total:            # 1º toque: completa a página
		_mostrado = _total
		texto.visible_characters = -1
	elif _pagina < _paginas.size() - 1:  # 2º toque: próxima página
		_pagina += 1
		_abrir_pagina()
	else:                             # última página: fecha (ou deixa a cena decidir)
		if fechar_no_fim:
			await _animar_fechar()
		else:
			_abrindo = true           # trava até a próxima fala
			seta.hide(); fim.hide()
		terminou.emit()

## Abre do centro com leve pulo. Anima o TAMANHO do NinePatchRect (não a escala): a corda continua nítida.
func _animar_abrir() -> void:
	_abrindo = true
	texto.text = ""; seta.hide(); fim.hide(); placa.hide()
	var c := _janela_rect.get_center()
	var ini := (Vector2(40, 16) * escala).round()
	janela.size = ini; janela.position = c - ini / 2; janela.modulate.a = 0.3
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(janela, "size", _janela_rect.size, 0.28)
	tw.tween_property(janela, "position", _janela_rect.position, 0.28)
	tw.tween_property(janela, "modulate:a", 1.0, 0.2)
	await tw.finished
	placa.position.y = _placa_y - 8 * escala; placa.show()      # placa cai no lugar
	var tp := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tp.tween_property(placa, "position:y", _placa_y, 0.18)
	await tp.finished
	_abrindo = false

func _animar_fechar() -> void:
	_abrindo = true
	texto.text = ""; seta.hide(); fim.hide(); placa.hide()
	var c := _janela_rect.get_center(); var fim_tam := (Vector2(40, 16) * escala).round()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(janela, "size", fim_tam, 0.18)
	tw.tween_property(janela, "position", c - fim_tam / 2, 0.18)
	tw.tween_property(janela, "modulate:a", 0.0, 0.18)
	await tw.finished
	hide()
	janela.size = _janela_rect.size; janela.position = _janela_rect.position; janela.modulate.a = 1.0
	_abrindo = false
