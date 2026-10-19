## Aba Guilda: vitrine (recepção + Mira interativa), resumo do dia e áreas da casa.
## Layout em px nativos ×4 (prévia aprovada: arte/ui/_tela_guilda.png).
extends AbaBase

const K := Estilo.K
const MIRA := "res://assets/personagens/mira/recortes/%s.png"
const FUNDO := "res://assets/conceito/recepcao_nivel%d.png"
const VW := 168                       # vitrine (px nativos)
const VH := 92
const BALAO_TXT_MAX := 60             # largura preferida do texto do balão (px nativos)
const BALAO_LINHAS := 6               # máx. de linhas (10 px cada) entre o topo da vitrine e o selo ABERTA
const BALAO_FOLGA_ROSTO := 4          # px nativos entre a ponta do rabicho e o cabelo/rosto da Mira

var _vitrine: Control
var _fundo: TextureRect
var _mira: TextureRect
var _balao: Control
var _balao_corpo: NinePatchRect
var _balao_rabicho: TextureRect
var _balao_texto: Label
var _placa_nome: NinePatchRect
var _chip: NinePatchRect
var _chip_txt: Label
var _toques: Array[float] = []
var _ignorar_ate := 0.0
var _ultima_expr := ""
var _versao_fala := 0
var _fala_fixa := ""

func montar() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 * K)
	add_child(v)
	var folga := Control.new()                      # a placa "Casa do Queixo" não encosta na placa do dia
	folga.custom_minimum_size = Vector2(0, 1 * K)
	v.add_child(folga)
	_montar_vitrine(v)
	criar_lista(v)
	lista.add_theme_constant_override("separation", 2 * K)

func _montar_vitrine(pai: Control) -> void:
	_vitrine = Control.new()
	_vitrine.custom_minimum_size = Vector2(VW * K, VH * K)
	pai.add_child(_vitrine)

	var janela := Control.new()                     # a imagem entra por baixo da moldura vazada
	janela.position = Vector2(4 * K, 4 * K)
	janela.size = Vector2((VW - 8) * K, (VH - 8) * K)
	janela.clip_contents = true
	janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitrine.add_child(janela)

	_fundo = TextureRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fundo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	janela.add_child(_fundo)

	# Mira à esquerda, até as mãos (base da imagem = base da vitrine), 98% da altura
	var alt := janela.size.y * 0.98
	_mira = TextureRect.new()
	_mira.texture = _retrato("01_neutra", alt)
	_mira.size = _mira.texture.get_size()
	_mira.position = Vector2(roundf(janela.size.x * 0.28 - _mira.size.x / 2.0), janela.size.y - _mira.size.y)
	_mira.mouse_filter = Control.MOUSE_FILTER_STOP
	_mira.gui_input.connect(_ao_tocar_mira)
	janela.add_child(_mira)

	var moldura := NinePatchRect.new()
	moldura.texture = Estilo.ui("moldura_vitrine")
	for lado in ["left", "top", "right", "bottom"]:
		moldura.set("patch_margin_" + lado, 8 * K)
	moldura.draw_center = false
	moldura.size = _vitrine.custom_minimum_size
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitrine.add_child(moldura)

	_placa_nome = Estilo.placa(Jogo.nome_da_guilda(), "l4", 13)
	_placa_nome.position = Vector2(8 * K, -5 * K)
	_vitrine.add_child(_placa_nome)

	_chip = NinePatchRect.new()                     # selo ABERTA / FECHADA — toque abre/fecha a guilda
	_chip.texture = Estilo.ui("chip_verde")
	for lado in ["left", "top", "right", "bottom"]:
		_chip.set("patch_margin_" + lado, 2 * K)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var alvo := Control.new()                       # área de toque 4 px maior que o selo em cada lado
	alvo.set_anchors_preset(Control.PRESET_FULL_RECT)
	alvo.offset_left = -4 * K; alvo.offset_top = -4 * K
	alvo.offset_right = 4 * K; alvo.offset_bottom = 4 * K
	alvo.mouse_filter = Control.MOUSE_FILTER_STOP
	alvo.gui_input.connect(func(e: InputEvent) -> void:
		if Estilo.e_toque(e):
			Jogo.guilda_aberta = not Jogo.guilda_aberta
			Jogo.mudou.emit())
	_chip.add_child(alvo)
	_chip_txt = Estilo.rotulo_px(Txt.t("open"), "m4", Color8(200, 255, 200))
	_chip_txt.position = Vector2(4 * K, 1 * K)      # letra em +2 (1 px de acento acima)
	_chip.add_child(_chip_txt)
	_vitrine.add_child(_chip)

	# balão simples: corpo 9-slice + rabicho à esquerda (contorno contínuo), nunca sobre o rosto
	_balao = Control.new()
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao_corpo = NinePatchRect.new()
	_balao_corpo.texture = Estilo.ui("balao_9slice")
	for lado in ["left", "top", "right", "bottom"]:
		_balao_corpo.set("patch_margin_" + lado, 6 * K)
	_balao.add_child(_balao_corpo)
	_balao_rabicho = TextureRect.new()
	_balao_rabicho.texture = Estilo.ui("balao_rabicho")
	_balao.add_child(_balao_rabicho)
	_balao_texto = Estilo.rotulo_px("", "l4", Estilo.COR_TINTA)
	_balao_texto.add_theme_constant_override("line_spacing", -2 * K)   # 10 px nativos por linha
	_balao.add_child(_balao_texto)
	_balao.hide()
	_vitrine.add_child(_balao)

