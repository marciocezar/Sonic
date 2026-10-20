# ADR 0004 — Renderer Web/mobile
Decisão: `gl_compatibility` (WebGL 2) em todos os destinos; Web sem threads (não exige COOP/COEP/SharedArrayBuffer,
melhor para Safari iOS); compressão ETC2/ASTC habilitada. WebGL 2 em aparelho específico só é afirmado após teste
real (`make web-mobile-check` é estrutural).
