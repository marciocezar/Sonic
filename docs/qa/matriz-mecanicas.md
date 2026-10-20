# Matriz de mecânicas, fases e objetos (gerada por `make qa-matrix`)

Atualizada: 2026-10-18T22:59:31+00:00. Resumo: BLOCKED=1, IMPLEMENTED_NOT_VERIFIED=12, IN_PROGRESS=3, NOT_STARTED=6, VERIFIED=17

> Código que compila não é jogo completo. VERIFIED exige replay idêntico à referência medida.

| Área | Mecânica | Status | Evidência |
|---|---|---|---|
| Física | Aceleração/frenagem/atrito no chão | **VERIFIED** | replay ghz1_run_brake (idêntico); EV-TAB fisica |
| Física | Salto curto/longo, gravidade, corte | **VERIFIED** | replay ghz1_jumps (idêntico) |
| Física | Controle aéreo e arrasto | **VERIFIED** | replay ghz1_jumps/ghz1_long_run |
| Física | Rolamento, roll-jump, desenrolar | **VERIFIED** | replay ghz1_roll (idêntico) |
| Física | Rampas (resistência, repulsão, queda de paredes) | **VERIFIED** | replay ghz1_long_run (idêntico 900 quadros) |
| Física | Sensores de chão/parede/teto, modos de quadrante | **VERIFIED** | replays ghz1_* (idênticos) |
| Física | Loops (troca de caminho) e túneis de rolagem | **IMPLEMENTED_NOT_VERIFIED** | player.gd _loops; replay de loop pendente |
| Física | Água (LZ/SBZ3): velocidades, salto, respingo | **IMPLEMENTED_NOT_VERIFIED** | player.gd _water; nível da água dinâmico pendente |
| Física | Afogamento / bolhas de ar | **NOT_STARTED** |  |
| Câmera | Rolagem horizontal/vertical, look up/down | **VERIFIED** | camx/camy/look idênticos nos replays ghz1_* |
| Câmera | Eventos dinâmicos de limites GHZ | **IMPLEMENTED_NOT_VERIFIED** | dynamic_events.gd; replay até x>=0x1780 pendente |
| Câmera | Eventos dinâmicos MZ/SYZ/LZ/SLZ/SBZ/FZ | **NOT_STARTED** |  |
| Objetos | Anéis (grupos, coleta, respawn) | **VERIFIED** | rings idênticos no replay ghz1_long_run |
| Objetos | Monitor + conteúdo (10 anéis/tênis/escudo/invencibilidade/vida) | **VERIFIED** | quique no monitor (quadro 174) idêntico; efeitos de conteúdo além de anéis não verificados |
| Objetos | Perda de anéis ao sofrer dano | **VERIFIED** | ghz2_bot: dano com anéis, espalhamento e recoleta idênticos (eixos seno/cosseno confirmados em ROM 0x9D40) |
| Objetos | Inimigos GHZ (Motobug, Crabmeat, Buzz Bomber, Chopper, Newtron) | **VERIFIED** | Motobug, Crabmeat(+bola), Buzz Bomber(+míssil), Chopper, Newtron: replays ghz1_bot/ghz2_bot/ghz3_bot/ghz1_death idênticos (ocupação de slots idêntica) |
| Objetos | Molas, espinhos, plataformas, ponte, pedra, muro | **IN_PROGRESS** | VERIFIED: molas, espinhos (bug REV00), ponte, pedra, plataforma 0x18, balanço 0x15, borda 0x44, parede quebrável 0x3C; pendentes: desmoronável 0x1A, tronco 0x17 |
| Objetos | Placa de fim de ato, poste de checkpoint | **IN_PROGRESS** | placa VERIFIED (tempo para, câmera trava) em ghz1_bot; poste pendente |
| Chefes | Chefes de todas as zonas e Final Zone | **NOT_STARTED** |  |
| Fluxo | Título, seleção, pausa, opções, game over | **IMPLEMENTED_NOT_VERIFIED** | main.gd (apresentação própria; não reproduz telas originais) |
| Fluxo | Cartão de título, HUD, tempo, vidas, pontuação | **IMPLEMENTED_NOT_VERIFIED** | tempo/vidas/pontuação idênticos nos replays; visual próprio |
| Fluxo | Fim de ato com bônus e progressão | **IMPLEMENTED_NOT_VERIFIED** | ordem EV-TAB progressao; tabela de bônus de tempo medida (ROM 0xECF0) usada pela placa |
| Fluxo | Morte, reinício, game over, continues | **IN_PROGRESS** | morte por inimigo sem anéis VERIFIED (ghz1_death até a recarga); continues não |
| Fluxo | Estágios especiais e esmeraldas | **NOT_STARTED** |  |
| Fluxo | Final (ending) e créditos | **NOT_STARTED** |  |
| Fases | Geometria das 19 fases (privado, ROM do usuário) | **VERIFIED** | EV-EXT plano A 1120/1120 em todas as fases |
| Fases | Fase própria publicável Lab Zone | **IMPLEMENTED_NOT_VERIFIED** | tooling/gen_demo_level.py |
| Render | Fidelity com arte privada (VRAM capturada) | **IMPLEMENTED_NOT_VERIFIED** | screenshots locais; sprites próprios; parallax aproximado |
| Render | Enhanced com arte própria | **IMPLEMENTED_NOT_VERIFIED** | geometry_art.gd/sprite_painter.gd |
| Render | Mesma simulação em ambos os perfis | **VERIFIED** | mesmo estado final (x/y/anéis) em smoke Fidelity e Enhanced |
| Áudio | Efeitos sonoros próprios por evento | **IMPLEMENTED_NOT_VERIFIED** | audio_bus.gd |
| Áudio | Música/FM reconstruída | **NOT_STARTED** | sem assets licenciados |
| Entrada | Teclado remapeável persistido, gamepad | **IMPLEMENTED_NOT_VERIFIED** | input_router.gd; teclado verificado no navegador |
| Entrada | Toque multitoque (lógica) | **VERIFIED** | make test-touch (11 casos) |
| Entrada | Toque em aparelho real | **BLOCKED** | sem aparelho; emulador suspenso por decisão do usuário |
| Objetos | Explosão → animal (RNG) → pontos | **VERIFIED** | slots/RNG idênticos ao longo de ghz1_bot |
| Objetos | Bônus escondido e anel gigante (presença/toque) | **IMPLEMENTED_NOT_VERIFIED** | bônus VERIFIED na pontuação de ghz1_bot; anel gigante leva a estágio especial (BLOQUEADO) |
| Objetos | Carga/descarga de objetos pela câmera (cursores, respawn) | **VERIFIED** | lógica de ROM 0xD8F0..0xDA8A; ocupação de slots idêntica em ghz1/2/3_bot |
| Simulação | Osciladores globais e animação sincronizada | **VERIFIED** | ROM 0x4118/0x416E/0x4206; plataformas e balanços idênticos em ghz2_bot |

