# Onboarding
## macOS
Xcode CLT (make, python3) já bastam: `make doctor`, `make bootstrap` (pede ~2.3 GB em tooling/ e ~1.9 GB em work/downloads).
## Windows
Instale MSYS2 (msys2.org), no terminal MSYS2: `pacman -S make python`. Baixe Godot 4.7.2 oficial e defina `GODOT_BIN`.
Os scripts usam apenas APIs Python portáveis (sem rm/sed/grep nas receitas). Caminhos com espaços/parênteses são tratados via pathlib.
## Linux
`make` e `python3` do sistema; defina `GODOT_BIN`.
## ROM
Coloque `Sonic The Hedgehog (USA, Europe).md` na raiz ou em `roms/`. Ela nunca é modificada (fica somente leitura).
