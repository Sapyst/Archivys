# Decisões de design

## Tempo
- **Jogo aberto:** 60× → 1 min real = 1 h de jogo (1 dia de jogo = 24 min reais).
- **Jogo fechado:** 4× → 10 min reais = 40 min de jogo (8 h fechado = 32 h de jogo).
- Implementação: salvar `timestamp_real` ao sair; ao abrir, `delta_jogo = (agora − timestamp) × 4`, simular em passos.
  Proteção contra relógio adiantado: limitar o delta máximo (ex.: 72 h de jogo) e ignorar delta negativo.

## Morte de aventureiro
| Situação | Reputação | Honra |
|---|---|---|
| Morre, grupo volta com o corpo, **sem** enterro | perda cheia (P) | 0 |
| Morre, grupo volta com o corpo, **com** enterro digno (custa verba) | perda × 0,2 | +0,8·P (equivale ao que foi evitado) |
| Grupo inteiro morre (sem corpos) | perda grande (P_total) | — |
| ...e a **Expedição de Honra** recupera os corpos | devolve 50% de P_total | +0,5·P_total |
| ...em seguida a **Missão de Vingança** (mesmo local/inimigo) | — | bônus de honra e moral da guilda |
- Regra: se morre só parte do grupo, **alguém sempre traz o corpo**.
- Expedição de Honra e Vingança aparecem automaticamente no quadro.

## Controle
- Sem avatar andando: **administração por clique** visto de cima (clicar balcão, barril, mesa, aventureiro, quadro).

## Recrutamento
- Aventureiros chegam sozinhos; o jogador **aceita/recusa** cada um.
- Com **recepcionista**: filtros de admissão (nível, força, classe, raça) do liberal ao seletivo, ou **aceitar todos**.

## Tecnologia
- **Godot 4 + GDScript**, export Android/iOS. Rust (gdext) só se algum cálculo pesado pedir — não deve.

## Aba Guilda = "frente" com a Mira (interativa)
- Vitrine mostra a Mira atrás do balcão; tocar nela → reação (expressão + animação de humor) + fala curta sobre o andamento
  (prioridade: alerta mais urgente → contrato/grupo → dica). Balão na lateral, nunca cobrindo o rosto.
- **Zonas de toque** (todas SFW): cabeça (cafuné → envergonhada/feliz), rosto (cutucão → brava), ombro/braço (surpresa), balcão/mãos (fala o andamento).
- **Paciência:** ≥4 toques em 3 s → "Ei! Estou trabalhando!" (brava) e ignora toques por 5 s; ≥3 seguidos na mesma zona → irritação.
  Paciência se recupera 1 ponto a cada 10 s. Reações não se repetem 2× seguidas.
- Bordas: **corda = só conversa**; menus usam **painel metálico minimalista** com cantos curvos.

## LOOP PRINCIPAL (redefinido pelo autor, 2026-10-18) — tem prioridade sobre o resto
**Abre a guilda → clientes chegam → pedem → servir a tempo.** Diálogos com personagens são RAROS; no dia a dia
os pedidos aparecem como **ícones de classe** (guerreiro, mago, caçador…) pedindo um serviço/prato.

### Mini-game 1 — Servir (estilo "tetris de pedidos")
- Pedidos (ícone do cliente + prato) **caem** de cima. O jogador **arrasta o prato certo** para a coluna/lugar certo;
  quando o pedido chega embaixo e casa com o prato → **match**, pontos, pagamento (+gorjeta se feliz).
- **Acelera** com o movimento da guilda (mais clientes = queda mais rápida).
- **Liga/desliga:** com funcionários servindo, o jogador pode desativar e o serviço vira automático (com eficiência do funcionário).

### Mini-game 2 — Cozinhar (traços)
- Depois do pico de refeição, repor pratos para o próximo dia: na tela aparece um **traço** com círculo no início e no fim;
  pressionar no círculo inicial, seguir o rastro e soltar no círculo final.
- **5 segundos sempre.** Nº de traços por prato: simples 1 · menos simples 2 · refinada 3 · complexa 4 · banquete 5.

### Ingredientes
- Comprar manualmente, ou **encomenda automática sob demanda** (custo adicional de serviço).

### Ciclo de crescimento
- Serviço eficiente + clientes felizes → **mais inscrições** → mais movimento → mais dinheiro.
- Felizes pagam o prato **+ gorjeta**.
- **Comidas dão buffs** nos status próprios de cada aventureiro → maior chance de sucesso em missões.
- Missões em geral **fáceis**; algumas difíceis e ultra raras.

## Idioma e nomes
- **Jogo em inglês por enquanto** (UI, falas, itens). Português depois via localização.
- Horários de refeição: **Breakfast Rush**, **Lunch Rush**, **Supper Rush** (o mini-game de servir acontece nesses rushes).

## Retratos → ícones de classe (por agora)
- Aventureiros comuns e clientes aparecem com **ícone de classe** (não retrato). Retratos virão depois.
- Classes iniciais: Warrior, Mage, Hunter, Rogue, Cleric, Guardian (tanque — combina com Peluvianim "pesados").
- Cada aventureiro: raça + classe; o ícone de classe aparece nos cartões, nos pedidos do mini-game de servir e no Quadro.
- Classes (ícones do autor, medalhões redondos): Warrior, Mage, Hunter, Guardian (torre com coroa), Druid (árvore e lua);
  o 2º medalhão "Guardian" (machado + maça cruzados) → sugestão: **Berserker** (aguardando confirmação).

## Alpha v0.1 (2026-10-19) — implementado
- Nome do jogo **Archivys** (v0.1.0). Abertura: lore curta + o jogador batiza a casa (máx. 18, padrão "Casa do Queixo").
- Rushes 07–09 / 12–14 / 19–21 com aviso (borda dourada) → mini-game de servir com o ESTOQUE REAL ou Auto (Mira 50%,
  garçom 70–85%, sem gorjeta de combo). Cozinhar pela área Kitchen (provisões → porções; estrelas = porções e qualidade).
  Auto-order de provisões +25%. Tempo de jogo pausa durante mini-games.
- Bebida saiu do HUD (o loop é de pratos); no lugar, o total de porções prontas.
- Funcionários exigem o selo: Server e Cook em fama Nv 2, Receptionist em fama Nv 3 (salário pago à meia-noite).
- Números e simulação: `docs/balanceamento.md`.
