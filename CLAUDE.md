# CLAUDE.md — regras do workspace sonic-megadrive

## Escopo (obrigatório)
- Trabalhe **somente** neste diretório e **somente** com `Sonic The Hedgehog (USA, Europe).md` (raiz ou `roms/`).
- Não acesse outros jogos, pastas vizinhas, `~/Documents`, `~/.ssh`, `~/.aws`, credenciais ou configuração global do agente.
- Emulador Android e iOS Simulator AUTORIZADOS (decisão do usuário, 2026-10-18, revogando a restrição anterior).
  Outras ferramentas que gravem fora do workspace continuam exigindo autorização explícita.
- REA AUTORIZADO fora do `sandbox-exec` (2026-10-18): local, sem rede, sem MCP global, lendo só o workspace.
  Ghidra headless continua em sandbox.
- Objetivo atual: jogo completo (todas as telas/fases/chefes/estágios especiais/sons) nas 6 modalidades
  (Windows, macOS, Web, Azure Web privada, Android, iOS). Conteúdo original é IMPORTADO DA ROM DO USUÁRIO EM
  EXECUÇÃO; builds (inclusive Azure privada) não contêm dados da Sega. Roadmap: `docs/operations/ROADMAP-JOGO-COMPLETO.md`.
- Nada de `sudo`, instalações globais, `curl | sh`, commit/push remoto, upload da ROM.

## Interface
- Tudo via `make` (`make help`). Scripts Python em `tooling/` só são chamados pelo Makefile.
- Antes de cada lote: liste arquivos a alterar. Depois: rode os alvos correspondentes e confira exit codes.

## Checkpoints
- Estado: `docs/STATUS.md`. Continuação: `docs/operations/CONTINUE-CLAUDE.md`. Atualize ambos ao final de cada lote.
- Não refaça operações caras (`bootstrap`, `extract-data`) sem necessidade.

## Honestidade
- Status permitidos: CONFIRMADO_BINARIO, CONFIRMADO_EMULACAO, INFERIDO, DESCONHECIDO, BLOQUEADO (evidências);
  NOT_STARTED, IN_PROGRESS, IMPLEMENTED_NOT_VERIFIED, VERIFIED, BLOCKED (mecânicas);
  NOT_STARTED, BUILT_NOT_TESTED, PASS, FAIL, BLOCKED (builds).
- Nunca declarar "idêntico ao original", "totalmente descompilado" ou "publicação autorizada".

## Links
- `README.md`, `docs/reverse-engineering/`, `docs/qa/`, `docs/security/`, `docs/operations/`.
