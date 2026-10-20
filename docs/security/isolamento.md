# Isolamento
- Perfil `sandbox-exec` gerado por `tooling/sandbox.py`: `(deny network*)`, escrita só em diretórios de análise de `work/`
  e temporários do sistema, leitura negada a ~/.ssh, ~/.aws, ~/.azure, ~/.gnupg, ~/Documents, ~/OneDrive, Keychains, ~/.claude etc.
- Limites: timeout por subprocess; memória do Ghidra via MAXMEM=3G. CPU não é limitada pelo perfil (limitação declarada).
- O REA não funciona sob este perfil (EPERM) e por decisão do usuário não roda fora dele.
- Ferramentas nativas de build (Godot export, xcodebuild) rodam no host com permissões do usuário, sem sudo;
  xcodebuild usa derivedData em `work/` (caches do sistema podem ser usados pelo Xcode — limitação declarada).