## Retrato reduzido com Lanczos para a altura pedida (cache por expressão/altura).
static var _cache_retratos := {}
func _retrato(expr: String, altura: float) -> Texture2D:
	var chave := "%s@%d" % [expr, int(altura)]
	if not _cache_retratos.has(chave):
		var t := Estilo.textura(MIRA % expr)
		var img := t.get_image()
		var esc := altura / img.get_height()
		img.resize(int(img.get_width() * esc), int(altura), Image.INTERPOLATE_LANCZOS)
		_cache_retratos[chave] = ImageTexture.create_from_image(img)
	return _cache_retratos[chave]

func _quebrar(fala: String, maximo: int) -> PackedStringArray:
	var f := _balao_texto.get_theme_font("font")
	var tam := _balao_texto.get_theme_font_size("font_size")
	var linhas: PackedStringArray = []
	var linha := ""
	for p in fala.split(" ", false):
		var t := p if linha.is_empty() else linha + " " + p
		if not linha.is_empty() and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > maximo * K:
			linhas.append(linha)
			linha = p
		else:
			linha = t
	linhas.append(linha)
	return linhas

## Borda direita da cabeça da Mira (px nativos, coordenadas da vitrine): pixel opaco mais à direita nas
## linhas da cabeça (40% de cima do retrato). O balão (com rabicho) nunca passa daqui para a esquerda.
var _rosto_dir := -1.0
func _limite_rosto() -> float:
	if _rosto_dir < 0.0:
		var img := Estilo.textura(MIRA % "01_neutra").get_image()
		if img.is_compressed():
			img.decompress()
		var mx := 0
		for y in range(0, int(img.get_height() * 0.4), 4):
			for x in range(img.get_width() - 1, mx, -1):
				if img.get_pixel(x, y).a > 0.5:
					mx = x
					break
		var esc := _mira.size.x / img.get_width()
		_rosto_dir = 4.0 + (_mira.position.x + mx * esc) / K       # janela começa 4 px dentro da vitrine
	return _rosto_dir

