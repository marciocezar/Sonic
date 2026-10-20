"""Máquina Mega Drive mínima para replays de referência (pesquisa).

Implementa: barramento 68000 (ROM, RAM 64 KiB espelhada), VDP (registradores, VRAM/CRAM/VSRAM,
DMA 68k->VDP / fill / copy, status com VBlank), I/O (controle de 3 botões com protocolo TH),
área Z80 (RAM e pedido de barramento sempre concedido; Z80 NÃO é executado), YM2612/PSG ignorados.
Não implementa: Z80, áudio, HBlank (usado só para paleta de água), renderização exata, sprites limit.

Temporização: quadro NTSC = 127841 ciclos aprox. (PAL 152000), VBlank no fim da linha 224.
O laço ocioso da espera por VBlank é detectado e avançado (sem efeito lógico).
"""
from __future__ import annotations

import struct
from typing import Dict, List, Optional

from m68k import CPU, M32

# Bits do controle no formato interno: U D L R B C A S
BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT, BTN_B, BTN_C, BTN_A, BTN_START = (1 << i for i in range(8))
BTN_NAMES = {"U": BTN_UP, "D": BTN_DOWN, "L": BTN_LEFT, "R": BTN_RIGHT,
             "B": BTN_B, "C": BTN_C, "A": BTN_A, "S": BTN_START}


def parse_buttons(s: str) -> int:
    v = 0
    for ch in s:
        if ch in BTN_NAMES:
            v |= BTN_NAMES[ch]
    return v


class VDP:
    def __init__(self, md):
        self.md = md
        self.reg = [0] * 24
        self.vram = bytearray(0x10000)
        self.cram = [0] * 64
        self.vsram = [0] * 40
        self.pending = False
        self.code = 0
        self.addr = 0
        self.first = 0
        self.fill_pending = False
        self.vblank = False
        self.pal = False
        self.hv = 0

    def autoinc(self):
        return self.reg[15]

    def write_control(self, v):
        if self.pending:
            self.pending = False
            self.code = (self.code & 3) | ((v >> 2) & 0x3C)
            self.addr = (self.addr & 0x3FFF) | ((v & 3) << 14)
            if self.code & 0x20 and self.reg[1] & 0x10:
                mode = self.reg[23] >> 6
                if mode in (0, 1):
                    self.dma_68k()
                elif mode == 2:
                    self.fill_pending = True
                else:
                    self.dma_copy()
            return
        if (v & 0xC000) == 0x8000:
            r = (v >> 8) & 0x1F
            if r < 24:
                self.reg[r] = v & 0xFF
            self.code = 0
            return
        self.pending = True
        self.code = (self.code & 0x3C) | (v >> 14)
        self.addr = (self.addr & 0xC000) | (v & 0x3FFF)

    def dma_len(self):
        n = self.reg[19] | (self.reg[20] << 8)
        return n or 0x10000

    def dma_68k(self):
        n = self.dma_len()
        src = ((self.reg[21] | (self.reg[22] << 8) | ((self.reg[23] & 0x7F) << 16)) << 1) & 0xFFFFFF
        bus = self.md
        for _ in range(n):
            self.store(bus.read16(src))
            src = (src + 2) & 0xFFFFFF
        self.code &= 0x1F

    def dma_copy(self):
        n = self.dma_len()
        src = self.reg[21] | (self.reg[22] << 8)
        for _ in range(n):
            self.vram[self.addr & 0xFFFF] = self.vram[src & 0xFFFF]
            src += 1
            self.addr = (self.addr + self.autoinc()) & 0xFFFF
        self.code &= 0x1F

    def store(self, v):
        t = self.code & 0xF
        a = self.addr
        if t == 1:
            if a & 1:
                v = ((v & 0xFF) << 8) | (v >> 8)
            self.vram[a & 0xFFFE] = v >> 8
            self.vram[(a & 0xFFFE) + 1] = v & 0xFF
        elif t == 3:
            self.cram[(a >> 1) & 0x3F] = v & 0xEEE
        elif t == 5:
            i = (a >> 1)
            if i < 40:
                self.vsram[i] = v & 0x7FF
        self.addr = (a + self.autoinc()) & 0xFFFF

    def write_data(self, v):
        self.pending = False
        if self.fill_pending:
            self.fill_pending = False
            self.store(v)
            n = self.dma_len()
            hi = v >> 8
            for _ in range(n - 1):
                self.vram[(self.addr ^ 1) & 0xFFFF] = hi
                self.addr = (self.addr + self.autoinc()) & 0xFFFF
            self.code &= 0x1F
            return
        self.store(v)

    def read_data(self):
        self.pending = False
        t = self.code & 0xF
        a = self.addr
        if t == 0:
            v = (self.vram[a & 0xFFFE] << 8) | self.vram[(a & 0xFFFE) + 1]
        elif t == 8:
            v = self.cram[(a >> 1) & 0x3F]
        elif t == 4:
            v = self.vsram[(a >> 1) % 40]
        else:
            v = 0
        self.addr = (a + self.autoinc()) & 0xFFFF
        return v

    def status(self):
        self.pending = False
        v = 0x3400 | 0x200  # FIFO vazio
        if self.vblank:
            v |= 0x8
        if self.pal:
            v |= 0x1
        return v

    def hvcounter(self):
        self.hv = (self.hv + 0x0101) & 0xFFFF
        return self.hv


