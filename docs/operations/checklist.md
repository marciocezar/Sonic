# Checklist antes de entregar um lote
- [ ] `make lint format-check` OK
- [ ] `make test` OK (paridade sem DIVERGE nos replays existentes)
- [ ] `make security-check check-no-rom-in-dist assets-check package-check` OK
- [ ] `make qa-matrix reverse-report docs`
- [ ] STATUS.md e CONTINUE-CLAUDE.md atualizados
