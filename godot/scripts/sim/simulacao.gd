## Simulação de balanceamento (headless) usando o código REAL do autoload Jogo.
## Rodar: godot --headless --path . res://cenas/simulacao.tscn  [-- dias=20 seeds=30 perfil=engajado|casual]
## Um "bot" joga como um jogador atento: entra 6× por dia (06:30, 09:30, 11:30, 15:00, 18:30, 22:00),
## cozinha antes dos rushes, joga os rushes no mini-game (acerto 90%, combo → gorjeta) ou deixa no
## automático (perfil casual: só o almoço é jogado), aceita candidatos, manda grupos com chance ≥ 70% e risco ≤ 5%,
## compra obras/funcionários por prioridade. Imprime marcos (dia do selo, 1º funcionário, recepção 2…),
## renda por dia, curva de fama e taxa de sucesso por grau. Resultados registrados em docs/balanceamento.md.
extends Node

var dias := 20
var seeds := 30
var perfil := "engajado"
const CHECKINS := [6.5, 9.5, 11.5, 15.0, 18.5, 22.0]
const ACERTO := 0.90
const PRIORIDADE := ["selo", "staff:server", "cozinha_2", "recepcao_2", "despensa_2", "staff:cook", "quartos",
	"recepcao_3", "staff:receptionist", "cozinha_3", "despensa_3", "forja", "recepcao_4"]

var J: Node
var _marcos := {}
var _renda_dia: Array = []
var _gasto_dia: Array = []
var _fama_dia: Array = []
var _moedas_dia: Array = []
var _missoes := {}          # grau -> [partidas, sucessos, mortes]
var _rush_stats := {"clientes": 0, "servidos": 0, "n": 0}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"dias": dias = int(kv[1])
				"seeds": seeds = int(kv[1])
				"perfil": perfil = kv[1]
	J = get_node("/root/Jogo")
	J.rush_comecou.connect(_ao_rush)
	J.missao_retornou.connect(_ao_retorno)
	var todos_marcos: Array = []
	var renda_por_dia := {}
	var fama_por_dia := {}
	var moedas_por_dia := {}
	var gasto_por_dia := {}
	for s in seeds:
		seed(1000 + s)
		_marcos = {}
		_renda_dia = []; _gasto_dia = []; _fama_dia = []; _moedas_dia = []
		J.novo_jogo()
		J.primeira_vez_feita = true
		_rodar()
		todos_marcos.append(_marcos)
		for d in _renda_dia.size():
			renda_por_dia[d + 1] = renda_por_dia.get(d + 1, []) + [_renda_dia[d]]
			fama_por_dia[d + 1] = fama_por_dia.get(d + 1, []) + [_fama_dia[d]]
			moedas_por_dia[d + 1] = moedas_por_dia.get(d + 1, []) + [_moedas_dia[d]]
			gasto_por_dia[d + 1] = gasto_por_dia.get(d + 1, []) + [_gasto_dia[d]]
	print("=== SIMULACAO perfil=%s seeds=%d dias=%d ===" % [perfil, seeds, dias])
	for m in ["selo", "staff", "staff:server", "staff:cook", "cozinha_2", "recepcao_2", "despensa_2", "quartos",
			"recepcao_3", "staff:receptionist", "fama1", "fama2", "fama3", "fama4"]:
		var l: Array = []
		for mk in todos_marcos:
			if mk.has(m):
				l.append(int(mk[m]))
		print("MARCO %-20s mediana dia %s  (p25 %s, p75 %s)  atingido %d/%d" % [m, _q(l, 0.5), _q(l, 0.25), _q(l, 0.75), l.size(), seeds])
	for d in [1, 2, 3, 4, 5, 7, 10, 15, 20]:
		if renda_por_dia.has(d):
			print("DIA %2d  renda bruta mediana %s (p25 %s p75 %s)  gastos %s  fama %s  moedas %s" % [d, _q(renda_por_dia[d], 0.5),
				_q(renda_por_dia[d], 0.25), _q(renda_por_dia[d], 0.75), _q(gasto_por_dia[d], 0.5), _q(fama_por_dia[d], 0.5), _q(moedas_por_dia[d], 0.5)])
	for g in [1, 2, 3, 4]:
		var st: Array = _missoes.get(g, [0, 0, 0])
		print("GRAU %d  partidas %d  sucesso %.0f%%  mortes/partida %.2f" % [g, st[0], 100.0 * st[1] / maxf(1, st[0]), float(st[2]) / maxf(1, st[0])])
	print("RUSH atendidos %.0f%% (%d de %d clientes em %d rushes)" % [100.0 * _rush_stats.servidos / maxf(1, _rush_stats.clientes),
		_rush_stats.servidos, _rush_stats.clientes, _rush_stats.n])
	_tabela_chance()
	get_tree().quit()