class MegaDrive:
    def __init__(self, rom: bytes, region: str = "USA", pal: bool = False):
        self.rom = rom
        self.romlen = len(rom)
        self.ram = bytearray(0x10000)
        self.z80ram = bytearray(0x2000)
        self.vdp = VDP(self)
        self.vdp.pal = pal
        self.pal = pal
        # A10001: bit7 = overseas, bit6 = PAL, bit5 = sem expansão
        self.version = (0x80 if region != "JP" else 0) | (0x40 if pal else 0) | 0x20
        self.pad = [0, 0]
        self.th = [0x40, 0x40]
        self.pad_ctrl = [0, 0]
        self.z80_busreq = False
        self.z80_reset = True
        self.cpu = CPU(self)
        self.frame = 0
        self.cycles_per_frame = 152000 if pal else 127841
        self.lines = 313 if pal else 262
        self.watch_writes: Optional[Dict[int, List]] = None
        self.coverage = None  # set() opcional de PCs executados (cobertura dinâmica)
        self.idle_reached = False
        self.prev_complete = True  # a lógica do último quadro terminou (CPU em espera)?
        self.lag_vblank = False
        self.cpu.reset()

    # --- barramento -------------------------------------------------------------
    def read8(self, a):
        a &= 0xFFFFFF
        if a < 0x400000:
            return self.rom[a] if a < self.romlen else 0xFF
        if a >= 0xE00000:
            return self.ram[a & 0xFFFF]
        return self.io_read8(a)

    def read16(self, a):
        a &= 0xFFFFFF
        if a < 0x400000:
            if a + 1 < self.romlen:
                return (self.rom[a] << 8) | self.rom[a + 1]
            return 0xFFFF
        if a >= 0xE00000:
            a &= 0xFFFF
            return (self.ram[a] << 8) | self.ram[(a + 1) & 0xFFFF]
        if 0xC00000 <= a < 0xC00020:
            return self.vdp_read16(a)
        return (self.io_read8(a) << 8) | self.io_read8(a + 1)

    def read32(self, a):
        return (self.read16(a) << 16) | self.read16(a + 2)

    def write8(self, a, v):
        a &= 0xFFFFFF
        if a >= 0xE00000:
            self.ram[a & 0xFFFF] = v
            if self.watch_writes is not None and (a & 0xFFFF) in self.watch_writes:
                self.watch_writes[a & 0xFFFF].append((self.frame, self.cpu.last_pc, 1, v))
            return
        self.io_write8(a, v)

    def write16(self, a, v):
        a &= 0xFFFFFF
        if a >= 0xE00000:
            o = a & 0xFFFF
            self.ram[o] = v >> 8
            self.ram[(o + 1) & 0xFFFF] = v & 0xFF
            if self.watch_writes is not None and o in self.watch_writes:
                self.watch_writes[o].append((self.frame, self.cpu.last_pc, 2, v))
            return
        if 0xC00000 <= a < 0xC00020:
            self.vdp_write16(a, v)
            return
        self.io_write8(a, v >> 8)
        self.io_write8(a + 1, v & 0xFF)

    def write32(self, a, v):
        self.write16(a, (v >> 16) & 0xFFFF)
        self.write16(a + 2, v & 0xFFFF)

    # --- VDP --------------------------------------------------------------------
    def vdp_read16(self, a):
        port = a & 0x1F
        if port < 4:
            return self.vdp.read_data()
        if port < 8:
            return self.vdp.status()
        if port < 0x10:
            return self.vdp.hvcounter()
        return 0

    def vdp_write16(self, a, v):
        port = a & 0x1F
        if port < 4:
            self.vdp.write_data(v)
        elif port < 8:
            self.vdp.write_control(v)
        # 0x11 PSG / 0x1C debug: ignorados

    # --- I/O --------------------------------------------------------------------
    def read_pad(self, i):
        b = self.pad[i]
        if self.th[i] & 0x40:
            # TH=1: ? 1 C B R L D U
            v = 0x40
            v |= 0 if b & BTN_C else 0x20
            v |= 0 if b & BTN_B else 0x10
            v |= 0 if b & BTN_RIGHT else 0x08
            v |= 0 if b & BTN_LEFT else 0x04
            v |= 0 if b & BTN_DOWN else 0x02
            v |= 0 if b & BTN_UP else 0x01
        else:
            # TH=0: ? 0 S A 0 0 D U
            v = 0
            v |= 0 if b & BTN_START else 0x20
            v |= 0 if b & BTN_A else 0x10
            v |= 0 if b & BTN_DOWN else 0x02
            v |= 0 if b & BTN_UP else 0x01
        return v | 0x80

    def io_read8(self, a):
        if 0xA00000 <= a < 0xA10000:
            if 0xA04000 <= a < 0xA04004:
                return 0  # status YM2612: nunca ocupado
            return self.z80ram[a & 0x1FFF]
        if 0xA10000 <= a < 0xA10020:
            r = (a & 0x1F) | 1
            if r == 0x01:
                return self.version
            if r == 0x03:
                return self.read_pad(0)
            if r == 0x05:
                return self.read_pad(1)
            if r == 0x09:
                return self.pad_ctrl[0]
            if r == 0x0B:
                return self.pad_ctrl[1]
            return 0
        if 0xA11100 <= a < 0xA11102:
            # bit0 = 0 -> barramento concedido ao 68000
            return 0 if (a & 1) == 0 else 0
        if 0xC00000 <= a < 0xC00020:
            v = self.vdp_read16(a & ~1)
            return v >> 8 if (a & 1) == 0 else v & 0xFF
        return 0

    def io_write8(self, a, v):
        if 0xA00000 <= a < 0xA10000:
            if a < 0xA02000:
                self.z80ram[a & 0x1FFF] = v
            return
        if 0xA10000 <= a < 0xA10020:
            r = (a & 0x1F) | 1
            if r == 0x03:
                self.th[0] = v & 0x40
            elif r == 0x05:
                self.th[1] = v & 0x40
            elif r == 0x09:
                self.pad_ctrl[0] = v
            elif r == 0x0B:
                self.pad_ctrl[1] = v
            return
        if 0xA11100 <= a < 0xA11102:
            if (a & 1) == 0:
                self.z80_busreq = bool(v & 1)
            return
        if 0xA11200 <= a < 0xA11202:
            if (a & 1) == 0:
                self.z80_reset = not (v & 1)
            return
        if 0xC00000 <= a < 0xC00020:
            port = a & 0x1F
            if port < 4:
                self.vdp.write_data((v << 8) | v)
            elif port < 8:
                self.vdp.write_control((v << 8) | v)
            return
        # A14000 (TMSS) e demais: ignorados

    # --- execução ---------------------------------------------------------------
    def run_cycles(self, budget):
        cpu = self.cpu
        start = cpu.cycles
        end = start + budget
        cov = self.coverage
        self.idle_reached = False
        while cpu.cycles < end:
            cpu.idle_hint = False
            cpu.step()
            if cov is not None:
                cov.add(cpu.last_pc)
            if cpu.idle_hint or cpu.stopped:
                # laço ocioso (desvio curto para trás) ou STOP: avança até o próximo evento
                if self._is_idle_loop():
                    cpu.cycles = end
                    self.idle_reached = True
                    break
        return cpu.cycles - start

    # Laço de espera pelo VBlank do jogo (listagem Ghidra 0x29A8: move #$2300,SR; tst.b $F62A; bne): EV-EMU
    IDLE_PC = 0x29AC
    VBLA_FLAG = 0xF62A

    def _is_idle_loop(self):
        cpu = self.cpu
        if cpu.stopped:
            return True
        return cpu.pc == self.IDLE_PC and self.ram[self.VBLA_FLAG] != 0 and cpu.imask < 6

    def step_frame(self, buttons: int = 0):
        """Executa um quadro começando no VBlank: IRQ6 (lê o pad), lógica do jogo, espera ociosa.

        Ordem: período de VBlank (status VB=1) seguido do período ativo. O snapshot ao fim do
        quadro reflete a lógica completa desse quadro, desde que ela caiba em um quadro
        (quadros com lag continuam no próximo, como no hardware, mas com temporização aproximada).
        """
        self.pad[0] = buttons
        # se a lógica do quadro anterior não terminou, este VBlank é de "lag" (sem leitura de pad pelo jogo)
        self.lag_vblank = not self.prev_complete
        active = self.cycles_per_frame * 224 // self.lines
        self.vdp.vblank = True
        if self.vdp.reg[1] & 0x20:
            self.cpu.irq(6)
        self.run_cycles(self.cycles_per_frame - active)
        done = self.idle_reached
        self.vdp.vblank = False
        self.run_cycles(active)
        done = done or self.idle_reached
        self.prev_complete = done
        self.frame += 1

    # --- utilidades de RAM ----------------------------------------------------------
    def r8(self, off):
        return self.ram[off & 0xFFFF]

    def r16(self, off):
        off &= 0xFFFF
        return (self.ram[off] << 8) | self.ram[off + 1]

    def r32(self, off):
        return (self.r16(off) << 16) | self.r16(off + 2)

    def s16(self, off):
        v = self.r16(off)
        return v - 0x10000 if v & 0x8000 else v

    def save_state(self):
        c = self.cpu
        return {
            "ram": bytes(self.ram), "z80": bytes(self.z80ram), "vram": bytes(self.vdp.vram),
            "cram": list(self.vdp.cram), "vsram": list(self.vdp.vsram), "vreg": list(self.vdp.reg),
            "d": list(c.d), "a": list(c.a), "pc": c.pc, "sr": c.get_sr(), "osp": c.other_sp,
            "frame": self.frame, "cycles": c.cycles,
        }

    def load_state(self, s):
        self.ram[:] = s["ram"]
        self.z80ram[:] = s["z80"]
        self.vdp.vram[:] = s["vram"]
        self.vdp.cram = list(s["cram"])
        self.vdp.vsram = list(s["vsram"])
        self.vdp.reg = list(s["vreg"])
        c = self.cpu
        c.d = list(s["d"])
        c.a = list(s["a"])
        c.pc = s["pc"]
        c.s = (s["sr"] >> 13) & 1
        c.set_sr(s["sr"])
        c.other_sp = s["osp"]
        self.frame = s["frame"]
        c.cycles = s["cycles"]
