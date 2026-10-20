# Licenças e proveniência

## Código deste projeto
Código e documentação escritos neste workspace (Makefile, `tooling/`, `game/src`, `game/tests`, `tests/`, `docs/`).
Licença do projeto: **a definir pelo titular do workspace** (nenhuma licença pública foi concedida ainda).
O código é novo; não copia código descompilado. Comportamentos foram especificados e validados por replays.

## Conteúdo próprio incluído nos builds
| Item | Origem |
|---|---|
| `game/icon.svg` | desenhado para o projeto |
| `game/data/levels/lab1.json` (Lab Zone) | gerado por `tooling/gen_demo_level.py` (perfil matemático próprio) |
| Arte Enhanced/Fidelity sem pacote privado | gerada em código (`geometry_art.gd`, `sprite_painter.gd`, `pixel_font.gd`) |
| Efeitos sonoros | sintetizados em código (`audio_bus.gd`) |

## Parâmetros funcionais
Constantes de física, tamanhos de hitbox, espaçamento de anéis, ordem de fases e tabelas trigonométricas
(geradas por fórmula + 2 erratas medidas) são tratados como **fatos funcionais** reimplementados como
constantes, com evidência no ledger. Esta é uma decisão técnica, **não um parecer jurídico** — requer revisão
de um profissional antes de qualquer distribuição.

## Conteúdo protegido (NÃO distribuível)
A ROM, e tudo derivado dela em `private/` (layouts de fase, chunks, VRAM/arte, paletas, traces), pertence aos
detentores dos direitos. Uso **local e privado** para pesquisa. Nada disso entra em `dist/` (verificado por
`make check-no-rom-in-dist`). A posse da ROM **não** licencia redistribuição de assets.

## Terceiros
| Componente | Versão | Licença | Uso |
|---|---|---|---|
| Godot Engine + export templates | 4.7.2-stable | MIT (+ licenças de terceiros do Godot) | runtime embutido nos builds |
| rea-agents (REA) | 6.7.0 | MIT | ferramenta local, não distribuída |
| Ghidra | 12.1.4 | Apache-2.0 | ferramenta local, não distribuída |
| Python stdlib | 3.9+ | PSF-2.0 | ferramenta local |

Inventário completo: `make sbom` (`reports/qa/sbom.json`) e `make license-audit`.
