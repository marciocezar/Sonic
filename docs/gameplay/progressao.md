# Progressão (EV-TAB progressao, ROM 0xC6F4)

GHZ1 → GHZ2 → GHZ3 → MZ1 → MZ2 → MZ3 → SYZ1 → SYZ2 → SYZ3 → LZ1 → LZ2 → LZ3 → SLZ1 → SLZ2 → SLZ3 → SBZ1 → SBZ2 → SBZ3 (LZ ato 4) → FZ (SBZ ato 3).

| Fase | Zona/ato interno | Início (x,y) | Objetos | Status de jogo |
|---|---|---|---|---|
| ghz1–3 | 0/0–2 | (80,944) (80,252) (80,944) | 214 / 244 / 286 | geometria+física OK; objetos parciais |
| mz1–3 | 2/0–2 | (48,614) (48,614) (48,358) | ver reports | geometria OK; objetos ausentes |
| syz1–3 | 4/0–2 | (48,957) (48,445) (48,236) | — | idem |
| lz1–3 | 1/0–2 | (96,108) (80,236) (80,748) | — | idem; água estática |
| slz1–3 | 3/0–2 | (64,716) (64,332) (64,332) | — | idem |
| sbz1–2 | 5/0–1 | (48,1164) (48,1868) | — | idem |
| sbz3 | 1/3 | (2944,0) | — | idem |
| fz | 5/2 | (8512,1452) | 2 | chefe ausente |

Eventos dinâmicos de limites: GHZ implementado; demais zonas NOT_STARTED. Estágios especiais e final: NOT_STARTED.
Transição SBZ2 → SBZ3 ao cair com x ≥ 0x2000 (implementada, não verificada).

## Zonas originais em todas as plataformas (ROM do próprio usuário)
O build publicável contém só a LAB ZONE própria. No título, "CARREGAR ROM" abre o seletor de arquivo nativo
(desktop/Android/iOS) ou `<input type=file>` (Web). O importador `game/src/levels/rom_importer.gd` aceita apenas a
REV00 (SHA-256 `46160baa…f2a6`), guarda a cópia em `user://rom/rom.bin` (somente no aparelho; "ESQUECER ROM
CARREGADA" apaga) e monta as 19 fases das tabelas da ROM (Kosinski próprio). A seguir, "JOGAR (ZONAS ORIGINAIS EM
SEQUENCIA)" segue a ordem medida GHZ1→…→SBZ3→FZ, e "SELECIONAR FASE" permite escolher qualquer ato.
Verificação: `make rom-import-check` (Python e GDScript = extração por emulação, 19/19), `make test-progression`
(19 atos em sequência a partir da ROM, sem levelpacks: PASS), Web no Chromium embutido (ROM carregada → GHZ1 jogável).
Limites honestos: chefes, estágios especiais e final ainda não reconstruídos — nos atos de chefe o jogo avança ao
chegar ao fim da área (mensagem na tela); objetos de MZ/SYZ/LZ/SLZ/SBZ e água de LZ parciais.
