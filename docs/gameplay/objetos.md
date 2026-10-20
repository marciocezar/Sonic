# Objetos (`game/src/entities`)

Execução em slots (0 = jogador; 0x20–0x7F objetos de fase), carga por janela de câmera
[(câmera−0x80)&~0x7F, +0x280), estado de respawn por objeto "lembrado". Toque: retângulo do jogador
(x−8, 16 de largura; altura 2×(raio_y−3), agachado 0x14) contra tamanhos medidos (ROM 0x1AE40);
só objetos visíveis na tela (bit 7) colidem.

| ID | Objeto | Status |
|---|---|---|
| 0x25 | Anéis (grupos por subtipo, coleta bloqueada nos primeiros 30 quadros de invulnerabilidade) | VERIFIED |
| 0x26 | Monitor (sólido; quebra rolando por cima; cai se atingido por baixo) + 0x2E conteúdo | VERIFIED (quique/quebra) |
| — | Perda de anéis (até 32, 2 círculos, vida 255 quadros) | IMPLEMENTED_NOT_VERIFIED |
| — | Explosão, pontos, animal | IMPLEMENTED_NOT_VERIFIED (apresentação) |
| 0x40, 0x1F, 0x22/0x23, 0x2B, 0x42 | Motobug, Crabmeat(+bola), Buzz Bomber(+míssil), Chopper, Newtron | VERIFIED (ghz*_bot) |
| 0x41, 0x36 | Molas (cima/lado/baixo), espinhos (dano REV00 sem checar invulnerabilidade) | VERIFIED |
| 0x11, 0x15, 0x18, 0x3B, 0x44, 0x3C, 0x17 | Ponte (curva por fórmula + errata), balanço, plataforma, pedra, borda, parede quebrável, tronco | VERIFIED |
| 0x0D, 0x7D, 0x4B | Placa (bônus de tempo medido), bônus escondido, anel gigante (estágio especial BLOQUEADO) | VERIFIED/BLOQUEADO |
| 0x3D, 0x48, 0x3E, 0x79, 0x1A e demais zonas | chefes, cápsula, poste, desmoronável, objetos de MZ/SYZ/LZ/SLZ/SBZ | NOT_STARTED (inertes; ver matriz) |

Pontuação por inimigos em sequência: 100, 200, 500, 1000; 10 000 a partir do 16º (pontuação interna em unidades de 10).
