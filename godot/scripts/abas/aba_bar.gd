## Aba Bar (salão de refeições): próximo rush, satisfação, Auto-serve, cardápio com o estoque real de pratos.
extends AbaBase

const K := Estilo.K

func atualizar() -> void:
	var rolar := rolagem.scroll_vertical
	Estilo.limpar(lista)
	lista.add_child(titulo(Txt.t("bar_title")))
	# ---- rush: agora / próximo
	var p := Estilo.painel()
	var v := VBoxContainer.new()
	if not Jogo.guilda_aberta:
		v.add_child(Estilo.rotulo(Txt.t("bar_closed"), 18, Estilo.COR_LARANJA, true))
	elif not Jogo.rush_atual.is_empty():
		v.add_child(Estilo.linha_icone("relogio", Txt.t("bar_rush_now", [Txt.t("rush_" + String(Jogo.rush_atual.id))])))
	else:
		var prox := Jogo.proximo_rush()
		if not prox.is_empty():
			var falta := float(prox.inicio) - Jogo.horas
			v.add_child(Estilo.linha_icone("relogio", Txt.t("bar_next_rush", [Txt.t("rush_" + String(prox.id)),
				Jogo.texto_hora_de(fmod(float(prox.inicio), 24.0)), Estilo.texto_horas(falta)])))
	var hs := HBoxContainer.new()
	hs.add_child(Estilo.icone_rect("moral", 24, 2))
	var ls := Estilo.rotulo(Txt.t("bar_satisfaction", [int(Jogo.satisfacao)]), 22)
	ls.custom_minimum_size.x = 300
	ls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hs.add_child(ls)
	var cor := Estilo.COR_VERDE if Jogo.satisfacao >= 60.0 else (Estilo.COR_DOURADO if Jogo.satisfacao >= 35.0 else Estilo.COR_VERMELHO)
	hs.add_child(Estilo.barra(Jogo.satisfacao, 100.0, cor))
	v.add_child(hs)
	v.add_child(Estilo.rotulo(Txt.t("bar_customers", [Jogo.clientes_rush(9), Jogo.assentos()]), 16, Estilo.COR_FRACO, true))
	# Auto-serve (precisa de garçom)
	if Jogo.funcionarios.has("server"):
		var st: Dictionary = Jogo.funcionarios.server
		var auto := CheckButton.new()
		auto.text = Txt.t("bar_auto_serve", [st.nome, int(round(Jogo.eficiencia_auto() * 100.0))])
		auto.button_pressed = Jogo.auto_servir
		auto.custom_minimum_size = Vector2(0, 16 * K)
		auto.toggled.connect(func(ligado: bool) -> void:
			Jogo.auto_servir = ligado
			Jogo.mudou.emit())
		v.add_child(auto)
	else:
		v.add_child(Estilo.rotulo(Txt.t("bar_auto_serve_off"), 16, Estilo.COR_FRACO, true))
	v.add_child(Estilo.linha_icone("moedas", Txt.t("bar_income", [Jogo.renda_dia, Jogo.gastos_dia, Jogo.renda_ontem]), 18))
	p.add_child(v)
	lista.add_child(p)
	# ---- cardápio
	lista.add_child(titulo(Txt.t("bar_menu")))
	for id in Jogo.ORDEM_PRATOS:
		if not Jogo.prato_destravado(id) and Jogo.porcoes(id) == 0:
			continue
		lista.add_child(_linha_prato(id))
	var f_coz := func() -> void:
		principal.trocar_aba("guilda")
		principal._abas.guilda.abrir_cozinha()
	lista.add_child(Estilo.botao(Txt.t("bar_cook"), f_coz))
	rolagem.set_deferred("scroll_vertical", rolar)

func _linha_prato(id: String) -> PanelContainer:
	var p := Estilo.painel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3 * K)
	var ic := Estilo.prato_rect(id, 2)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Estilo.rotulo(Txt.t("dish_" + id), 22, Estilo.COR_TEXTO, true))
	var n := Jogo.porcoes(id)
	v.add_child(Estilo.rotulo(Txt.t("bar_dish_line", [n, Jogo.preco_porcao(id)]), 18,
		Estilo.COR_VERMELHO if n == 0 else Estilo.COR_SUB, true))
	h.add_child(v)
	if n > 0:
		var e := Estilo.estrelas(Jogo.qualidade(id), 18, 2)
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(e)
	p.add_child(h)
	return p
