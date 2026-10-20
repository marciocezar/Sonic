# ADR 0003 — Formato de recursos
Decisão: JSON neutro (schema 1) para fases e replays; JSONL para traces; ConfigFile para configurações.
Levelpacks privados são lidos de um diretório externo informado na execução (nunca importados em `res://`).
Motivo: rastreabilidade (diff legível), separação estrita entre projeto publicável e dados protegidos.
