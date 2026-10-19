# Balanceamento — Archivys Alpha v0.1

Fonte da verdade: `godot/scripts/autoload/jogo.gd` (constantes no topo). Simulação: `godot/scripts/sim/simulacao.gd`
(usa o código REAL do jogo). Rodar:

```
G="$HOME/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64"
"$G" --headless --path godot res://cenas/simulacao.tscn -- dias=20 seeds=30 perfil=engajado   # ou perfil=casual
```

Tempo: 1 dia de jogo = 24 min reais a 60× (app fechado: 4×, máx. 72 h). Dia 1 começa às **10:00** (depois da abertura).

## 1. Dia e rushes
| Rush | Janela | Clientes base |
|---|---|---|
| Breakfast Rush | 07:00–09:00 | 6 |
| Lunch Rush | 12:00–14:00 | 9 |
| Supper Rush | 19:00–21:00 | 11 |

- **Clientes** = round(base × demanda), mínimo 3, máximo = **assentos**.
  - demanda = 1 + 0,12 × Nv fama + conforto/80 + (satisfação − 60)/200
  - assentos = 8 + 3 × Nv recepção + 2 × mesas (até 4 mesas) → dia 1: 8 + 3 + 2 = **13**
  - Dia 1: Lunch = round(9 × (1 + 0 + 9/80 + 0)) = **10**; Supper = **12**.
- No início do rush aparece o aviso (borda dourada) com **Serve!** (mini-game) ou **Auto N%**.
  Sem decisão até o fim da janela → resolvido no automático. Guilda fechada → sem rush.
- **Automático**: cada cliente pede um prato com estoque; é atendido com chance = eficiência
  (Mira sozinha **50%**; garçom **70% / 77,5% / 85%** por habilidade 1/2/3); **sem gorjeta de combo**.
- **Mini-game** (servir.gd): só pede pratos que existem (bandeja + balcões − pedidos caindo). Sem estoque → clientes
  restantes vão embora ("turned away"). Duração = clamp(14 + 2,6 × clientes, 30, 75) s; intervalo entre pedidos =
  (duração − 8)/clientes × (1,25 → 0,75); queda 70 → ~200 px/s. Acerto = preço; **gorjeta = preço × min(0,1 × combo, 0,5)**.
- Depois de cada rush:
  - **Satisfação do rush** = 100 × atendidos/clientes + (qualidade média − 1,5) × 10 + min(10, 40 × gorjetas/moedas), 0–100.
    Satisfação da casa = 0,7 × antiga + 0,3 × rush (começa em 60).
  - **Fama do rush** = round(atendidos/4 × (0,6 + nota/100 × 0,8)) → 10 atendidos com nota 90 = **+3**.
  - **Heróis da casa comem** (fome < 85): o prato que mais ajuda a classe; pagam **50%** do preço. Sem porção: mingau de
    1 provisão (fome +60, sem buff).
- O tempo de jogo **para** enquanto um mini-game está aberto.

## 2. Pratos, cozinha e provisões
| Prato | Traços | Provisões/fornada | Porções (2★) | Preço base (1★) | Buff | Duração | Destrava |
|---|---|---|---|---|---|---|---|
| Buttered Bread | 1 | 1 | 4 | 3 | Grit +10% | 8 h | início |
| Steak & Rice | 2 | 2 | 4 | 6 | Might +18% | 10 h | início |
| Roast Chicken | 3 | 3 | 4 | 10 | Grit +15%, Might +10% | 12 h | fama Nv 1 |
| Frost Sundae | 4 | 3 | 3 | 13 | Wits +22% | 12 h | fama Nv 2 |
| Roast Boar Feast (banquete) | 5 | **8** | 4 | 22 | Might/Wits/Grit +25% | 16 h | fama Nv 3 + Cozinha Nv 2 |

