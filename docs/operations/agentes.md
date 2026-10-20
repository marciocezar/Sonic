# README para agentes
1. Leia `CLAUDE.md`, `docs/STATUS.md`, `docs/operations/CONTINUE-CLAUDE.md`.
2. Respeite o escopo: só este workspace e só a ROM deste jogo; nada de emuladores/simuladores externos sem autorização.
3. Use apenas `make`. Após mudanças: `make lint test` e, se tocou física/objetos, `make test-parity`.
4. Para nova mecânica: crie replay em `tests/parity/replays/`, `make reference-traces REPLAY=x`, implemente, `make test-parity REPLAY=x`.
5. Atualize `tooling/mechanics.json`, rode `make qa-matrix`, atualize STATUS/CONTINUE.
6. Nunca marque VERIFIED/PASS sem execução real registrada.
