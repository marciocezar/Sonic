# Release
Não há release pública autorizada. Para um release interno:
1. `make clean build-supported verify-artifacts check-no-rom-in-dist package-check license-audit sbom`.
2. macOS: assinar com Developer ID e notarizar (fora do escopo atual). Windows: Authenticode (opcional).
3. Android: `build-android-aab` com keystore de release. iOS: `ios-archive` com Team/provisioning.
4. Revisão jurídica da política de assets e parâmetros funcionais antes de qualquer distribuição.