func _mostrar_balao(fala: String) -> void:
	var f := _balao_texto.get_theme_font("font")
	var tam := _balao_texto.get_theme_font_size("font_size")
	# largura máxima: do rosto (+ folga + rabicho 8 px) até 10 px antes da borda direita da vitrine
	var esq_min := ceili(_limite_rosto()) + BALAO_FOLGA_ROSTO + 8
	var txt_max := (VW - 10 - esq_min) - 11
	var linhas := _quebrar(fala, mini(BALAO_TXT_MAX, txt_max))
	if linhas.size() > 4 and txt_max > BALAO_TXT_MAX:  # texto longo: alarga só até o limite do rosto
		linhas = _quebrar(fala, txt_max)
	if linhas.size() > BALAO_LINHAS:                    # salvaguarda: corta com reticências
		linhas = linhas.slice(0, BALAO_LINHAS)
		var ultima := linhas[BALAO_LINHAS - 1]
		while ultima.length() > 1 and f.get_string_size(ultima + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > txt_max * K:
			ultima = ultima.substr(0, ultima.length() - 1)
		linhas[BALAO_LINHAS - 1] = ultima.strip_edges() + "..."
	var larg := 0.0
	for l in linhas:
		larg = maxf(larg, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
	var bw := ceili(larg / K) + 11                 # 6 px de cada lado (a fonte já soma 1 de espaço)
	var bh := linhas.size() * 10 - 3 + 10
	_balao_texto.text = "\n".join(linhas)
	_balao_texto.position = Vector2(6 * K, 3 * K)  # letra a 5 px do topo
	_balao_texto.size = Vector2(bw * K, bh * K)
	_balao_corpo.size = Vector2(bw * K, bh * K)
	_balao_rabicho.position = Vector2(-8 * K, (bh / 2 - 5) * K)
	# entre o topo da vitrine (6) e o selo ABERTA/FECHADA (VH − 14, com 2 px de folga)
	_balao.position = Vector2((VW - bw - 10) * K, clampi(VH - 16 - bh, 6, 22) * K)
	_balao.show()

func atualizar() -> void:
	_fundo.texture = Estilo.textura(FUNDO % clampi(Jogo.nivel_recepcao, 1, 4))
	if (_placa_nome.get_node("Texto") as Label).text != Jogo.nome_da_guilda():
		Estilo.ajustar_placa(_placa_nome, Jogo.nome_da_guilda())
	_chip.texture = Estilo.ui("chip_verde" if Jogo.guilda_aberta else "chip_vermelho")
	_chip_txt.text = Txt.t("open") if Jogo.guilda_aberta else Txt.t("closed")
	_chip_txt.add_theme_color_override("font_color", Color8(200, 255, 200) if Jogo.guilda_aberta else Color8(255, 200, 190))
	var cw := ceili(_chip_txt.get_minimum_size().x / K) + 7
	_chip.size = Vector2(cw * K, 9 * K)
	_chip.position = Vector2((VW - cw - 8) * K, (VH - 14) * K)
	# balão fixo com o aviso mais urgente (toques na Mira mostram reações por 3 s)
	var alertas := Jogo.alertas()
	_fala_fixa = String(alertas[0].texto) if not alertas.is_empty() else ""
	if _versao_fala == 0 or not _balao.visible:
		if _fala_fixa.is_empty():
			_balao.hide()
		else:
			_mostrar_balao(_fala_fixa)
	var rolar := rolagem.scroll_vertical
	Estilo.limpar(lista)
	_montar_resumo()
	var t := titulo(Txt.t("areas_title"))
	lista.add_child(t)
	var n_cand := Jogo.candidatos.size()
	var sub_rec := Txt.t("area_reception_sub", [n_cand]) if n_cand > 0 else Txt.t("area_reception_none")
	if Jogo.funcionarios.has("receptionist"):
		sub_rec = Txt.t("area_reception_staff", [Jogo.funcionarios.receptionist.nome, n_cand])
	_area(Txt.t("area_reception"), "guilda", sub_rec, n_cand, _gaveta_recepcao)
	_area(Txt.t("area_hall"), "conforto", Txt.t("area_hall_sub", [int(Jogo.conforto()), Jogo.assentos()]), 0, _gaveta_salao)
	var poucos := 1 if Jogo.total_porcoes() < 6 else 0
	_area(Txt.t("area_kitchen"), "pratos", Txt.t("area_kitchen_sub", [Jogo.nivel_cozinha, Jogo.total_porcoes()]), poucos, _gaveta_cozinha,
		clampf(Jogo.total_porcoes() / 24.0, 0.0, 1.0))
	var falta := Jogo.provisoes < 4.0 and not Jogo.auto_encomenda
	var sub_pan := Txt.t("area_pantry_sub_auto" if Jogo.auto_encomenda else "area_pantry_sub", [int(Jogo.provisoes), Jogo.cap_provisoes()])
	_area(Txt.t("area_pantry"), "provisoes", sub_pan, 1 if falta else 0, _gaveta_despensa, Jogo.provisoes / maxf(1.0, Jogo.cap_provisoes()))
	if Jogo.tem_melhoria("selo"):
		var n_st := Jogo.funcionarios.size()
		var novo := 0
		for f in Jogo.ORDEM_FUNCOES:
			if Jogo.funcao_destravada(f) and not Jogo.funcionarios.has(f) and n_st == 0:
				novo = 1
		_area(Txt.t("area_staff"), "aventureiros", Txt.t("area_staff_sub", [n_st, Jogo.salarios_dia()]) if n_st > 0 else Txt.t("area_staff_none"),
			novo, _gaveta_staff)
	else:
		_area(Txt.t("area_staff"), "aventureiros", Txt.t("area_locked_seal"), 0, Callable(), -1.0, true)
	_area_trancavel("quartos", Txt.t("area_rooms"), "descanso", 2, Txt.t("area_rooms_sub", [Jogo.ALUGUEL_QUARTO]), _gaveta_quartos)
	_area_trancavel("forja", Txt.t("area_forge"), "melhorias", 3, Txt.t("area_forge_sub"), _gaveta_forja)
	rolagem.set_deferred("scroll_vertical", rolar)

func _montar_resumo() -> void:
	var p := Control.new()
	p.custom_minimum_size = Vector2(VW * K, 31 * K)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := NinePatchRect.new()
	fundo.texture = Estilo.ui("metal_9slice")
	for lado in ["left", "top", "right", "bottom"]:
		fundo.set("patch_margin_" + lado, 6 * K)
	fundo.size = p.custom_minimum_size
	p.add_child(fundo)
	var cols := [
		["moedas", "%+d" % Jogo.renda_dia, "sum_income", Estilo.COR_VERDE if Jogo.renda_dia > 0 else Estilo.COR_TEXTO],
		["aventureiros", "%d/%d" % [Jogo.contar("na_casa"), Jogo.capacidade()], "sum_home", Estilo.COR_TEXTO],
		["contratos", str(Jogo.contar("em_missao")), "sum_mission", Estilo.COR_TEXTO],
		["conforto", str(int(Jogo.conforto())), "sum_comfort", Estilo.COR_TEXTO],
	]
	var cw := VW / 4
	for i in cols.size():
		var c: Array = cols[i]
		var x := i * cw
		var ic := Estilo.icone_rect(String(c[0]), 18, 2)
		ic.position = Vector2((x + 4) * K, 6 * K)
		ic.size = ic.custom_minimum_size
		p.add_child(ic)
		var v := Estilo.rotulo_px(String(c[1]), "t4", c[3])
		v.position = Vector2((x + 15) * K, 5 * K)
		p.add_child(v)
		var r := Estilo.rotulo_px(Txt.t(String(c[2])), "m4", Color8(160, 150, 140))
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.position = Vector2(x * K, 18 * K)
		r.size = Vector2(cw * K, 8 * K)
		p.add_child(r)
	lista.add_child(p)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 1 * K)
	lista.add_child(gap)

## Linha de área (25 px nativos): ícone 12, nome técnica, info mini, alerta numerado, seta / cadeado, barra opcional.
func _area(nome: String, icone: String, sub: String, alerta: int, gaveta: Callable, barra := -1.0, trancada := false) -> void:
	var abrir := func() -> void:
		principal.abrir_gaveta(nome, gaveta)
	var c := Control.new()
	c.custom_minimum_size = Vector2(VW * K, 25 * K)
	if not trancada:
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(func(e: InputEvent) -> void:
			if Estilo.e_clique(e, c):
				abrir.call())
	var fundo := NinePatchRect.new()
	fundo.texture = Estilo.ui("metal_9slice")
	for lado in ["left", "top", "right", "bottom"]:
		fundo.set("patch_margin_" + lado, 6 * K)
	fundo.size = c.custom_minimum_size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if trancada:
		fundo.modulate.a = 0.75
	c.add_child(fundo)
	var ic := Estilo.icone_rect(icone, 24, 2)
	ic.position = Vector2(5 * K, 6 * K)
	ic.size = ic.custom_minimum_size
	if trancada:
		ic.material = Estilo.material_cinza()
	c.add_child(ic)
	var n := Estilo.rotulo_px(nome, "t4", Estilo.COR_FRACO if trancada else Estilo.COR_TEXTO)
	n.position = Vector2(23 * K, 4 * K)
	c.add_child(n)
	var s := Estilo.rotulo_px(sub, "m4", Color8(130, 120, 110) if trancada else Estilo.COR_SUB)
	s.position = Vector2(23 * K, 15 * K)
	s.clip_text = true
	s.size = Vector2((VW - 23 - 24) * K, 8 * K)
	c.add_child(s)
	var dir := TextureRect.new()
	dir.texture = _tex_cadeado() if trancada else _tex_seta()
	dir.size = dir.texture.get_size()
	dir.position = Vector2((VW - 17) * K, (6 if trancada else 9) * K) if not trancada else Vector2((VW - 22) * K, 6 * K)
	dir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dir)
	if alerta > 0:
		var b := TextureRect.new()
		b.texture = _tex_alerta()
		b.size = b.texture.get_size()
		b.position = Vector2((VW - 30) * K, 8 * K)
		c.add_child(b)
		var bl := Estilo.rotulo_px(str(alerta) if alerta < 10 else "!", "m4", Estilo.COR_TEXTO)
		bl.position = Vector2((VW - 27) * K, 9 * K)
		c.add_child(bl)
	if barra >= 0.0:                               # na linha do nome (a linha de baixo é do texto mini)
		var bx := VW - 66
		var trilho := ColorRect.new()
		trilho.color = Color8(20, 14, 16)
		trilho.position = Vector2(bx * K, 7 * K)
		trilho.size = Vector2(34 * K, 3 * K)
		c.add_child(trilho)
		var cheio := ColorRect.new()
		cheio.color = Estilo.COR_VERMELHO if barra < 0.35 else Color8(230, 180, 70)
		cheio.position = Vector2((bx + 1) * K, 8 * K)
		cheio.size = Vector2(maxi(1, roundi(32 * clampf(barra, 0.0, 1.0))) * K, 1 * K)
		c.add_child(cheio)
	lista.add_child(c)

