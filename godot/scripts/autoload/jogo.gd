## Estado e simulação da guilda (autoload "Jogo").
## Todo o tempo é medido em HORAS DE JOGO (float). Dia 1 começa às 10:00 (horas = 10.0).
## Loop principal (docs/decisoes.md "LOOP PRINCIPAL"): a guilda abre, clientes chegam nos 3 rushes do dia
## (Breakfast 07–09, Lunch 12–14, Supper 19–21), pedem pratos do ESTOQUE REAL, o jogador serve (mini-game) ou
## deixa no automático; cozinhar (mini-game) transforma provisões em porções; comida dá buffs aos aventureiros.
## Números e fórmulas: docs/balanceamento.md (mantenha os dois em sincronia).
extends Node

signal mudou                              # algo relevante mudou (UI reconstrói)
signal missao_retornou(retorno: Dictionary)
signal rush_comecou(rush: Dictionary)     # início de um rush aguardando decisão (servir / automático)
signal rush_resolvido(resumo: Dictionary) # resultado aplicado (mini-game ou automático)

# ================================================================ dados fixos
const HORA_INICIO := 10.0

# ---------------------------------------------------------------- contratos (missões)
const RANKS := ["E", "D", "C", "B", "A", "S"]
const GRAU_POR_RANK := {"E": 1, "D": 1, "C": 2, "B": 3, "A": 3, "S": 4}
const DIFICULDADE := {"E": 30.0, "D": 48.0, "C": 95.0, "B": 170.0, "A": 270.0, "S": 440.0}
const DURACAO := {"E": [3, 6], "D": [5, 9], "C": [10, 16], "B": [18, 30], "A": [30, 48], "S": [48, 72]}
const RECOMPENSA := {"E": 28, "D": 50, "C": 110, "B": 240, "A": 450, "S": 900}
const FAMA_CONTRATO := {"E": 3, "D": 5, "C": 10, "B": 22, "A": 40, "S": 90}
## Peso de sorteio do grau (com o selo). Antes do selo: só grau 1. Grau 4 só a partir de fama Nv 2
## (antes, o peso dele vai para o grau 3). Resultado: 82% grau 1–2, 16% grau 3, 2% grau 4.
const PESO_GRAU := {1: 52.0, 2: 30.0, 3: 16.0, 4: 2.0}
const MORTE_BASE := 0.10                 # chance de morrer, por herói, numa FALHA: 0,10 + 0,07 × grau
const MORTE_GRAU := 0.07
const FERIDO_CHANCE := 0.4               # por herói em falha/parcial (se não morreu)
const NIVEIS_FAMA := [0, 40, 120, 300, 600, 1200]     # fama mínima de cada nível (Nv 0..5)

## Chaves de texto (Txt) das ameaças por grau e dos locais.
const AMEACAS := {
	1: ["threat_corgnal_rats", "threat_corgnal_loose", "threat_corgnal_nest", "threat_cellar_critter"],
	2: ["threat_mimic", "threat_broken_rune", "threat_trapped_corridor"],
	3: ["threat_aeos_roots", "threat_sarcoplast", "threat_ancient_guardian"],
	4: ["threat_witness"],
}
const LOCAIS := ["place_archive_cellar", "place_low_valley", "place_illamar_sewer", "place_dock_warehouse",
	"place_amagor_ruin", "place_dry_well", "place_fallen_tower", "place_deep_gallery"]

# ---------------------------------------------------------------- aventureiros
const NOMES := {
	"Dravhin": ["Tavo", "Lena", "Brás", "Iria", "Davi", "Cora", "Otto", "Sela", "Rui", "Mara", "Teo", "Lia", "Nico", "Ana"],
	"Peluvia": ["Kaa", "Rhuun", "Ossa", "Fenn", "Gurra", "Mibi", "Tok", "Sarra", "Brun", "Ylla", "Rakk", "Pim"],
	"Igramir": ["Hodrin", "Barda", "Grum", "Thessa", "Dorn", "Ulva", "Kedrim", "Brissa"],
}
const NOMES_STAFF := ["Tullo", "Lusa", "Nerva", "Prisca", "Rufo", "Mirel", "Valir", "Ondra", "Haber", "Cass", "Dena", "Amil"]
const RACAS := ["Dravhin", "Peluvia", "Igramir"]
const ANIMAIS := ["lobo", "raposa", "gato", "urso", "coelho", "texugo"]
const ESCAMAS := ["lagarto", "serpente", "tartaruga"]
const CLASSES := ["warrior", "mage", "hunter", "guardian", "berserker", "druid"]
const ATRIBUTOS := ["might", "wits", "grit"]
## Quanto cada atributo pesa para a classe (soma 1). Usado no poder e no efeito dos buffs de comida.
const PESO_CLASSE := {
	"warrior": {"might": 0.6, "wits": 0.0, "grit": 0.4},
	"mage": {"might": 0.0, "wits": 0.8, "grit": 0.2},
	"hunter": {"might": 0.4, "wits": 0.4, "grit": 0.2},
	"guardian": {"might": 0.3, "wits": 0.0, "grit": 0.7},
	"berserker": {"might": 0.8, "wits": 0.0, "grit": 0.2},
	"druid": {"might": 0.0, "wits": 0.5, "grit": 0.5},
}
## Sorteio de classe por raça (pesos). Peluvia "pesado" usa a linha "pesado".
const CLASSE_POR_RACA := {
	"Dravhin": {"warrior": 25, "mage": 25, "hunter": 25, "guardian": 10, "berserker": 5, "druid": 10},
	"Peluvia": {"warrior": 15, "mage": 10, "hunter": 30, "guardian": 10, "berserker": 10, "druid": 25},
	"pesado": {"warrior": 20, "mage": 0, "hunter": 0, "guardian": 40, "berserker": 40, "druid": 0},
	"Igramir": {"warrior": 30, "mage": 5, "hunter": 10, "guardian": 35, "berserker": 15, "druid": 5},
}

# ---------------------------------------------------------------- comida
const ORDEM_PRATOS := ["bread_butter", "steak_rice", "roast_chicken", "sundae", "roast_pig_feast"]
## tracos = traços no mini-game · prov = provisões por fornada · porcoes = porções com 2 estrelas
## preco = moedas por porção com 1 estrela (MULT_PRECO: 0★ ×0,6 · 1★ ×1,0 · 2★ ×1,2 · 3★ ×1,5) · buff = % por atributo · horas = duração do buff
## fama_nv / cozinha = requisitos para destravar
const PRATOS := {
	"bread_butter": {"tracos": 1, "prov": 1, "porcoes": 4, "preco": 3, "buff": {"grit": 0.10}, "horas": 8.0, "fama_nv": 0, "cozinha": 1, "pop": 5},
	"steak_rice": {"tracos": 2, "prov": 2, "porcoes": 4, "preco": 6, "buff": {"might": 0.18}, "horas": 10.0, "fama_nv": 0, "cozinha": 1, "pop": 4},
	"roast_chicken": {"tracos": 3, "prov": 3, "porcoes": 4, "preco": 10, "buff": {"grit": 0.15, "might": 0.10}, "horas": 12.0, "fama_nv": 1, "cozinha": 1, "pop": 3},
	"sundae": {"tracos": 4, "prov": 3, "porcoes": 3, "preco": 13, "buff": {"wits": 0.22}, "horas": 12.0, "fama_nv": 2, "cozinha": 1, "pop": 2},
	"roast_pig_feast": {"tracos": 5, "prov": 8, "porcoes": 4, "preco": 22, "buff": {"might": 0.25, "wits": 0.25, "grit": 0.25}, "horas": 16.0, "fama_nv": 3, "cozinha": 2, "pop": 1},
}
const MULT_PRECO := [0.6, 1.0, 1.2, 1.5]        # por estrelas (0 = queimado)
const MULT_BUFF := [0.0, 0.6, 1.0, 1.4]
const PRECO_CASA := 0.5                          # aventureiros da casa pagam 50% do preço
const CUSTO_PROVISAO := 3                        # moedas por provisão (compra manual)
const TAXA_ENCOMENDA := 1.25                     # encomenda automática: +25%
const CAP_PROVISOES := [30, 60, 100]             # por nível da despensa
const CAP_PRATO := [12, 18, 24]                  # porções máximas por prato, por nível da despensa
const HORAS_COZINHEIRO := [10.0, 16.0, 23.0]     # o cozinheiro contratado cozinha nestes horários
const ALVO_COZINHEIRO := {"bread_butter": 8, "steak_rice": 6, "roast_chicken": 5, "sundae": 4, "roast_pig_feast": 3}

