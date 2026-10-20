# 05 — Paridade

`make reference-traces` gera traces da referência (interpretador próprio executando a ROM) e
`make test-parity` executa os mesmos replays na simulação Godot headless, comparando quadro a quadro.

- Estado inicial: snapshot F0 medido (primeiro quadro com modo 0x0C) aplicado à simulação.
- Campos estritos (tolerância **zero**): x, xs, y, ys, xv, yv, gs, ang, st, rt, camx, camy, rings, lives, score, time, look, yr, xr.
- Campos suaves (relatados, não reprovam): anim, camys, lock, jmp, inv, lim, rng.
- Sem trace de referência (sem ROM): NAO_AVALIADO — nunca "aprovado".

Resultado atual: ver `reports/parity/summary.md` — 9 replays IDÊNTICOS (inclui `ghz1_bot`: ato inteiro, 3241 quadros
até o anel gigante; `ghz2_bot`, `ghz3_bot`, `ghz1_death`) e 2 de fronteira (`ghz3_boss`, `mz1_bot`).

## Alinhamentos explícitos (não escondidos)
- Quadros de lag medidos na referência: a simulação não avança neles (não modela carga de CPU). Até agora nenhum
  quadro de lag ocorreu nos replays após a detecção exata do laço de espera (0x29AC).
- Estado inicial F0: jogador, câmera, tempo, osciladores ($FE5E), animação sincronizada ($FEC0), contadores e
  1 passagem de objetos anterior ao laço principal (medida contra a ocupação de slots em F0).
- "Pokes": escritas roteirizadas da posição do jogador, aplicadas igualmente nos dois lados (cenários de chefe).
- Fim do trecho comparável: recarga de fase pela referência ou entrada em estágio especial (não reconstruído).

## Ferramentas de diagnóstico
`make parity-diag REPLAY=x`, `make slot-diff REPLAY=x`, `make listing FROM= TO=`, `make anim-dump ADDR=`, `make bot-replay`.

## Limites da comparação
- A referência é um interpretador próprio (não cycle-accurate). Concordância com hardware real não foi medida.
- A cobertura é limitada a GHZ1 e aos objetos encontrados nesses trajetos (anéis, monitor).
- Animação (`anim`) e sprites não fazem parte do critério estrito.
