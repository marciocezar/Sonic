# ADR 0007 — Segurança e isolamento
Decisão: escopo restrito ao workspace (`wslib.safe_path` com caminho canônico); terceiros (REA/Ghidra) em
`sandbox-exec` sem rede; código da ROM só executa no interpretador Python (sem execução nativa); downloads apenas
com aprovação, versão fixa e hash; original somente leitura; nada de emuladores/simuladores externos sem autorização.