# ---------------------------------------------------------------- rushes
const RUSHES := [
	{"id": "breakfast", "inicio": 7.0, "fim": 9.0, "base": 6},
	{"id": "lunch", "inicio": 12.0, "fim": 14.0, "base": 9},
	{"id": "supper", "inicio": 19.0, "fim": 21.0, "base": 11},
]
const EFICIENCIA_MIRA := 0.5                     # recusou o mini-game sem garçom: a Mira serve sozinha

# ---------------------------------------------------------------- funcionários
## contratar = taxa de contratação (hab. 1, +30 por nível) · salario = por dia (hab. 1, +4 por nível)
const FUNCOES := {
	"server": {"fama_nv": 2, "contratar": 80, "salario": 10},
	"cook": {"fama_nv": 2, "contratar": 110, "salario": 14},
	"receptionist": {"fama_nv": 3, "contratar": 140, "salario": 16},
}
const ORDEM_FUNCOES := ["server", "cook", "receptionist"]

## Decoração: conforto base; cópias repetidas valem 50%, 25%, 12,5%...
var DECORACOES := {
	"mesa": {"nome": Txt.t("deco_mesa"), "conforto": 4.0, "moedas": 30, "materiais": 2, "favores": 0, "fama_nv": 0},
	"tapete": {"nome": Txt.t("deco_tapete"), "conforto": 3.0, "moedas": 25, "materiais": 0, "favores": 0, "fama_nv": 0},
	"vaso": {"nome": Txt.t("deco_vaso"), "conforto": 2.0, "moedas": 12, "materiais": 0, "favores": 0, "fama_nv": 0},
	"estandarte": {"nome": Txt.t("deco_estandarte"), "conforto": 5.0, "moedas": 70, "materiais": 3, "favores": 0, "fama_nv": 1},
	"lareira": {"nome": Txt.t("deco_lareira"), "conforto": 8.0, "moedas": 160, "materiais": 10, "favores": 0, "fama_nv": 2},
}

## Construções únicas. "requer" = outra construção necessária antes; "selo" = exige o selo de filiação.
var MELHORIAS := {
	"selo": {"nome": Txt.t("upg_selo"), "desc": Txt.t("upg_selo_desc"), "moedas": 40, "materiais": 0, "favores": 3, "fama_nv": 0, "requer": ""},
	"recepcao_2": {"nome": Txt.t("upg_recepcao_2"), "desc": Txt.t("upg_recepcao_desc"), "moedas": 300, "materiais": 12, "favores": 1, "fama_nv": 2, "requer": "selo"},
	"recepcao_3": {"nome": Txt.t("upg_recepcao_3"), "desc": Txt.t("upg_recepcao_desc"), "moedas": 800, "materiais": 30, "favores": 2, "fama_nv": 3, "requer": "recepcao_2"},
	"recepcao_4": {"nome": Txt.t("upg_recepcao_4"), "desc": Txt.t("upg_recepcao_desc"), "moedas": 1800, "materiais": 60, "favores": 4, "fama_nv": 4, "requer": "recepcao_3"},
	"cozinha_2": {"nome": Txt.t("upg_cozinha_2"), "desc": Txt.t("upg_cozinha_desc"), "moedas": 160, "materiais": 6, "favores": 0, "fama_nv": 1, "requer": ""},
	"cozinha_3": {"nome": Txt.t("upg_cozinha_3"), "desc": Txt.t("upg_cozinha_desc"), "moedas": 450, "materiais": 20, "favores": 0, "fama_nv": 2, "requer": "cozinha_2"},
	"despensa_2": {"nome": Txt.t("upg_despensa_2"), "desc": Txt.t("upg_despensa_desc"), "moedas": 100, "materiais": 4, "favores": 0, "fama_nv": 0, "requer": ""},
	"despensa_3": {"nome": Txt.t("upg_despensa_3"), "desc": Txt.t("upg_despensa_desc"), "moedas": 320, "materiais": 14, "favores": 0, "fama_nv": 2, "requer": "despensa_2"},
	"quartos": {"nome": Txt.t("upg_quartos"), "desc": Txt.t("upg_quartos_desc"), "moedas": 400, "materiais": 20, "favores": 1, "fama_nv": 2, "requer": "selo"},
	"forja": {"nome": Txt.t("upg_forja"), "desc": Txt.t("upg_forja_desc"), "moedas": 600, "materiais": 35, "favores": 2, "fama_nv": 3, "requer": "selo"},
}
const ORDEM_MELHORIAS := ["selo", "recepcao_2", "recepcao_3", "recepcao_4", "cozinha_2", "cozinha_3",
	"despensa_2", "despensa_3", "quartos", "forja"]
const ALUGUEL_QUARTO := 3                        # moedas por herói em casa, por noite (com Quartos)
const CUSTO_FORJA := {"moedas": 25, "materiais": 3}

# ================================================================ estado
var horas := HORA_INICIO
var guilda_aberta := true
var velocidade_jogo := 60          # × do tempo com o app aberto (Relogio.VELOCIDADES)
var nome_guilda := ""
var moedas := 100
var fama := 0
var honra := 0.0
var provisoes := 16.0
var materiais := 4
var favores := 0
var satisfacao := 60.0             # 0–100: humor dos clientes (média móvel dos rushes)
var nivel_recepcao := 1
var nivel_cozinha := 1
var nivel_despensa := 1
var pratos := {}                   # id -> {"n": porções, "q": qualidade média 0–3}
var auto_servir := false
var auto_encomenda := false
var funcionarios := {}             # funcao -> {nome, habilidade, salario}
var candidatos_staff := {}         # funcao -> {nome, habilidade, salario, taxa}
var filtro := {}                   # recepcionista: {nivel_min, classes{}, racas{}}
var rush_atual := {}               # {id, dia, clientes, status: "aguardando" | "jogando"}
var decoracoes: Array = []         # ids de DECORACOES (repetidos permitidos)
var melhorias: Array = []          # ids de MELHORIAS compradas
var aventureiros: Array = []
var candidatos: Array = []
var contratos: Array = []
var missoes: Array = []
var retornos_pendentes: Array = []
var renda_dia := 0
var renda_ontem := 0
var gastos_dia := 0
var bruto_ontem := 0               # renda bruta (sem descontar gastos) do dia anterior — resumo/simulação
var gastos_ontem := 0
var primeira_vez_feita := false
var proximo_id := 1
var estat := {}                    # contadores para o resumo/balanceamento

var _acum_cand := 0.0
var _registro: Array = []          # últimas mensagens
var _coleta: Array = []
var _coletando := false

