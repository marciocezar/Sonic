# Windows
- Saída: `make build-windows` → `dist/windows/MegadrivePlatformerLab.exe` + `.pck` (x86_64; também `.console.exe` quando gerado).
- Estado: **BUILT_NOT_TESTED** (PE x86-64 válido; sem máquina/VM Windows disponível). Teste: copiar `.exe`+`.pck` juntos e executar.
- Ícone/metadados do executável não modificados (rcedit não usado). Assinatura Authenticode não configurada.
- Desenvolvimento em Windows: instale MSYS2, `pacman -S make python`; defina `GODOT_BIN` para um Godot 4.7.2 oficial
  (o bootstrap automático baixa o editor apenas para macOS).
