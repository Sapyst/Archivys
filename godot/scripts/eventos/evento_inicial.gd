## Abertura do jogo (docs/lore_no_jogo.md, "Abertura do jogo"): a casa é uma filial abandonada do Arquivo
## de Illamar no 4C8xx; o antigo dono sumiu num Mau'Vhin e a Mira ficou cuidando. Uma arquivista Rhosanih
## exige um nome novo no registro (Vhin'urr) e explica que o selo de filiação custa favores.
## 1) falas() → 2) o jogador digita o nome → 3) falas_registro(nome).
class_name EventoInicial
extends RefCounted

const MIRA := "res://assets/personagens/mira/recortes/%s.png"
const RHOS := "res://assets/personagens/rhosanih_f/recortes/%s.png"
# TODO: existe só rhosanih_f/recortes; quando houver rhosanih_m, sortear.

static func falas() -> Array:
	return [
		{"quem": "Mira", "retrato": MIRA % "04_surpresa", "lado": "esq", "texto": Txt.t("intro_1")},
		{"quem": Txt.t("speaker_archivist"), "retrato": RHOS % "falando", "lado": "dir", "texto": Txt.t("intro_2")},
		{"quem": "Mira", "retrato": MIRA % "07_triste", "lado": "esq", "texto": Txt.t("intro_3")},
		{"quem": Txt.t("speaker_archivist"), "retrato": RHOS % "falando", "lado": "dir", "texto": Txt.t("intro_4")},
		{"quem": Txt.t("speaker_archivist"), "retrato": RHOS % "parado", "lado": "dir", "texto": Txt.t("intro_5")},
	]

static func falas_registro(nome: String) -> Array:
	return [
		{"quem": Txt.t("speaker_archivist"), "retrato": RHOS % "falando", "lado": "dir", "texto": Txt.t("intro_6", [nome])},
		{"quem": "Mira", "retrato": MIRA % "02_feliz", "lado": "esq", "texto": Txt.t("intro_7")},
	]
