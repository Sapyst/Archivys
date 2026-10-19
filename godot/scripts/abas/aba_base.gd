## Base das abas da área central. `principal` é o nó Principal (sem tipo: chamadas dinâmicas).
class_name AbaBase
extends MarginContainer

var principal

var rolagem: Rolagem
var lista: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("margin_left", 6 * Estilo.K)
	add_theme_constant_override("margin_right", 3 * Estilo.K)    # + 3 px de calha do indicador na lista
	add_theme_constant_override("margin_top", 2 * Estilo.K)
	add_theme_constant_override("margin_bottom", 2 * Estilo.K)
	montar()
	atualizar()

## Cria a estrutura fixa. Padrão: uma lista rolável.
func montar() -> void:
	criar_lista(self)

func criar_lista(pai: Control) -> void:
	# rola arrastando (com inércia); indicador metálico só enquanto rola, na calha de 3 px à direita;
	# folga de 14 px nativos no fim = altura do degradê do HUD inferior (o último item sobe acima dele)
	lista = VBoxContainer.new()
	rolagem = Rolagem.envolver(lista, 3, 14)
	rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pai.add_child(rolagem)

## Reconstrói o conteúdo (chamado quando Jogo.mudou).
func atualizar() -> void:
	pass

## Cartão tocável (painel) que chama `acao` ao ser tocado.
func cartao(acao: Callable = Callable(), cor: Color = Estilo.COR_PAINEL) -> PanelContainer:
	var p := Estilo.painel(cor)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if acao.is_valid():
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if Estilo.e_clique(e, p):
				acao.call())
	return p

func titulo(texto: String) -> Label:
	var l := Estilo.rotulo_px(texto, "t4", Estilo.COR_DOURADO)
	return l
