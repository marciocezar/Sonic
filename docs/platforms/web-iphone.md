# Web no iPhone (Safari iOS)
- Mesma build de `dist/web`; meta viewport `viewport-fit=cover`, `user-scalable=no`, `touch-action:none`.
- Controles de toque visíveis por padrão (detecção `web_ios`/touchscreen). Áreas seguras: Web não expõe notch ao Godot;
  margens fixas do layout.
- `make web-mobile-check`: verificação estrutural OK. Estado: **NOT_STARTED/BUILT_NOT_TESTED** — sem iPhone disponível.
- Teste manual: `make web-serve LAN=1`, abrir pelo IP local em HTTPS/HTTP no Safari, testar multitoque, rotação, áudio por gesto. Registrar com `make qa-record TARGET=web-ios-safari STATUS=...`.
