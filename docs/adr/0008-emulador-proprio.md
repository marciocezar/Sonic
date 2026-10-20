# ADR 0008 — Interpretador 68000 próprio como referência
Contexto: nenhum emulador disponível; necessidade de RAM/VRAM por quadro e replays programáticos.
Decisão: interpretador próprio mínimo. Riscos: não cycle-accurate, sem Z80/HBlank. Mitigações: validação cruzada
(tabela de nomes do VDP 100%, física idêntica), documentação das limitações. Reabrir para comparação com um emulador
de referência legalmente configurado quando autorizado.
