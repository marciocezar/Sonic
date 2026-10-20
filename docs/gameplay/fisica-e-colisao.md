# Física e colisão (especificação implementada em `game/src/entities/player.gd` e `collision/terrain.gd`)

Unidades: posição 16.16, velocidade 8.8 (1/256 px/quadro), ângulo 0–255 (0 = chão; aumenta no sentido horário com Y para baixo).
Tick fixo de 60 Hz. Status: VERIFIED nos replays GHZ1 salvo indicação.

## Parâmetros (EV-TAB fisica)
| Parâmetro | Normal | Tênis | Água |
|---|---|---|---|
| velocidade máxima | 0x600 | 0xC00 | 0x300 |
| aceleração / atrito | 0x0C | 0x18 | 0x06 |
| desaceleração (frenagem) | 0x80 | 0x80 | 0x40 |
| salto | −0x680 | — | −0x380 |
| corte do salto | −0x400 | — | −0x200 |
| gravidade | 0x38 | — | 0x38 − 0x28 |
Rolamento: atrito = aceleração/2, frenagem = desaceleração/4, |vx| ≤ 0x1000; rampa ×0x50 (÷4 subindo). Rampa a pé: ×0x20.

## Ordem por modo
- Chão: salto (aborta o resto do quadro) → resistência de rampa → movimento → início de rolamento → limites → posição → sensores → repulsão em paredes/teto.
- Rolando: salto → rampa de rolamento → velocidade de rolamento → limites → posição → sensores → repulsão.
- Ar: corte de salto → controle aéreo (aceleração×2; travado no roll-jump) → limites → queda (posição com vy antiga, depois +0x38) → água → ângulo volta a 0 (±2) → colisão aérea por quadrante de movimento.

## Regras notáveis
- Segurar a direção acima da velocidade máxima **reduz** para a máxima (não preserva).
- Frenagem: ao cruzar zero vira ±0x80 (assimetria: virar à esquerda com gs igual à desaceleração dá 0).
- Arrasto aéreo apenas com −0x400 ≤ vy < 0: vx −= vx>>5 (negativos sempre decaem ≥1).
- Escorregar: em superfícies não-chão com |gs| < 0x280 cai e trava controle 30 quadros.
- Sensores: dois verticais nas bordas (x±raio_x, y+raio_y); menor distância vence, empate favorece o segundo;
  ajuste até ±14 px; acima disso cai (exceto "grudar"). Ângulo ímpar = usar ângulo cardinal.
- Mapas de altura 16×16 com espelhos X/Y por bloco; extensão para o tile vizinho ao encontrar vazio/cheio.
- Pouso: ângulo plano → gs = vx; inclinação média → vy/2; íngreme → vx=0, gs=±vy (máx 0xFC0).
- Loops (GHZ/SLZ): chunk com bit 7 alterna para o chunk seguinte conforme posição/ângulo (IMPLEMENTED_NOT_VERIFIED).