func _area_trancavel(id: String, nome: String, icone: String, fama_nv: int, sub: String, gaveta: Callable) -> void:
	if Jogo.tem_melhoria(id):
		_area(nome, icone, sub, 0, gaveta)
		return
	var motivo := Txt.t("area_locked_fame", [fama_nv]) if Jogo.nivel_fama() < fama_nv else Txt.t("area_locked_build")
	_area(nome, icone, motivo, 0, Callable(), -1.0, true)

# ---------------------------------------------------------------- texturas pequenas (px nativos ×4)
static var _tex := {}
func _tex_px(chave: String, mapa: Array, cores: Dictionary) -> Texture2D:
	if not _tex.has(chave):
		var img := Image.create(String(mapa[0]).length(), mapa.size(), false, Image.FORMAT_RGBA8)
		for y in mapa.size():
			var linha := String(mapa[y])
			for x in linha.length():
				if cores.has(linha[x]):
					img.set_pixel(x, y, cores[linha[x]])
		img.resize(img.get_width() * K, img.get_height() * K, Image.INTERPOLATE_NEAREST)
		_tex[chave] = ImageTexture.create_from_image(img)
	return _tex[chave]

func _tex_seta() -> Texture2D:
	return _tex_px("seta", ["G....", "GGG..", "GGGG.", "GGGGG", "GGGG.", "GGG..", "G...."],
		{"G": Estilo.COR_DOURADO})

