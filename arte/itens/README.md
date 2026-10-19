# Itens e magias — Guild Dungeon

Gerados por código (Pillow), sem IA. Para regenerar (de `arte/geradores/`):
    python gerar_itens.py   # props, armas, armaduras, cena
    python magias.py        # GIFs de magia

- `geradores/base.py` — grade com contorno automático, paleta, personagem em camadas
  (pernas → saia → peitoral → arma → cabeça → cabelo → capacete), armas com pivô na mão.
- **props/**: caixas (4), barris (4), mesas (4), cadeiras/bancos (4) + `_folha_props.png`
- **armas/**: Adaga, Espada, Espadão, Machado, Maça, Lança, Arco × Bronze/Ferro/Mithril/Obsidiana
  + 4 cajados elementais. Ícones de inventário e sprites com mão (pivô) para o golpe.
- **armaduras/**: peitorais Túnica, Couro, Malha, Placas, Manto; capacetes Capuz de couro,
  Elmo de ferro, Elmo fechado, Capuz, Chapéu de mago. Metal muda de cor pelo material.
- **magias/**: por elemento — bolt até qualquer ponto (velocidade fixa) e magia de área
  com raio variável no ponto escolhido (`cast_bolt(tl, alvo)`, `cast_area(tl, centro, raio)`).
