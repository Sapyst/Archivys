## Aba Quadro: contratos (grau, chance e risco estimados com o melhor grupo), detalhe com montagem de grupo
## (até 4, emblema de classe) e chance/risco ao vivo; missões em andamento.
extends AbaBase

const K := Estilo.K
## Cor das marcas de grau 1–4 (verde, azul, roxo, ouro)
const COR_GRAU := {1: Color8(120, 200, 110), 2: Color8(98, 168, 220), 3: Color8(176, 123, 224), 4: Color8(242, 193, 78)}

var _selecionados: Array = []
var _contrato_aberto := -1

func atualizar() -> void:
	var rolar := rolagem.scroll_vertical
	Estilo.limpar(lista)
	if not Jogo.missoes.is_empty():
		lista.add_child(titulo(Txt.t("board_ongoing")))
		for m in Jogo.missoes:
			var p := Estilo.painel(Estilo.COR_PAINEL_ESCURO)
			var v := VBoxContainer.new()
			var c: Dictionary = m.contrato
			v.add_child(Estilo.rotulo("[%s] %s" % [c.rank, c.nome], 20, Estilo.COR_TEXTO, true))
			var nomes: Array = []
			var ems := HBoxContainer.new()
			ems.add_theme_constant_override("separation", 1 * K)
			for id in m.herois:
				var heroi := Jogo.aventureiro_por_id(int(id))
				nomes.append(String(heroi.get("nome", "?")))
				ems.add_child(Estilo.emblema_rect(String(heroi.get("classe", "warrior")), 64))
			v.add_child(ems)
			v.add_child(Estilo.rotulo(Txt.t("board_party_line", [", ".join(PackedStringArray(nomes)),
				Estilo.texto_horas(maxf(0.0, float(m.fim) - Jogo.horas)), int(float(m.chance) * 100.0)]), 18, Estilo.COR_FRACO, true))
			var dur := maxf(0.01, float(m.fim) - float(m.inicio))
			v.add_child(Estilo.barra(Jogo.horas - float(m.inicio), dur, Estilo.COR_AZUL))
			p.add_child(v)
			lista.add_child(p)
	lista.add_child(titulo(Txt.t("board_contracts")))
	if not Jogo.tem_melhoria("selo"):
		lista.add_child(Estilo.rotulo(Txt.t("board_no_seal"), 18, Estilo.COR_LARANJA, true))
	for c in Jogo.contratos:
		lista.add_child(_cartao_contrato(c))
	rolagem.set_deferred("scroll_vertical", rolar)

func _cartao_contrato(c: Dictionary) -> PanelContainer:
	var id := int(c.id)
	var abrir := func() -> void:
		_abrir_detalhe(id)
	var grau := int(c.grau)
	var p := cartao(abrir, Estilo.COR_PAINEL)
	if grau >= 3:                                    # contrato difícil: destaque = metal dourado
		p.add_theme_stylebox_override("panel", Estilo.caixa_9("metal_dourado", 6, Vector4(6, 5, 6, 5)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3 * K)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_selo_grau(grau, bool(c.do_arquivo)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1 * K)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Estilo.rotulo(String(c.nome), 22, Estilo.COR_TEXTO, true))
	var extra := Txt.t("board_archive_extra", [int(c.favores)]) if bool(c.do_arquivo) else ""
	v.add_child(Estilo.rotulo(Txt.t("board_contract_line", [grau, String(c.rank), Estilo.texto_horas(float(c.duracao)),
		int(c.moedas), int(c.fama), extra]), 18, Estilo.COR_FRACO, true))
	var grupo := Jogo.melhor_grupo(c)
	if grupo.is_empty():
		v.add_child(Estilo.rotulo(Txt.t("board_estimate_none"), 18, Estilo.COR_FRACO, true))
	else:
		var ch := Jogo.chance(c, grupo)
		v.add_child(Estilo.rotulo(Txt.t("board_estimate", [grupo.size(), int(ch * 100.0), int(ceil(Jogo.risco(c, grupo) * 100.0))]),
			18, _cor_chance(ch), true))
	h.add_child(v)
	p.add_child(h)
	return p

static func _cor_chance(ch: float) -> Color:
	return Estilo.COR_VERDE if ch >= 0.7 else (Estilo.COR_DOURADO if ch >= 0.4 else Estilo.COR_VERMELHO)

