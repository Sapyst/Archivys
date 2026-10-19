## Estilo dos menus — pixel art em escala inteira (UI nativa 180×320 → ×4 = 720×1280).
## Painéis: metal minimalista em 9-slice (arte/geradores/ui_metal.py → exportar_godot.py).
## Fontes: técnica bitmap 5×7 com sombra (menus/HUD), mini 3×5 (rótulos), cursiva Snide Asides PT SÓ nas falas.
## Corda é SÓ para diálogo (ui/caixa_dialogo.gd + scripts/ui/cena_dialogo.gd).
class_name Estilo
extends RefCounted

const K := 4                          # 1 pixel nativo da UI = 4 px do canvas

const COR_FUNDO := Color8(24, 17, 20)
const COR_PAINEL := Color8(28, 22, 24)
const COR_PAINEL_ESCURO := Color8(20, 15, 17)
const COR_PAINEL_CLARO := Color8(46, 37, 40)
const COR_SOMBRA := Color8(12, 8, 10)
const COR_TEXTO := Color8(240, 230, 212)
const COR_FRACO := Color8(170, 156, 140)
const COR_SUB := Color8(205, 190, 170)
const COR_DOURADO := Color8(214, 176, 118)     # = corda clara (títulos e aba ativa, como na prévia)
const COR_OURO := Color8(242, 193, 78)
const COR_VERDE := Color8(120, 200, 110)
const COR_VERMELHO := Color8(230, 90, 70)
const COR_AZUL := Color8(98, 168, 220)
const COR_LARANJA := Color8(227, 139, 60)
const COR_TINTA := Color8(40, 26, 22)          # texto no balão creme
const COR_PLACA := Color8(40, 24, 16)          # texto escuro nas placas

const ICONES := "res://assets/ui/icones/%s_%d.png"
const UI := "res://assets/ui/%s.png"
const FONTE_FALA := "res://assets/fontes/SnideAsidesPT.ttf"
const FONTES := {
	"t4": "res://assets/fontes/tecnica_4x.fnt", "t3": "res://assets/fontes/tecnica_3x.fnt",
	"l4": "res://assets/fontes/tecnica_4x_lisa.fnt", "l3": "res://assets/fontes/tecnica_3x_lisa.fnt",
	"m4": "res://assets/fontes/mini_4x.fnt", "m3": "res://assets/fontes/mini_3x.fnt",
}
const TAM_FONTE := {"t4": 48, "t3": 36, "l4": 48, "l3": 36, "m4": 36, "m3": 27}

const _SHADER_CINZA := """
shader_type canvas_item;
uniform float sat = 0.3;
uniform float brilho = 0.65;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(g), c.rgb, sat) * brilho;
	COLOR = c;
}
"""

static var _cache := {}
static var _material_cinza: ShaderMaterial

# ---------------------------------------------------------------- texturas
static func textura(caminho: String) -> Texture2D:
	if not _cache.has(caminho):
		var t: Texture2D = null
		if ResourceLoader.exists(caminho):
			t = load(caminho) as Texture2D
		_cache[caminho] = t
	return _cache[caminho]

## Textura ampliada k× com nearest (para 9-slices e StyleBoxTexture: margens em px já ampliados).
static func textura_px(caminho: String, k: int = K) -> Texture2D:
	var chave := "%s@%d" % [caminho, k]
	if not _cache.has(chave):
		var base := textura(caminho)
		var t: Texture2D = null
		if base != null:
			var img := base.get_image()
			if img.is_compressed():
				img.decompress()
			img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
			t = ImageTexture.create_from_image(img)
		_cache[chave] = t
	return _cache[chave]

## Emblema de classe (assets/classes/<classe>.png, 32×32). Sem o arquivo importado, tenta o PNG cru;
## sem nada, cai no ícone genérico de aventureiros (28 px).
static func emblema_classe(classe: String) -> Texture2D:
	var caminho := "res://assets/classes/%s.png" % classe
	var chave := "emblema:" + classe
	if not _cache.has(chave):
		var t: Texture2D = null
		if ResourceLoader.exists(caminho):
			t = load(caminho) as Texture2D
		elif FileAccess.file_exists(caminho):
			var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
			if img != null and not img.is_empty():
				t = ImageTexture.create_from_image(img)
		if t == null:
			t = icone("aventureiros", 28)
		_cache[chave] = t
	return _cache[chave]

