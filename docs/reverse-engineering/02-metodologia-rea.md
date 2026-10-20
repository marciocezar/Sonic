# 02 — Metodologia (REA, Ghidra, interpretador próprio)

Ciclo: hipótese → inspeção → evidência → teste de referência → especificação → código novo → replay → comparação.

## REA (Reverse Engineer Anything) 6.7.0
- Instalado localmente em `tooling/rea` (`npm --prefix`, `--ignore-scripts`, integridade npm verificada). `setup` **não** executado.
- Executado sempre em `sandbox-exec` (sem rede; escrita só em `work/rea*`; `HOME` isolado em `work/rea-home`).
- `rea doctor --provider ghidra`: Ghidra 12.1.4 reconhecido; decompilador nativo arm64 compilado localmente
  (`make bootstrap COMPONENTS=ghidra-natives`); **falha** `java: spawn EPERM` apenas sob sandbox.
- `rea inspect-artifact <rom>`: "unsupported binary format" (REA não reconhece ROM bruta por cabeçalho).
- `rea analyze --target-format raw-binary --architecture m68k`: **BLOQUEADO** (provider indisponível sob sandbox).
- Decisão do usuário (2026-10-18): não rodar REA fora do sandbox. Portanto **nenhuma** conclusão deste projeto
  foi produzida pelo REA; o relatório registra isso explicitamente (`EV-REA-*`).

## Ghidra 12.1.4 (complementar)
- `make ghidra-analyze`: import BinaryLoader base 0, `68000:BE:32:default`, vetores semeados (pre-script próprio)
  e **PCs executados medidos no interpretador** (cobertura dinâmica, `private/extracted/coverage_pcs.txt`).
- Resultado: 304 funções / 16 415 instruções (antes da semeadura: 198 / 6 754). Listagem e inventário ficam em
  `private/extracted/ghidra/` (derivados da ROM, privados). Descompilação não foi usada como fonte de código.

## Interpretador 68000 e máquina mínima próprios
- `tooling/m68k.py`: ISA inteira do 68000, exceções e IRQ. `tooling/mdmachine.py`: ROM/RAM, VDP (registradores,
  VRAM/CRAM/VSRAM, DMA), controle de 3 botões (protocolo TH), Z80 apenas como RAM + barramento concedido.
- Temporização aproximada (custo fixo por instrução); quadro começa no VBlank; laço ocioso avançado.
- Limitações: sem Z80/áudio, sem HBlank, sem renderização exata; quadros com lag podem divergir do hardware.
- Uso: boot até o título, seleção de zona/ato por escrita em RAM, dumps pós-carga, traces por quadro,
  rastreio de leituras de ROM por PC (localizou alturas/ângulos/índice de colisão), cobertura de PCs.
- Validação: a decodificação chunk→bloco→tile reproduz 1120/1120 células da tabela de nomes do VDP nas 19 fases;
  a física reimplementada reproduz os traces com tolerância zero (ver 05-paridade.md).

## Por que não um emulador de terceiros
Nenhum emulador estava instalado; o interpretador próprio dá acesso programático a RAM/VRAM por quadro e roda
no sandbox natural do Python (sem execução nativa de código da ROM). Ver ADR 0008.
