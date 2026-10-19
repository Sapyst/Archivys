## Trilha sonora: toca em loop e faz crossfade entre faixas (idle ↔ rush ↔ kitchen).
## Faixas em res://assets/musica/<nome>.ogg; se uma faixa ainda não existir, continua na atual.
extends Node

const FAIXAS := {
	"menu": "res://assets/musica/menu_rest_for_the_wayward.ogg",     # abertura / lore / nome da guilda
	"idle": "res://assets/musica/idle_archivists_hearth.ogg",         # guilda (fora dos mini-games)
	"rush": "res://assets/musica/lunch_rush.ogg",
	"kitchen": "res://assets/musica/kitchen.ogg",
}
const VOLUME := {"menu": -14.0, "idle": -14.0, "rush": -10.0, "kitchen": -12.0}   # dB (mixagem pedida nos prompts)
const FADE := 1.2                                                 # s de crossfade

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var atual := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new(); _b = AudioStreamPlayer.new()
	add_child(_a); add_child(_b)
	# primeira abertura (sem save) começa com a música de abertura; principal.gd chama tocar("idle") ao fim da lore
	tocar("idle" if FileAccess.file_exists("user://guilda.json") else "menu")

func tocar(nome: String) -> void:
	if nome == atual or not FAIXAS.has(nome) or not ResourceLoader.exists(FAIXAS[nome]): return
	var stream := load(FAIXAS[nome]) as AudioStreamOggVorbis
	if stream == null: return
	stream.loop = true
	var sai := _a if _a.playing else null
	var entra := _b if sai == _a else _a
	entra.stream = stream; entra.volume_db = -60.0; entra.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(entra, "volume_db", VOLUME.get(nome, -14.0), FADE)
	if sai: tw.tween_property(sai, "volume_db", -60.0, FADE)
	atual = nome
	if sai: tw.chain().tween_callback(sai.stop)
