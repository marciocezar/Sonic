"""Testes unitários da ferramentaria (stdlib unittest). Executados por `make test-unit`."""
import csv
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tooling"))
import wslib  # noqa: E402
from m68k import CPU  # noqa: E402


class Bus:
    def __init__(self, code: bytes):
        self.mem = bytearray(0x10000)
        self.mem[0x100:0x100 + len(code)] = code

    def read8(self, a): return self.mem[a & 0xFFFF]
    def read16(self, a): a &= 0xFFFF; return (self.mem[a] << 8) | self.mem[a + 1]
    def read32(self, a): return (self.read16(a) << 16) | self.read16(a + 2)
    def write8(self, a, v): self.mem[a & 0xFFFF] = v & 0xFF
    def write16(self, a, v): a &= 0xFFFF; self.mem[a] = (v >> 8) & 0xFF; self.mem[a + 1] = v & 0xFF
    def write32(self, a, v): self.write16(a, v >> 16); self.write16(a + 2, v)


def run(code_hex, steps, setup=None):
    bus = Bus(bytes.fromhex(code_hex))
    cpu = CPU(bus)
    cpu.pc, cpu.a[7] = 0x100, 0x8000
    if setup:
        setup(cpu)
    for _ in range(steps):
        cpu.step()
    return cpu


class TestScope(unittest.TestCase):
    def test_traversal_rejected(self):
        with self.assertRaises(wslib.ScopeError):
            wslib.safe_path("../../etc/passwd")

    def test_inside_ok(self):
        self.assertTrue(str(wslib.safe_path("work/x")).startswith(str(wslib.WORKSPACE_ROOT)))


class TestM68k(unittest.TestCase):
    def test_moveq_add(self):
        c = run("7005" "7203" "D041", 3)  # moveq #5,d0; moveq #3,d1; add.w d1,d0
        self.assertEqual(c.d[0] & 0xFFFF, 8)

    def test_sub_flags(self):
        c = run("7001" "7202" "9041", 3)  # d0=1 - d1=2 -> -1, C=1, N=1
        self.assertEqual(c.d[0] & 0xFFFF, 0xFFFF)
        self.assertEqual((c.c, c.n, c.x), (1, 1, 1))

    def test_dbf_loop(self):
        c = run("7003" "7200" "5281" "51C8FFFC", 2 + 4 * 2)  # loop 4x addq.l #1,d1
        self.assertEqual(c.d[1], 4)

    def test_muls_divu(self):
        c = run("70FD" "C1FC0003" "81FC0003", 3)  # d0=-3; muls #3 -> -9; divs #3 -> -3 resto 0
        self.assertEqual(c.d[0], 0x0000FFFD)

    def test_bsr_rts(self):
        c = run("6104" "7009" "4E71" "7207" "4E75", 4)
        self.assertEqual(c.d[1], 7)


class TestEvidence(unittest.TestCase):
    def test_ledger_valid(self):
        p = ROOT / "docs/reverse-engineering/04-evidence-ledger.csv"
        if not p.is_file():
            self.skipTest("ledger ainda não gerado")
        rows = list(csv.DictReader(open(p, encoding="utf-8")))
        ok = {"CONFIRMADO_BINARIO", "CONFIRMADO_EMULACAO", "INFERIDO", "DESCONHECIDO", "BLOQUEADO"}
        ids = [r["evidence_id"] for r in rows]
        self.assertEqual(len(ids), len(set(ids)))
        for r in rows:
            self.assertIn(r["status"], ok)


class TestGeneratedTables(unittest.TestCase):
    """Tabelas geradas matematicamente vs referência (pulado sem ROM)."""
    def setUp(self):
        self.rom = wslib.find_rom()

    def test_sine(self):
        if not self.rom:
            self.skipTest("ROM ausente")
        data = self.rom.read_bytes()
        gen = [int(math.sin(k * 2 * math.pi / 256) * 256) for k in range(320)]
        gen[147] = gen[237] = -117
        ref = [int.from_bytes(data[0x29F2 + 2 * k:0x29F4 + 2 * k], "big", signed=True) for k in range(320)]
        self.assertEqual(gen, ref)

    def test_atan(self):
        if not self.rom:
            self.skipTest("ROM ausente")
        data = self.rom.read_bytes()
        gen = [round(math.atan(k / 256) * 128 / math.pi) for k in range(257)]
        self.assertEqual(gen, list(data[0x2D0E:0x2D0E + 257]))


class TestDemoLevel(unittest.TestCase):
    def test_lab_level_has_no_rom_marker(self):
        p = ROOT / "game/data/levels/lab1.json"
        txt = p.read_text()
        self.assertIn('"license"', txt)
        rom = wslib.find_rom()
        if rom:
            self.assertNotIn(wslib.sha256_file(rom), txt)


if __name__ == "__main__":
    unittest.main()
