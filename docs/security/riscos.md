# Riscos de segurança
| Risco | Mitigação |
|---|---|
| Execução de código da ROM | só no interpretador Python próprio; nenhuma execução nativa |
| Ferramentas de terceiros (REA/Ghidra) | sandbox-exec sem rede, escrita restrita a work/, HOME isolado |
| Vazamento de conteúdo protegido em builds | `check-no-rom-in-dist` (hash, assinatura do cabeçalho, SHA da ROM em dados), export_filter exclui tests/ |
| Traversal/links simbólicos | `safe_path` canônico; `security-check` procura links para fora |
| Segredos versionados | `.gitignore` + varredura de padrões em `security-check` |
| Downloads | somente aprovados, versão fixa, SHA-512/SHA-256/integridade npm verificados |
| Escrita fora do workspace | proibida; emuladores/simuladores suspensos por decisão do usuário |
| Envio de dados ao provedor de IA | apenas resumos textuais mínimos; nenhum binário anexado |
