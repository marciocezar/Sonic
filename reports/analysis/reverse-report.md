# Relatório de engenharia reversa (gerado por `make reverse-report`)

Gerado em 2026-10-18T22:34:26+00:00. Fonte única: `Sonic The Hedgehog (USA, Europe).md`.

## Integridade

- Tamanho: 524288 bytes; SHA-256 `46160baa06362c711c9f1a5017cb7371026444936c8af5e93a78996cf32ff2a6`
- Serial/revisão: GM 00001009-00; região declarada JUE
- Checksum interno: 0x264A (calculado 0x264A, confere=True)
- Formato: raw_binary_big_endian

## Ferramentas

- REA 6.7.0: `inspect-artifact` rejeita ROM bruta; `analyze --target-format raw-binary --architecture m68k` **BLOQUEADO** (provider Ghidra sob sandbox: java spawn EPERM; usuário negou execução fora do sandbox). Doctor: ghidra-java com falha.
- Ghidra 12.1.4 headless em sandbox, semeado com cobertura dinâmica: 332 funções, 18553 instruções (sem descompilação validada).
- Interpretador 68000 próprio (`tooling/m68k.py`/`mdmachine.py`): boot, título, carga das 19 fases, replays por quadro.

## Fases extraídas (privado)

| Fase | Início | Limites | Objetos | Plano A |
|---|---|---|---|---|
| ghz1 | {'x': 80, 'y': 944} | {'left': 0, 'right': 9407, 'top': 0, 'bottom': 768} | 214 | 1120/1120 |
| ghz2 | {'x': 80, 'y': 252} | {'left': 0, 'right': 7871, 'top': 0, 'bottom': 768} | 244 | 1120/1120 |
| ghz3 | {'x': 80, 'y': 944} | {'left': 0, 'right': 10592, 'top': 0, 'bottom': 768} | 286 | 1120/1120 |
| lz1 | {'x': 96, 'y': 108} | {'left': 0, 'right': 6591, 'top': 0, 'bottom': 1328} | 188 | 1120/1120 |
| lz2 | {'x': 80, 'y': 236} | {'left': 0, 'right': 4271, 'top': 0, 'bottom': 1824} | 138 | 1120/1120 |
| lz3 | {'x': 80, 'y': 748} | {'left': 0, 'right': 8239, 'top': -256, 'bottom': 2048} | 250 | 1120/1120 |
| sbz3 | {'x': 2944, 'y': 0} | {'left': 0, 'right': 8383, 'top': 0, 'bottom': 1824} | 195 | 1120/1120 |
| mz1 | {'x': 48, 'y': 614} | {'left': 0, 'right': 6079, 'top': 0, 'bottom': 464} | 145 | 1120/1120 |
| mz2 | {'x': 48, 'y': 614} | {'left': 0, 'right': 6079, 'top': 0, 'bottom': 1312} | 198 | 1120/1120 |
| mz3 | {'x': 48, 'y': 358} | {'left': 0, 'right': 6144, 'top': 0, 'bottom': 1824} | 232 | 1120/1120 |
| slz1 | {'x': 64, 'y': 716} | {'left': 0, 'right': 8127, 'top': 0, 'bottom': 1600} | 223 | 1120/1120 |
| slz2 | {'x': 64, 'y': 332} | {'left': 0, 'right': 8127, 'top': 0, 'bottom': 1600} | 187 | 1120/1120 |
| slz3 | {'x': 64, 'y': 332} | {'left': 0, 'right': 8192, 'top': 0, 'bottom': 1728} | 250 | 1120/1120 |
| syz1 | {'x': 48, 'y': 957} | {'left': 0, 'right': 8896, 'top': 0, 'bottom': 1056} | 193 | 1120/1120 |
| syz2 | {'x': 48, 'y': 445} | {'left': 0, 'right': 10432, 'top': 0, 'bottom': 1312} | 230 | 1120/1120 |
| syz3 | {'x': 48, 'y': 236} | {'left': 0, 'right': 11264, 'top': 0, 'bottom': 1568} | 256 | 1120/1120 |
| sbz1 | {'x': 48, 'y': 1164} | {'left': 0, 'right': 8640, 'top': 0, 'bottom': 1824} | 308 | 1120/1120 |
| sbz2 | {'x': 48, 'y': 1868} | {'left': 0, 'right': 7744, 'top': -256, 'bottom': 2048} | 292 | 1120/1120 |
| fz | {'x': 8512, 'y': 1452} | {'left': 8352, 'right': 9312, 'top': 1296, 'bottom': 1296} | 2 | 1120/1120 |

## Paridade

