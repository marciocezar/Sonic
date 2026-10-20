# Critérios de paridade
- Caso determinístico comparável = mesma fase, estado F0 medido, mesma sequência de entradas por quadro.
- Aprovação (IDENTICO): todos os campos estritos iguais em todos os quadros (tolerância 0). Qualquer diferença = DIVERGE.
- Campos suaves (anim, fração vertical da câmera, timers auxiliares, limites, RNG) são relatados para diagnóstico.
- Sem referência: NAO_AVALIADO. Referência = interpretador próprio (limitações em 02-metodologia-rea.md).
- Thresholds versionados em `tooling/parity.py` (FIELDS_STRICT/FIELDS_SOFT).