# ================================================================ jogo novo
func novo_jogo() -> void:
	horas = HORA_INICIO; guilda_aberta = true; velocidade_jogo = 60
	nome_guilda = ""
	moedas = 100; fama = 0; honra = 0.0
	provisoes = 16.0; materiais = 4; favores = 0; satisfacao = 60.0
	nivel_recepcao = 1; nivel_cozinha = 1; nivel_despensa = 1
	pratos = {}
	for id in ORDEM_PRATOS:
		pratos[id] = {"n": 0, "q": 2.0}
	pratos.bread_butter.n = 6
	pratos.steak_rice.n = 4
	auto_servir = false; auto_encomenda = false
	funcionarios = {}; candidatos_staff = {}
	filtro = filtro_padrao()
	rush_atual = {}
	decoracoes = ["mesa"]; melhorias = []
	aventureiros = []; candidatos = []; contratos = []; missoes = []; retornos_pendentes = []
	renda_dia = 0; renda_ontem = 0; gastos_dia = 0; primeira_vez_feita = false; proximo_id = 1
	estat = {"rushes": 0, "servidos": 0, "clientes": 0, "missoes": 0, "sucessos": 0, "mortes": 0}
	_acum_cand = 0.0
	# tutorial: 2 novatos (guerreiro + caçador) + 1 candidato esperando + contrato do Arquivo (rank E)
	var a1 := gerar_aventureiro(1, "warrior")
	var a2 := gerar_aventureiro(1, "hunter")
	aventureiros.append(a1)
	aventureiros.append(a2)
	candidatos.append(gerar_aventureiro(1))
	var c := _gerar_contrato(1, "E")
	c.nome = Txt.t("contract_tutorial")
	c.do_arquivo = true
	c.favores = 1
	c.duracao = 4.0
	c.dificuldade = 28.0
	c.expira = horas + 96.0
	contratos.append(c)
	_completar_quadro()
	_renovar_candidatos_staff()
	_mudou()

func filtro_padrao() -> Dictionary:
	var cl := {}
	for k in CLASSES:
		cl[k] = true
	var rc := {}
	for r in RACAS:
		rc[r] = true
	return {"nivel_min": 1, "classes": cl, "racas": rc}

func nome_da_guilda() -> String:
	return nome_guilda if not nome_guilda.is_empty() else Txt.t("guild_name")

# ================================================================ tempo
func dia() -> int:
	return int(horas / 24.0) + 1

func hora_do_dia() -> float:
	return fmod(horas, 24.0)

func texto_hora() -> String:
	return texto_hora_de(hora_do_dia())

static func texto_hora_de(h: float) -> String:
	return "%02d:%02d" % [int(h), int((h - floor(h)) * 60.0)]

## Avança a simulação em passos de no máximo 1 h de jogo.
func avancar(h: float) -> void:
	if h <= 0.0:
		return
	var hora_antes := int(horas)
	while h > 0.0:
		var passo := minf(1.0, h)
		_passo(passo)
		h -= passo
	if int(horas) != hora_antes:
		_mudou()

## true se o instante `hora_dia` (0–24) de algum dia está em (antes, depois].
static func _cruzou(antes: float, depois: float, hora_dia: float) -> bool:
	var base := floorf(antes / 24.0) * 24.0
	for b in [base, base + 24.0]:
		var t: float = b + hora_dia
		if antes < t and t <= depois:
			return true
	return false

func _passo(p: float) -> void:
	var antes := horas
	var dia_antes := dia()
	horas += p
	var conf := conforto()
	var tem_quartos := tem_melhoria("quartos")
	for a in aventureiros:
		match String(a.estado):
			"na_casa":
				a.fome = clampf(a.fome - 4.0 * p, 0.0, 100.0)
				a.descanso = clampf(a.descanso + (5.0 if tem_quartos else 2.0) * p, 0.0, 100.0)
			"em_missao":
				a.fome = clampf(a.fome - 3.0 * p, 0.0, 100.0)
				a.descanso = clampf(a.descanso - 4.0 * p, 0.0, 100.0)
			"ferido":
				a.fome = clampf(a.fome - 3.0 * p, 0.0, 100.0)
				a.descanso = clampf(a.descanso + 2.0 * p, 0.0, 100.0)
				if horas >= float(a.ferido_ate):
					a.estado = "na_casa"
					_registrar(Txt.t("log_recovered", [a.nome]))
		if String(a.estado) != "morto":
			# moral deriva devagar para um alvo dado pelo conforto; fome extrema machuca
			var alvo := clampf(conf / 4.0 - 5.0, -20.0, 30.0)
			a.moral = a.moral + (alvo - a.moral) * 0.03 * p
			if a.fome < 15.0:
				a.moral = a.moral - 1.5 * p
			a.moral = clampf(a.moral, -50.0, 50.0)

	# candidatos chegam com a guilda aberta, das 7h às 23h (clientes felizes = mais inscrições)
	var hd := hora_do_dia()
	if guilda_aberta and hd >= 7.0 and hd < 23.0:
		_acum_cand += taxa_candidatos() * p
		while _acum_cand >= 1.0:
			_acum_cand -= 1.0
			_chegou_candidato()

	# rushes: começo e fim da janela
	for r in RUSHES:
		if _cruzou(antes, horas, float(r.inicio)):
			_comecar_rush(r)
		if _cruzou(antes, horas, float(r.fim)) and not rush_atual.is_empty() \
				and String(rush_atual.id) == String(r.id) and String(rush_atual.status) == "aguardando":
			_fim_da_janela()

	# cozinheiro contratado cozinha entre os rushes
	if funcionarios.has("cook"):
		for hc in HORAS_COZINHEIRO:
			if _cruzou(antes, horas, hc):
				_cozinheiro_trabalha()

	# missões que terminaram
	for m in missoes.duplicate():
		if horas >= float(m.fim):
			missoes.erase(m)
			_resolver_missao(m)

	if dia() != dia_antes:
		_virar_dia()

func _virar_dia() -> void:
	renda_ontem = renda_dia - gastos_dia
	bruto_ontem = renda_dia
	gastos_ontem = gastos_dia
	# salários
	for f in ORDEM_FUNCOES:
		if not funcionarios.has(f):
			continue
		var st: Dictionary = funcionarios[f]
		var sal := int(st.salario)
		if moedas >= sal:
			_gastar(sal)
		else:
			funcionarios.erase(f)
			if f == "server":
				auto_servir = false
			_registrar(Txt.t("log_staff_quit", [st.nome, Txt.t("role_" + f)]))
	# aluguel dos quartos
	if tem_melhoria("quartos"):
		var aluguel := contar("na_casa") * ALUGUEL_QUARTO
		if aluguel > 0:
			_ganhar(aluguel)
	renda_dia = 0
	gastos_dia = 0
	for c in contratos.duplicate():
		if horas >= float(c.expira):
			contratos.erase(c)
	# sem o selo, o Arquivo põe 1 contrato de favor por dia no quadro
	if not tem_melhoria("selo"):
		var tem_arquivo := false
		for c in contratos:
			if bool(c.do_arquivo):
				tem_arquivo = true
		if not tem_arquivo:
			var c := _gerar_contrato(1)
			c.do_arquivo = true
			c.favores = 1
			contratos.push_front(c)
	_completar_quadro()
	_renovar_candidatos_staff()
	_registrar(Txt.t("log_new_day", [dia(), renda_ontem]))

func _ganhar(v: int) -> void:
	moedas += v
	renda_dia += v

func _gastar(v: int) -> void:
	moedas -= v
	gastos_dia += v

# ================================================================ recursos / níveis
func nivel_fama() -> int:
	var nv := 0
	for i in NIVEIS_FAMA.size():
		if fama >= int(NIVEIS_FAMA[i]):
			nv = i
	return nv

func fama_proximo_nivel() -> int:
	var nv := nivel_fama()
	return int(NIVEIS_FAMA[nv + 1]) if nv + 1 < NIVEIS_FAMA.size() else fama

func mudar_fama(v: int) -> void:
	fama = maxi(0, fama + v)

func conforto() -> float:
	var total := nivel_recepcao * 5.0
	var contagem := {}
	for d in decoracoes:
		if not DECORACOES.has(d):
			continue
		var k: int = contagem.get(d, 0)
		total += float(DECORACOES[d].conforto) * pow(0.5, k)
		contagem[d] = k + 1
	return total

