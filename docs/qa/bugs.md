# Bugs e limitações conhecidas
| ID | Descrição | Status |
|---|---|---|
| B-001 | Toques de tecla < 1 quadro eram perdidos (Web) | corrigido (retenção em InputRouter) |
| B-002 | Sprites desenhados sem deslocamento de câmera | corrigido |
| B-003 | Interior de terreno sem colisão vazio no Enhanced | corrigido (varredura de interior) |
| B-004 | Fundo (plano B) no Fidelity com parallax aproximado | aberto |
| B-005 | Bônus de tempo do fim de ato inferido | aberto |
| B-006 | test_ios reportava sucesso sem instalação | corrigido |
| B-007 | Objetos não implementados ficam inertes (sem colisão) | aberto (ver matriz) |
| B-008 | Simulator iOS 27 rejeita build x86_64 do template oficial | bloqueado |
| B-009 | Web falhava ao abrir index.html por file:// (bloqueio do navegador a fetch/addModule) | corrigido: `index.embed.js` carregado só em file:// |
