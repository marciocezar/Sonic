# Instalação segura
- Tudo em `tooling/` e `work/`; nenhuma instalação global, nenhum `sudo`, nenhum `curl | sh`.
- Versões e hashes em `tooling/versions.lock`; downloads verificados antes de extrair (proteção contra zip-slip).
- Godot em modo auto-contido (`_sc_`): configurações e templates em `tooling/godot/editor_data`.
- REA: `npm install --prefix tooling/rea --ignore-scripts`; **não** executar `rea setup` (alteraria registros globais do agente).
