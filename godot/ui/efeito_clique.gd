## Spark de clique (8 direções) onde o jogador toca — em qualquer tela.
## Coloque como Autoload (CanvasLayer alto) e aponte `folha` para spark_sheet.png (7 quadros de 19×19).
extends CanvasLayer

@export var folha: Texture2D = load("res://assets/ui/spark_sheet.png")
@export var quadros := 7
@export var fps := 22.0
@export var escala := 4.0

func _ready() -> void:
	layer = 100

func _input(evento: InputEvent) -> void:
	var toque: bool = (evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT) \
		or (evento is InputEventScreenTouch and evento.pressed)
	if toque:
		_soltar(evento.position)      # _input não consome o evento: a UI embaixo continua recebendo o toque

func _soltar(onde: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", fps)
	var lado := folha.get_width() / quadros
	for i in quadros:
		var a := AtlasTexture.new(); a.atlas = folha; a.region = Rect2(i * lado, 0, lado, folha.get_height())
		frames.add_frame("default", a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames; s.position = onde; s.scale = Vector2.ONE * escala
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s); s.play()
	s.animation_finished.connect(s.queue_free)