func _tex_cadeado() -> Texture2D:
	var o := Color8(28, 18, 16)
	return _tex_px("cadeado", ["..OOOO..", ".O....O.", ".O....O.", ".O....O.", "OOOOOOOO", "OMMMMMMO", "OMMOOMMO", "OMMMMMMO", "OMMMMMMO", "OOOOOOOO"],
		{"O": o, "M": Color8(150, 140, 120)})

func _tex_alerta() -> Texture2D:
	return _tex_px("alerta", ["..OOOOO..", ".ORRRRRO.", "ORRRRRRRO", "ORRRRRRRO", "ORRRRRRRO", "ORRRRRRRO", "ORRRRRRRO", ".ORRRRRO.", "..OOOOO.."],
		{"O": Color8(28, 18, 16), "R": Color8(214, 38, 30)})

# ---------------------------------------------------------------- gavetas
func abrir_cozinha() -> void:
	principal.abrir_gaveta(Txt.t("area_kitchen"), _gaveta_cozinha)

## Linha com emblema de classe (64 px) + textos à direita.
func _linha_heroi(a: Dictionary, titulo_txt: String) -> HBoxContainer:
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 3 * K)
	cab.add_child(Estilo.emblema_rect(String(a.get("classe", "warrior")), 64))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Estilo.rotulo(titulo_txt, 24, Estilo.COR_TEXTO, true))
	info.add_child(Estilo.rotulo(Txt.t("rec_class_race", [Jogo.nome_classe(a), Jogo.descricao_raca(a)]), 18, Estilo.COR_FRACO, true))
	cab.add_child(info)
	return cab

func _gaveta_recepcao(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.rotulo(Txt.t("rec_slots", [Jogo.vivos(), Jogo.capacidade()]), 20, Estilo.COR_FRACO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("rec_rate", [Jogo.taxa_candidatos() * 16.0, int(Jogo.satisfacao)]), 18, Estilo.COR_FRACO, true))
	if Jogo.candidatos.is_empty():
		corpo.add_child(Estilo.rotulo(Txt.t("rec_empty"), 20, Estilo.COR_FRACO, true))
	var cheio := Jogo.vivos() >= Jogo.capacidade()
	for c in Jogo.candidatos:
		var id := int(c.id)
		var p := Estilo.painel(Estilo.COR_PAINEL_CLARO)
		var v := VBoxContainer.new()
		v.add_child(_linha_heroi(c, Txt.t("rec_cand", [c.nome, int(c.nivel)])))
		var at: Dictionary = c.get("atrib", {})
		v.add_child(Estilo.rotulo(Txt.t("hero_stats", [int(at.get("might", 0)), int(at.get("wits", 0)), int(at.get("grit", 0)),
			int(Jogo.poder_heroi(c))]), 16, Estilo.COR_SUB, true))
		var bts := HBoxContainer.new()
		var f_ac := func() -> void:
			Jogo.aceitar_candidato(id)
			principal.atualizar_gaveta()
		var ac := Estilo.botao(Txt.t("btn_accept"), f_ac, not cheio)
		ac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var f_rc := func() -> void:
			Jogo.recusar_candidato(id)
			principal.atualizar_gaveta()
		var rc := Estilo.botao(Txt.t("btn_refuse"), f_rc)
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bts.add_child(ac); bts.add_child(rc)
		v.add_child(bts)
		p.add_child(v)
		corpo.add_child(p)
	if cheio and not Jogo.candidatos.is_empty():
		corpo.add_child(Estilo.rotulo(Txt.t("rec_full"), 18, Estilo.COR_LARANJA, true))

func _gaveta_salao(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.linha_icone("conforto", Txt.t("hall_comfort", [Jogo.conforto()])))
	corpo.add_child(Estilo.linha_icone("moral", Txt.t("hall_satisfaction", [int(Jogo.satisfacao)])))
	corpo.add_child(Estilo.rotulo(Txt.t("hall_seats", [Jogo.assentos()]), 18, Estilo.COR_FRACO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("hall_decor"), 18, Estilo.COR_FRACO, true))
	var cont := {}
	for d in Jogo.decoracoes:
		cont[d] = int(cont.get(d, 0)) + 1
	for d in cont:
		corpo.add_child(Estilo.rotulo("• %s ×%d" % [Jogo.DECORACOES[d].nome, cont[d]], 20, Estilo.COR_TEXTO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("hall_home"), 20, Estilo.COR_DOURADO))
	for a in Jogo.aventureiros:
		if String(a.estado) == "na_casa" or String(a.estado) == "ferido":
			corpo.add_child(Estilo.rotulo(Txt.t("hall_hero", [a.nome, int(Jogo.moral_efetiva(a)),
				Txt.t("hall_wounded") if String(a.estado) == "ferido" else ""]), 20, Estilo.COR_TEXTO, true))

