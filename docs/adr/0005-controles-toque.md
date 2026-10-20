# ADR 0005 — Controles de toque
Decisão: overlay desenhado no jogo com lógica pura testável (`TouchLogic`): captura por ponteiro, arrasto entre
botões, cancelamento, área segura, tamanho/opacidade/posição ajustáveis, zona morta. Visível por padrão em apps
móveis e Web móvel; oculto no desktop salvo opção. Toque/teclado/gamepad só emitem ações (byte de botões).
