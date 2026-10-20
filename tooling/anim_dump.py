"""make anim-dump ADDR=0xF782 — decodifica uma tabela de scripts de animação (diagnóstico local, privado)."""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

rom = wslib.require_rom().read_bytes()
base = int(sys.argv[1], 16)
first = struct.unpack(">H", rom[base:base + 2])[0]
n = first // 2
for i in range(n):
    off = struct.unpack(">H", rom[base + 2 * i:base + 2 * i + 2])[0]
    p = base + off
    out = [rom[p]]
    k = p + 1
    while True:
        b = rom[k]
        out.append(b)
        k += 1
        if b >= 0xFA:
            if b in (0xFE, 0xFD):
                out.append(rom[k])
            break
    print(f"anim {i}: dur={out[0]} frames={[hex(x) for x in out[1:]]}")