## Texto do buff de um prato: "Might +18%, Grit +10%".
static func texto_buff(id: String) -> String:
	var partes: Array = []
	var buff: Dictionary = Jogo.PRATOS[id].buff
	for s in Jogo.ATRIBUTOS:
		if buff.has(s):
			partes.append("%s +%d%%" % [Txt.t("stat_" + s), int(round(float(buff[s]) * 100.0))])
	return ", ".join(PackedStringArray(partes))

func _gaveta_cozinha(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.linha_icone("provisoes", Txt.t("kit_provisions", [int(Jogo.provisoes), Jogo.cap_provisoes()])))
	corpo.add_child(Estilo.rotulo(Txt.t("kit_help"), 16, Estilo.COR_FRACO, true))
	if Jogo.funcionarios.has("cook"):
		var st: Dictionary = Jogo.funcionarios.cook
		var hab := int(st.habilidade)
		var q := Txt.t("kit_stars_1") if hab <= 1 else (Txt.t("kit_stars_2") if hab >= 3 else Txt.t("kit_stars_12"))
		corpo.add_child(Estilo.rotulo(Txt.t("kit_cook_hired", [st.nome, q]), 16, Estilo.COR_VERDE, true))
	for id in Jogo.ORDEM_PRATOS:
		var dest := Jogo.prato_destravado(id)
		var p := Estilo.painel(Estilo.COR_PAINEL_CLARO if dest else Estilo.COR_PAINEL_ESCURO)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3 * K)
		var ic := Estilo.prato_rect(id, 2)
		if not dest:
			ic.material = Estilo.material_cinza()
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 1 * K)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var linha := HBoxContainer.new()
		var nm := Estilo.rotulo(Txt.t("dish_" + id), 22, Estilo.COR_TEXTO if dest else Estilo.COR_FRACO, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nm)
		linha.add_child(Estilo.rotulo(Txt.t("kit_stock", [Jogo.porcoes(id), Jogo.cap_prato()]), 22,
			Estilo.COR_VERMELHO if Jogo.porcoes(id) == 0 and dest else Estilo.COR_OURO))
		info.add_child(linha)
		if Jogo.porcoes(id) > 0:
			info.add_child(Estilo.estrelas(Jogo.qualidade(id), 18, 2))
		info.add_child(Estilo.rotulo(Txt.t("kit_batch", [Jogo.provisoes_por_lote(id), Jogo.porcoes_lote(id, 2), Jogo.preco_porcao(id)]),
			16, Estilo.COR_SUB, true))
		info.add_child(Estilo.rotulo(Txt.t("kit_buff", [texto_buff(id), int(Jogo.PRATOS[id].horas)]), 16, Estilo.COR_FRACO, true))
		var motivo := Jogo.motivo_nao_cozinha(id)
		var rot := Txt.t("kit_cook")
		match motivo:
			"locked":
				var pr: Dictionary = Jogo.PRATOS[id]
				rot = Txt.t("kit_locked_kitchen", [int(pr.cozinha)]) if Jogo.nivel_cozinha < int(pr.cozinha) else Txt.t("kit_locked_fame", [int(pr.fama_nv)])
			"full":
				rot = Txt.t("kit_full")
			"provisions":
				rot = Txt.t("kit_no_prov")
		var pid: String = id
		var b := Estilo.botao(rot, func() -> void: principal.abrir_cozinhar(pid), motivo.is_empty())
		info.add_child(b)
		h.add_child(info)
		p.add_child(h)
		corpo.add_child(p)

func _gaveta_despensa(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.linha_icone("provisoes", Txt.t("pan_provisions", [int(Jogo.provisoes), Jogo.cap_provisoes()])))
	corpo.add_child(Estilo.linha_icone("moedas", Txt.t("pan_coins", [Jogo.moedas])))
	corpo.add_child(Estilo.rotulo(Txt.t("pan_price", [Jogo.CUSTO_PROVISAO]), 16, Estilo.COR_FRACO, true))
	var h := HBoxContainer.new()
	for q in [5, 10, 20]:
		var qtd: int = q
		var f := func() -> void:
			Jogo.comprar_provisoes(qtd)
			principal.atualizar_gaveta()
		var b := Estilo.botao(Txt.t("pan_buy", [qtd, qtd * Jogo.CUSTO_PROVISAO]), f,
			Jogo.moedas >= qtd * Jogo.CUSTO_PROVISAO and Jogo.provisoes + qtd <= Jogo.cap_provisoes())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	corpo.add_child(h)
	var auto := CheckButton.new()
	auto.text = Txt.t("pan_auto")
	auto.button_pressed = Jogo.auto_encomenda
	auto.custom_minimum_size = Vector2(0, 16 * K)
	auto.toggled.connect(func(ligado: bool) -> void:
		Jogo.auto_encomenda = ligado
		Jogo.mudou.emit())
	corpo.add_child(auto)
	corpo.add_child(Estilo.rotulo(Txt.t("pan_auto_help", [Jogo.custo_encomenda(4), 4]), 16, Estilo.COR_FRACO, true))