## Quanto a PRÓXIMA cópia da decoração somaria.
func conforto_proxima_copia(id: String) -> float:
	return float(DECORACOES[id].conforto) * pow(0.5, decoracoes.count(id))

func capacidade() -> int:
	return 2 + nivel_recepcao * 2 + (4 if tem_melhoria("quartos") else 0)

## Lugares no salão (limite de clientes por rush).
func assentos() -> int:
	return 8 + 3 * nivel_recepcao + 2 * mini(decoracoes.count("mesa"), 4)

func cap_provisoes() -> int:
	return int(CAP_PROVISOES[clampi(nivel_despensa, 1, 3) - 1])

func cap_prato() -> int:
	return int(CAP_PRATO[clampi(nivel_despensa, 1, 3) - 1])

func tem_melhoria(id: String) -> bool:
	return melhorias.has(id)

func contar(estado: String) -> int:
	var n := 0
	for a in aventureiros:
		if String(a.estado) == estado:
			n += 1
	return n

func vivos() -> int:
	return aventureiros.size() - contar("morto")

func pode_pagar(custo: Dictionary) -> bool:
	return moedas >= int(custo.get("moedas", 0)) and materiais >= int(custo.get("materiais", 0)) \
		and favores >= int(custo.get("favores", 0)) and nivel_fama() >= int(custo.get("fama_nv", 0))

func _pagar(custo: Dictionary) -> void:
	_gastar(int(custo.get("moedas", 0)))
	materiais -= int(custo.get("materiais", 0))
	favores -= int(custo.get("favores", 0))

# ================================================================ aventureiros
func _sortear_peso(pesos: Dictionary) -> String:
	var total := 0.0
	for k in pesos:
		total += float(pesos[k])
	var r := randf() * total
	for k in pesos:
		r -= float(pesos[k])
		if r < 0.0:
			return String(k)
	return String(pesos.keys()[0])

func gerar_aventureiro(nivel: int, classe := "") -> Dictionary:
	var raca := "Igramir"
	var variante := ""                    # id: "", "bestial", "pesado", "escamado"
	var animal := ""                      # id do animal (bestial/escamado), ver ANIMAIS/ESCAMAS
	var r := randf()
	if r < 0.45:
		raca = "Dravhin"
	elif r < 0.85:
		raca = "Peluvia"
		var v := (r - 0.45) / 0.40          # 22 / 10 / 8 dentro dos 40%
		if v < 0.55:
			variante = "bestial"
			animal = ANIMAIS.pick_random()
		elif v < 0.80:
			variante = "pesado"
		else:
			variante = "escamado"
			animal = ESCAMAS.pick_random()
	if classe.is_empty():
		classe = _sortear_peso(CLASSE_POR_RACA["pesado" if variante == "pesado" else raca])
	var equip := 5.0
	if variante == "pesado":
		equip += 4.0
	elif raca == "Igramir":
		equip += 2.0
	var nome: String = NOMES[raca].pick_random()
	return {
		"id": _novo_id(), "nome": nome, "raca": raca, "variante": variante, "animal": animal,
		"classe": classe, "atrib": _gerar_atributos(classe),
		"genero": "f" if randf() < 0.5 else "m",
		"nivel": nivel, "xp": 0, "equip": equip,
		"fome": randf_range(55.0, 80.0), "descanso": randf_range(60.0, 90.0),
		"moral": randf_range(-5.0, 10.0), "estado": "na_casa", "ferido_ate": 0.0, "buff": {},
	}

## Atributos 1–6: 1 + peso da classe × 4 (arredondado) + 0..1 aleatório.
func _gerar_atributos(classe: String) -> Dictionary:
	var w: Dictionary = PESO_CLASSE.get(classe, PESO_CLASSE.warrior)
	var d := {}
	for s in ATRIBUTOS:
		d[s] = 1 + int(round(float(w[s]) * 4.0)) + randi() % 2
	return d

func descricao_raca(a: Dictionary) -> String:
	var v := String(a.get("variante", ""))
	if v.is_empty():
		return String(a.raca)
	var chave := "variant_" + v
	if not Txt.tem(chave):
		return String(a.raca) + " " + v          # save antigo: variante já era texto
	var bicho := String(a.get("animal", ""))
	var txt := Txt.t(chave, [Txt.t("animal_" + bicho)]) if not bicho.is_empty() else Txt.t(chave)
	return String(a.raca) + " " + txt

func nome_classe(a: Dictionary) -> String:
	return Txt.t("class_" + String(a.get("classe", "warrior")))

func aventureiro_por_id(id: int) -> Dictionary:
	for a in aventureiros:
		if int(a.id) == id:
			return a
	return {}

## Candidatos por hora (guilda aberta, 7h–23h): 0,08 × (0,5 + satisfação/100) × (1 + 0,1 × Nv fama) (+10%/hab. da recepcionista).
func taxa_candidatos() -> float:
	var t := 0.08 * (0.5 + satisfacao / 100.0) * (1.0 + 0.1 * nivel_fama())
	if funcionarios.has("receptionist"):
		t *= 1.0 + 0.1 * int(funcionarios.receptionist.habilidade)
	return t

func _chegou_candidato() -> void:
	if candidatos.size() >= 3:
		return
	var nv := 1 + (randi() % (nivel_fama() + 1))
	var cand := gerar_aventureiro(nv)
	_registrar(Txt.t("log_arrived", [cand.nome, descricao_raca(cand)]))
	if funcionarios.has("receptionist"):
		var st: Dictionary = funcionarios.receptionist
		if not passa_filtro(cand):
			_registrar(Txt.t("log_rec_refused", [st.nome, cand.nome]))
			_mudou()
			return
		if vivos() < capacidade():
			aventureiros.append(cand)
			_registrar(Txt.t("log_rec_admitted", [st.nome, cand.nome]))
			_mudou()
			return
	candidatos.append(cand)
	_mudou()

func passa_filtro(a: Dictionary) -> bool:
	if int(a.nivel) < int(filtro.get("nivel_min", 1)):
		return false
	if not bool(filtro.get("classes", {}).get(String(a.classe), true)):
		return false
	return bool(filtro.get("racas", {}).get(String(a.raca), true))

func aceitar_candidato(id: int) -> bool:
	if vivos() >= capacidade():
		return false
	for c in candidatos:
		if int(c.id) == id:
			candidatos.erase(c)
			aventureiros.append(c)
			_registrar(Txt.t("log_joined", [c.nome]))
			_mudou()
			return true
	return false

func recusar_candidato(id: int) -> void:
	for c in candidatos:
		if int(c.id) == id:
			candidatos.erase(c)
			_mudou()
			return

func melhorar_equipamento(id: int) -> bool:
	var a := aventureiro_por_id(id)
	if a.is_empty() or not tem_melhoria("forja") or not pode_pagar(CUSTO_FORJA) or String(a.estado) != "na_casa":
		return false
	_pagar(CUSTO_FORJA)
	a.equip = float(a.equip) + 5.0
	_mudou()
	return true

# ================================================================ comida
func prato_destravado(id: String) -> bool:
	var p: Dictionary = PRATOS[id]
	return nivel_fama() >= int(p.fama_nv) and nivel_cozinha >= int(p.cozinha)

func porcoes(id: String) -> int:
	return int(pratos.get(id, {}).get("n", 0))

func qualidade(id: String) -> float:
	return float(pratos.get(id, {}).get("q", 2.0))

func total_porcoes() -> int:
	var n := 0
	for id in ORDEM_PRATOS:
		n += porcoes(id)
	return n

## Multiplicador por qualidade média (interpola MULT entre as estrelas).
static func _interp(tabela: Array, q: float) -> float:
	var q0 := clampi(int(floor(q)), 0, 3)
	var q1 := mini(q0 + 1, 3)
	return lerpf(float(tabela[q0]), float(tabela[q1]), clampf(q - q0, 0.0, 1.0))

