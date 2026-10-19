## Camada de diálogo: monta por código a árvore que ui/caixa_dialogo.gd espera, com retrato do falante.
## Tudo em pixels nativos ampliados por escala INTEIRA (×3, nearest): a corda do 9-slice fica nítida.
## - Fundo escurece e desfoca levemente durante a conversa.
## - O retrato fica recortado na linha de cima da janela: entra subindo de trás dela e sai antes de ela fechar.
## - Cursiva Snide Asides PT 48 (= 16 nativo ×3), sem antialiasing/hinting (ver .import).
class_name CenaDialogo
extends CanvasLayer

const E := 3                              # escala do diálogo
const JW := 224                           # janela (px nativos): (JW−26) e (JH−26) múltiplos de 6 → trança contínua
const JH := 80                            # 3 linhas + faixa da seta abaixo da última linha
const LH := 15                            # altura de linha nativa da Snide
## Área segura: corda 7 px + sombra interna 3 px + respiro 4 px = 14 px de cada lado (a paginação ainda
## desconta 3 px de inclinação da cursiva à direita — ver caixa_dialogo.gd folga_inclinacao).
const MARGEM_TXT := 14
const TOPO_TXT := 12
const LARG_RETRATO := 600.0
const COR_TEXTO := Color8(236, 224, 204)
const COR_NOME := Color8(40, 24, 16)