## Selo do contrato: ícone de contrato (selo de cera, se for do Arquivo) + 1–4 marcas de grau embaixo.
func _selo_grau(grau: int, arquivo: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1 * K)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Estilo.icone_rect("favores" if arquivo else "contratos", 28, 2))
	var marcas := HBoxContainer.new()
	marcas.add_theme_constant_override("separation", 1 * K)
	marcas.alignment = BoxContainer.ALIGNMENT_CENTER
	marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 4:
		var m := ColorRect.new()
		m.custom_minimum_size = Vector2(3 * K, 3 * K)
		m.color = COR_GRAU[grau] if k < grau else Color8(50, 40, 44)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marcas.add_child(m)
	v.add_child(marcas)
	return v

func _abrir_detalhe(id: int) -> void:
	if _contrato_aberto != id:
		_selecionados.clear()
	_contrato_aberto = id
	var montar := func(corpo: VBoxContainer) -> void:
		_montar_detalhe(corpo, id)
	principal.abrir_gaveta(Txt.t("board_contract_title"), montar)

func _montar_detalhe(corpo: VBoxContainer, id: int) -> void:
	var c := Jogo.contrato_por_id(id)
	if c.is_empty():
		corpo.add_child(Estilo.rotulo(Txt.t("board_gone"), 20, Estilo.COR_TEXTO, true))
		return
	corpo.add_child(Estilo.rotulo("[%s] %s" % [c.rank, c.nome], 24, Estilo.COR_DOURADO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("board_detail", [int(c.grau), String(c.rank),
		Estilo.texto_horas(float(c.duracao)), int(c.dificuldade)]), 18, Estilo.COR_FRACO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("board_reward", [int(c.moedas),
		int(c.materiais), int(c.fama), int(c.favores)]), 18, Estilo.COR_TEXTO, true))
	corpo.add_child(Estilo.rotulo(Txt.t("board_risk_rule", [int(round(Jogo.chance_morte(int(c.grau)) * 100.0))]), 16, Estilo.COR_LARANJA, true))
	corpo.add_child(Estilo.rotulo(Txt.t("board_archive_rule"), 16, Estilo.COR_FRACO, true))
	# remove da seleção quem não está mais disponível
	for sid in _selecionados.duplicate():
		if String(Jogo.aventureiro_por_id(int(sid)).get("estado", "")) != "na_casa":
			_selecionados.erase(sid)
	var ch := Jogo.chance(c, _selecionados)
	corpo.add_child(Estilo.rotulo(Txt.t("board_party", [_selecionados.size(), int(Jogo.poder(_selecionados)),
		int(ch * 100.0), int(ceil(Jogo.risco(c, _selecionados) * 100.0))]), 24, _cor_chance(ch), true))
	var algum := false
	for a in Jogo.aventureiros:
		if String(a.estado) != "na_casa":
			continue
		algum = true
		var aid := int(a.id)
		var marcado := _selecionados.has(aid)
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 2 * K)
		var em := Estilo.emblema_rect(String(a.get("classe", "warrior")), 64)
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(em)
		var b := CheckButton.new()
		var fed := Jogo.bonus_comida(a)
		b.text = Txt.t("board_hero_check", [a.nome, int(a.nivel), Jogo.nome_classe(a), int(Jogo.poder_heroi(a)),
			Txt.t("board_hero_buff", [int(round(fed * 100.0))]) if fed > 0.0 else ""])
		b.button_pressed = marcado
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		linha.add_child(b)
		b.disabled = not marcado and _selecionados.size() >= 4
		b.toggled.connect(func(ligado: bool) -> void:
			if ligado and not _selecionados.has(aid):
				_selecionados.append(aid)
			elif not ligado:
				_selecionados.erase(aid)
			principal.atualizar_gaveta())
		corpo.add_child(linha)
	if not algum:
		corpo.add_child(Estilo.rotulo(Txt.t("board_none_home"), 20, Estilo.COR_FRACO, true))
	var partir := func() -> void:
		if Jogo.partir(id, _selecionados):
			_selecionados.clear()
			_contrato_aberto = -1
			principal.fechar_gaveta()
	corpo.add_child(Estilo.botao(Txt.t("board_depart"), partir, not _selecionados.is_empty()))
