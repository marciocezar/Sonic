# 03 — Mapa de funções e dados (com evidência)

Endereços são da ROM REV00. Status conforme ledger (`04-evidence-ledger.csv`).

## Código (PCs observados)
| Endereço | Papel inferido | Como | Status |
|---|---|---|---|
| 0x0029E4/0x0029EC | leitura da tabela de seno | listagem Ghidra | CONFIRMADO_BINARIO |
| 0x002CD6/0x002CE2 | leitura da tabela de arco-tangente | listagem Ghidra | CONFIRMADO_BINARIO |
| 0x0149F0 | leitura do índice de colisão da zona | rastreio de leituras por PC | CONFIRMADO_EMULACAO |
| 0x014A00 / 0x014AA8 | leitura do mapa de ângulos | rastreio por PC | CONFIRMADO_EMULACAO |
| 0x014A2E / 0x014AD6 | leitura dos mapas de altura | rastreio por PC | CONFIRMADO_EMULACAO |
| 0x00DA02.. | leitura da lista de objetos da fase | rastreio por PC | CONFIRMADO_EMULACAO |
| 0x071B4C.. | rotinas do driver de som (68000) | rastreio por PC | INFERIDO |

## Dados
| Endereço | Conteúdo | Uso no projeto | Status |
|---|---|---|---|
| 0x0029F2 | seno 320 words | gerado por fórmula + errata (índices 147/237 = -117) | CONFIRMADO_BINARIO |
| 0x002D0E | atan 257 bytes | gerado por fórmula (257/257) | CONFIRMADO_BINARIO |
| 0x009B3E | espaçamento de anéis (16 pares) | constante funcional | CONFIRMADO_BINARIO |
| 0x00C6F4 | ordem de fases | progressão | CONFIRMADO_BINARIO |
| 0x01AE40 | tamanhos de toque (36 pares) | constante funcional | CONFIRMADO_BINARIO |
| 0x062900 | mapa de ângulos (256) | **privado** (levelpack) | CONFIRMADO_EMULACAO |
| 0x062A00 / 0x063A00 | alturas / larguras 256×16 | **privado** | CONFIRMADO_EMULACAO |
| 0x064A00.. | índices de colisão por zona | **privado** | CONFIRMADO_EMULACAO |

## RAM ($FF0000+)
| Offset | Conteúdo | Status |
|---|---|---|
| $0000–$A3FF | chunks 256×256 descomprimidos (chunk N em (N−1)×0x200) | CONFIRMADO_EMULACAO |
| $A400–$A7FF | layout 8×0x80 (FG/BG intercalados) | CONFIRMADO_EMULACAO |
| $B000–$C7FF | blocos 16×16 (4 palavras de tile) | CONFIRMADO_EMULACAO |
| $D000 | objeto do jogador (x+8, y+C, vx+10, vy+12, gs+14, raio y/x +16/+17, anim+1C, status+22, rotina+24, ângulo+26, bloqueio+3E) | CONFIRMADO_EMULACAO |
| $F600 | modo de jogo (00 SEGA, 04 título, 0C fase) | CONFIRMADO_EMULACAO |
| $F700/$F704 | câmera x/y (16.16) | CONFIRMADO_EMULACAO |
| $F728–$F72E | limites de câmera atuais | CONFIRMADO_EMULACAO |
| $F73E | look shift | CONFIRMADO_EMULACAO |
| $F770 | ponteiro da lista de objetos | CONFIRMADO_EMULACAO |
| $F796 | ponteiro do índice de colisão | CONFIRMADO_EMULACAO |
| $F7AC–$F7AF | chunks de loop e de túnel de rolagem | CONFIRMADO_EMULACAO |
| $FE10/$FE11 | zona/ato | CONFIRMADO_EMULACAO |
| $FE12, $FE20, $FE22, $FE26 | vidas, anéis, tempo, pontuação/10 | CONFIRMADO_EMULACAO |

## Formato de objeto na lista
6 bytes: x (word), y (bits 0–11; bit 14 espelho X; bit 15 espelho Y), id (bit 7 = lembrar estado), subtipo.
Status: CONFIRMADO_EMULACAO (paridade de anéis/monitor no replay longo).
