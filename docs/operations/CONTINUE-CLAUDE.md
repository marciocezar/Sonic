# Continuação (checkpoint para agentes)

Leia também `docs/STATUS.md`. Não refaça operações caras já concluídas sem necessidade.

## Escopo fixo
- Único arquivo de origem: `Sonic The Hedgehog (USA, Europe).md` (raiz do workspace). Não procurar outros jogos/pastas.
- Interface única: `make help`. Python 3 stdlib em `tooling/`, chamado só pelo Makefile.

## Decisões do usuário (2026-10-18)
- Aprovado: baixar Godot 4.7.2-stable (editor + templates) em `tooling/godot` (modo auto-contido `_sc_`).
- Aprovado: REA `rea-agents@6.7.0` local em `tooling/rea` (sem `setup`, sem MCP global) + Ghidra 12.1.4 em `tooling/ghidra`.
- **Negado**: executar REA fora do sandbox-exec. Sob sandbox, o provider Ghidra do REA falha (`java spawn EPERM`) ⇒ análise profunda via REA = BLOQUEADO. Ghidra headless direto roda em sandbox (`make ghidra-analyze`).

## Já feito (não repetir sem motivo)
- `make bootstrap` concluído (hashes verificados; natives do Ghidra compilados para arm64).
- `make rom-analyze`: ROM REV00 `GM 00001009-00`, checksum 0x264A OK, sha256 `46160baa…f2a6`.
- `make extract-data`: 19 fases extraídas para `private/extracted/levelpacks/*` com validação 100% da tabela de nomes do VDP.
- `make reference-traces`: traces em `private/reference-captures/*.jsonl` (5 replays GHZ1).
- `make test-parity`: 7/7 replays IDÊNTICOS (tolerância zero) — inclui `ghz1_bot` (ato inteiro, 3241 quadros até o anel
  gigante) e `ghz1_death`. Ver `reports/parity/summary.md`.
- Laço de trabalho para objetos: `make bot-replay LEVEL=x` → `make reference-traces REPLAY=x_bot` → `make test-parity REPLAY=x_bot`
  → `make parity-diag REPLAY=x_bot` → ler código com `make listing FROM= TO=` / `make anim-dump ADDR=` → implementar.
- Tabela de código de objetos: base 0xD382 (id 1); laço ocioso VBlank em 0x29AC (detecção exata no interpretador).

## Ferramentas próprias
- `tooling/m68k.py` + `tooling/mdmachine.py`: interpretador 68000 + máquina mínima (VDP/IO/DMA; sem Z80/áudio; temporização aproximada; quadro começa no VBlank).
- Endereços RAM confirmados por emulação: jogador $FFD000 (x +8, y +C, xv +10, yv +12, gs +14, ang +26, st +22),
  câmera $FFF700/$F704, anéis $FE20, vidas $FE12, tempo $FE22, modo $F600, zona/ato $FE10/$FE11, limites $F728..

## Próximos passos priorizados
1. Chefe GHZ: código em ROM 0x17700 (chefe), 0x17AE4 (bola 0x48), rotinas de dano não cobertas — criar bot que
   acerte o chefe (posição do chefe no slot) ou replay manual; cápsula 0x3E (0x1AB22), poste 0x79 (0x16E2E), 0x1A.
2. MZ: 0x2F (código 0xAEB8; mapas de altura em ROM → extrair para pacote privado), 0x46, 0x31, 0x33, 0x52, 0x54...
2. Demais zonas: eventos dinâmicos de limites, objetos, água dinâmica (LZ), estágios especiais, final.
3. Sprites/animações Fidelity (privado) e deformação de fundo.
(Já prontos: app jogável, fase própria Lab Zone, exportações 5 destinos + verify-artifacts; ver STATUS.)
Escopo: NÃO usar emuladores Android/Simuladores iOS sem autorização (pedido do usuário).

## 2026-10-18 (Web)
- Seletor de ROM Web = painel HTML (`WEB_ROM_PICKER_JS` em main.gd) por causa do Safari.
- Azure: `make package-web-azure` (zip com index.html na raiz) e `make web-azure-check URL=`.
- Pendente: confirmação do usuário no Safari e na Azure (registrar com `make qa-record`).

## 2026-10-18 (jogo completo — F0 arte/fundo)
- Novo: `game/src/levels/rom_assets.gd` (Nemesis/Enigma/PLC 0x1D612/paletas 0x2168), `render_modes/rom_sprites.gd`
  (mapeamentos + DPLC Sonic 0x217FE/0x21AFE), `render_modes/object_art_table.gd` (mapa/arte por ID; sobreposições por zona),
  `simulation/bg_scroll.gd` (deformação 0x61EC/0x6286). `make rom-assets-check` PASS (6 zonas).
- Paridade com campos de fundo (bgx,bgy,bg2x,bgv,hsb): GHZ (8 replays) e SBZ1 IDÊNTICOS; SYZ1 idêntico até 736.
- PENDENTE: MZ1 diverge em bgy/bgv no quadro 0 (inicialização do fundo de MZ: conferir 0x6230 e $F70C/$F714 via
  `make parity-diag REPLAY=mz1_bot`); LZ/SLZ divergem por objetos. Depois: tiles animados, ciclo de paletas,
  sprites por subtipo, telas (F1), som (F6). Rodar lint/test-unit/format/docs (não rodados após este lote).

## 2026-10-18 (builds privados)
- Usuário pediu remover "carregar ROM" e ter visual original direto (inclusive Web). Feito: `make build-private-<alvo>`
  (dist-private/, ROM em res://private_pack/content.bin só durante export), Fidelity padrão (settings schema 2 migra),
  `make run` usa a ROM do workspace. MZ1 fundo diverge no quadro 0 (pendente). Medir FPS da Web com o painel do
  navegador VISÍVEL (oculto = limitado pelo Chromium).

## 2026-10-18 (sprites, animação, placar, cartão, resultados)
- Sonic_Animate portado (0x139C4) com roteiros da ROM; `frm` agora é campo estrito de paridade. Derrapagem usa só o
  byte alto da velocidade (0x130BE); dano = anim 0x1A; objetos sólidos gravam palavra 0x0001 em anim (0x8AB0).
- `make sprite-check`: compara quadro/flags/arte/mapeamento de cada objeto com a referência (traces têm "ospr").
  Tabela de arte medida por zona/ID/subtipo em object_art_table.gd; objetos podem definir map_addr/gfx próprios.
- Novos objetos: 0x1C cenário, 0x1A plataforma que desmorona (replay ghz1_ledge IDÊNTICO), 0x79 poste (salva/restaura).
  Míssil 0x23 só é cancelado se o slot do atirador virar explosão (0x99A4). Visibilidade usa altura com render bit 4.
- Ghidra recebe sementes estáticas de tabelas de salto (tooling/static_seeds.py): listagem 18 553 -> 20 999 instruções.
- Telas originais: placar (rom_hud.gd), cartão de título (rom_title_card.gd, 60 Hz), resultados (rom_results.gd);
  composição de peças com prioridade do hardware (1ª peça por cima); deslocamentos de mapeamento com sinal.
- VRAM: card_vram (cartão, PLC16) x game_vram (+PLC 2 e animais 0x15+zona).
- PRÓXIMO: tela SEGA/título/seleção, game over/continue, cápsula 0x3E, chefe GHZ, objetos MZ..SBZ, estágio especial, som.