## Pips de habilidade 1–3 (estrelas de fama 18 px).
func _gaveta_staff(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.rotulo(Txt.t("staff_help"), 16, Estilo.COR_FRACO, true))
	for f in Jogo.ORDEM_FUNCOES:
		var p := Estilo.painel(Estilo.COR_PAINEL_CLARO if Jogo.funcao_destravada(f) else Estilo.COR_PAINEL_ESCURO)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1 * K)
		var cab := HBoxContainer.new()
		var nm := Estilo.rotulo(Txt.t("role_" + f), 24, Estilo.COR_DOURADO)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cab.add_child(nm)
		v.add_child(cab)
		var desc := Txt.t("role_%s_desc" % f)
		if f == "server":
			var hab_s := int(Jogo.funcionarios.get("server", Jogo.candidatos_staff.get("server", {"habilidade": 1})).habilidade)
			desc = Txt.t("role_server_desc", [int(round((0.70 + 0.075 * (hab_s - 1)) * 100.0))])
		v.add_child(Estilo.rotulo(desc, 16, Estilo.COR_FRACO, true))
		var fid: String = f
		if Jogo.funcionarios.has(f):
			var st: Dictionary = Jogo.funcionarios[f]
			var h := HBoxContainer.new()
			var l := Estilo.rotulo(Txt.t("staff_hired", [st.nome, int(st.habilidade), int(st.salario)]), 20, Estilo.COR_VERDE, true)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(l)
			var f_dem := func() -> void:
				Jogo.demitir(fid)
				principal.atualizar_gaveta()
			var b := Estilo.botao(Txt.t("staff_fire"), f_dem)
			b.custom_minimum_size.x = 150
			h.add_child(b)
			v.add_child(h)
			if f == "receptionist":
				_filtros(v)
		elif not Jogo.tem_melhoria("selo"):
			v.add_child(Estilo.rotulo(Txt.t("staff_locked_seal"), 18, Estilo.COR_LARANJA, true))
		elif not Jogo.funcao_destravada(f):
			v.add_child(Estilo.rotulo(Txt.t("staff_locked_fame", [int(Jogo.FUNCOES[f].fama_nv)]), 18, Estilo.COR_LARANJA, true))
		elif Jogo.candidatos_staff.has(f):
			var c: Dictionary = Jogo.candidatos_staff[f]
			var h2 := HBoxContainer.new()
			var l2 := Estilo.rotulo(Txt.t("staff_applicant", [c.nome, int(c.habilidade), int(c.salario)]), 20, Estilo.COR_TEXTO, true)
			l2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h2.add_child(l2)
			var f_con := func() -> void:
				Jogo.contratar(fid)
				principal.atualizar_gaveta()
			var b2 := Estilo.botao(Txt.t("staff_fee", [int(c.taxa)]), f_con, Jogo.moedas >= int(c.taxa))
			b2.custom_minimum_size.x = 210
			h2.add_child(b2)
			v.add_child(h2)
		p.add_child(v)
		corpo.add_child(p)

## Filtros de admissão da recepcionista: nível mínimo, classes (emblemas) e raças.
func _filtros(v: VBoxContainer) -> void:
	v.add_child(Estilo.rotulo(Txt.t("filter_title"), 20, Estilo.COR_DOURADO))
	var hn := HBoxContainer.new()
	var nv := int(Jogo.filtro.get("nivel_min", 1))
	var ln := Estilo.rotulo(Txt.t("filter_level", [nv]), 20, Estilo.COR_TEXTO, true)
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hn.add_child(ln)
	for d in [-1, 1]:
		var delta: int = d
		var f_nv := func() -> void:
			Jogo.filtro.nivel_min = clampi(int(Jogo.filtro.get("nivel_min", 1)) + delta, 1, 5)
			principal.atualizar_gaveta()
		var b := Estilo.botao("−" if d < 0 else "+", f_nv, (nv > 1) if d < 0 else (nv < 5))
		b.custom_minimum_size.x = 72
		hn.add_child(b)
	v.add_child(hn)
	v.add_child(Estilo.rotulo(Txt.t("filter_classes"), 18, Estilo.COR_FRACO))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 1 * K)
	for cl in Jogo.CLASSES:
		var classe: String = cl
		var on := bool(Jogo.filtro.classes.get(classe, true))
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = on
		b.custom_minimum_size = Vector2(22 * K, 22 * K)
		b.focus_mode = Control.FOCUS_NONE
		var em := Estilo.emblema_rect(classe, 64)
		em.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		em.offset_left = 3 * K; em.offset_top = 3 * K; em.offset_right = -3 * K; em.offset_bottom = -3 * K
		if not on:                                   # desligada = emblema apagado
			em.material = Estilo.material_cinza()
		b.add_child(em)
		b.toggled.connect(func(lig: bool) -> void:
			Jogo.filtro.classes[classe] = lig
			principal.atualizar_gaveta())
		g.add_child(b)
	v.add_child(g)
	v.add_child(Estilo.rotulo(Txt.t("filter_races"), 18, Estilo.COR_FRACO))
	var hr := HBoxContainer.new()
	for r in Jogo.RACAS:
		var raca: String = r
		var cb := Button.new()
		cb.toggle_mode = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = raca
		cb.button_pressed = bool(Jogo.filtro.racas.get(raca, true))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 16 * K)
		cb.toggled.connect(func(lig: bool) -> void:
			Jogo.filtro.racas[raca] = lig)
		hr.add_child(cb)
	v.add_child(hr)