- ghz1_bot: **IDENTICO** (3241 quadros; 1ª divergência None)
- ghz1_death: **IDENTICO** (329 quadros; 1ª divergência None)
- ghz1_idle: **IDENTICO** (241 quadros; 1ª divergência None)
- ghz1_jumps: **IDENTICO** (301 quadros; 1ª divergência None)
- ghz1_long_run: **IDENTICO** (901 quadros; 1ª divergência None)
- ghz1_roll: **IDENTICO** (301 quadros; 1ª divergência None)
- ghz1_run_brake: **IDENTICO** (261 quadros; 1ª divergência None)
- ghz2_bot: **IDENTICO** (1884 quadros; 1ª divergência None)
- ghz3_boss: **DIVERGE_FRONTEIRA** (1059 quadros; 1ª divergência 1059)
- ghz3_bot: **IDENTICO** (3001 quadros; 1ª divergência None)
- mz1_bot: **DIVERGE_FRONTEIRA** (1538 quadros; 1ª divergência 170)

## Ledger

Contagem por status: BLOQUEADO=1, CONFIRMADO_BINARIO=15, CONFIRMADO_EMULACAO=56

| ID | Categoria | Local | Hipótese | Status |
|---|---|---|---|---|
| EV-EXT-0001 | colisao | ROM 0x062900 | Mapa de ângulos (256 bytes) lido pelo código em PC 0x014A00 | CONFIRMADO_EMULACAO |
| EV-EXT-0002 | colisao | ROM 0x062A00 | Array de alturas 256x16 (4096 bytes) lido por PC 0x014A2E/0x014AD6 | CONFIRMADO_EMULACAO |
| EV-EXT-0003 | colisao | ROM 0x063A00 | Array de larguras (rotação das alturas): 255/256 mapas conferem com a rotação calculada | CONFIRMADO_BINARIO |
| EV-EXT-0004 | fluxo | RAM $FFF600 | Modo de jogo 0x00 (SEGA) -> 0x04 (título) após Start; 0x0C = fase | CONFIRMADO_EMULACAO |
| EV-EXT-0005 | formato | ghz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0006 | fase | zona 0 ato 0 | ghz1: carregada; início (80,944); limites {'left': 0, 'right': 9407, 'top': 0, 'bottom': 768}; 214 objetos em ROM 0x06B096; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0007 | formato | ghz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0008 | fase | zona 0 ato 1 | ghz2: carregada; início (80,252); limites {'left': 0, 'right': 7871, 'top': 0, 'bottom': 768}; 244 objetos em ROM 0x06B5A0; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0009 | formato | ghz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0010 | fase | zona 0 ato 2 | ghz3: carregada; início (80,944); limites {'left': 0, 'right': 10592, 'top': 0, 'bottom': 768}; 286 objetos em ROM 0x06BB5E; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0011 | formato | lz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0012 | fase | zona 1 ato 0 | lz1: carregada; início (96,108); limites {'left': 0, 'right': 6591, 'top': 0, 'bottom': 1328}; 188 objetos em ROM 0x06C218; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0013 | formato | lz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0014 | fase | zona 1 ato 1 | lz2: carregada; início (80,236); limites {'left': 0, 'right': 4271, 'top': 0, 'bottom': 1824}; 138 objetos em ROM 0x06C686; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0015 | formato | lz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0016 | fase | zona 1 ato 2 | lz3: carregada; início (80,748); limites {'left': 0, 'right': 8239, 'top': -256, 'bottom': 2048}; 250 objetos em ROM 0x06C9C8; índice colisã | CONFIRMADO_EMULACAO |
| EV-EXT-0017 | formato | sbz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0018 | fase | zona 1 ato 3 | sbz3: carregada; início (2944,0); limites {'left': 0, 'right': 8383, 'top': 0, 'bottom': 1824}; 195 objetos em ROM 0x06CFAA; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0019 | formato | mz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0020 | fase | zona 2 ato 0 | mz1: carregada; início (48,614); limites {'left': 0, 'right': 6079, 'top': 0, 'bottom': 464}; 145 objetos em ROM 0x06D592; índice colisão 0x | CONFIRMADO_EMULACAO |
| EV-EXT-0021 | formato | mz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0022 | fase | zona 2 ato 1 | mz2: carregada; início (48,614); limites {'left': 0, 'right': 6079, 'top': 0, 'bottom': 1312}; 198 objetos em ROM 0x06D8FE; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0023 | formato | mz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0024 | fase | zona 2 ato 2 | mz3: carregada; início (48,358); limites {'left': 0, 'right': 6144, 'top': 0, 'bottom': 1824}; 232 objetos em ROM 0x06DDA8; índice colisão 0 | CONFIRMADO_EMULACAO |
| EV-EXT-0025 | formato | slz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0026 | fase | zona 3 ato 0 | slz1: carregada; início (64,716); limites {'left': 0, 'right': 8127, 'top': 0, 'bottom': 1600}; 223 objetos em ROM 0x06E31E; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0027 | formato | slz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0028 | fase | zona 3 ato 1 | slz2: carregada; início (64,332); limites {'left': 0, 'right': 8127, 'top': 0, 'bottom': 1600}; 187 objetos em ROM 0x06E85E; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0029 | formato | slz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0030 | fase | zona 3 ato 2 | slz3: carregada; início (64,332); limites {'left': 0, 'right': 8192, 'top': 0, 'bottom': 1728}; 250 objetos em ROM 0x06ECC6; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0031 | formato | syz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0032 | fase | zona 4 ato 0 | syz1: carregada; início (48,957); limites {'left': 0, 'right': 8896, 'top': 0, 'bottom': 1056}; 193 objetos em ROM 0x06F2A8; índice colisão  | CONFIRMADO_EMULACAO |
| EV-EXT-0033 | formato | syz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0034 | fase | zona 4 ato 1 | syz2: carregada; início (48,445); limites {'left': 0, 'right': 10432, 'top': 0, 'bottom': 1312}; 230 objetos em ROM 0x06F734; índice colisão | CONFIRMADO_EMULACAO |
| EV-EXT-0035 | formato | syz3 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0036 | fase | zona 4 ato 2 | syz3: carregada; início (48,236); limites {'left': 0, 'right': 11264, 'top': 0, 'bottom': 1568}; 256 objetos em ROM 0x06FC9E; índice colisão | CONFIRMADO_EMULACAO |
| EV-EXT-0037 | formato | sbz1 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0038 | fase | zona 5 ato 0 | sbz1: carregada; início (48,1164); limites {'left': 0, 'right': 8640, 'top': 0, 'bottom': 1824}; 308 objetos em ROM 0x0702A4; índice colisão | CONFIRMADO_EMULACAO |
| EV-EXT-0039 | formato | sbz2 VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0040 | fase | zona 5 ato 1 | sbz2: carregada; início (48,1868); limites {'left': 0, 'right': 7744, 'top': -256, 'bottom': 2048}; 292 objetos em ROM 0x0709E2; índice coli | CONFIRMADO_EMULACAO |
| EV-EXT-0041 | formato | fz VRAM plano A | Decodificação chunk/bloco/tile reproduz a tabela de nomes do VDP: 1120/1120 células | CONFIRMADO_EMULACAO |
| EV-EXT-0042 | fase | zona 5 ato 2 | fz: carregada; início (8512,1452); limites {'left': 8352, 'right': 9312, 'top': 1296, 'bottom': 1296}; 2 objetos em ROM 0x0710C0; índice col | CONFIRMADO_EMULACAO |
| EV-EXT-0043 | cobertura | 0x000000-0x07FFFF | 7311 endereços de instrução executados ao carregar as 19 fases (60 quadros cada) | CONFIRMADO_EMULACAO |
| EV-REA-0001 | ferramenta | work/rea/sonic.bin | REA inspect-artifact sobre a ROM: exit=1; 'Cannot open artifact: unsupported binary format.' | CONFIRMADO_BINARIO |
| EV-REA-0002 | ferramenta | work/rea/sonic.bin | REA analyze --target-format raw-binary --architecture m68k: falhou (ghidra:runtime_unavailable; hopper:executable_missing; hopper:target_for | BLOQUEADO |
| EV-REA-0003 | ferramenta | 0x000000-0x07FFFF | Ghidra 12.1.4 headless (68000:BE:32, BinaryLoader, vetores semeados) recuperou 198 funções e 6754 instruções | CONFIRMADO_BINARIO |
| EV-ROM-0001 | formato | 0x100-0x10F | Magic 'SEGA MEGA DRIVE' em 0x100 identifica cartucho Mega Drive/Genesis | CONFIRMADO_BINARIO |
| EV-ROM-0002 | formato | arquivo inteiro | Tamanho 524288 bytes; sem cabeçalho de copiador (len % 16384 = 0); binário bruto, não intercalado (SMD) | CONFIRMADO_BINARIO |
| EV-ROM-0003 | cabecalho | 0x180-0x18D | Serial/revisão 'GM 00001009-00' | CONFIRMADO_BINARIO |
| EV-ROM-0004 | cabecalho | 0x1F0-0x1FF | Região declarada 'JUE' (J/U/E); timing NTSC/PAL não é inferido disso | CONFIRMADO_BINARIO |
| EV-ROM-0005 | integridade | 0x18E | Checksum calculado 0x264A vs cabeçalho 0x264A: confere | CONFIRMADO_BINARIO |
| EV-ROM-0006 | cpu | 0x000-0x0FF | Vetores 68000: SSP inicial 0x00FFFE00, reset PC 0x00000206, VBlank 0x00000B10, HBlank 0x00001126 | CONFIRMADO_BINARIO |
| EV-ROM-0007 | mapa | 0x07FFFA-0x07FFFF | Preenchimento final com byte 0x82 | CONFIRMADO_BINARIO |
| EV-TAB-0001 | trigonometria | ROM 0x0029F2 (320 words); leitura em PC 0x0029E4/0x0029EC (Ghidra) | Seno = trunc(sin(k*2pi/256)*256) exceto índices [147, 237] (valor [-117, -117]) | CONFIRMADO_BINARIO |
| EV-TAB-0002 | trigonometria | ROM 0x002D0E (257 bytes); leitura em PC 0x002CD6/0x002CE2 (Ghidra) | Arco-tangente = round(atan(k/256)*128/pi): 257/257 iguais | CONFIRMADO_BINARIO |
| EV-TAB-0003 | objetos | ROM 0x009B3E (16 pares) | Espaçamento de grupos de anéis (dx,dy com sinal): [(16, 0), (24, 0), (32, 0), (0, 16), (0, 24), (0, 32), (16, 16), (24, 24), (32, 32), (-16, | CONFIRMADO_BINARIO |
| EV-TAB-0004 | colisao | ROM 0x01AE40 (36 pares) | Tamanhos de toque (meia-largura, meia-altura) índices 1..0x24: [(16, 12), (8, 8), (20, 16), (20, 8), (14, 14), (24, 24), (40, 16), (16, 24)] | CONFIRMADO_BINARIO |
| EV-TAB-0005 | progressao | ROM 0x00C6F4 (6 zonas x 4 atos) | Ordem de fases: 0001 0002 0200 0000 0101 0102 0300 0502 0201 0202 0400 0000 0301 0302 0500 0000 0401 0402 0100 0000 0501 0103 0000 0000 | CONFIRMADO_BINARIO |
| EV-TAB-0006 | ram | 0xFFD000 | objeto do jogador: x +8, y +C, vx +10, vy +12, gs +14, status +22, rotina +24, ângulo +26 | CONFIRMADO_EMULACAO |
| EV-TAB-0007 | ram | 0xFFF700 | câmera x (+0 inteiro, +2 fração), y em +4/+6 | CONFIRMADO_EMULACAO |
| EV-TAB-0008 | ram | 0xFFFE20 | anéis (word) | CONFIRMADO_EMULACAO |
| EV-TAB-0009 | ram | 0xFFFE12 | vidas (byte) | CONFIRMADO_EMULACAO |
| EV-TAB-0010 | ram | 0xFFFE22 | tempo (min +1, s +2, quadros +3) | CONFIRMADO_EMULACAO |
| EV-TAB-0011 | ram | 0xFFF600 | modo de jogo | CONFIRMADO_EMULACAO |
| EV-TAB-0012 | ram | 0xFFFE10 | zona/ato | CONFIRMADO_EMULACAO |
| EV-TAB-0013 | ram | 0xFFF728 | limites de câmera atuais (esq, dir, topo, base) | CONFIRMADO_EMULACAO |
| EV-TAB-0014 | ram | 0xFFF73E | deslocamento de olhar (look shift) | CONFIRMADO_EMULACAO |
| EV-TAB-0015 | fisica | traces de referência | aceleração no chão: 0x0C/quadro | CONFIRMADO_EMULACAO |
| EV-TAB-0016 | fisica | traces de referência | velocidade máxima: 0x600 | CONFIRMADO_EMULACAO |
| EV-TAB-0017 | fisica | traces de referência | salto: -0x680 (água -0x380) | CONFIRMADO_EMULACAO |
| EV-TAB-0018 | fisica | traces de referência | gravidade: 0x38/quadro | CONFIRMADO_EMULACAO |
| EV-TAB-0019 | fisica | traces de referência | corte do salto: -0x400 ao soltar | CONFIRMADO_EMULACAO |

## O que NÃO foi feito

- A ROM **não** foi descompilada integralmente; não há afirmação de equivalência total.
- Z80/áudio, deformação de fundo por linha, HBlank e a maioria dos objetos/chefes ainda não foram reconstruídos.
- Temporização do interpretador é aproximada (quadros com lag podem divergir do hardware).
