# 01 — Formato do arquivo de origem

Gerado/validado por `make rom-analyze` (`reports/analysis/rom-integrity.json`, evidências `EV-ROM-*`).

| Propriedade | Valor | Evidência |
|---|---|---|
| Arquivo | `Sonic The Hedgehog (USA, Europe).md` (raiz do workspace, somente leitura) | — |
| Tamanho | 524 288 bytes (512 KiB) | EV-ROM-0002 |
| SHA-256 | `46160baa06362c711c9f1a5017cb7371026444936c8af5e93a78996cf32ff2a6` | rom-integrity.json |
| Magic em 0x100 | `SEGA MEGA DRIVE` | EV-ROM-0001 |
| Cabeçalho de copiador / intercalação SMD | ausentes (tamanho múltiplo de 16 KiB, magic no lugar) | EV-ROM-0002 |
| Serial/revisão | `GM 00001009-00` (REV00) | EV-ROM-0003 |
| Região declarada | `JUE` — timing NTSC/PAL **não** é inferido disso | EV-ROM-0004 |
| Checksum interno 0x18E | 0x264A, calculado 0x264A (confere) | EV-ROM-0005 |
| CPU | Motorola 68000, big-endian; SSP 0xFFFE00, reset 0x000206 | EV-ROM-0006 |
| Interrupções | VBlank (nível 6) e HBlank (nível 4) a partir da tabela de vetores | EV-ROM-0006 |

O sufixo `.md` significa "Mega Drive", não Markdown.

## Layout observado
- 0x000–0x0FF vetores; 0x100–0x1FF cabeçalho; código a partir de 0x200.
- Tabelas localizadas (EV-TAB-*): seno 0x29F2, arco-tangente 0x2D0E, espaçamento de anéis 0x9B3E,
  ordem de fases 0xC6F4, tamanhos de toque 0x1AE40, mapa de ângulos 0x62900, alturas 0x62A00,
  larguras 0x63A00, índices de colisão por zona a partir de 0x64A00, listas de objetos ~0x6B000+.
- Driver de som executado pelo 68000 por volta de 0x71B4C (leituras observadas; não reconstruído).

## Compressões
Os dados de fase foram obtidos **depois** de descomprimidos pelo próprio código do jogo (RAM/VRAM no
interpretador), então nenhum formato de compressão foi assumido. Formatos de compressão: DESCONHECIDO
(não necessários até aqui).
