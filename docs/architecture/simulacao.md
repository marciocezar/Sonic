# Simulação determinística

- `GameSim.tick(buttons)`: hold/press → quadro++ → tempo → objetos (jogador primeiro, depois slots 1..0x7F) →
  câmera → eventos dinâmicos de limites → visibilidade/carga de objetos. Mesma ordem medida na referência.
- Aritmética inteira com estouros explícitos (`Fx.s16/u16`), trigonometria tabelada (`Trig`).
- Renderização, áudio e UI apenas leem o estado ou consomem `sim.events`; nunca escrevem nele.
- Determinismo verificado: replays idênticos à referência; teste "determinismo 600 quadros"; mesmos resultados nos perfis.
- Custo medido: ~16 µs/tick (Apple Silicon, headless) — `make bench`.
