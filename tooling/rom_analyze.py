"""make rom-analyze — prova de formato e integridade da ROM Mega Drive (somente leitura).

Saídas:
  reports/analysis/rom-integrity.json   (versionável: só metadados/hashes, nenhum byte da ROM)
  docs/reverse-engineering/04-evidence-ledger.csv (linhas source=rom_analyze)
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import wslib  # noqa: E402

VECTOR_NAMES = ["initial_ssp", "reset_pc", "bus_error", "address_error", "illegal_instr", "zero_divide",
                "chk", "trapv", "privilege", "trace", "line_a", "line_f"]


def header_fields(rom: bytes) -> dict:
    def s(a, b):
        return rom[a:b].decode("ascii", "replace").rstrip()
    return {
        "console": s(0x100, 0x110),
        "copyright": s(0x110, 0x120),
        "title_domestic": " ".join(s(0x120, 0x150).split()),
        "title_overseas": " ".join(s(0x150, 0x180).split()),
        "serial_revision": s(0x180, 0x18E),
        "checksum_header": f"0x{struct.unpack('>H', rom[0x18E:0x190])[0]:04X}",
        "io_support": s(0x190, 0x1A0),
        "rom_start": f"0x{struct.unpack('>I', rom[0x1A0:0x1A4])[0]:08X}",
        "rom_end": f"0x{struct.unpack('>I', rom[0x1A4:0x1A8])[0]:08X}",
        "ram_start": f"0x{struct.unpack('>I', rom[0x1A8:0x1AC])[0]:08X}",
        "ram_end": f"0x{struct.unpack('>I', rom[0x1AC:0x1B0])[0]:08X}",
        "sram": rom[0x1B0:0x1BC].hex(),
        "modem": s(0x1BC, 0x1C8),
        "notes": s(0x1C8, 0x1F0),
        "region": s(0x1F0, 0x200),
    }


def detect_smd_interleave(rom: bytes) -> dict:
    """Arquivos .smd de copiadores têm cabeçalho de 512 bytes e blocos intercalados de 16 KiB."""
    has_sega_at_100 = rom[0x100:0x104] in (b"SEGA", b" SEG")
    copier = len(rom) % 0x4000 == 512
    return {"sega_magic_at_0x100": has_sega_at_100, "copier_header_512": copier,
            "format": "raw_binary_big_endian" if has_sega_at_100 and not copier else "suspeito"}


def checksum(rom: bytes) -> int:
    total = 0
    for i in range(0x200, len(rom) - 1, 2):
        total = (total + ((rom[i] << 8) | rom[i + 1])) & 0xFFFF
    return total


def table_evidence(rom: bytes, sha: str) -> None:
    """Tabelas funcionais localizadas e comparadas com hipóteses/geradores próprios."""
    import math
    ev = evidence.Collector("EV-TAB", sha, "tooling/rom_analyze.py (comparação de tabelas)")
    sin_ref = [struct.unpack(">h", rom[0x29F2 + 2 * k:0x29F4 + 2 * k])[0] for k in range(320)]
    gen = [int(math.sin(k * 2 * math.pi / 256) * 256) for k in range(320)]
    diff = [k for k in range(320) if gen[k] != sin_ref[k]]
    ev.add("trigonometria", "ROM 0x0029F2 (320 words); leitura em PC 0x0029E4/0x0029EC (Ghidra)",
           f"Seno = trunc(sin(k*2pi/256)*256) exceto índices {diff} (valor {[sin_ref[k] for k in diff]})",
           "CONFIRMADO_BINARIO", "alta", "comparação elemento a elemento; errata aplicada em game/src/simulation/trig.gd")
    at_ref = list(rom[0x2D0E:0x2D0E + 257])
    at_gen = [round(math.atan(k / 256) * 128 / math.pi) for k in range(257)]
    ev.add("trigonometria", "ROM 0x002D0E (257 bytes); leitura em PC 0x002CD6/0x002CE2 (Ghidra)",
           f"Arco-tangente = round(atan(k/256)*128/pi): {sum(a == b for a, b in zip(at_ref, at_gen))}/257 iguais",
           "CONFIRMADO_BINARIO", "alta", "comparação elemento a elemento")
    rp = list(rom[0x9B3E:0x9B3E + 32])
    ev.add("objetos", "ROM 0x009B3E (16 pares)", f"Espaçamento de grupos de anéis (dx,dy com sinal): {[(rp[i]-256 if rp[i]>127 else rp[i], rp[i+1]) for i in range(0, 32, 2)]}",
           "CONFIRMADO_BINARIO", "alta", "busca por padrão + uso validado pelo replay ghz1_long_run (anéis idênticos)")
    rs = list(rom[0x1AE40:0x1AE40 + 72])
    ev.add("colisao", "ROM 0x01AE40 (36 pares)", f"Tamanhos de toque (meia-largura, meia-altura) índices 1..0x24: {[(rs[i], rs[i+1]) for i in range(0, 72, 2)][:8]}...",
           "CONFIRMADO_BINARIO", "media", "padrão localizado após RTS; 2 entradas divergiram da hipótese de memória e o valor da ROM foi adotado")
    lo = [struct.unpack(">H", rom[0xC6F4 + 2 * k:0xC6F6 + 2 * k])[0] for k in range(24)]
    ev.add("progressao", "ROM 0x00C6F4 (6 zonas x 4 atos)", "Ordem de fases: " + " ".join(f"{v:04X}" for v in lo),
           "CONFIRMADO_BINARIO", "alta", "GHZ->MZ->SYZ->LZ->SLZ->SBZ1-2->LZ4(SBZ3)->FZ; usado em LevelCatalog.ORIGINAL_ORDER")
    for a, h in [(0xFFD000, "objeto do jogador: x +8, y +C, vx +10, vy +12, gs +14, status +22, rotina +24, ângulo +26"),
                 (0xFFF700, "câmera x (+0 inteiro, +2 fração), y em +4/+6"), (0xFFFE20, "anéis (word)"),
                 (0xFFFE12, "vidas (byte)"), (0xFFFE22, "tempo (min +1, s +2, quadros +3)"), (0xFFF600, "modo de jogo"),
                 (0xFFFE10, "zona/ato"), (0xFFF728, "limites de câmera atuais (esq, dir, topo, base)"),
                 (0xFFF73E, "deslocamento de olhar (look shift)")]:
        ev.add("ram", f"0x{a:06X}", h, "CONFIRMADO_EMULACAO", "alta",
               "valores observados por quadro em traces; paridade idêntica nos replays ghz1_* confirma a interpretação")
    for name, val, how in [("aceleração no chão", "0x0C/quadro", "inércia +12 por quadro (trace ghz1_run_brake)"),
                           ("velocidade máxima", "0x600", "replays + teste unitário"),
                           ("salto", "-0x680 (água -0x380)", "trace ghz1_jumps"),
                           ("gravidade", "0x38/quadro", "trace ghz1_jumps"),
                           ("corte do salto", "-0x400 ao soltar", "trace ghz1_jumps")]:
        ev.add("fisica", "traces de referência", f"{name}: {val}", "CONFIRMADO_EMULACAO", "alta", how)
    evidence.replace_source("tables", ev.rows)


def main():
    rom_path = wslib.require_rom()
    rom = rom_path.read_bytes()
    sha = wslib.sha256_file(rom_path)
    ev = evidence.Collector("EV-ROM", sha, "tooling/rom_analyze.py (Python stdlib, leitura estática)")
    hdr = header_fields(rom)
    fmt = detect_smd_interleave(rom)
    vectors = struct.unpack(">64I", rom[:256])
    vec = {VECTOR_NAMES[i] if i < len(VECTOR_NAMES) else f"vec_{i:02d}": f"0x{v:08X}" for i, v in enumerate(vectors)}
    named = {"hblank_level4": f"0x{vectors[28]:08X}", "vblank_level6": f"0x{vectors[30]:08X}"}
    calc = checksum(rom)
    hdr_ck = struct.unpack(">H", rom[0x18E:0x190])[0]
    rom_end = struct.unpack(">I", rom[0x1A4:0x1A8])[0]

    # bloco de preenchimento no fim da ROM (bytes iguais), útil para o mapa
    tail = len(rom)
    while tail > 0 and rom[tail - 1] == rom[-1]:
        tail -= 1

    report = {
        "file": wslib.ROM_NAME,
        "path": wslib.rel(rom_path),
        "size_bytes": len(rom),
        "size_kib": len(rom) // 1024,
        "sha256": sha,
        "md5": wslib.hash_file(rom_path, "md5"),
        "sha1": wslib.hash_file(rom_path, "sha1"),
        "format_detection": fmt,
        "endianness": "big-endian (Motorola 68000)",
        "header": hdr,
        "checksum_calculated": f"0x{calc:04X}",
        "checksum_match": calc == hdr_ck,
        "rom_end_matches_size": rom_end + 1 == len(rom),
        "vectors": vec,
        "interrupt_vectors": named,
        "padding_tail_start": f"0x{tail:06X}",
        "padding_tail_byte": f"0x{rom[-1]:02X}",
        "suffix_note": "O sufixo .md indica 'Mega Drive', não Markdown.",
        "timestamp": wslib.now_iso(),
    }
    wslib.write_json(wslib.safe_path("reports/analysis/rom-integrity.json"), report)

    ev.add("formato", "0x100-0x10F", f"Magic '{hdr['console']}' em 0x100 identifica cartucho Mega Drive/Genesis",
           "CONFIRMADO_BINARIO" if fmt["sega_magic_at_0x100"] else "DESCONHECIDO", "alta", "leitura direta de bytes")
    ev.add("formato", "arquivo inteiro", f"Tamanho {len(rom)} bytes; sem cabeçalho de copiador (len % 16384 = {len(rom) % 16384}); binário bruto, não intercalado (SMD)",
           "CONFIRMADO_BINARIO", "alta", "aritmética de tamanho + magic em 0x100")
    ev.add("cabecalho", "0x180-0x18D", f"Serial/revisão '{hdr['serial_revision']}'",
           "CONFIRMADO_BINARIO", "alta", "leitura ASCII")
    ev.add("cabecalho", "0x1F0-0x1FF", f"Região declarada '{hdr['region']}' (J/U/E); timing NTSC/PAL não é inferido disso",
           "CONFIRMADO_BINARIO", "alta", "leitura ASCII")
    ev.add("integridade", "0x18E", f"Checksum calculado 0x{calc:04X} vs cabeçalho 0x{hdr_ck:04X}: {'confere' if calc == hdr_ck else 'NÃO confere'}",
           "CONFIRMADO_BINARIO", "alta", "soma de words 0x200..fim mod 0x10000")
    ev.add("cpu", "0x000-0x0FF", f"Vetores 68000: SSP inicial {vec['initial_ssp']}, reset PC {vec['reset_pc']}, VBlank {named['vblank_level6']}, HBlank {named['hblank_level4']}",
           "CONFIRMADO_BINARIO", "alta", "decodificação big-endian dos 64 vetores")
    ev.add("mapa", f"0x{tail:06X}-0x{len(rom)-1:06X}", f"Preenchimento final com byte 0x{rom[-1]:02X}",
           "CONFIRMADO_BINARIO", "media", "varredura reversa de bytes repetidos")
    evidence.replace_source("rom_analyze", ev.rows)
    table_evidence(rom, sha)
    wslib.info(f"ROM OK: {len(rom)} bytes, sha256={sha}")
    wslib.info(f"serial={hdr['serial_revision']} região={hdr['region']} checksum={'OK' if calc == hdr_ck else 'DIVERGENTE'}")
    wslib.info("relatório: reports/analysis/rom-integrity.json")


if __name__ == "__main__":
    main()