## Emblema em TextureRect quadrado de `lado` px (nearest; 32 px nativos → ×2 = 64).
static func emblema_rect(classe: String, lado: int = 64) -> TextureRect:
	var r := TextureRect.new()
	r.texture = emblema_classe(classe)
	r.custom_minimum_size = Vector2(lado, lado)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Prato em pixel art (assets/pratos/px/<id>_32.png, canvas 36) — exibir em múltiplo inteiro.
static func prato_rect(id: String, escala: int = 2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = textura("res://assets/pratos/px/%s_32.png" % id)
	r.custom_minimum_size = Vector2(36 * escala, 36 * escala)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Estrelas de qualidade (ícone de fama 18 px ×2; apagadas em cinza). q pode ser fracionário (arredonda).
static func estrelas(q: float, tam: int = 18, escala: int = 2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := int(round(q))
	for k in 3:
		var st := icone_rect("fama", tam, escala)
		if k >= n:
			st.material = material_cinza()
			st.modulate = Color(1, 1, 1, 0.5)
		h.add_child(st)
	return h

static func ui(nome: String, k: int = K) -> Texture2D:
	return textura_px(UI % nome, k)

static func icone(nome: String, tam: int = 24) -> Texture2D:
	return textura(ICONES % [nome, tam])

## Ícone pixelizado em escala inteira (nearest herdado do projeto).
static func icone_rect(nome: String, tam: int = 24, escala: int = 2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icone(nome, tam)
	r.custom_minimum_size = Vector2(tam * escala, tam * escala)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## 9-slice nativo → StyleBoxTexture ampliado k× (margem em px nativos).
static func caixa_9(nome: String, margem_px: int, conteudo := Vector4(5, 4, 5, 4), k: int = K) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = ui(nome, k)
	s.set_texture_margin_all(margem_px * k)
	s.content_margin_left = conteudo.x * k
	s.content_margin_top = conteudo.y * k
	s.content_margin_right = conteudo.z * k
	s.content_margin_bottom = conteudo.w * k
	return s

## Painel metálico (menus). `cor` escolhe a variante (compatível com as chamadas antigas).
static func caixa_painel(cor: Color = COR_PAINEL, _raio: int = 0, margem: int = 16) -> StyleBoxTexture:
	var nome := "metal_9slice"
	if cor == COR_PAINEL_ESCURO:
		nome = "metal_escuro"
	elif cor == COR_PAINEL_CLARO:
		nome = "metal_botao"
	# área segura do texto: aro metálico (contorno 1 + aro 2 + filete 1 = 4 px) + respiro → mín. 6 px nos lados, 5 em cima/baixo
	var m := margem / float(K)
	var mh := maxf(m, 6.0)
	var mv := maxf(m, 5.0)
	return caixa_9(nome, 6, Vector4(mh, mv, mh, mv))

# ---------------------------------------------------------------- fontes
static func fonte(tipo: String) -> Font:
	var c: String = FONTES.get(tipo, FONTES.t3)
	if not _cache.has(c):
		_cache[c] = load(c) as Font
	return _cache[c]

static func fonte_fala() -> Font:
	if not _cache.has(FONTE_FALA):
		_cache[FONTE_FALA] = load(FONTE_FALA) as Font
	return _cache[FONTE_FALA]

static func aplicar_fonte(c: Control, tipo: String) -> void:
	c.add_theme_font_override("font", fonte(tipo))
	c.add_theme_font_size_override("font_size", TAM_FONTE[tipo])

## Tamanhos antigos (px de fonte do sistema) → fonte bitmap: ≥24 = técnica ×4, senão técnica ×3.
static func tipo_por_tam(tam: int) -> String:
	return "t4" if tam >= 24 else "t3"

# ---------------------------------------------------------------- tema
static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = fonte("t3")
	t.default_font_size = TAM_FONTE.t3
	t.set_color("font_color", "Label", COR_TEXTO)
	t.set_constant("line_spacing", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", caixa_painel())
	t.set_stylebox("panel", "Panel", caixa_painel())
	var cm := Vector4(5, 3, 5, 3)
	t.set_stylebox("normal", "Button", caixa_9("metal_botao", 6, cm))
	t.set_stylebox("hover", "Button", caixa_9("metal_botao_hover", 6, cm))
	var ap := caixa_9("metal_botao_apertado", 6, Vector4(5, 4, 5, 2))   # afunda 1 px
	t.set_stylebox("pressed", "Button", ap)
	t.set_stylebox("hover_pressed", "Button", ap)
	var off := caixa_9("metal_escuro", 6, cm)
	off.modulate_color = Color(1, 1, 1, 0.55)
	t.set_stylebox("disabled", "Button", off)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COR_TEXTO)
	t.set_color("font_hover_color", "Button", COR_TEXTO)
	t.set_color("font_pressed_color", "Button", COR_OURO)
	t.set_color("font_hover_pressed_color", "Button", COR_OURO)
	t.set_color("font_disabled_color", "Button", COR_FRACO)
	for tipo in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", tipo, caixa_9("metal_escuro", 6, cm))
		t.set_stylebox("hover", tipo, caixa_9("metal_9slice", 6, cm))
		t.set_stylebox("pressed", tipo, caixa_9("metal_botao", 6, cm))
		t.set_stylebox("hover_pressed", tipo, caixa_9("metal_botao_hover", 6, cm))
		t.set_stylebox("disabled", tipo, off)
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
		t.set_color("font_color", tipo, COR_SUB)
		t.set_color("font_pressed_color", tipo, COR_OURO)
		t.set_color("font_hover_pressed_color", tipo, COR_OURO)
		t.set_color("font_disabled_color", tipo, COR_FRACO)
	# interruptor pixel 14×8 nativo (×4): desligado = trilho escuro, botão cinza à esquerda; ligado = verde, botão dourado à direita
	var sw_off := _textura_mapa(["..OOOOOOOOOO..", ".ODDDDDDDDDDDO.", "OGGGGDDDDDDDDO", "OGWGGDDDDDDDDO", "OGGGGDDDDDDDDO", "OGGGGDDDDDDDDO", ".ODDDDDDDDDDDO.", "..OOOOOOOOOO.."],
		{"O": Color8(16, 12, 14), "D": Color8(52, 42, 44), "G": Color8(150, 144, 140), "W": Color8(200, 196, 190)})
	var sw_on := _textura_mapa(["..OOOOOOOOOO..", ".OVVVVVVVVVVO.", "OVVVVVVVVYYYYO", "OVVVVVVVVYWYYO", "OVVVVVVVVYYYYO", "OVVVVVVVVYYYYO", ".OVVVVVVVVVVO.", "..OOOOOOOOOO.."],
		{"O": Color8(16, 12, 14), "V": Color8(70, 140, 70), "Y": Color8(242, 193, 78), "W": Color8(255, 240, 190)})
	for ic in ["checked", "checked_disabled"]:
		t.set_icon(ic, "CheckButton", sw_on)
	for ic in ["unchecked", "unchecked_disabled"]:
		t.set_icon(ic, "CheckButton", sw_off)
	var fundo_barra := StyleBoxFlat.new()
	fundo_barra.bg_color = Color8(20, 14, 16)
	fundo_barra.border_color = COR_SOMBRA
	fundo_barra.set_border_width_all(K / 2)
	fundo_barra.anti_aliasing = false
	t.set_stylebox("background", "ProgressBar", fundo_barra)
	# campo de texto (nome da guilda): metal escuro; com foco = borda dourada (destaque)
	t.set_stylebox("normal", "LineEdit", caixa_9("metal_escuro", 6, Vector4(6, 4, 6, 4)))
	t.set_stylebox("focus", "LineEdit", caixa_9("metal_dourado", 6, Vector4(6, 4, 6, 4)))
	t.set_stylebox("read_only", "LineEdit", caixa_9("metal_escuro", 6, Vector4(6, 4, 6, 4)))
	t.set_font("font", "LineEdit", fonte("l4"))
	t.set_font_size("font_size", "LineEdit", TAM_FONTE.l4)
	t.set_color("font_color", "LineEdit", COR_TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", COR_FRACO)
	t.set_color("caret_color", "LineEdit", COR_OURO)
	t.set_color("selection_color", "LineEdit", Color(0.84, 0.69, 0.46, 0.45))
	t.set_constant("caret_width", "LineEdit", K)
	t.set_constant("separation", "VBoxContainer", 2 * K)
	t.set_constant("separation", "HBoxContainer", 2 * K)
	var vazio := StyleBoxEmpty.new()
	t.set_stylebox("scroll", "VScrollBar", vazio)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color8(118, 114, 112, 120)
	grab.content_margin_left = 4; grab.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return t

## Textura pixel a partir de um mapa de caracteres (ampliada k× nearest). Linhas mais curtas são completadas com vazio.
static func _textura_mapa(mapa: Array, cores: Dictionary, k: int = K) -> Texture2D:
	var w := 0
	for l in mapa:
		w = maxi(w, String(l).length())
	var img := Image.create(w, mapa.size(), false, Image.FORMAT_RGBA8)
	for y in mapa.size():
		var linha := String(mapa[y])
		for x in linha.length():
			if cores.has(linha[x]):
				img.set_pixel(x, y, cores[linha[x]])
	img.resize(w * k, mapa.size() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- widgets
static func rotulo(texto: String, tam: int = 22, cor: Color = COR_TEXTO, quebra: bool = false) -> Label:
	return rotulo_px(texto, tipo_por_tam(tam), cor, quebra)

## tipo: t4/t3 (técnica com sombra), l4/l3 (sem sombra), m4/m3 (mini 3×5 caixa alta).
static func rotulo_px(texto: String, tipo: String = "t3", cor: Color = COR_TEXTO, quebra: bool = false) -> Label:
	var l := Label.new()
	l.text = texto.to_upper() if tipo.begins_with("m") else texto
	aplicar_fonte(l, tipo)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func botao(texto: String, acao: Callable, habilitado: bool = true) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 16 * K)
	b.disabled = not habilitado
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART    # texto longo quebra dentro do botão (nunca alarga a tela)
	b.pressed.connect(acao)
	return b

static func barra(valor: float, maximo: float, cor: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = maximo
	p.value = valor
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 3 * K)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f := StyleBoxFlat.new()
	f.bg_color = cor
	f.anti_aliasing = false
	f.expand_margin_top = -K / 2; f.expand_margin_bottom = -K / 2
	p.add_theme_stylebox_override("fill", f)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Ícone + barra numa linha (para necessidades).
static func linha_barra(icone_nome: String, valor: float, maximo: float, cor: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icone_rect(icone_nome, 24, 2))
	h.add_child(barra(valor, maximo, cor))
	return h

static func linha_icone(icone_nome: String, texto: String, tam: int = 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icone_rect(icone_nome, 24, 2))
	var l := rotulo(texto, tam, COR_TEXTO, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

static func painel(cor: Color = COR_PAINEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", caixa_painel(cor))
	return p

## Corda horizontal tileável (só HUD/diálogo).
static func corda_h() -> TextureRect:
	var r := TextureRect.new()
	r.texture = ui("corda_h")
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = Vector2(0, 7 * K)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Placa de madeira (9-slice só na horizontal) com texto escuro centralizado.
static func placa(texto: String, tipo: String = "l4", altura_px: int = 13, k: int = K) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = textura_px(UI % ("placa_%d" % altura_px), k)
	p.patch_margin_left = 4 * k; p.patch_margin_right = 4 * k
	p.patch_margin_top = 6 * k; p.patch_margin_bottom = (altura_px - 7) * k
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := rotulo_px(texto, tipo, COR_PLACA)
	l.name = "Texto"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	p.add_child(l)
	ajustar_placa(p, texto)
	return p

static func ajustar_placa(p: NinePatchRect, texto: String, k: int = K) -> void:
	var l := p.get_node("Texto") as Label
	l.text = texto
	var f := l.get_theme_font("font")
	var tam := l.get_theme_font_size("font_size")
	var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var h := p.texture.get_height()
	p.custom_minimum_size = Vector2(w + 12 * k, h)
	p.size = p.custom_minimum_size
	# a linha da fonte reserva 2 px de acento em cima → centraliza pelos 7 px reais da letra
	var hn := h / k
	l.position = Vector2(0, floori((hn - 7) / 2.0 - 2.0) * k)
	l.size = Vector2(p.size.x, tam)

static func material_cinza() -> ShaderMaterial:
	if _material_cinza == null:
		var sh := Shader.new()
		sh.code = _SHADER_CINZA
		_material_cinza = ShaderMaterial.new()
		_material_cinza.shader = sh
	return _material_cinza

static func limpar(no: Node) -> void:
	for f in no.get_children():
		no.remove_child(f)
		f.queue_free()

static func e_toque(evento: InputEvent) -> bool:
	## Só mouse (o toque é emulado como mouse por padrão) — evita contar 2× no celular.
	var mb := evento as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT

## Clique de cartão (age no release): botão esquerdo solto DENTRO do controle e sem arraste no gesto
## (ver Rolagem: o dedo andou ≥ 12 px → era rolagem, não clique).
static func e_clique(evento: InputEvent, c: Control) -> bool:
	var mb := evento as InputEventMouseButton
	return mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
		and Rect2(Vector2.ZERO, c.size).has_point(mb.position) and Rolagem.clique_valido()

static func texto_horas(h: float) -> String:
	if h < 1.0:
		return "%d min" % int(h * 60.0)
	return "%dh%02d" % [int(h), int((h - floor(h)) * 60.0)]