const _SHADER_FUNDO := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float quanto : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = textureLod(tela, SCREEN_UV, quanto * 1.6).rgb;
	COLOR = vec4(c * (1.0 - 0.5 * quanto), 1.0);
}
"""

var caixa: Control
var retrato: TextureRect
var _bloqueio: ColorRect
var _fundo_mat: ShaderMaterial
var _palco: Control
var _placa: NinePatchRect
var _nome: Label
var _retrato_atual := ""
var _y_retrato := 0.0

func _ready() -> void:
	layer = 50
	var vp := get_viewport().get_visible_rect().size

	_bloqueio = ColorRect.new()               # escurece + desfoca o que está atrás; também recebe os toques
	_fundo_mat = ShaderMaterial.new()
	_fundo_mat.shader = Shader.new()
	_fundo_mat.shader.code = _SHADER_FUNDO
	_bloqueio.material = _fundo_mat
	_bloqueio.position = Vector2.ZERO
	_bloqueio.size = vp
	_bloqueio.mouse_filter = Control.MOUSE_FILTER_STOP
	_bloqueio.gui_input.connect(_ao_tocar)
	add_child(_bloqueio)

	var jw := JW * E
	var jh := JH * E
	var jpos := Vector2(roundi((vp.x - jw) / 2.0), vp.y - jh - 8 * E - 8)

	# palco do retrato: termina na linha de cima da janela (centro da corda) → o retrato some atrás dela
	_palco = Control.new()
	_palco.clip_contents = true
	_palco.position = Vector2.ZERO
	_palco.size = Vector2(vp.x, jpos.y + 4 * E)
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)
	retrato = TextureRect.new()
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_palco.add_child(retrato)
	_y_retrato = jpos.y + 14 * E                # base do retrato fica 14 px nativos abaixo do topo (escondida)

	caixa = Control.new()
	caixa.set_script(load("res://ui/caixa_dialogo.gd"))
	caixa.set("escala", float(E))
	caixa.set("fechar_no_fim", false)
	caixa.position = jpos
	caixa.size = Vector2(jw, jh)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var janela := NinePatchRect.new()
	janela.name = "Janela"
	janela.texture = Estilo.ui("janela_corda_9slice", E)
	for lado in ["left", "top", "right", "bottom"]:
		janela.set("patch_margin_" + lado, 13 * E)
	janela.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	janela.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	janela.position = Vector2.ZERO
	janela.size = Vector2(jw, jh)
	caixa.add_child(janela)

	_placa = NinePatchRect.new()
	_placa.name = "Placa"
	_placa.texture = Estilo.ui("placa_14", E)
	_placa.patch_margin_left = 4 * E; _placa.patch_margin_right = 4 * E
	_placa.patch_margin_top = 6 * E; _placa.patch_margin_bottom = 7 * E
	_placa.position = Vector2(8 * E, -7 * E)
	_placa.size = Vector2(40 * E, 14 * E)
	caixa.add_child(_placa)

	_nome = Label.new()
	_nome.name = "Nome"
	_nome.add_theme_font_override("font", Estilo.fonte_fala())
	_nome.add_theme_font_size_override("font_size", 16 * E)
	_nome.add_theme_color_override("font_color", COR_NOME)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caixa.add_child(_nome)        # caixa_dialogo.gd espera $Nome como filho direto; _process segue a placa

	var fonte := Estilo.fonte_fala()
	var texto := Label.new()
	texto.name = "Texto"
	texto.add_theme_font_override("font", fonte)
	texto.add_theme_font_size_override("font_size", 16 * E)
	texto.add_theme_color_override("font_color", COR_TEXTO)
	texto.add_theme_constant_override("line_spacing", LH * E - int(fonte.get_height(16 * E)))
	texto.autowrap_mode = TextServer.AUTOWRAP_OFF
	texto.clip_text = true
	texto.position = Vector2(MARGEM_TXT * E, TOPO_TXT * E)
	texto.size = Vector2((JW - 2 * MARGEM_TXT) * E, 3 * LH * E)
	caixa.add_child(texto)

	var seta := TextureRect.new()
	seta.name = "Seta"
	seta.texture = Estilo.textura_px("res://assets/ui/seta_continuar.png", E)
	seta.position = Vector2((JW - 22) * E, (JH - 19) * E)      # dentro da área segura, abaixo da 3ª linha
	seta.size = Vector2(7 * E, 6 * E)
	caixa.add_child(seta)

	var fim := TextureRect.new()              # quadradinho de fim (contorno + miolo de corda clara)
	fim.name = "Fim"
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color8(28, 18, 16))
	img.fill_rect(Rect2i(1, 1, 3, 3), Color8(214, 176, 118))
	img.resize(5 * E, 5 * E, Image.INTERPOLATE_NEAREST)
	fim.texture = ImageTexture.create_from_image(img)
	fim.position = Vector2((JW - 21) * E, (JH - 18) * E)
	fim.size = Vector2(5 * E, 5 * E)
	caixa.add_child(fim)

	add_child(caixa)
	# a camada repassa os toques (só mouse/emulado) — evita avançar 2× com toque + mouse emulado
	caixa.set_process_unhandled_input(false)

func _process(_delta: float) -> void:
	if _nome != null and _placa != null:
		_nome.visible = _placa.visible
		_nome.position = _placa.position + Vector2(0, -2 * E)
		_nome.size = _placa.size

func _ajustar_placa(quem: String) -> void:
	var f := Estilo.fonte_fala()
	var w := f.get_string_size(quem, HORIZONTAL_ALIGNMENT_LEFT, -1, 16 * E).x
	_placa.size = Vector2(ceili(w / E) * E + 14 * E, 14 * E)

func _textura_retrato(caminho: String) -> Texture2D:
	var t := Estilo.textura(caminho)
	if t == null:
		return null
	var img := t.get_image()
	var alt := int(img.get_height() * LARG_RETRATO / img.get_width())
	img.resize(int(LARG_RETRATO), alt, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _retrato_entra(caminho: String, lado: String) -> void:
	retrato.texture = _textura_retrato(caminho)
	_retrato_atual = caminho
	if retrato.texture == null:
		return
	retrato.size = retrato.texture.get_size()
	var desloc := -60.0 if lado == "esq" else 60.0
	retrato.position = Vector2(roundf((_palco.size.x - retrato.size.x) / 2.0 + desloc), _y_retrato - retrato.size.y + retrato.size.y * 0.35)
	retrato.modulate.a = 0.0
	retrato.show()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(retrato, "position:y", _y_retrato - retrato.size.y, 0.28)
	tw.tween_property(retrato, "modulate:a", 1.0, 0.16)
	await tw.finished

func _retrato_sai() -> void:
	if not retrato.visible or retrato.texture == null:
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(retrato, "position:y", _y_retrato - retrato.size.y * 0.6, 0.18)
	tw.tween_property(retrato, "modulate:a", 0.0, 0.18)
	await tw.finished
	retrato.hide()
	_retrato_atual = ""

func _fundo(alvo: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _fundo_mat.set_shader_parameter("quanto", v),
		float(_fundo_mat.get_shader_parameter("quanto")), alvo, dur)
	await tw.finished

## falas: Array de {quem, texto, retrato (caminho), lado ("esq"/"dir")}
func rodar(falas: Array) -> void:
	_fundo_mat.set_shader_parameter("quanto", 0.0)
	_fundo(1.0, 0.25)
	for i in falas.size():
		var f: Dictionary = falas[i]
		var caminho := String(f.retrato)
		var lado := String(f.get("lado", "esq"))
		_ajustar_placa(String(f.quem))
		if caminho != _retrato_atual:
			if i == 0:
				_retrato_entra(caminho, lado)          # surge junto com a janela
			else:
				await _retrato_sai()
				await _retrato_entra(caminho, lado)
		await caixa.falar(String(f.quem), String(f.texto))
		await caixa.terminou
	await _retrato_sai()                            # sai ANTES da janela fechar
	_fundo(0.0, 0.2)
	await caixa.fechar()
	queue_free()

func _ao_tocar(evento: InputEvent) -> void:
	if Estilo.e_toque(evento):
		caixa._unhandled_input(evento)
