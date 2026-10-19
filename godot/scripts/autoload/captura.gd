## Modo de captura para testes (só ativo com a variável de ambiente GD_CAPTURA=<pasta>).
## Fixa a tela em 720×1280 (aspect keep), executa uma sequência de toques e salva prints numerados.
## GD_ROTEIRO = "espera:2;print;toque:360,1220;espera:1;print" (coordenadas do canvas 720×1280)
## Passos: espera:s | print | toque:x,y | arrasta:x1,y1,x2,y2,segundos (press → movimentos → release,
## injetando mouse com button_mask esquerdo E ScreenTouch/ScreenDrag, como num celular)
## | digita:texto (teclas com unicode no controle com foco; "_" vira espaço) | tecla:Enter|BackSpace|...
## | avanca:h (avança h horas de jogo — teste de rushes/missões) | estado (imprime um resumo do Jogo).
extends Node

var _pasta := ""
var _passos: PackedStringArray = []
var _n := 0

func _ready() -> void:
	_pasta = OS.get_environment("GD_CAPTURA")
	if _pasta.is_empty():
		set_process(false); return
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_size(Vector2i(540, 960))
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT   # print sai em 720×1280 exatos
	var r := OS.get_environment("GD_ROTEIRO")
	_passos = r.split(";", false) if not r.is_empty() else PackedStringArray(["espera:3", "print"])
	_rodar.call_deferred()

func _rodar() -> void:
	for p in _passos:
		var partes := p.split(":")
		match partes[0]:
			"espera":
				await get_tree().create_timer(float(partes[1])).timeout
			"print":
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				_n += 1
				img.save_png("%s/cap_%02d.png" % [_pasta, _n])
			"toque":
				var xy := partes[1].split(",")
				_tocar(Vector2(float(xy[0]), float(xy[1])))
				await get_tree().create_timer(0.15).timeout
			"digita":
				for ch in partes[1].replace("_", " "):
					for apertada in [true, false]:
						var k := InputEventKey.new()
						k.pressed = apertada
						k.unicode = ch.unicode_at(0)
						k.keycode = OS.find_keycode_from_string(ch) if ch != " " else KEY_SPACE
						Input.parse_input_event(k)
					await get_tree().process_frame
			"tecla":
				for apertada in [true, false]:
					var k2 := InputEventKey.new()
					k2.pressed = apertada
					k2.keycode = OS.find_keycode_from_string(partes[1])
					Input.parse_input_event(k2)
				await get_tree().process_frame
			"estado":
				var j := get_node("/root/Jogo")
				print("ESTADO dia=%d hora=%s moedas=%d fama=%d porcoes=%d prov=%d herois=%d missoes=%d retornos=%d rush=%s" % [j.dia(),
					j.texto_hora(), j.moedas, j.fama, j.total_porcoes(), int(j.provisoes), j.vivos(), j.missoes.size(),
					j.retornos_pendentes.size(), str(j.rush_atual)])
			"avanca":
				get_node("/root/Jogo").avancar(float(partes[1]))
				await get_tree().process_frame
			"arrasta":
				var v := partes[1].split(",")
				await _arrastar(Vector2(float(v[0]), float(v[1])), Vector2(float(v[2]), float(v[3])),
					float(v[4]) if v.size() > 4 else 0.4)
	get_tree().quit()

func _tocar(pos: Vector2) -> void:
	var t := get_viewport().get_screen_transform() * get_viewport().get_canvas_transform()
	var tela := get_viewport().get_final_transform() * pos
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = tela; e.global_position = tela
		Input.parse_input_event(e)

## Arraste: press → ~60 movimentos/s (mouse com botão esquerdo + ScreenDrag) → release.
func _arrastar(de: Vector2, ate: Vector2, segundos: float) -> void:
	var xf := get_viewport().get_final_transform()
	var passos := maxi(6, int(segundos * 60.0))
	var ant := xf * de
	_botao(ant, true)
	await get_tree().process_frame
	for i in range(1, passos + 1):
		await get_tree().process_frame
		var pos := xf * de.lerp(ate, float(i) / passos)
		var rel := pos - ant
		var vel := rel * 60.0
		var mm := InputEventMouseMotion.new()
		mm.position = pos; mm.global_position = pos
		mm.relative = rel; mm.velocity = vel
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		var sd := InputEventScreenDrag.new()
		sd.index = 0; sd.position = pos; sd.relative = rel; sd.velocity = vel
		Input.parse_input_event(sd)
		ant = pos
	_botao(ant, false)
	await get_tree().create_timer(0.1).timeout

func _botao(pos: Vector2, apertado: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = apertado; e.position = pos; e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	Input.parse_input_event(e)
	var t := InputEventScreenTouch.new()
	t.index = 0; t.pressed = apertado; t.position = pos
	Input.parse_input_event(t)
