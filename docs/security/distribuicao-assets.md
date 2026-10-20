# Política de distribuição de assets
1. A ROM e qualquer derivado (layouts, chunks, colisão, VRAM, paletas, listas de objetos, traces) são **privados**.
2. Builds publicáveis só contêm conteúdo próprio inventariado por `make assets-check`.
3. Perfil Fidelity com arte original existe apenas em execução local de laboratório (`make run` com levelpacks).
4. `make check-no-rom-in-dist` deve passar antes de qualquer distribuição; `make package-check` garante nomes/IDs sem afiliação.
5. Redistribuição de qualquer asset original exige autorização/licença dos detentores. Este projeto não possui.