## Preço de uma porção do estoque atual (moedas inteiras, mínimo 1).
func preco_porcao(id: String) -> int:
	return maxi(1, int(round(float(PRATOS[id].preco) * _interp(MULT_PRECO, qualidade(id)))))

func provisoes_por_lote(id: String) -> int:
	return int(PRATOS[id].prov)

## Porções produzidas: base (2 estrelas) + (estrelas − 2) + (nível da cozinha − 1). Queimado: base − 2 (mín. 1).
func porcoes_lote(id: String, estrelas: int) -> int:
	var base := int(PRATOS[id].porcoes) + (nivel_cozinha - 1)
	if estrelas <= 0:
		return maxi(1, base - 2)
	return base + estrelas - 2

func custo_encomenda(qtd: int) -> int:
	return int(ceil(qtd * CUSTO_PROVISAO * TAXA_ENCOMENDA))

## Motivo pelo qual não dá para cozinhar ("" = pode).
func motivo_nao_cozinha(id: String) -> String:
	if not prato_destravado(id):
		return "locked"
	if porcoes(id) >= cap_prato():
		return "full"
	var falta := provisoes_por_lote(id) - int(provisoes)
	if falta > 0 and not (auto_encomenda and moedas >= custo_encomenda(falta)):
		return "provisions"
	return ""

## Gasta as provisões da fornada (encomenda o que faltar se Auto-order estiver ligado). Chamado ao começar o mini-game.
func iniciar_fornada(id: String) -> bool:
	if not motivo_nao_cozinha(id).is_empty():
		return false
	var custo := provisoes_por_lote(id)
	var falta := custo - int(provisoes)
	if falta > 0:
		_gastar(custo_encomenda(falta))
		provisoes += falta
		_registrar(Txt.t("log_auto_order", [falta, custo_encomenda(falta)]))
	provisoes -= custo
	_mudou()
	return true

## Resultado do mini-game (ou do cozinheiro): soma as porções com a qualidade = estrelas.
func terminar_fornada(id: String, estrelas: int) -> int:
	var n := porcoes_lote(id, estrelas)
	var e: Dictionary = pratos[id]
	var antes := int(e.n)
	n = mini(n, cap_prato() - antes)
	if n <= 0:
		return 0
	e.q = (float(e.q) * antes + float(estrelas) * n) / float(antes + n)
	e.n = antes + n
	_mudou()
	return n

func comprar_provisoes(qtd: int) -> bool:
	qtd = mini(qtd, cap_provisoes() - int(provisoes))
	if qtd <= 0 or moedas < qtd * CUSTO_PROVISAO:
		return false
	_gastar(qtd * CUSTO_PROVISAO)
	provisoes += qtd
	_mudou()
	return true

func _cozinheiro_trabalha() -> void:
	var st: Dictionary = funcionarios.cook
	var lotes := 0
	for id in ORDEM_PRATOS:
		if not prato_destravado(id):
			continue
		while lotes < 6 and porcoes(id) < int(ALVO_COZINHEIRO[id]) and motivo_nao_cozinha(id).is_empty():
			iniciar_fornada(id)
			var hab := int(st.habilidade)
			var estrelas := 1 if hab <= 1 else (2 if hab >= 3 else (1 if randf() < 0.5 else 2))
			terminar_fornada(id, estrelas)
			lotes += 1
	if lotes > 0:
		_registrar(Txt.t("log_cook_batches", [st.nome, lotes]))

## Bônus de comida do herói (fração): Σ peso_da_classe[atributo] × buff[atributo], se ainda ativo.
func bonus_comida(a: Dictionary) -> float:
	var b: Dictionary = a.get("buff", {})
	if b.is_empty() or horas >= float(b.get("ate", 0.0)):
		return 0.0
	var w: Dictionary = PESO_CLASSE.get(String(a.get("classe", "warrior")), PESO_CLASSE.warrior)
	var t := 0.0
	for s in ATRIBUTOS:
		t += float(w[s]) * float(b.get(s, 0.0))
	return t

## O que esse prato daria de bônus para esse herói (fração), na qualidade atual do estoque.
func bonus_prato_para(a: Dictionary, id: String) -> float:
	var w: Dictionary = PESO_CLASSE.get(String(a.get("classe", "warrior")), PESO_CLASSE.warrior)
	var buff: Dictionary = PRATOS[id].buff
	var m := _interp(MULT_BUFF, qualidade(id))
	var t := 0.0
	for s in buff:
		t += float(w[s]) * float(buff[s]) * m
	return t

## Depois de cada rush os heróis da casa comem: o prato do estoque que mais ajuda a classe (pagam 50%);
## sem estoque, mingau de 1 provisão (sem buff).
func _herois_comem() -> Dictionary:
	var comeram := 0
	var mingau := 0
	for a in aventureiros:
		var est := String(a.estado)
		if est != "na_casa" and est != "ferido":
			continue
		if a.fome >= 85.0:
			continue
		var melhor := ""
		var melhor_b := -1.0
		for id in ORDEM_PRATOS:
			if porcoes(id) <= 0:
				continue
			var b := bonus_prato_para(a, id)
			if b > melhor_b + 0.001:
				melhor_b = b
				melhor = id
		if not melhor.is_empty():
			var q := qualidade(melhor)
			pratos[melhor].n = porcoes(melhor) - 1
			_ganhar(int(round(preco_porcao(melhor) * PRECO_CASA)))
			a.fome = 100.0
			a.moral = minf(50.0, a.moral + 1.0 + q)
			var buff := {"prato": melhor, "ate": horas + float(PRATOS[melhor].horas)}
			var m := _interp(MULT_BUFF, q)
			for s in PRATOS[melhor].buff:
				buff[s] = float(PRATOS[melhor].buff[s]) * m
			if bonus_comida(a) <= melhor_b:
				a.buff = buff
			comeram += 1
		elif provisoes >= 1.0:
			provisoes -= 1.0
			a.fome = minf(100.0, a.fome + 60.0)
			mingau += 1
	return {"comeram": comeram, "mingau": mingau}

# ================================================================ rushes
func rush_def(id: String) -> Dictionary:
	for r in RUSHES:
		if String(r.id) == id:
			return r
	return {}

## Clientes do rush = base × demanda, limitado aos assentos.
## demanda = 1 + 0,12 × Nv fama + conforto/80 + (satisfação − 60)/200
func clientes_rush(base: int) -> int:
	var demanda := 1.0 + 0.12 * nivel_fama() + conforto() / 80.0 + (satisfacao - 60.0) / 200.0
	return clampi(int(round(base * demanda)), 3, assentos())

## Próximo rush a partir de agora: {id, inicio (horas absolutas)}.
func proximo_rush() -> Dictionary:
	var base := floorf(horas / 24.0) * 24.0
	for d in [0.0, 24.0]:
		for r in RUSHES:
			var t: float = base + d + float(r.inicio)
			if t > horas:
				return {"id": r.id, "inicio": t}
	return {}

func eficiencia_auto() -> float:
	if funcionarios.has("server"):
		return 0.70 + 0.075 * (int(funcionarios.server.habilidade) - 1)
	return EFICIENCIA_MIRA

func _comecar_rush(r: Dictionary) -> void:
	if not rush_atual.is_empty():
		_fim_da_janela()          # salvaguarda: um rush anterior ainda pendente
	if not guilda_aberta:
		_registrar(Txt.t("log_rush_closed", [Txt.t("rush_" + String(r.id))]))
		return
	rush_atual = {"id": r.id, "dia": dia(), "clientes": clientes_rush(int(r.base)), "status": "aguardando"}
	if auto_servir and funcionarios.has("server"):
		resolver_rush_auto()
		return
	rush_comecou.emit(rush_atual)
	_mudou()