## Chance por rank para grupos típicos (moral 0, descanso/fome 70, conforto 9) — com e sem comida (Steak & Rice 2★ / Feast).
func _tabela_chance() -> void:
	J.novo_jogo()
	var grupos := {"2x Lv1": [1, 1], "3x Lv2": [2, 2, 2], "4x Lv3": [3, 3, 3, 3], "4x Lv5": [5, 5, 5, 5], "4x Lv8": [8, 8, 8, 8]}
	for g in grupos:
		var ids: Array = []
		J.aventureiros = []
		for nv in grupos[g]:
			var a: Dictionary = J.gerar_aventureiro(int(nv), "warrior")
			a.atrib = {"might": 4, "wits": 1, "grit": 3}
			a.moral = 0.0; a.fome = 70.0; a.descanso = 70.0
			J.aventureiros.append(a)
			ids.append(int(a.id))
		var linha := "CHANCE %-7s poder %4d |" % [g, int(J.poder(ids))]
		for rk in J.RANKS:
			var c := {"dificuldade": float(J.DIFICULDADE[rk]), "grau": int(J.GRAU_POR_RANK[rk])}
			linha += " %s %3d%%" % [rk, int(J.chance(c, ids) * 100.0)]
		for a in J.aventureiros:
			a.buff = {"prato": "steak_rice", "ate": J.horas + 10.0, "might": 0.18}
		linha += " | +steak:"
		for rk in J.RANKS:
			var c2 := {"dificuldade": float(J.DIFICULDADE[rk]), "grau": int(J.GRAU_POR_RANK[rk])}
			linha += " %s %3d%%" % [rk, int(J.chance(c2, ids) * 100.0)]
		print(linha)

static func _q(l: Array, q: float) -> String:
	if l.is_empty():
		return "-"
	var s := l.duplicate()
	s.sort()
	return str(s[clampi(int(round((s.size() - 1) * q)), 0, s.size() - 1)])

func _rodar() -> void:
	var fim: float = J.HORA_INICIO + 24.0 * dias
	var dia_ant := 1
	var saldo_ant: int = J.moedas
	while J.horas < fim:
		# próximo instante: hora cheia ou check-in
		var hd: float = J.hora_do_dia()
		var prox := floorf(J.horas) + 1.0
		for c in CHECKINS:
			var t: float = floorf(J.horas / 24.0) * 24.0 + c
			if t > J.horas + 0.001 and t < prox:
				prox = t
		J.avancar(prox - J.horas)
		hd = J.hora_do_dia()
		if J.dia() != dia_ant:
			_renda_dia.append(J.bruto_ontem)
			_gasto_dia.append(J.gastos_ontem)
			_fama_dia.append(J.fama)
			_moedas_dia.append(J.moedas)
			saldo_ant = J.moedas
			dia_ant = J.dia()
		for c in CHECKINS:
			if absf(hd - c) < 0.01:
				_checkin()
		_marcar()

func _marcar() -> void:
	var d: int = J.dia()
	for m in J.melhorias:
		if not _marcos.has(m):
			_marcos[m] = d
	for f in J.funcionarios:
		if not _marcos.has("staff:" + f):
			_marcos["staff:" + f] = d
		if not _marcos.has("staff"):
			_marcos["staff"] = d
	for nv in range(1, 5):
		if J.nivel_fama() >= nv and not _marcos.has("fama%d" % nv):
			_marcos["fama%d" % nv] = d

# ---------------------------------------------------------------- rushes
func _ao_rush(r: Dictionary) -> void:
	var jogar := perfil == "engajado" or String(r.id) == "lunch"
	if not jogar:
		J.resolver_rush_auto()
		return
	J.jogar_rush()
	var disp := {}
	for id in J.ORDEM_PRATOS:
		disp[id] = J.porcoes(id)
	var servidos := {}
	var perdidos := 0
	var recusados := 0
	var gorjetas := 0
	var combo := 0
	for i in int(r.clientes):
		var id: String = J.sortear_pedido(disp)
		if id.is_empty():
			recusados += 1
			continue
		if randf() < ACERTO:
			disp[id] = int(disp[id]) - 1
			servidos[id] = int(servidos.get(id, 0)) + 1
			combo += 1
			gorjetas += int(round(J.preco_porcao(id) * minf(0.1 * combo, 0.5)))
		else:
			perdidos += 1
			combo = 0
	var res: Dictionary = J.aplicar_rush({"servidos": servidos, "perdidos": perdidos, "recusados": recusados,
		"gorjetas": gorjetas, "combo": combo}, "player")
	_rush_stats.clientes += int(res.clientes)
	_rush_stats.servidos += int(res.servidos)
	_rush_stats.n += 1