func _gaveta_quartos(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.rotulo(Txt.t("rooms_help", [Jogo.ALUGUEL_QUARTO]), 20, Estilo.COR_TEXTO, true))
	for a in Jogo.aventureiros:
		if String(a.estado) == "na_casa":
			var h := HBoxContainer.new()
			h.add_child(Estilo.emblema_rect(String(a.get("classe", "warrior")), 64))
			var l := Estilo.rotulo(String(a.nome), 20)
			l.custom_minimum_size.x = 180
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(l)
			h.add_child(Estilo.barra(a.descanso, 100.0, Estilo.COR_VERDE))
			corpo.add_child(h)

func _gaveta_forja(corpo: VBoxContainer) -> void:
	corpo.add_child(Estilo.rotulo(Txt.t("forge_help"), 20, Estilo.COR_TEXTO, true))
	var pode := Jogo.pode_pagar(Jogo.CUSTO_FORJA)
	for a in Jogo.aventureiros:
		if String(a.estado) != "na_casa":
			continue
		var id := int(a.id)
		var f_eq := func() -> void:
			Jogo.melhorar_equipamento(id)
			principal.atualizar_gaveta()
		var h := HBoxContainer.new()
		h.add_child(Estilo.emblema_rect(String(a.get("classe", "warrior")), 64))
		var b := Estilo.botao(Txt.t("forge_hero", [a.nome, int(a.equip)]), f_eq, pode)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		corpo.add_child(h)

# ---------------------------------------------------------------- Mira
func _ao_tocar_mira(evento: InputEvent) -> void:
	if not Estilo.e_toque(evento):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if agora < _ignorar_ate:
		return
	_toques.append(agora)
	while not _toques.is_empty() and agora - _toques[0] > 3.0:
		_toques.pop_front()
	if _toques.size() >= 4:            # paciência esgotada
		_toques.clear()
		_ignorar_ate = agora + 5.0
		_reagir("05_brava", Txt.t("mira_busy"))
		return
	var mb := evento as InputEventMouseButton
	var na_cabeca := mb.position.y < _mira.size.y * 0.28
	if na_cabeca:
		var opcoes := ["08_envergonhada", "02_feliz"]
		_reagir(_sem_repetir(opcoes), Txt.t(["mira_pat1", "mira_pat2"].pick_random()))
		return
	var alertas := Jogo.alertas()
	if alertas.is_empty():
		var dicas := [Txt.t("mira_tip1"), Txt.t("mira_tip2"), Txt.t("mira_tip3")]
		_reagir(_sem_repetir(["01_neutra", "03_rindo", "09_pensativa"]), dicas.pick_random())
	else:
		var a: Dictionary = alertas[0]
		_reagir(_sem_repetir([String(a.expressao), "09_pensativa"]), String(a.texto))

func _sem_repetir(opcoes: Array) -> String:
	for o in opcoes:
		if String(o) != _ultima_expr:
			return String(o)
	return String(opcoes[0])

func _reagir(expressao: String, fala: String) -> void:
	_ultima_expr = expressao
	_mira.texture = _retrato(expressao, _mira.size.y)
	_mostrar_balao(fala)
	var t := create_tween()
	_mira.pivot_offset = Vector2(_mira.size.x / 2.0, _mira.size.y)
	t.tween_property(_mira, "scale", Vector2(1.03, 0.97), 0.07)
	t.tween_property(_mira, "scale", Vector2.ONE, 0.12)
	_versao_fala += 1
	var minha := _versao_fala
	await get_tree().create_timer(3.0).timeout
	if minha == _versao_fala and is_instance_valid(_mira):
		_mira.texture = _retrato("01_neutra", _mira.size.y)
		if _fala_fixa.is_empty():
			_balao.hide()
		else:
			_mostrar_balao(_fala_fixa)
