# Paridade por replay (gerado por `make test-parity`)

Gerado em 2026-10-19T02:57:50+00:00. Tolerância 0 nos campos estritos: x, xs, y, ys, xv, yv, gs, ang, st, rt, camx, camy, rings, lives, score, time, look, yr, xr, bgx, bgy, bg2x, bgv, hsb, frm.

| Replay | Status | Quadros comparados | Fim | 1ª divergência | Campos |
|---|---|---|---|---|---|
| ghz1_bot | IDENTICO | 3241 | quadro 3241: entrada no anel gigante (estágio especial não reconstruído) | None |  |
| ghz1_death | IDENTICO | 329 | quadro 329: referência recarregando a fase | None |  |
| ghz1_idle | IDENTICO | 241 | fim do replay | None |  |
| ghz1_jumps | IDENTICO | 301 | fim do replay | None |  |
| ghz1_ledge | IDENTICO | 601 | fim do replay | None |  |
| ghz1_long_run | IDENTICO | 901 | fim do replay | None |  |
| ghz1_roll | IDENTICO | 301 | fim do replay | None |  |
| ghz1_run_brake | IDENTICO | 261 | fim do replay | None |  |
| ghz2_bot | IDENTICO | 1884 | fim do replay | None |  |
| ghz3_boss | DIVERGE_FRONTEIRA | 1059 | fim do replay | 1059 | xv, yv, gs, rt |
| ghz3_bot | IDENTICO | 3001 | fim do replay | None |  |
| lz1_bot | DIVERGE_FRONTEIRA | 901 | fim do replay | 114 | xv, yv, st, x, y, ys |
| mz1_bot | DIVERGE_FRONTEIRA | 1538 | fim do replay | 0 | bgy, bgv, x, xv, gs, st |
| sbz1_bot | IDENTICO | 197 | fim do replay | None |  |
| slz1_bot | DIVERGE_FRONTEIRA | 901 | fim do replay | 345 | xv, yv, gs, st, rt, camy |
| syz1_bot | DIVERGE_FRONTEIRA | 751 | fim do replay | 736 | y, st, camy, bgy, bgv, xs |
