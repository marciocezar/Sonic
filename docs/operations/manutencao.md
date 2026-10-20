# Manutenção
- Atualizar Godot: alterar `tooling/versions.lock` (URL/SHA-512 da release oficial), `make bootstrap COMPONENTS="godot templates"`,
  reexportar e repetir `make test`.
- Atualizar REA: mudar versão/integridade no lock e `make bootstrap COMPONENTS=rea`; reavaliar compatibilidade com sandbox.
- Novos replays: adicionar JSON em tests/parity/replays e regenerar traces.
