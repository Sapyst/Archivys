## Aba Obras: construções (selo, recepção 1–4, cozinha 1–3, despensa 1–3, quartos, forja) e decoração
## (conforto com retorno decrescente). Mostra só o próximo nível de cada linha.
extends AbaBase

const ORDEM := ["selo", "recepcao_2", "recepcao_3", "recepcao_4", "cozinha_2", "cozinha_3", "despensa_2", "despensa_3", "quartos", "forja"]
const SECOES := [
	["works_sec_house", ["selo", "recepcao_2", "recepcao_3", "recepcao_4"]],
	["works_sec_food", ["cozinha_2", "cozinha_3", "despensa_2", "despensa_3"]],
	["works_sec_rooms", ["quartos", "forja"]],
]
const ICONE := {"selo": "favores", "recepcao": "guilda", "cozinha": "pratos", "despensa": "provisoes", "quartos": "descanso", "forja": "melhorias"}

func atualizar() -> void:
	var rolar := rolagem.scroll_vertical
	Estilo.limpar(lista)
	lista.add_child(titulo(Txt.t("works_title")))
	lista.add_child(Estilo.rotulo(Txt.t("works_fame", [Jogo.nivel_fama(), Jogo.fama, Jogo.fama_proximo_nivel(),
		int(Jogo.conforto())]), 18, Estilo.COR_FRACO, true))
	for sec in SECOES:
		var ids: Array = []
		for id in sec[1]:
			if Jogo.tem_melhoria(id):
				continue
			var req := String(Jogo.MELHORIAS[id].requer)
			# da mesma linha (recepção/cozinha/despensa), só o próximo nível
			if not req.is_empty() and req.get_slice("_", 0) == String(id).get_slice("_", 0) and not Jogo.tem_melhoria(req):
				continue
			ids.append(id)
		if ids.is_empty():
			continue
		lista.add_child(Estilo.rotulo_px(Txt.t(String(sec[0])), "m4", Estilo.COR_SUB))
		for id in ids:
			lista.add_child(_cartao_melhoria(id))
	lista.add_child(titulo(Txt.t("works_decor")))
	for id in Jogo.DECORACOES:
		lista.add_child(_cartao_decoracao(id))
	var feitas: Array = []
	for id in ORDEM:
		if Jogo.tem_melhoria(id):
			feitas.append(String(Jogo.MELHORIAS[id].nome))
	if not feitas.is_empty():
		lista.add_child(titulo(Txt.t("works_done")))
		lista.add_child(Estilo.rotulo(", ".join(PackedStringArray(feitas)), 18, Estilo.COR_FRACO, true))
	rolagem.set_deferred("scroll_vertical", rolar)

func _custo_texto(m: Dictionary) -> String:
	var partes: Array = []
	if int(m.moedas) > 0: partes.append(Txt.t("cost_coins", [int(m.moedas)]))
	if int(m.materiais) > 0: partes.append(Txt.t("cost_materials", [int(m.materiais)]))
	if int(m.favores) > 0: partes.append(Txt.t("cost_favors", [int(m.favores)]))
	if int(m.fama_nv) > 0: partes.append(Txt.t("cost_fame", [int(m.fama_nv)]))
	return Txt.t("cost_sep").join(PackedStringArray(partes)) if not partes.is_empty() else Txt.t("cost_free")

func _cartao_melhoria(id: String) -> PanelContainer:
	var m: Dictionary = Jogo.MELHORIAS[id]
	var req := String(m.requer)
	var falta_req := not req.is_empty() and not Jogo.tem_melhoria(req)
	var pode := Jogo.pode_pagar(m) and not falta_req
	var p := Estilo.painel(Estilo.COR_PAINEL if pode else Estilo.COR_PAINEL_ESCURO)
	if pode:                                         # dá para construir agora: destaque = metal dourado
		p.add_theme_stylebox_override("panel", Estilo.caixa_9("metal_dourado", 6, Vector4(6, 5, 6, 5)))
	var v := VBoxContainer.new()
	var h := HBoxContainer.new()
	var ic := Estilo.icone_rect(String(ICONE.get(id.get_slice("_", 0), "melhorias")), 28, 2)
	if not pode:
		ic.material = Estilo.material_cinza()
	h.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Estilo.rotulo(String(m.nome), 22, Estilo.COR_TEXTO if pode else Estilo.COR_FRACO, true))
	info.add_child(Estilo.rotulo(String(m.desc), 16, Estilo.COR_FRACO, true))
	var custo := _custo_texto(m)
	if falta_req:
		custo += Txt.t("works_requires", [String(Jogo.MELHORIAS[req].nome)])
	info.add_child(Estilo.rotulo(custo, 16, Estilo.COR_DOURADO if pode else Estilo.COR_FRACO, true))
	h.add_child(info)
	v.add_child(h)
	var construir := func() -> void:
		Jogo.comprar_melhoria(id)
	v.add_child(Estilo.botao(Txt.t("works_build"), construir, pode))
	p.add_child(v)
	return p

func _cartao_decoracao(id: String) -> PanelContainer:
	var d: Dictionary = Jogo.DECORACOES[id]
	var pode := Jogo.pode_pagar(d)
	var p := Estilo.painel()
	var h := HBoxContainer.new()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Estilo.rotulo(Txt.t("deco_owned", [d.nome, Jogo.decoracoes.count(id)]), 22, Estilo.COR_TEXTO, true))
	info.add_child(Estilo.rotulo(Txt.t("deco_comfort", [Jogo.conforto_proxima_copia(id), _custo_texto(d)]), 16, Estilo.COR_FRACO, true))
	h.add_child(info)
	var comprar := func() -> void:
		Jogo.comprar_decoracao(id)
	var b := Estilo.botao(Txt.t("works_buy"), comprar, pode)
	b.custom_minimum_size.x = 150
	h.add_child(b)
	p.add_child(h)
	return p