func _fim_da_janela() -> void:
	if rush_atual.is_empty():
		return
	if not guilda_aberta:
		rush_atual = {}
		_mudou()
		return
	resolver_rush_auto()

## Cardápio do rush para o mini-game: [{id, n, preco}] na ORDEM_PRATOS.
func cardapio() -> Array:
	var l: Array = []
	for id in ORDEM_PRATOS:
		l.append({"id": id, "n": porcoes(id), "preco": preco_porcao(id)})
	return l

## Sorteia o prato do próximo cliente entre os que ainda têm porção (peso = popularidade).
func sortear_pedido(disponivel: Dictionary) -> String:
	var pesos := {}
	for id in ORDEM_PRATOS:
		if int(disponivel.get(id, 0)) > 0:
			pesos[id] = float(PRATOS[id].pop)
	if pesos.is_empty():
		return ""
	return _sortear_peso(pesos)

## Rush resolvido sem o jogador (garçom ou só a Mira): cada cliente pede um prato com estoque; é atendido
## com chance = eficiência; sem gorjeta de combo.
func resolver_rush_auto() -> Dictionary:
	if rush_atual.is_empty():
		return {}
	var n := int(rush_atual.clientes)
	var ef := eficiencia_auto()
	var disp := {}
	for id in ORDEM_PRATOS:
		disp[id] = porcoes(id)
	var servidos := {}
	var perdidos := 0
	var recusados := 0
	for i in n:
		var id := sortear_pedido(disp)
		if id.is_empty():
			recusados += 1
			continue
		if randf() < ef:
			disp[id] = int(disp[id]) - 1
			servidos[id] = int(servidos.get(id, 0)) + 1
		else:
			perdidos += 1
	return aplicar_rush({"servidos": servidos, "perdidos": perdidos, "recusados": recusados, "gorjetas": 0,
		"combo": 0}, "server" if funcionarios.has("server") else "mira")

## Marca o rush como em andamento no mini-game (a janela não o resolve sozinha).
func jogar_rush() -> Dictionary:
	if rush_atual.is_empty():
		return {}
	rush_atual.status = "jogando"
	return rush_atual

## Aplica o resultado. r = {servidos{id:n}, perdidos, recusados, gorjetas, combo}. modo: "player" | "server" | "mira".
func aplicar_rush(r: Dictionary, modo: String) -> Dictionary:
	var servidos: Dictionary = r.get("servidos", {})
	var n_serv := 0
	var moedas_pratos := 0
	var q_soma := 0.0
	for id in servidos:
		var k := mini(int(servidos[id]), porcoes(id))
		if k <= 0:
			continue
		moedas_pratos += preco_porcao(id) * k
		q_soma += qualidade(id) * k
		pratos[id].n = porcoes(id) - k
		n_serv += k
	var clientes := int(rush_atual.get("clientes", n_serv + int(r.get("perdidos", 0)) + int(r.get("recusados", 0))))
	var gorjetas := int(r.get("gorjetas", 0))
	_ganhar(moedas_pratos + gorjetas)
	var q_media := q_soma / maxf(1.0, n_serv)
	# satisfação do rush: % atendidos + qualidade + gorjetas (combo)
	var nota := 100.0 * n_serv / maxf(1.0, clientes) + (q_media - 1.5) * 10.0 \
		+ minf(10.0, 40.0 * gorjetas / maxf(1.0, moedas_pratos))
	nota = clampf(nota, 0.0, 100.0)
	satisfacao = clampf(satisfacao * 0.7 + nota * 0.3, 0.0, 100.0)
	var fama_rush := int(round(n_serv / 4.0 * (0.6 + nota / 100.0 * 0.8)))
	mudar_fama(fama_rush)
	var refeicao := _herois_comem()
	var id_rush := String(rush_atual.get("id", "lunch"))
	var resumo := {"id": id_rush, "modo": modo, "clientes": clientes, "servidos": n_serv,
		"perdidos": int(r.get("perdidos", 0)), "recusados": int(r.get("recusados", 0)),
		"moedas": moedas_pratos, "gorjetas": gorjetas, "fama": fama_rush, "nota": int(nota),
		"comeram": int(refeicao.comeram), "mingau": int(refeicao.mingau)}
	estat.rushes = int(estat.get("rushes", 0)) + 1
	estat.servidos = int(estat.get("servidos", 0)) + n_serv
	estat.clientes = int(estat.get("clientes", 0)) + clientes
	_registrar(Txt.t("log_rush", [Txt.t("rush_" + id_rush), n_serv, clientes, moedas_pratos + gorjetas]))
	rush_atual = {}
	rush_resolvido.emit(resumo)
	_mudou()
	return resumo

# ================================================================ funcionários
func funcao_destravada(f: String) -> bool:
	return tem_melhoria("selo") and nivel_fama() >= int(FUNCOES[f].fama_nv)

func _renovar_candidatos_staff() -> void:
	for f in ORDEM_FUNCOES:
		if funcionarios.has(f):
			candidatos_staff.erase(f)
			continue
		var r := randf()
		var hab := 1 if r < 0.5 else (2 if r < 0.85 else 3)
		candidatos_staff[f] = {"nome": NOMES_STAFF.pick_random(), "habilidade": hab,
			"salario": int(FUNCOES[f].salario) + 4 * (hab - 1),
			"taxa": int(FUNCOES[f].contratar) + 30 * (hab - 1)}

func contratar(f: String) -> bool:
	if funcionarios.has(f) or not funcao_destravada(f) or not candidatos_staff.has(f):
		return false
	var c: Dictionary = candidatos_staff[f]
	if moedas < int(c.taxa):
		return false
	_gastar(int(c.taxa))
	funcionarios[f] = {"nome": c.nome, "habilidade": int(c.habilidade), "salario": int(c.salario)}
	candidatos_staff.erase(f)
	_registrar(Txt.t("log_hired", [c.nome, Txt.t("role_" + f)]))
	_mudou()
	return true

func demitir(f: String) -> void:
	if not funcionarios.has(f):
		return
	var st: Dictionary = funcionarios[f]
	funcionarios.erase(f)
	if f == "server":
		auto_servir = false
	_registrar(Txt.t("log_fired", [st.nome, Txt.t("role_" + f)]))
	_renovar_candidatos_staff()
	_mudou()

func salarios_dia() -> int:
	var t := 0
	for f in funcionarios:
		t += int(funcionarios[f].salario)
	return t

# ================================================================ obras
func comprar_melhoria(id: String) -> bool:
	var m: Dictionary = MELHORIAS[id]
	if tem_melhoria(id) or not pode_pagar(m):
		return false
	if not String(m.requer).is_empty() and not tem_melhoria(String(m.requer)):
		return false
	_pagar(m)
	melhorias.append(id)
	if id.begins_with("recepcao_"):
		nivel_recepcao = int(id.substr(9))
	elif id.begins_with("cozinha_"):
		nivel_cozinha = int(id.substr(8))
	elif id.begins_with("despensa_"):
		nivel_despensa = int(id.substr(9))
	elif id == "selo":
		_renovar_candidatos_staff()
	_registrar(Txt.t("log_built", [m.nome]))
	_mudou()
	return true

func comprar_decoracao(id: String) -> bool:
	var d: Dictionary = DECORACOES[id]
	if not pode_pagar(d):
		return false
	_pagar(d)
	decoracoes.append(id)
	_mudou()
	return true

# ================================================================ contratos e missões
func _novo_id() -> int:
	proximo_id += 1
	return proximo_id - 1

func _sortear_grau() -> int:
	if not tem_melhoria("selo"):
		return 1
	var pesos := PESO_GRAU.duplicate()
	if nivel_fama() < 2:
		pesos[3] = float(pesos[3]) + float(pesos[4])
		pesos[4] = 0.0
	var total := 0.0
	for g in pesos:
		total += float(pesos[g])
	var r := randf() * total
	for g in [1, 2, 3, 4]:
		r -= float(pesos[g])
		if r < 0.0:
			return g
	return 1