- **Porções por fornada** = base + (estrelas − 2) + (Nv cozinha − 1). Queimado (0★) = base − 2 (mín. 1).
- **Qualidade** do estoque = média ponderada das estrelas. **Preço** = base × [0★ 0,6 · 1★ 1,0 · 2★ 1,2 · 3★ 1,5]
  (interpolado). **Buff** × [0 · 0,6 · 1,0 · 1,4].
- Popularidade dos pedidos (peso): pão 5, steak 4, frango 3, sundae 2, banquete 1.
- **Provisão** = 3 moedas (compra manual em pacotes de 5/10/20). **Auto-order**: compra só o que falta na hora,
  a 3 × 1,25 = 3,75 moedas (arredonda para cima por pedido: 4 provisões = 15 moedas).
- Capacidade (despensa Nv 1/2/3): provisões **30 / 60 / 100**; porções por prato **12 / 18 / 24**.
- Margem: pão 2★ = 3 moedas de insumo → 4 porções × 4 = 16 moedas (+433%); banquete 2★ = 24 → 4 × 26 = 104.
- Estoque inicial: 6 pães + 4 steaks (2★), 16 provisões, 100 moedas, 4 materiais.

## 3. Aventureiros e missões
- Atributos Might/Wits/Grit = 1 + round(peso da classe × 4) + 0..1. Pesos (Might/Wits/Grit):
  Warrior .6/0/.4 · Mage 0/.8/.2 · Hunter .4/.4/.2 · Guardian .3/0/.7 · Berserker .8/0/.2 · Druid 0/.5/.5.
- **Poder do herói** = (nível × 10 + equipamento + 2 × Σ peso × atributo) × (1 + moral efetiva/100) × (1 + bônus de comida)
  - moral efetiva = moral + ((fome + descanso)/2 − 50) × 0,3 + conforto/20
  - bônus de comida = Σ peso da classe × buff do prato (enquanto durar). Ex.: Warrior + Steak 2★ = 0,6 × 18% = **+10,8%**.
- **Chance** = clamp(0,5 + 0,6 × (poder do grupo − dificuldade)/dificuldade, 5%, 95%).
- **Risco de morte** por herói = (1 − chance) × (0,10 + 0,07 × grau) → numa falha: grau 1 17%, 2 24%, 3 31%, 4 38%.
  Ferido (40%) em falha/parcial. Resultado: margem > 30 brilhante (×1,5), ≥ 0 sucesso, ≥ −20 parcial (×0,4), senão falha.

| Rank | Grau | Dificuldade | Duração (h) | Moedas | Fama |
|---|---|---|---|---|---|
| E | 1 | 30 | 3–6 | 28 | 3 |
| D | 1 | 48 | 5–9 | 50 | 5 |
| C | 2 | 95 | 10–16 | 110 | 10 |
| B | 3 | 170 | 18–30 | 240 | 22 |
| A | 3 | 270 | 30–48 | 450 | 40 |
| S | 4 | 440 | 48–72 | 900 | 90 |
(dificuldade ×0,9–1,15; moedas ×0,85–1,2; materiais = 1–3 × grau.)

- **Sorteio do grau** (com o selo): 52 / 30 / 16 / 2% → **82% grau 1–2, 16% grau 3, 2% grau 4** (grau 4 só a partir de fama
  Nv 2; antes o peso dele vai para o grau 3). Sem selo: só grau 1 (rank E), quadro com 4 contratos e **1 contrato do Arquivo
  por dia** (1 favor). Com selo: 5 contratos, 25% do Arquivo (1 favor; grau 3–4: 2).
- Cartão do contrato mostra a **chance e o risco com o melhor grupo disponível**; grau ≥ 3 tem borda dourada.

**Chance por grupo** (Warriors Might 4/Wits 1/Grit 3, moral 0, fome/descanso 70, conforto 9) — saída da simulação:

| Grupo | Poder | E | D | C | B | A | S | com Steak 2★: D | C | B | A |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2× Nv 1 | ~47 | 84% | 49% | 19% | 6% | 5% | 5% | 55% | 23% | 8% | 5% |
| 3× Nv 2 | ~104 | 95% | 95% | 56% | 27% | 13% | 5% | 95% | 63% | 31% | 15% |
| 4× Nv 3 | ~181 | 95% | 95% | 95% | 54% | 30% | 14% | 95% | 95% | 61% | 34% |
| 4× Nv 5 | ~264 | 95% | 95% | 95% | 83% | 48% | 26% | 95% | 95% | 93% | 55% |
| 4× Nv 8 | ~396 | 95% | 95% | 95% | 95% | 78% | 44% | 95% | 95% | 95% | 87% |

## 4. Fama
Níveis: **Nv 0 = 0 · Nv 1 = 40 · Nv 2 = 120 · Nv 3 = 300 · Nv 4 = 600 · Nv 5 = 1200**.
Fontes: rushes (~+3 por rush cheio) e contratos (tabela acima; brilhante ×1,5; parcial ×0,5; falha −metade).
Mortes: sem enterro −P; enterro digno (10 + 15 × grau moedas) −0,2P e honra +0,8P (P = 2 × fama do contrato + 5 × grau).

## 5. Funcionários (aba Guild → Staff; exigem o selo)
| Função | Destrava | Contratar (hab. 1/2/3) | Salário/dia (hab. 1/2/3) | Efeito |
|---|---|---|---|---|
| Server | fama Nv 2 | 80 / 110 / 140 | 10 / 14 / 18 | Auto-serve 70 / 77,5 / 85% |
| Cook | fama Nv 2 | 110 / 140 / 170 | 14 / 18 / 22 | cozinha às 10:00, 16:00, 23:00 até 8/6/5/4/3 porções, 1★ / 1–2★ / 2★ |
| Receptionist | fama Nv 3 | 140 / 170 / 200 | 16 / 20 / 24 | filtros (nível mín., classes, raças): aceita quem passa (se há vaga), recusa o resto; +10%/hab. candidatos |
- Candidato de cada função sorteado por dia: habilidade 1 (50%), 2 (35%), 3 (15%).
- Salários pagos à meia-noite; sem dinheiro → o funcionário sai (garçom sai → Auto-serve desliga).
- **Candidatos a aventureiro** por hora (aberta, 07–23 h) = 0,08 × (0,5 + satisfação/100) × (1 + 0,1 × Nv fama)
  → satisfação 60%: **~1,4 por dia**; 90%: ~1,8.

## 6. Obras (aba Works)
| Obra | Moedas | Materiais | Favores | Fama | Requer | Efeito |
|---|---|---|---|---|---|---|
| Selo de filiação | 40 | 0 | 3 | 0 | — | contratos > rank E, funcionários, 5 contratos |
| Recepção Nv 2 | 300 | 12 | 1 | Nv 2 | selo | +5 conforto, +2 vagas, +3 assentos (imagem recepcao_nivel2) |
| Recepção Nv 3 | 800 | 30 | 2 | Nv 3 | Recepção 2 | idem (nivel3) |
| Recepção Nv 4 | 1800 | 60 | 4 | Nv 4 | Recepção 3 | idem (nivel4) |
| Cozinha Nv 2 | 160 | 6 | 0 | Nv 1 | — | +1 porção por fornada; destrava o banquete |
| Cozinha Nv 3 | 450 | 20 | 0 | Nv 2 | Cozinha 2 | +1 porção por fornada |
| Despensa Nv 2 | 100 | 4 | 0 | 0 | — | 60 provisões, 18 porções/prato |
| Despensa Nv 3 | 320 | 14 | 0 | Nv 2 | Despensa 2 | 100 provisões, 24 porções/prato |
| Quartos | 400 | 20 | 1 | Nv 2 | selo | descanso ×2,5, +4 vagas, aluguel 3 moedas/herói em casa/noite |
| Forja | 600 | 35 | 2 | Nv 3 | selo | +5 equipamento (25 moedas + 3 materiais por vez) |
Decoração (conforto; cópias repetidas valem 50%, 25%, 12,5%…): mesa 4 (30 m + 2 mat; também +2 assentos),
tapete 3 (25), vaso 2 (12), estandarte 5 (70 + 3 mat, fama Nv 1), lareira 8 (160 + 10 mat, fama Nv 2).
Conforto = 5 × Nv recepção + decoração.

