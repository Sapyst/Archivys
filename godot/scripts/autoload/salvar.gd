## Salvar/carregar JSON em user:// com versão (autoload "Salvar").
extends Node

signal voltou(horas: float)        # app voltou do segundo plano: horas de jogo passadas fora

const CAMINHO := "user://guilda.json"
const VERSAO := 1
const INTERVALO_AUTO := 30.0

var timestamp_salvo := 0.0
var _t := 0.0

func existe() -> bool:
	return FileAccess.file_exists(CAMINHO)

func salvar() -> void:
	timestamp_salvo = Time.get_unix_time_from_system()
	var dados := {"versao": VERSAO, "timestamp": timestamp_salvo, "estado": Jogo.para_dict()}
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if f == null:
		push_error("Salvar: não abriu %s (%s)" % [CAMINHO, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(dados))
	f.close()

## true se carregou um save válido.
func carregar() -> bool:
	if not existe():
		return false
	var f := FileAccess.open(CAMINHO, FileAccess.READ)
	if f == null:
		return false
	var dados = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("estado"):
		push_warning("Salvar: arquivo inválido, começando do zero.")
		return false
	var versao := int(dados.get("versao", 0))
	if versao > VERSAO:
		push_warning("Salvar: save de versão mais nova (%d)." % versao)
	dados = _migrar(dados, versao)
	timestamp_salvo = float(dados.get("timestamp", 0.0))
	Jogo.de_dict(dados.estado)
	return true

func _migrar(dados: Dictionary, _versao: int) -> Dictionary:
	# TODO: quando VERSAO subir, converter campos antigos aqui.
	return dados

func apagar() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO))

func _process(delta: float) -> void:
	if not Relogio.ativo:
		return
	_t += delta
	if _t >= INTERVALO_AUTO:
		_t = 0.0
		salvar()

func _notification(what: int) -> void:
	if not Relogio.ativo:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		salvar()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var h := Relogio.horas_ausencia(timestamp_salvo)
		if h > 0.0:
			voltou.emit(h)
