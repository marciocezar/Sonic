# Schemas

## Levelpack / fase (schema 1, JSON)
`id, zone, act, zone_name, start{x,y}, limits{left,right,top,bottom}, layout_fg[8][64], layout_bg[8][64],
chunks[n][256] (palavras de bloco), blocks[n][4] (palavras de tile), collision_index[], loop_chunks[2],
roll_chunks[2], water_level|null, objects[{x,y,yraw,id,sub}], cram[64]?, vdp_regs[24]?, theme?`.
Fases próprias incluem `collision{heights[4096], widths[4096], angles[256]}` e `license`.
Levelpacks privados carregam `source_sha256` (SHA da ROM) — usado por `check-no-rom-in-dist`.

## Replay (tests/parity/replays/*.json)
`{name, level, description, inputs: [[quadros, "UDLRBCAS"], ...], frames}`.

## Trace (JSONL por quadro)
`f, in, x, xs, y, ys, xv, yv, gs, yr, xr, anim, frm, st, rt, ang, lock, stick, jmp, inv, camx, camxs, camy, camys,
rings, lives, score, time, look, lim[4], rng` (+ `mode, zone, act` na referência).

## Settings (user://settings.cfg)
`meta.schema=1; video.profile; touch.{mode,size,opacity,dpad_offset,buttons_offset,deadzone}; audio.{sfx,music};
debug.overlay; input.bindings{acao:[keycodes]}; progress.level`.

## Status de build (reports/build/status.json)
`{alvo: {status, timestamp, command, notes, host, artifacts[{path,size,sha256}]}}`.
