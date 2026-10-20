# 06 — Riscos e lacunas

| Lacuna | Impacto | Próximo passo |
|---|---|---|
| REA bloqueado sob sandbox | nenhuma evidência via REA | autorização explícita para rodar fora do sandbox ou provider alternativo |
| Interpretador não cycle-accurate | quadros com lag podem divergir | comparar com emulador de referência legalmente configurado |
| Z80/áudio não emulados | música/SFX originais não analisados | não necessário para lógica; música própria/licenciada |
| Maioria dos objetos (inimigos, plataformas, chefes) | fases jogáveis mas incompletas | implementar por zona com replays |
| Eventos dinâmicos fora de GHZ | limites de câmera estáticos nessas zonas | medir via traces de limites |
| Deformação de fundo/HBlank | parallax aproximado no Fidelity | reconstruir por zona |
| Estágios especiais, final | ausentes | extrair layout via RAM e reimplementar |
| Animações/sprites originais | Fidelity usa sprite próprio do personagem | extrair mapeamentos (privado) |
| Testes em aparelhos (iOS/Android/Safari/Chrome mobile/Windows) | sem PASS real | sessões em dispositivos reais |
| Avaliação jurídica de parâmetros funcionais | risco de distribuição | revisão por profissional |