func _ao_retorno(ret: Dictionary) -> void:
	var g := int(ret.grau)
	var st: Array = _missoes.get(g, [0, 0, 0])
	st[0] += 1
	if String(ret.resultado) == "sucesso" or String(ret.resultado) == "brilhante":
		st[1] += 1
	st[2] += ret.mortos.size()
	_missoes[g] = st

# ---------------------------------------------------------------- check-in do jogador
func _checkin() -> void:
	# enterros e retornos
	for r in J.retornos_pendentes.duplicate():
		for i in r.mortos.size():
			if not r.mortos[i].resolvido:
				if not J.decidir_enterro(int(r.id), i, true):
					J.decidir_enterro(int(r.id), i, false)
		J.dispensar_retorno(int(r.id))
	# candidatos
	for c in J.candidatos.duplicate():
		if J.vivos() < J.capacidade():
			J.aceitar_candidato(int(c.id))
		elif int(c.nivel) == 1:
			J.recusar_candidato(int(c.id))
	_comprar()
	_cozinhar()
	_missionar()
	if J.funcionarios.has("server") and perfil == "casual":
		J.auto_servir = true

func _cozinhar() -> void:
	# alvo: clientes do próximo rush × 1,15 + heróis, repartido por popularidade entre os pratos destravados
	var prox: Dictionary = J.proximo_rush()
	if prox.is_empty():
		return
	var base := 9
	var def: Dictionary = J.rush_def(String(prox.id))
	if not def.is_empty():
		base = int(def.base)
	var alvo_total: int = int(ceil(J.clientes_rush(base) * 1.15)) + J.contar("na_casa")
	var pesos := 0.0
	for id in J.ORDEM_PRATOS:
		if J.prato_destravado(id):
			pesos += float(J.PRATOS[id].pop)
	var lotes := 0
	for id in J.ORDEM_PRATOS:
		if not J.prato_destravado(id):
			continue
		var alvo := mini(int(ceil(alvo_total * float(J.PRATOS[id].pop) / pesos)), J.cap_prato())
		while J.porcoes(id) < alvo and lotes < 8:
			if J.provisoes < J.provisoes_por_lote(id):
				J.comprar_provisoes(mini(20, J.cap_provisoes() - int(J.provisoes)))
			if not J.iniciar_fornada(id):
				break
			var r := randf()
			J.terminar_fornada(id, 1 if r < 0.15 else (2 if r < 0.65 else 3))
			lotes += 1

func _missionar() -> void:
	var contratos: Array = J.contratos.duplicate()
	contratos.sort_custom(func(a, b): return (int(a.favores) * 100 + int(a.moedas)) > (int(b.favores) * 100 + int(b.moedas)))
	for c in contratos:
		var livres: Array = []
		for a in J.aventureiros:
			if String(a.estado) == "na_casa" and float(a.descanso) > 25.0:
				livres.append(a)
		if livres.is_empty():
			return
		livres.sort_custom(func(x, y): return J.poder_heroi(x) > J.poder_heroi(y))
		var ids: Array = []
		for a in livres:
			if ids.size() >= 3 or J.chance(c, ids) >= 0.85:
				break
			ids.append(int(a.id))
		if J.chance(c, ids) >= 0.70 and J.risco(c, ids) <= 0.05:
			J.partir(int(c.id), ids)

func _comprar() -> void:
	var reserva: int = 40 + J.salarios_dia() * 2       # guarda para provisões e salários
	for item in PRIORIDADE:
		var it := String(item)
		if it.begins_with("staff:"):
			var f := it.substr(6)
			if J.funcionarios.has(f) or not J.funcao_destravada(f) or not J.candidatos_staff.has(f):
				continue
			if J.moedas - int(J.candidatos_staff[f].taxa) >= reserva:
				J.contratar(f)
			continue
		if J.tem_melhoria(it):
			continue
		var m: Dictionary = J.MELHORIAS[it]
		if not String(m.requer).is_empty() and not J.tem_melhoria(String(m.requer)):
			continue
		if J.pode_pagar(m) and J.moedas - int(m.moedas) >= reserva:
			J.comprar_melhoria(it)
	# decoração barata quando sobra
	if J.moedas > 400 and J.decoracoes.count("mesa") < 3:
		J.comprar_decoracao("mesa")