## 7. Resultados da simulação (30 seeds × 20 dias, código real)
Perfis: **engajado** (6 entradas por dia, joga os 3 rushes no mini-game com 90% de acerto) e **casual** (6 entradas,
joga só o almoço; café e jantar no automático — Mira 50% até contratar o garçom, depois Auto-serve).
Cozinha antes de cada rush para cobrir 115% dos clientes esperados (estrelas: 15% 1★, 50% 2★, 35% 3★); manda grupos com
chance ≥ 70% e risco ≤ 5%; compra na ordem selo → garçom → cozinha 2 → recepção 2 → despensa 2 → cozinheiro → quartos →
recepção 3 → recepcionista…, guardando 40 + 2 × salários.

**Marcos (mediana, p25–p75)**

| Marco | Engajado | Casual | Meta |
|---|---|---|---|
| Selo de filiação | dia 3 (3–3) | dia 3 (3–3) | 3–4 ✔ |
| 1º funcionário (garçom/cozinheiro) | dia 5 (5–5) | dia 6 (6–7) | 4–6 ✔ |
| Recepção Nv 2 | dia 6 (5–6) | dia 7 (6–7) | 5–7 ✔ |
| Cozinha Nv 2 | dia 2 | dia 3 | — |
| Quartos | dia 9 | dia 7 | — |
| Recepcionista | dia 10 | dia 11 | — |
| Recepção Nv 3 | dia 11 | dia 11 | — |
| Fama Nv 1 / 2 / 3 / 4 | 2 / 5 / 10 / 14 | 3 / 6 / 11 / 15 | — |

**Renda bruta por dia (mediana; p25–p75) e fama no fim do dia**

| Dia | Engajado | Fama | Casual | Fama |
|---|---|---|---|---|
| 1 | **230** (205–248) | 14 | **179** (160–200) | 12 |
| 2 | 449 | 43 | 343 | 37 |
| 3 | 540 | 70 | 378 | 60 |
| 5 | **576** (503–636) | 127 | **366** (337–411) | 108 |
| 7 | 725 | 198 | 532 | 166 |
| 10 | 1039 | 331 | 761 | 297 |
| 15 | **1653** (1459–1763) | 723 | **1192** (1003–1349) | 612 |
| 20 | 1864 | 1200 | 1489 | 1084 |
Dia 1 confortável: começa com 100 moedas e termina com ~230 (engajado) / ~180 (casual) depois de comprar a Despensa 2.

**Missões e rushes**: grupos enviados com chance ≥ 70% venceram 93% (grau 1), 92% (grau 2), 89% (grau 3); mortes < 0,01
por missão nesse perfil cauteloso. Rushes no mini-game: 90% dos clientes atendidos (24 232 de 26 995).

## 8. Ajustes feitos com a simulação
- 1ª rodada: funcionários e Recepção 2 em fama Nv 1 → 1º funcionário no dia 3 (cedo demais). Passaram para **fama Nv 2**
  (recepcionista Nv 3; Recepção 3 → Nv 3, Recepção 4 → Nv 4). Resultado acima.
- O selo é limitado por favores (1 contrato do Arquivo por dia sem selo + o do tutorial) → dia 3 garantido se não falhar.

## 9. Pendências de balanceamento
- Economia tardia (dia 15+) cresce rápido (~1700/dia); faltam sumidouros (impostos do Conselho, manutenção, banquetes).
- Bot cauteloso nunca pega grau 4; testar perfis arriscados. Expedição de Honra / Vingança: TODO.
- Buffs de comida pesam +5–10 pontos de chance; avaliar se devem pesar mais.
