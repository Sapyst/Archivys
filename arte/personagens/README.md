# Guild Dungeon — Sistema de personagem (pixel art procedural)

Tudo desenhado por código, sem IA de imagem.

## Criador de personagem
`criador_de_personagem.html` — abrir no navegador. Camadas independentes:
- Corpo: 6 tons de pele naturais; olhos com coluna branca fixa + coluna de íris (cor variável)
- Cabelo: Curto, Longo, Rabo de cavalo, Coque, Tranças, Raspado (+ cor)
- Tronco: Túnica, Armadura, Manto, Colete (cor principal + detalhe)
- Pernas: Calça, Bermuda, Saia, Saia longa
- Calçado: Botas, Botas altas, Sandálias, Sapatilhas
Sombras derivadas da cor automaticamente. Exporta PNG e folha (idle 8 + andar 6).

## Estrutura do sprite (pixels nativos)
Ordem das camadas: cabelo-trás → pernas → saia → tronco → armas → cabeça → cabelo-frente → efeitos.
- Cabeça 20×15 (1 px maior que o tronco em cada lado), sobrepõe o tronco em 2 px
- Tronco 12×9 sem braços; armas são independentes com a mão como pegada (pivô = mão)
- Animação: tronco balança 1 px, cabeça balança menos (atrasada)

## Geradores Python (`geradores/`)
- `guerreira_v3.py` — armas (espada, espadão, duas espadas, arco, cajados de fogo/água/elétrico/vento),
  3 ataques por arma, idle, andar em 8 direções. Saída em `sprites/armas_e_ataques/`.
- Requer Pillow: `python -m venv .venv && .venv/bin/pip install pillow && .venv/bin/python guerreira_v3.py`
