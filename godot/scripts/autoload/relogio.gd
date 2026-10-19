## Tempo de jogo (autoload "Relogio").
## App aberto: velocidade escolhida na placa "Dia N 60×" (ciclo 30× → 60× → 120× → 240×; padrão 60× =
## 1 min real = 1 h de jogo), salva em Jogo.velocidade_jogo. Abrir/fechar a guilda não muda o tempo.
## App fechado: 4× sempre, calculado pelo timestamp salvo, limitado a 72 h de jogo; delta negativo é ignorado.
extends Node

const VELOCIDADES := [30, 60, 120, 240]
const VEL_PADRAO := 60
const VEL_FECHADO := 4.0       # app fechado
const MAX_AUSENCIA_H := 72.0

var ativo := false        # só avança depois do carregamento / evento inicial

func velocidade() -> float:
	return float(Jogo.velocidade_jogo if VELOCIDADES.has(Jogo.velocidade_jogo) else VEL_PADRAO)

## Próxima velocidade do ciclo (toque na placa).
func alternar_velocidade() -> void:
	var i := VELOCIDADES.find(Jogo.velocidade_jogo)
	Jogo.velocidade_jogo = VELOCIDADES[(i + 1) % VELOCIDADES.size()]
	Jogo.mudou.emit()

func _process(delta: float) -> void:
	if ativo:
		Jogo.avancar(delta * velocidade() / 3600.0)

## Horas de jogo que passaram desde `timestamp_salvo` (segundos Unix) com o app fechado.
func horas_ausencia(timestamp_salvo: float) -> float:
	if timestamp_salvo <= 0.0:
		return 0.0
	var real := Time.get_unix_time_from_system() - timestamp_salvo
	if real <= 0.0:
		return 0.0          # relógio atrasado: ignora
	return minf(real * VEL_FECHADO / 3600.0, MAX_AUSENCIA_H)

func texto_placa() -> String:
	return Txt.t("clock_plate", [Jogo.dia(), int(velocidade())])