## Cobertura de tipos de objeto das fases originais

Instâncias cobertas por objetos implementados: 1927/4031 (47.8%). Tipos implementados: 19/79.

| ID | Instâncias nas 19 fases | Implementado |
|---|---|---|
| 0x0B | 5 | não |
| 0x0C | 3 | não |
| 0x0D | 13 | sim |
| 0x11 | 11 | sim |
| 0x12 | 21 | não |
| 0x13 | 51 | não |
| 0x15 | 26 | sim |
| 0x16 | 30 | não |
| 0x17 | 4 | sim |
| 0x18 | 96 | sim |
| 0x1A | 19 | não |
| 0x1C | 41 | não |
| 0x1E | 10 | não |
| 0x1F | 43 | sim |
| 0x22 | 78 | sim |
| 0x25 | 829 | sim |
| 0x26 | 206 | sim |
| 0x2A | 14 | não |
| 0x2B | 14 | sim |
| 0x2C | 35 | não |
| 0x2D | 81 | não |
| 0x2F | 37 | não |
| 0x30 | 14 | não |
| 0x31 | 23 | não |
| 0x32 | 49 | não |
| 0x33 | 6 | não |
| 0x36 | 205 | sim |
| 0x3B | 25 | sim |
| 0x3C | 26 | sim |
| 0x3E | 10 | não |
| 0x40 | 15 | sim |
| 0x41 | 159 | sim |
| 0x42 | 32 | sim |
| 0x43 | 4 | não |
| 0x44 | 74 | sim |
| 0x46 | 99 | não |
| 0x47 | 43 | não |
| 0x49 | 11 | não |
| 0x4B | 11 | sim |
| 0x4C | 4 | não |
| 0x4E | 1 | não |
| 0x50 | 10 | não |
| 0x51 | 30 | não |
| 0x52 | 18 | não |
| 0x53 | 45 | não |
| 0x54 | 48 | não |
| 0x55 | 37 | não |
| 0x56 | 233 | não |
| 0x57 | 39 | não |
| 0x58 | 34 | não |
| 0x59 | 16 | não |
| 0x5A | 68 | não |
| 0x5B | 23 | não |
| 0x5C | 3 | não |
| 0x5D | 36 | não |
| 0x5E | 16 | não |
| 0x5F | 99 | não |
| 0x60 | 40 | não |
| 0x61 | 60 | não |
| 0x62 | 21 | não |
| 0x63 | 36 | não |
| 0x64 | 68 | não |
| 0x65 | 60 | não |
| 0x66 | 2 | não |
| 0x67 | 8 | não |
| 0x68 | 20 | não |
| 0x69 | 56 | não |
| 0x6A | 14 | não |
| 0x6B | 19 | não |
| 0x6C | 64 | não |
| 0x6D | 42 | não |
| 0x6E | 52 | não |
| 0x6F | 6 | não |
| 0x70 | 12 | não |
| 0x71 | 88 | não |
| 0x72 | 8 | não |
| 0x78 | 37 | não |
| 0x79 | 25 | não |
| 0x7D | 60 | sim |
