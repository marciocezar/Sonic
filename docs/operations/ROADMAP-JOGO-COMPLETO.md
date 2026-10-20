# Roadmap — jogo completo nas 6 modalidades

Pedido do usuário (2026-10-18): reproduzir todas as telas, menus, fases, cenários, animações, inimigos, chefes, sons,
física, colisões e funcionalidades, para estudo privado, em Windows, macOS, Web, Azure Web privada, Android e iOS
(teclado físico nos computadores, toque multitouch nos móveis). Critério de conclusão: tudo reproduzido **e testado**
nas seis modalidades. Status honestos (ver `CLAUDE.md`); nada aqui é "idêntico ao original".

## Decisões
- **Conteúdo original importado em execução da ROM do usuário** (fases, artes, paletas, mapeamentos, sons). Nenhum
  build, inclusive o da Azure privada, contém dados da Sega; a ROM é escolhida uma vez e fica só no aparelho.
- Código 100% próprio (GDScript tipado, Godot 4.7.2, Compatibility). Sem GDExtension (o template Web não suporta).
- REA liberado fora do sandbox (local, sem rede); Ghidra em sandbox; emulador Android e iOS Simulator liberados.
- Referência de comportamento: interpretador 68000 próprio + traços quadro a quadro (tolerância zero onde medido).

## Fases de trabalho
| # | Bloco | Conteúdo | Status |
|---|---|---|---|
| F0 | Importação de assets | Nemesis/Enigma/PLC/paletas VERIFIED (6 zonas); sprites ROM e fundo com deformação IMPLEMENTED (GHZ/SBZ fundo VERIFIED); faltam tiles animados, ciclo de paleta, MZ init | IN_PROGRESS |
| F1 | Telas | SEGA, título, seleção de fase, cartões de título, HUD original, resultados do ato, game over, continue, final, créditos | NOT_STARTED |
| F2 | Personagem | todas as animações/mapeamentos, escudo, invencibilidade, tênis, afogamento/bolhas, poste de checkpoint | IN_PROGRESS (física VERIFIED) |
| F3 | Zonas | objetos e eventos dinâmicos de GHZ, MZ, SYZ, LZ (água), SLZ, SBZ, FZ; deformação de fundo | IN_PROGRESS (GHZ) |
| F4 | Chefes | GHZ, MZ, SYZ, LZ, SLZ, SBZ/FZ + cápsula | NOT_STARTED |
| F5 | Estágio especial | labirinto giratório, esmeraldas, resultados | NOT_STARTED |
| F6 | Som | driver de música/efeitos (68000), síntese YM2612 + PSG + DAC em GDScript | NOT_STARTED |
| F7 | Plataformas | roteiro automático "todas as fases" por plataforma; Azure privada com login obrigatório | IN_PROGRESS |

## Validação planejada por fase
- Assets: comparação byte a byte com VRAM/CRAM capturadas por emulação (`private/extracted/levelpacks/*/vram.bin`).
- Mecânicas/objetos: replays com tolerância zero (`make test-parity`), por zona.
- Plataformas: `make test-progression` (todas as fases a partir da ROM) em cada destino; registro em `make qa-record`.

## Estimativa honesta
É um trabalho de muitas sessões. Cada lote atualiza este arquivo, `docs/STATUS.md` e `CONTINUE-CLAUDE.md`.
