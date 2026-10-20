"""make listing FROM=0xF61A TO=0xF780 — mostra a listagem Ghidra privada de um intervalo (diagnóstico local)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

a, b = int(sys.argv[1], 16), int(sys.argv[2], 16)
for line in wslib.safe_path("private/extracted/ghidra/ghidra-listing.txt").read_text().splitlines():
    addr = int(line[:6], 16)
    if a <= addr < b:
        print(line)