func _rank_do_grau(grau: int) -> String:
	match grau:
		1:
			return "D" if (tem_melhoria("selo") and randf() < 0.4) else "E"
		2:
			return "C"
		3:
			return "A" if randf() < 0.3 else "B"
	return "S"

func _gerar_contrato(grau: int = 0, rank: String = "") -> Dictionary:
	if grau <= 0:
		grau = _sortear_grau()
	if rank.is_empty():
		rank = _rank_do_grau(grau)
	var faixa: Array = DURACAO[rank]
	var do_arquivo := tem_melhoria("selo") and randf() < 0.25
	var ameaca: String = AMEACAS[grau].pick_random()
	var local: String = LOCAIS.pick_random()
	return {
		"id": _novo_id(), "rank": rank, "grau": grau,
		"nome": Txt.t("contract_name", [Txt.t(ameaca), Txt.t(local)]),
		"duracao": float(randi_range(int(faixa[0]), int(faixa[1]))),
		"dificuldade": float(DIFICULDADE[rank]) * randf_range(0.9, 1.15),
		"moedas": int(RECOMPENSA[rank] * randf_range(0.85, 1.2)),
		"fama": int(FAMA_CONTRATO[rank]),
		"materiais": randi_range(1, 3) * grau,
		"favores": (1 if grau <= 2 else 2) if do_arquivo else 0,
		"do_arquivo": do_arquivo,
		"expira": horas + 48.0,
	}

func _completar_quadro() -> void:
	var alvo := 5 if tem_melhoria("selo") else 4
	while contratos.size() < alvo:
		contratos.append(_gerar_contrato())

func contrato_por_id(id: int) -> Dictionary:
	for c in contratos:
		if int(c.id) == id:
			return c
	return {}

func moral_efetiva(a: Dictionary) -> float:
	var media := (float(a.fome) + float(a.descanso)) / 2.0
	return float(a.moral) + (media - 50.0) * 0.3 + conforto() / 20.0

## Pontos de atributo que contam para a classe: Σ peso × atributo × 2.
func atributo_classe(a: Dictionary) -> float:
	var w: Dictionary = PESO_CLASSE.get(String(a.get("classe", "warrior")), PESO_CLASSE.warrior)
	var at: Dictionary = a.get("atrib", {})
	var t := 0.0
	for s in ATRIBUTOS:
		t += float(w[s]) * float(at.get(s, 2))
	return t * 2.0

## Poder de um herói = (nível × 10 + equipamento + atributos da classe) × (1 + moral/100) × (1 + bônus de comida).
func poder_heroi(a: Dictionary) -> float:
	var base := int(a.nivel) * 10.0 + float(a.equip) + atributo_classe(a)
	return base * (1.0 + moral_efetiva(a) / 100.0) * (1.0 + bonus_comida(a))

func poder(ids: Array) -> float:
	var total := 0.0
	for id in ids:
		var a := aventureiro_por_id(int(id))
		if not a.is_empty():
			total += poder_heroi(a)
	return total

## Chance de sucesso = 0,5 + 0,6 × (poder − dificuldade)/dificuldade, limitada a 5–95%.
func chance(c: Dictionary, ids: Array) -> float:
	if ids.is_empty() or c.is_empty():
		return 0.0
	var dif := float(c.dificuldade)
	return clampf(0.5 + (poder(ids) - dif) / dif * 0.6, 0.05, 0.95)

func chance_morte(grau: int) -> float:
	return MORTE_BASE + MORTE_GRAU * grau

## Risco de morte por herói = (1 − chance) × chance de morrer numa falha.
func risco(c: Dictionary, ids: Array) -> float:
	return (1.0 - chance(c, ids)) * chance_morte(int(c.grau)) if not ids.is_empty() else 0.0

## Melhor grupo disponível (até 4, por poder) — estimativa mostrada no cartão do contrato.
func melhor_grupo(c: Dictionary) -> Array:
	var livres: Array = []
	for a in aventureiros:
		if String(a.estado) == "na_casa":
			livres.append(a)
	livres.sort_custom(func(x, y): return poder_heroi(x) > poder_heroi(y))
	var ids: Array = []
	for a in livres:
		if ids.size() >= 4 or chance(c, ids) >= 0.95:
			break
		ids.append(int(a.id))
	return ids

func partir(contrato_id: int, ids: Array) -> bool:
	var c := contrato_por_id(contrato_id)
	if c.is_empty() or ids.is_empty() or ids.size() > 4:
		return false
	for id in ids:
		var a := aventureiro_por_id(int(id))
		if a.is_empty() or String(a.estado) != "na_casa":
			return false
	var ch := chance(c, ids)
	for id in ids:
		var heroi := aventureiro_por_id(int(id))
		heroi.estado = "em_missao"
	contratos.erase(c)
	missoes.append({"id": _novo_id(), "contrato": c, "herois": ids.duplicate(), "inicio": horas,
		"fim": horas + float(c.duracao), "chance": ch})
	_completar_quadro()
	_registrar(Txt.t("log_departed", [c.nome]))
	_mudou()
	return true

func _resolver_missao(m: Dictionary) -> void:
	var c: Dictionary = m.contrato
	var grau := int(c.grau)
	var margem := (float(m.chance) - randf()) * 100.0
	var res := "falha"
	var mult := 0.0
	var fama_ganha := -int(c.fama) / 2
	if margem > 30.0:
		res = "brilhante"; mult = 1.5; fama_ganha = int(c.fama * 1.5)
	elif margem >= 0.0:
		res = "sucesso"; mult = 1.0; fama_ganha = int(c.fama)
	elif margem >= -20.0:
		res = "parcial"; mult = 0.4; fama_ganha = int(c.fama) / 2
	var ret := {
		"id": _novo_id(), "contrato": c.nome, "rank": c.rank, "grau": grau, "resultado": res,
		"moedas": int(c.moedas * mult), "materiais": int(c.materiais * mult),
		"favores": int(c.favores) if mult >= 1.0 else 0, "fama": fama_ganha,
		"mortos": [], "feridos": [], "grupo_perdido": false,
	}
	_ganhar(int(ret.moedas))
	materiais += int(ret.materiais)
	favores += int(ret.favores)
	mudar_fama(fama_ganha)
	estat.missoes = int(estat.get("missoes", 0)) + 1
	if mult >= 1.0:
		estat.sucessos = int(estat.get("sucessos", 0)) + 1

	var mortos: Array = []
	for id in m.herois:
		var a := aventureiro_por_id(int(id))
		if a.is_empty():
			continue
		if res == "falha" and randf() < chance_morte(grau):
			a.estado = "morto"
			var p := int(c.fama) * 2 + 5 * grau
			mortos.append({"id": int(a.id), "nome": a.nome, "P": p, "custo": 10 + 15 * grau, "resolvido": false, "digno": false})
		elif (res == "falha" or res == "parcial") and randf() < FERIDO_CHANCE:
			a.estado = "ferido"
			a.ferido_ate = horas + 12.0 * grau
			ret.feridos.append(a.nome)
		else:
			a.estado = "na_casa"
		if String(a.estado) != "morto":
			a.xp = int(a.xp) + int(grau * 10 * maxf(mult, 0.2)) + 5
			if int(a.xp) >= int(a.nivel) * 30:
				a.xp = int(a.xp) - int(a.nivel) * 30
				a.nivel = int(a.nivel) + 1
				_registrar(Txt.t("log_level_up", [a.nome, a.nivel]))
			a.moral = clampf(a.moral + (8.0 if mult >= 1.0 else -6.0), -50.0, 50.0)
	estat.mortes = int(estat.get("mortes", 0)) + mortos.size()
	if not mortos.is_empty() and mortos.size() == m.herois.size():
		# grupo inteiro morreu: sem corpos, sem enterro.
		# TODO: Expedição de Honra (recupera os corpos, devolve 50%) e Missão de Vingança no quadro.
		ret.grupo_perdido = true
		var total := 0
		for mo in mortos:
			total += int(mo.P) * 2
			mo.resolvido = true
		mudar_fama(-total)
		ret["perda_total"] = total
	ret.mortos = mortos
	retornos_pendentes.append(ret)
	_registrar(Txt.t("log_returned", [c.nome, Txt.t("res_" + res)]))
	missao_retornou.emit(ret)
	_mudou()

