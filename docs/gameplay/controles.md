# Controles

## Original (inferido do código e confirmado por emulação)
Controle de 3 botões: direcional, A, B, C e Start. A, B e C saltam (máscara 0x70 nos replays: A em ghz1_long_run,
B em ghz1_roll, C em ghz1_jumps — todos idênticos). Start pausa. Baixo em movimento rola; parado agacha; cima olha.

## Mapeamento do projeto (adaptador único `InputRouter`)
| Ação | Bit | Teclado padrão | Gamepad | Toque |
|---|---|---|---|---|
| Cima/Baixo/Esq./Dir. | 1/2/4/8 | Setas, WASD | D-pad, analógico (zona morta 0.4) | direcional (8 direções, zona morta 28%) |
| B | 16 | K, X | botão inferior | B |
| C | 32 | L, C, Espaço | botão direito | C |
| A | 64 | J, Z | botão esquerdo | A |
| Start | 128 | Enter, Esc, P | Start | START |

Teclas remapeáveis e persistidas (`user://settings.cfg`, schema 1). Perda de foco libera tudo (sem tecla presa).
Toques mais curtos que um quadro são retidos até a próxima leitura. O teclado de texto do sistema nunca é aberto.
