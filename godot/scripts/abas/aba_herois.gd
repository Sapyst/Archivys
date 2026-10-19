## Aba Heróis: cartões com emblema de classe, nome, raça, barras (fome/descanso/moral), atributos e buff de comida.
extends AbaBase

const K := Estilo.K
const ESTADOS := {                 # [chave Txt, cor]
	"na_casa": ["state_home", Estilo.COR_VERDE],
	"em_missao": ["state_quest", Estilo.COR_AZUL],
	"ferido": ["state_injured", Estilo.COR_LARANJA],
	"morto": ["state_dead", Estilo.COR_FRACO],
}

func atualizar() -> void:
	var rolar := rolagem.scroll_vertical
	Estilo.limpar(lista)
	lista.add_child(titulo(Txt.t("heroes_title", [Jogo.vivos(), Jogo.capacidade()])))
	if Jogo.aventureiros.is_empty():
		lista.add_child(Estilo.rotulo(Txt.t("heroes_empty"), 20, Estilo.COR_FRACO, true))
	var ordem := ["na_casa", "ferido", "em_missao", "morto"]
	for est in ordem:
		for a in Jogo.aventureiros:
			if String(a.estado) == est:
				lista.add_child(_cartao_heroi(a))
	rolagem.set_deferred("scroll_vertical", rolar)

func _cartao_heroi(a: Dictionary) -> PanelContainer:
	var est := String(a.estado)
	var morto := est == "morto"
	var c := cartao(Callable(), Estilo.COR_PAINEL_ESCURO if morto else Estilo.COR_PAINEL)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1 * K)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 3 * K)
	var em := Estilo.emblema_rect(String(a.get("classe", "warrior")), 64)
	if morto:
		em.material = Estilo.material_cinza()
	cab.add_child(em)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var linha := HBoxContainer.new()
	var nome := Estilo.rotulo(Txt.t("hero_name_level", [a.nome, int(a.nivel)]), 24, Estilo.COR_FRACO if morto else Estilo.COR_TEXTO, true)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	var info: Array = ESTADOS.get(est, ["?", Estilo.COR_FRACO])
	var txt := Txt.t(String(info[0]))
	if est == "ferido":
		txt += " (%s)" % Estilo.texto_horas(maxf(0.0, float(a.ferido_ate) - Jogo.horas))
	if morto:
		linha.add_child(Estilo.icone_rect("morte", 24, 1))
	linha.add_child(Estilo.rotulo(txt, 20, info[1]))
	tv.add_child(linha)
	tv.add_child(Estilo.rotulo(Txt.t("rec_class_race", [Jogo.nome_classe(a), Jogo.descricao_raca(a)]), 18, Estilo.COR_FRACO, true))
	cab.add_child(tv)
	v.add_child(cab)
	if not morto:
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 4 * K)
		var b1 := Estilo.linha_barra("fome", a.fome, 100.0, Estilo.COR_LARANJA)
		var b2 := Estilo.linha_barra("descanso", a.descanso, 100.0, Estilo.COR_VERDE)
		var b3 := Estilo.linha_barra("moral", float(a.moral) + 50.0, 100.0, Estilo.COR_DOURADO)
		for b in [b1, b2, b3]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(b)
		v.add_child(g)
		var at: Dictionary = a.get("atrib", {})
		v.add_child(Estilo.rotulo(Txt.t("hero_stats", [int(at.get("might", 0)), int(at.get("wits", 0)), int(at.get("grit", 0)),
			int(Jogo.poder_heroi(a))]), 18, Estilo.COR_SUB, true))
		var bonus := Jogo.bonus_comida(a)
		if bonus > 0.0:
			var bf: Dictionary = a.buff
			var h := HBoxContainer.new()
			var ic := Estilo.prato_rect(String(bf.prato), 1)
			h.add_child(ic)
			var lb := Estilo.rotulo(Txt.t("hero_buff", [Txt.t("dish_" + String(bf.prato)), int(round(bonus * 100.0)),
				Estilo.texto_horas(float(bf.ate) - Jogo.horas)]), 16, Estilo.COR_VERDE, true)
			lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(lb)
			v.add_child(h)
		else:
			v.add_child(Estilo.rotulo(Txt.t("hero_no_buff"), 16, Estilo.COR_FRACO, true))
		v.add_child(Estilo.rotulo(Txt.t("hero_xp", [int(Jogo.moral_efetiva(a)), int(a.equip), int(a.xp), int(a.nivel) * 30]),
			16, Estilo.COR_FRACO, true))
	c.add_child(v)
	return c