func retorno_por_id(id: int) -> Dictionary:
	for r in retornos_pendentes:
		if int(r.id) == id:
			return r
	return {}

## Enterro digno: perda de fama cai para 20% e ganha honra 0,8·P.
func decidir_enterro(retorno_id: int, indice: int, digno: bool) -> bool:
	var r := retorno_por_id(retorno_id)
	if r.is_empty() or indice < 0 or indice >= r.mortos.size():
		return false
	var mo: Dictionary = r.mortos[indice]
	if mo.resolvido:
		return false
	var p := int(mo.P)
	if digno:
		if moedas < int(mo.custo):
			return false
		_gastar(int(mo.custo))
		mudar_fama(-int(round(p * 0.2)))
		honra += 0.8 * p
		mo.digno = true
	else:
		mudar_fama(-p)
	mo.resolvido = true
	_mudou()
	return true

func retorno_resolvido(r: Dictionary) -> bool:
	for mo in r.mortos:
		if not mo.resolvido:
			return false
	return true

func dispensar_retorno(retorno_id: int) -> void:
	var r := retorno_por_id(retorno_id)
	if not r.is_empty() and retorno_resolvido(r):
		retornos_pendentes.erase(r)
		_mudou()

# ================================================================ alertas
## Lista ordenada por prioridade (maior primeiro): {texto, prioridade, aba, expressao}
func alertas() -> Array:
	var l: Array = []
	for r in retornos_pendentes:
		if not retorno_resolvido(r):
			l.append({"texto": Txt.t("alert_burial"), "prioridade": 100, "aba": "guilda", "expressao": "12_luto"})
			break
	if not rush_atual.is_empty() and String(rush_atual.status) == "aguardando":
		l.append({"texto": Txt.t("alert_rush", [Txt.t("rush_" + String(rush_atual.id))]), "prioridade": 90, "aba": "bar", "expressao": "04_surpresa"})
	if total_porcoes() < 6:
		l.append({"texto": Txt.t("alert_dishes"), "prioridade": 80, "aba": "guilda", "expressao": "06_preocupada"})
	if provisoes < 4.0 and not auto_encomenda:
		l.append({"texto": Txt.t("alert_pantry"), "prioridade": 75, "aba": "guilda", "expressao": "06_preocupada"})
	for a in aventureiros:
		if String(a.estado) == "na_casa" and a.fome < 20.0:
			l.append({"texto": Txt.t("alert_hungry", [a.nome]), "prioridade": 70, "aba": "herois", "expressao": "06_preocupada"})
			break
	if not tem_melhoria("selo") and favores >= 3:
		l.append({"texto": Txt.t("alert_seal"), "prioridade": 60, "aba": "obras", "expressao": "02_feliz"})
	if not candidatos.is_empty():
		l.append({"texto": Txt.t("alert_reception"), "prioridade": 50, "aba": "guilda", "expressao": "04_surpresa"})
	for f in ORDEM_FUNCOES:
		if funcao_destravada(f) and not funcionarios.has(f) and funcionarios.is_empty():
			l.append({"texto": Txt.t("alert_staff"), "prioridade": 45, "aba": "guilda", "expressao": "02_feliz"})
			break
	if contar("na_casa") > 0 and not contratos.is_empty():
		l.append({"texto": Txt.t("alert_idle"), "prioridade": 40, "aba": "quadro", "expressao": "11_determinada"})
	l.sort_custom(func(x, y): return int(x.prioridade) > int(y.prioridade))
	return l

# ================================================================ registro
func _registrar(texto: String) -> void:
	_registro.append(texto)
	if _registro.size() > 40:
		_registro.pop_front()
	if _coletando:
		_coleta.append(texto)

func iniciar_coleta() -> void:
	_coleta = []
	_coletando = true

func terminar_coleta() -> Array:
	_coletando = false
	return _coleta.duplicate()

func _mudou() -> void:
	mudou.emit()

# ================================================================ salvar / carregar
const CAMPOS := ["horas", "guilda_aberta", "velocidade_jogo", "nome_guilda", "moedas", "fama", "honra", "provisoes",
	"materiais", "favores", "satisfacao", "nivel_recepcao", "nivel_cozinha", "nivel_despensa", "pratos",
	"auto_servir", "auto_encomenda", "funcionarios", "candidatos_staff", "filtro", "rush_atual", "decoracoes",
	"melhorias", "aventureiros", "candidatos", "contratos", "missoes", "retornos_pendentes", "renda_dia",
	"renda_ontem", "gastos_dia", "primeira_vez_feita", "proximo_id", "estat"]
const CAMPOS_INT := ["velocidade_jogo", "moedas", "fama", "materiais", "favores", "nivel_recepcao", "nivel_cozinha",
	"nivel_despensa", "renda_dia", "renda_ontem", "gastos_dia", "proximo_id"]

func para_dict() -> Dictionary:
	var d := {}
	for k in CAMPOS:
		d[k] = get(k)
	return d

func de_dict(d: Dictionary) -> void:
	novo_jogo()            # garante valores padrão para campos ausentes
	for k in CAMPOS:
		if d.has(k):
			var v = d[k]
			if CAMPOS_INT.has(k):
				v = int(v)
			set(k, v)
	# save v1: despensa única → nível 2
	if melhorias.has("despensa"):
		melhorias.erase("despensa")
		if not melhorias.has("despensa_2"):
			melhorias.append("despensa_2")
		nivel_despensa = maxi(nivel_despensa, 2)
	for id in ORDEM_PRATOS:
		if not pratos.has(id):
			pratos[id] = {"n": 0, "q": 2.0}
		pratos[id].n = int(pratos[id].n)
	# JSON devolve números como float: normaliza os campos inteiros usados em comparações
	for lista in [aventureiros, candidatos]:
		for a in lista:
			a.id = int(a.id); a.nivel = int(a.nivel); a.xp = int(a.xp)
			if not a.has("classe"):
				a.classe = _sortear_peso(CLASSE_POR_RACA["pesado" if String(a.get("variante", "")) == "pesado" else String(a.raca)])
			if not a.has("atrib"):
				a.atrib = _gerar_atributos(String(a.classe))
			if not a.has("buff"):
				a.buff = {}
			if not a.has("descanso"):
				a.descanso = 70.0
	for f in funcionarios:
		funcionarios[f].habilidade = int(funcionarios[f].habilidade)
		funcionarios[f].salario = int(funcionarios[f].salario)
	for f in candidatos_staff:
		for k in ["habilidade", "salario", "taxa"]:
			candidatos_staff[f][k] = int(candidatos_staff[f][k])
	if not rush_atual.is_empty():
		rush_atual.clientes = int(rush_atual.clientes)
		if String(rush_atual.status) == "jogando":
			rush_atual.status = "aguardando"      # fechou o app no meio do mini-game
	for c in contratos:
		c.id = int(c.id); c.grau = int(c.grau)
	for m in missoes:
		m.id = int(m.id)
		m.contrato.id = int(m.contrato.id); m.contrato.grau = int(m.contrato.grau)
		var ids: Array = []
		for i in m.herois:
			ids.append(int(i))
		m.herois = ids
	for r in retornos_pendentes:
		r.id = int(r.id)
	if candidatos_staff.is_empty():
		_renovar_candidatos_staff()
	_completar_quadro()
	_mudou()
