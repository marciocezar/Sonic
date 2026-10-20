"""Interpretador Motorola 68000 próprio (Python 3 stdlib) para análise/replay de referência.

Escopo e limitações (documentadas em docs/reverse-engineering/02-metodologia-rea.md):
- Conjunto inteiro completo do 68000 (sem 68010+), modo supervisor/usuário, exceções e IRQ.
- Temporização APROXIMADA: custo fixo por instrução + extras (MUL/DIV/MOVEM/shifts).
  Não é cycle-accurate; quadros com "lag" podem divergir do hardware real.
- Não executa nada no host: é um interpretador puro sobre um barramento em memória.
"""
from __future__ import annotations

M8, M16, M32 = 0xFF, 0xFFFF, 0xFFFFFFFF
MASK = {1: M8, 2: M16, 4: M32}
MSB = {1: 0x80, 2: 0x8000, 4: 0x80000000}


def s8(v):
    v &= 0xFF
    return v - 0x100 if v & 0x80 else v


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def s32(v):
    v &= M32
    return v - 0x100000000 if v & 0x80000000 else v


def sx(v, size):
    if size == 1:
        return s8(v)
    if size == 2:
        return s16(v)
    return s32(v)


class CPUError(Exception):
    pass


class CPU:
    def __init__(self, bus):
        self.bus = bus
        self.d = [0] * 8
        self.a = [0] * 8
        self.pc = 0
        self.x = self.n = self.z = self.v = self.c = 0
        self.s = 1
        self.imask = 7
        self.trace = 0
        self.other_sp = 0  # USP quando em supervisor, SSP quando em usuário
        self.stopped = False
        self.cycles = 0
        self.pending_irq = 0
        self.table = [None] * 65536
        self.last_pc = 0
        self.idle_hint = False

    # --- SR ---------------------------------------------------------------
    def get_sr(self):
        return ((self.trace << 15) | (self.s << 13) | (self.imask << 8) | (self.x << 4) |
                (self.n << 3) | (self.z << 2) | (self.v << 1) | self.c)

    def set_sr(self, v):
        new_s = (v >> 13) & 1
        if new_s != self.s:
            self.a[7], self.other_sp = self.other_sp, self.a[7]
        self.s = new_s
        self.trace = (v >> 15) & 1
        self.imask = (v >> 8) & 7
        self.set_ccr(v)

    def set_ccr(self, v):
        self.x = (v >> 4) & 1
        self.n = (v >> 3) & 1
        self.z = (v >> 2) & 1
        self.v = (v >> 1) & 1
        self.c = v & 1

    # --- fetch --------------------------------------------------------------
    def fetch16(self):
        v = self.bus.read16(self.pc)
        self.pc = (self.pc + 2) & M32
        return v

    def fetch32(self):
        v = self.bus.read32(self.pc)
        self.pc = (self.pc + 4) & M32
        return v

    def reset(self):
        self.s = 1
        self.imask = 7
        self.a[7] = self.bus.read32(0)
        self.pc = self.bus.read32(4)
        self.stopped = False

    # --- pilha / exceções -------------------------------------------------------
    def push16(self, v):
        self.a[7] = (self.a[7] - 2) & M32
        self.bus.write16(self.a[7], v)

    def push32(self, v):
        self.a[7] = (self.a[7] - 4) & M32
        self.bus.write32(self.a[7], v)

    def pop16(self):
        v = self.bus.read16(self.a[7])
        self.a[7] = (self.a[7] + 2) & M32
        return v

    def pop32(self):
        v = self.bus.read32(self.a[7])
        self.a[7] = (self.a[7] + 4) & M32
        return v

    def exception(self, vector, pc=None):
        sr = self.get_sr()
        if not self.s:
            self.set_sr(sr | 0x2000)
        self.trace = 0
        self.push32(self.pc if pc is None else pc)
        self.push16(sr)
        self.pc = self.bus.read32(vector * 4)
        self.cycles += 34

    def irq(self, level):
        self.pending_irq = max(self.pending_irq, level)

    def check_irq(self):
        lvl = self.pending_irq
        if lvl and (lvl > self.imask or lvl == 7):
            self.pending_irq = 0
            self.stopped = False
            sr = self.get_sr()
            self.set_sr(sr | 0x2000)
            self.trace = 0
            self.imask = lvl
            self.push32(self.pc)
            self.push16(sr)
            self.pc = self.bus.read32((24 + lvl) * 4)
            self.cycles += 44
            return True
        return False

    # --- execução --------------------------------------------------------------
    def step(self):
        if self.pending_irq:
            self.check_irq()
        if self.stopped:
            self.cycles += 4
            return
        self.last_pc = self.pc
        op = self.fetch16()
        h = self.table[op]
        if h is None:
            h = self.table[op] = self.decode(op)
        h(op)
        self.cycles += 8

    # --- endereçamento efetivo --------------------------------------------------
    def index_ext(self, base):
        ext = self.fetch16()
        r = (ext >> 12) & 7
        idx = self.a[r] if ext & 0x8000 else self.d[r]
        if not ext & 0x800:
            idx = s16(idx)
        return (base + idx + s8(ext)) & M32

    def ea_addr(self, mode, reg, size):
        if mode == 2:
            return self.a[reg]
        if mode == 3:
            a = self.a[reg]
            self.a[reg] = (a + (2 if (reg == 7 and size == 1) else size)) & M32
            return a
        if mode == 4:
            self.a[reg] = (self.a[reg] - (2 if (reg == 7 and size == 1) else size)) & M32
            return self.a[reg]
        if mode == 5:
            return (self.a[reg] + s16(self.fetch16())) & M32
        if mode == 6:
            return self.index_ext(self.a[reg])
        if mode == 7:
            if reg == 0:
                return s16(self.fetch16()) & M32
            if reg == 1:
                return self.fetch32()
            if reg == 2:
                base = self.pc
                return (base + s16(self.fetch16())) & M32
            if reg == 3:
                return self.index_ext(self.pc)
        raise CPUError(f"EA inválido mode={mode} reg={reg} pc={self.last_pc:06X}")

    def loc(self, mode, reg, size):
        """Localização para leitura-modificação-escrita: <0 = registrador, >=0 = endereço."""
        if mode == 0:
            return -1 - reg
        if mode == 1:
            return -9 - reg
        if mode == 7 and reg == 4:
            raise CPUError("imediato não é destino")
        return self.ea_addr(mode, reg, size)

    def rd(self, loc, size):
        if loc < 0:
            if loc >= -8:
                return self.d[-1 - loc] & MASK[size]
            return self.a[-9 - loc] & MASK[size]
        if size == 1:
            return self.bus.read8(loc)
        if size == 2:
            return self.bus.read16(loc)
        return self.bus.read32(loc)

    def wr(self, loc, size, v):
        if loc < 0:
            if loc >= -8:
                r = -1 - loc
                if size == 4:
                    self.d[r] = v & M32
                elif size == 2:
                    self.d[r] = (self.d[r] & 0xFFFF0000) | (v & M16)
                else:
                    self.d[r] = (self.d[r] & 0xFFFFFF00) | (v & M8)
            else:
                r = -9 - loc
                self.a[r] = (sx(v, size) & M32) if size != 4 else v & M32
            return
        if size == 1:
            self.bus.write8(loc, v & M8)
        elif size == 2:
            self.bus.write16(loc, v & M16)
        else:
            self.bus.write32(loc, v & M32)

    def ea_read(self, mode, reg, size):
        if mode == 0:
            return self.d[reg] & MASK[size]
        if mode == 1:
            return self.a[reg] & MASK[size]
        if mode == 7 and reg == 4:
            if size == 4:
                return self.fetch32()
            v = self.fetch16()
            return v & 0xFF if size == 1 else v
        return self.rd(self.ea_addr(mode, reg, size), size)

    # --- flags ---------------------------------------------------------------
    def nz(self, v, size):
        self.n = 1 if v & MSB[size] else 0
        self.z = 1 if (v & MASK[size]) == 0 else 0

    def logic_flags(self, v, size):
        self.nz(v, size)
        self.v = self.c = 0

    def add_core(self, s, d, size, x=0, addx=False):
        m = MASK[size]
        r = s + d + x
        res = r & m
        self.c = self.x = 1 if r > m else 0
        msb = MSB[size]
        self.v = 1 if ((s ^ res) & (d ^ res) & msb) else 0
        self.n = 1 if res & msb else 0
        if addx:
            if res:
                self.z = 0
        else:
            self.z = 0 if res else 1
        return res

    def sub_core(self, s, d, size, x=0, subx=False, setx=True):
        m = MASK[size]
        r = d - s - x
        res = r & m
        c = 1 if r < 0 else 0
        self.c = c
        if setx:
            self.x = c
        msb = MSB[size]
        self.v = 1 if ((s ^ d) & (res ^ d) & msb) else 0
        self.n = 1 if res & msb else 0
        if subx:
            if res:
                self.z = 0
        else:
            self.z = 0 if res else 1
        return res

    def cond(self, cc):
        if cc == 0:
            return True
        if cc == 1:
            return False
        if cc == 2:
            return not self.c and not self.z
        if cc == 3:
            return bool(self.c or self.z)
        if cc == 4:
            return not self.c
        if cc == 5:
            return bool(self.c)
        if cc == 6:
            return not self.z
        if cc == 7:
            return bool(self.z)
        if cc == 8:
            return not self.v
        if cc == 9:
            return bool(self.v)
        if cc == 10:
            return not self.n
        if cc == 11:
            return bool(self.n)
        if cc == 12:
            return self.n == self.v
        if cc == 13:
            return self.n != self.v
        if cc == 14:
            return not self.z and self.n == self.v
        return bool(self.z or self.n != self.v)

    # --- decodificação ----------------------------------------------------------
    def decode(self, op):
        top = op >> 12
        fn = getattr(self, f"_dec{top:X}")
        h = fn(op)
        if h is None:
            return self.op_illegal
        return h

    def op_illegal(self, op):
        if (op >> 12) == 0xA:
            self.exception(10, self.last_pc)
        elif (op >> 12) == 0xF:
            self.exception(11, self.last_pc)
        else:
            self.exception(4, self.last_pc)

    def priv(self):
        if not self.s:
            self.exception(8, self.last_pc)
            return False
        return True

    # 0xxx: imediatos e bits
    def _dec0(self, op):
        mode, reg = (op >> 3) & 7, op & 7
        if op & 0x100:
            if mode == 1:
                return self.op_movep
            return self.op_bit_dyn
        sub = (op >> 9) & 7
        if sub == 4:
            return self.op_bit_static
        size_bits = (op >> 6) & 3
        if size_bits == 3:
            return None
        if sub in (0, 1, 5) and mode == 7 and reg == 4:
            return self.op_imm_ccr_sr
        return {0: self.op_ori, 1: self.op_andi, 2: self.op_subi, 3: self.op_addi,
                5: self.op_eori, 6: self.op_cmpi}.get(sub)

    def op_imm_ccr_sr(self, op):
        sub = (op >> 9) & 7
        word = (op >> 6) & 3 == 1
        imm = self.fetch16()
        if word:
            if not self.priv():
                return
            sr = self.get_sr()
            if sub == 0:
                sr |= imm
            elif sub == 1:
                sr &= imm
            else:
                sr ^= imm
            self.set_sr(sr & 0xA71F)
        else:
            ccr = self.get_sr() & 0x1F
            imm &= 0xFF
            if sub == 0:
                ccr |= imm
            elif sub == 1:
                ccr &= imm
            else:
                ccr ^= imm
            self.set_ccr(ccr)

    def _imm(self, size):
        if size == 4:
            return self.fetch32()
        v = self.fetch16()
        return v & 0xFF if size == 1 else v

    @staticmethod
    def _size(op):
        return (1, 2, 4)[(op >> 6) & 3]

    def op_ori(self, op):
        size = self._size(op)
        imm = self._imm(size)
        l = self.loc((op >> 3) & 7, op & 7, size)
        r = self.rd(l, size) | imm
        self.wr(l, size, r)
        self.logic_flags(r, size)

    def op_andi(self, op):
        size = self._size(op)
        imm = self._imm(size)
        l = self.loc((op >> 3) & 7, op & 7, size)
        r = self.rd(l, size) & imm
        self.wr(l, size, r)
        self.logic_flags(r, size)

    def op_eori(self, op):
        size = self._size(op)
        imm = self._imm(size)
        l = self.loc((op >> 3) & 7, op & 7, size)
        r = self.rd(l, size) ^ imm
        self.wr(l, size, r)
        self.logic_flags(r, size)

    def op_subi(self, op):
        size = self._size(op)
        imm = self._imm(size)
        l = self.loc((op >> 3) & 7, op & 7, size)
        self.wr(l, size, self.sub_core(imm, self.rd(l, size), size))

    def op_addi(self, op):
        size = self._size(op)
        imm = self._imm(size)
        l = self.loc((op >> 3) & 7, op & 7, size)
        self.wr(l, size, self.add_core(imm, self.rd(l, size), size))

    def op_cmpi(self, op):
        size = self._size(op)
        imm = self._imm(size)
        d = self.ea_read((op >> 3) & 7, op & 7, size)
        self.sub_core(imm, d, size, setx=False)

    def _bit_common(self, op, bit):
        mode, reg = (op >> 3) & 7, op & 7
        kind = (op >> 6) & 3
        if mode == 0:
            bit &= 31
            v = self.d[reg]
            self.z = 0 if (v >> bit) & 1 else 1
            if kind == 1:
                v ^= 1 << bit
            elif kind == 2:
                v &= ~(1 << bit)
            elif kind == 3:
                v |= 1 << bit
            self.d[reg] = v & M32
            return
        bit &= 7
        if kind == 0:
            v = self.ea_read(mode, reg, 1)
            self.z = 0 if (v >> bit) & 1 else 1
            return
        l = self.loc(mode, reg, 1)
        v = self.rd(l, 1)
        self.z = 0 if (v >> bit) & 1 else 1
        if kind == 1:
            v ^= 1 << bit
        elif kind == 2:
            v &= ~(1 << bit)
        else:
            v |= 1 << bit
        self.wr(l, 1, v)

    def op_bit_dyn(self, op):
        self._bit_common(op, self.d[(op >> 9) & 7])

    def op_bit_static(self, op):
        self._bit_common(op, self.fetch16() & 0xFF)

    def op_movep(self, op):
        dreg, areg = (op >> 9) & 7, op & 7
        opm = (op >> 6) & 7
        addr = (self.a[areg] + s16(self.fetch16())) & M32
        if opm == 4:
            self.d[dreg] = (self.d[dreg] & 0xFFFF0000) | (self.bus.read8(addr) << 8) | self.bus.read8(addr + 2)
        elif opm == 5:
            v = 0
            for i in range(4):
                v = (v << 8) | self.bus.read8(addr + 2 * i)
            self.d[dreg] = v
        elif opm == 6:
            v = self.d[dreg]
            self.bus.write8(addr, (v >> 8) & 0xFF)
            self.bus.write8(addr + 2, v & 0xFF)
        else:
            v = self.d[dreg]
            for i in range(4):
                self.bus.write8(addr + 2 * i, (v >> (24 - 8 * i)) & 0xFF)

    # 1/2/3: MOVE
    def _dec1(self, op):
        return self.op_move

    _dec2 = _dec1
    _dec3 = _dec1

    def op_move(self, op):
        size = (0, 1, 4, 2)[op >> 12]
        v = self.ea_read((op >> 3) & 7, op & 7, size)
        dmode, dreg = (op >> 6) & 7, (op >> 9) & 7
        if dmode == 1:
            self.a[dreg] = sx(v, size) & M32
            return
        self.wr(self.loc(dmode, dreg, size), size, v)
        self.logic_flags(v, size)

    # 4: diversos
    def _dec4(self, op):
        if op == 0x4E71:
            return self.op_nop
        if op == 0x4E75:
            return self.op_rts
        if op == 0x4E73:
            return self.op_rte
        if op == 0x4E77:
            return self.op_rtr
        if op == 0x4E72:
            return self.op_stop
        if op == 0x4E70:
            return self.op_resetins
        if op == 0x4E76:
            return self.op_trapv
        if op == 0x4AFC:
            return None
        if op & 0xFFF0 == 0x4E40:
            return self.op_trap
        if op & 0xFFF8 == 0x4E50:
            return self.op_link
        if op & 0xFFF8 == 0x4E58:
            return self.op_unlk
        if op & 0xFFF0 == 0x4E60:
            return self.op_move_usp
        if op & 0xFFC0 == 0x4E80:
            return self.op_jsr
        if op & 0xFFC0 == 0x4EC0:
            return self.op_jmp
        if op & 0xF1C0 == 0x41C0:
            return self.op_lea
        if op & 0xF1C0 == 0x4180:
            return self.op_chk
        if op & 0xFFC0 == 0x40C0:
            return self.op_move_from_sr
        if op & 0xFFC0 == 0x44C0:
            return self.op_move_to_ccr
        if op & 0xFFC0 == 0x46C0:
            return self.op_move_to_sr
        if op & 0xFF00 == 0x4000:
            return self.op_negx
        if op & 0xFF00 == 0x4200:
            return self.op_clr
        if op & 0xFF00 == 0x4400:
            return self.op_neg
        if op & 0xFF00 == 0x4600:
            return self.op_not
        if op & 0xFFC0 == 0x4800:
            return self.op_nbcd
        if op & 0xFFF8 == 0x4840:
            return self.op_swap
        if op & 0xFFC0 == 0x4840:
            return self.op_pea
        if op & 0xFFB8 == 0x4880:
            return self.op_ext
        if op & 0xFB80 == 0x4880:
            return self.op_movem
        if op & 0xFFC0 == 0x4AC0:
            return self.op_tas
        if op & 0xFF00 == 0x4A00:
            return self.op_tst
        return None

    def op_nop(self, op):
        pass

    def op_rts(self, op):
        self.pc = self.pop32()

    def op_rte(self, op):
        if not self.priv():
            return
        sr = self.pop16()
        self.pc = self.pop32()
        self.set_sr(sr)

    def op_rtr(self, op):
        self.set_ccr(self.pop16())
        self.pc = self.pop32()

    def op_stop(self, op):
        imm = self.fetch16()
        if not self.priv():
            return
        self.set_sr(imm)
        self.stopped = True

    def op_resetins(self, op):
        self.priv()

    def op_trapv(self, op):
        if self.v:
            self.exception(7)

    def op_trap(self, op):
        self.exception(32 + (op & 15))

    def op_link(self, op):
        r = op & 7
        disp = s16(self.fetch16())
        self.push32(self.a[r])
        self.a[r] = self.a[7]
        self.a[7] = (self.a[7] + disp) & M32

    def op_unlk(self, op):
        r = op & 7
        self.a[7] = self.a[r]
        self.a[r] = self.pop32()

    def op_move_usp(self, op):
        if not self.priv():
            return
        r = op & 7
        if op & 8:
            self.a[r] = self.other_sp
        else:
            self.other_sp = self.a[r]

    def op_jsr(self, op):
        addr = self.ea_addr((op >> 3) & 7, op & 7, 4)
        self.push32(self.pc)
        self.pc = addr

    def op_jmp(self, op):
        self.pc = self.ea_addr((op >> 3) & 7, op & 7, 4)

    def op_lea(self, op):
        self.a[(op >> 9) & 7] = self.ea_addr((op >> 3) & 7, op & 7, 4)

    def op_chk(self, op):
        bound = s16(self.ea_read((op >> 3) & 7, op & 7, 2))
        v = s16(self.d[(op >> 9) & 7])
        if v < 0:
            self.n = 1
            self.exception(6)
        elif v > bound:
            self.n = 0
            self.exception(6)

    def op_move_from_sr(self, op):
        self.wr(self.loc((op >> 3) & 7, op & 7, 2), 2, self.get_sr())

    def op_move_to_ccr(self, op):
        self.set_ccr(self.ea_read((op >> 3) & 7, op & 7, 2))

    def op_move_to_sr(self, op):
        if not self.priv():
            return
        self.set_sr(self.ea_read((op >> 3) & 7, op & 7, 2))

    def op_negx(self, op):
        size = self._size(op)
        l = self.loc((op >> 3) & 7, op & 7, size)
        self.wr(l, size, self.sub_core(self.rd(l, size), 0, size, self.x, subx=True))

    def op_clr(self, op):
        size = self._size(op)
        l = self.loc((op >> 3) & 7, op & 7, size)
        self.wr(l, size, 0)
        self.n = self.v = self.c = 0
        self.z = 1

    def op_neg(self, op):
        size = self._size(op)
        l = self.loc((op >> 3) & 7, op & 7, size)
        self.wr(l, size, self.sub_core(self.rd(l, size), 0, size))

    def op_not(self, op):
        size = self._size(op)
        l = self.loc((op >> 3) & 7, op & 7, size)
        r = (~self.rd(l, size)) & MASK[size]
        self.wr(l, size, r)
        self.logic_flags(r, size)

    def op_swap(self, op):
        r = op & 7
        v = self.d[r]
        v = ((v >> 16) | (v << 16)) & M32
        self.d[r] = v
        self.logic_flags(v, 4)

    def op_pea(self, op):
        addr = self.ea_addr((op >> 3) & 7, op & 7, 4)
        self.push32(addr)

    def op_ext(self, op):
        r = op & 7
        if op & 0x40:
            v = s16(self.d[r]) & M32
            self.d[r] = v
            self.logic_flags(v, 4)
        else:
            v = s8(self.d[r]) & M16
            self.d[r] = (self.d[r] & 0xFFFF0000) | v
            self.logic_flags(v, 2)

    def op_movem(self, op):
        mask = self.fetch16()
        size = 4 if op & 0x40 else 2
        mode, reg = (op >> 3) & 7, op & 7
        to_regs = op & 0x400
        if to_regs:
            if mode == 3:
                addr = self.a[reg]
            else:
                addr = self.ea_addr(mode, reg, size)
            for i in range(16):
                if mask & (1 << i):
                    v = self.bus.read32(addr) if size == 4 else s16(self.bus.read16(addr)) & M32
                    if i < 8:
                        self.d[i] = v
                    else:
                        self.a[i - 8] = v
                    addr += size
                    self.cycles += 4 * (size // 2)
            if mode == 3:
                self.a[reg] = addr & M32
        else:
            if mode == 4:
                addr = self.a[reg]
                for i in range(16):
                    if mask & (1 << i):
                        r = 15 - i
                        addr -= size
                        v = self.d[r] if r < 8 else self.a[r - 8]
                        if size == 4:
                            self.bus.write32(addr & M32, v)
                        else:
                            self.bus.write16(addr & M32, v & M16)
                        self.cycles += 4 * (size // 2)
                self.a[reg] = addr & M32
            else:
                addr = self.ea_addr(mode, reg, size)
                for i in range(16):
                    if mask & (1 << i):
                        v = self.d[i] if i < 8 else self.a[i - 8]
                        if size == 4:
                            self.bus.write32(addr & M32, v)
                        else:
                            self.bus.write16(addr & M32, v & M16)
                        addr += size
                        self.cycles += 4 * (size // 2)

    def op_tas(self, op):
        l = self.loc((op >> 3) & 7, op & 7, 1)
        v = self.rd(l, 1)
        self.logic_flags(v, 1)
        self.wr(l, 1, v | 0x80)

    def op_tst(self, op):
        size = self._size(op)
        self.logic_flags(self.ea_read((op >> 3) & 7, op & 7, size), size)

    def op_nbcd(self, op):
        l = self.loc((op >> 3) & 7, op & 7, 1)
        self.wr(l, 1, self._sbcd(self.rd(l, 1), 0))

    # 5: ADDQ/SUBQ/Scc/DBcc
    def _dec5(self, op):
        if (op >> 6) & 3 == 3:
            if (op >> 3) & 7 == 1:
                return self.op_dbcc
            return self.op_scc
        return self.op_addq_subq

    def op_addq_subq(self, op):
        q = (op >> 9) & 7 or 8
        size = self._size(op)
        mode, reg = (op >> 3) & 7, op & 7
        if mode == 1:
            if op & 0x100:
                self.a[reg] = (self.a[reg] - q) & M32
            else:
                self.a[reg] = (self.a[reg] + q) & M32
            return
        l = self.loc(mode, reg, size)
        d = self.rd(l, size)
        if op & 0x100:
            self.wr(l, size, self.sub_core(q, d, size))
        else:
            self.wr(l, size, self.add_core(q, d, size))

    def op_scc(self, op):
        l = self.loc((op >> 3) & 7, op & 7, 1)
        self.wr(l, 1, 0xFF if self.cond((op >> 8) & 15) else 0)

    def op_dbcc(self, op):
        r = op & 7
        base = self.pc
        disp = s16(self.fetch16())
        if self.cond((op >> 8) & 15):
            return
        cnt = (self.d[r] - 1) & M16
        self.d[r] = (self.d[r] & 0xFFFF0000) | cnt
        if cnt != 0xFFFF:
            self.pc = (base + disp) & M32

    # 6: desvios
    def _dec6(self, op):
        return self.op_bcc

    def op_bcc(self, op):
        cc = (op >> 8) & 15
        base = self.pc
        disp = op & 0xFF
        if disp == 0:
            disp = s16(self.fetch16())
        else:
            disp = s8(disp)
        if cc == 1:  # BSR
            self.push32(self.pc)
            self.pc = (base + disp) & M32
            return
        if self.cond(cc):
            target = (base + disp) & M32
            if disp < 0 and target >= self.last_pc - 8:
                self.idle_hint = True
            self.pc = target

    # 7: MOVEQ
    def _dec7(self, op):
        if op & 0x100:
            return None
        return self.op_moveq

    def op_moveq(self, op):
        v = s8(op) & M32
        self.d[(op >> 9) & 7] = v
        self.logic_flags(v, 4)

    # 8: OR/DIV/SBCD
    def _dec8(self, op):
        opm = (op >> 6) & 7
        if opm == 3:
            return self.op_divu
        if opm == 7:
            return self.op_divs
        if op & 0x1F0 == 0x100:
            return self.op_sbcd
        return self.op_or

    def op_or(self, op):
        self._logic(op, lambda a, b: a | b)

    def _logic(self, op, f):
        dn = (op >> 9) & 7
        size = (1, 2, 4)[(op >> 6) & 3]
        mode, reg = (op >> 3) & 7, op & 7
        if op & 0x100:
            l = self.loc(mode, reg, size)
            r = f(self.rd(l, size), self.d[dn] & MASK[size])
            self.wr(l, size, r)
        else:
            r = f(self.ea_read(mode, reg, size), self.d[dn] & MASK[size])
            self.wr(-1 - dn, size, r)
        self.logic_flags(r, size)

    def op_divu(self, op):
        src = self.ea_read((op >> 3) & 7, op & 7, 2)
        dn = (op >> 9) & 7
        self.cycles += 130
        if src == 0:
            self.exception(5)
            return
        q, r = divmod(self.d[dn], src)
        self.c = 0
        if q > 0xFFFF:
            self.v = 1
            self.n = 1
            return
        self.d[dn] = ((r & M16) << 16) | q
        self.v = 0
        self.nz(q, 2)

    def op_divs(self, op):
        src = s16(self.ea_read((op >> 3) & 7, op & 7, 2))
        dn = (op >> 9) & 7
        self.cycles += 150
        if src == 0:
            self.exception(5)
            return
        dv = s32(self.d[dn])
        q = abs(dv) // abs(src)
        if (dv < 0) != (src < 0):
            q = -q
        r = dv - q * src
        self.c = 0
        if q > 32767 or q < -32768:
            self.v = 1
            self.n = 1
            return
        self.d[dn] = ((r & M16) << 16) | (q & M16)
        self.v = 0
        self.nz(q & M16, 2)

    def _abcd(self, s, d):
        lo = (d & 0xF) + (s & 0xF) + self.x
        hi = (d >> 4) + (s >> 4)
        if lo > 9:
            lo -= 10
            hi += 1
        c = 0
        if hi > 9:
            hi -= 10
            c = 1
        r = ((hi << 4) | lo) & 0xFF
        self.c = self.x = c
        if r:
            self.z = 0
        self.n = 1 if r & 0x80 else 0
        return r

    def _sbcd(self, s, d):
        lo = (d & 0xF) - (s & 0xF) - self.x
        hi = (d >> 4) - (s >> 4)
        if lo < 0:
            lo += 10
            hi -= 1
        c = 0
        if hi < 0:
            hi += 10
            c = 1
        r = ((hi << 4) | lo) & 0xFF
        self.c = self.x = c
        if r:
            self.z = 0
        self.n = 1 if r & 0x80 else 0
        return r

    def _bcd_op(self, op, fn):
        rx, ry = (op >> 9) & 7, op & 7
        if op & 8:
            self.a[ry] = (self.a[ry] - (2 if ry == 7 else 1)) & M32
            s = self.bus.read8(self.a[ry])
            self.a[rx] = (self.a[rx] - (2 if rx == 7 else 1)) & M32
            d = self.bus.read8(self.a[rx])
            self.bus.write8(self.a[rx], fn(s, d))
        else:
            r = fn(self.d[ry] & 0xFF, self.d[rx] & 0xFF)
            self.d[rx] = (self.d[rx] & 0xFFFFFF00) | r

    def op_sbcd(self, op):
        self._bcd_op(op, self._sbcd)

    def op_abcd(self, op):
        self._bcd_op(op, self._abcd)

    # 9/D: SUB/ADD
    def _dec9(self, op):
        return self._dec_addsub(op, sub=True)

    def _decD(self, op):
        return self._dec_addsub(op, sub=False)

    def _dec_addsub(self, op, sub):
        opm = (op >> 6) & 7
        if opm in (3, 7):
            return self.op_suba if sub else self.op_adda
        if opm >= 4 and (op >> 3) & 7 in (0, 1):
            return self.op_subx if sub else self.op_addx
        return self.op_sub if sub else self.op_add

    def op_add(self, op):
        dn = (op >> 9) & 7
        size = (1, 2, 4)[(op >> 6) & 3]
        mode, reg = (op >> 3) & 7, op & 7
        if op & 0x100:
            l = self.loc(mode, reg, size)
            self.wr(l, size, self.add_core(self.d[dn] & MASK[size], self.rd(l, size), size))
        else:
            s = self.ea_read(mode, reg, size)
            self.wr(-1 - dn, size, self.add_core(s, self.d[dn] & MASK[size], size))

    def op_sub(self, op):
        dn = (op >> 9) & 7
        size = (1, 2, 4)[(op >> 6) & 3]
        mode, reg = (op >> 3) & 7, op & 7
        if op & 0x100:
            l = self.loc(mode, reg, size)
            self.wr(l, size, self.sub_core(self.d[dn] & MASK[size], self.rd(l, size), size))
        else:
            s = self.ea_read(mode, reg, size)
            self.wr(-1 - dn, size, self.sub_core(s, self.d[dn] & MASK[size], size))

    def op_adda(self, op):
        size = 4 if op & 0x100 else 2
        s = sx(self.ea_read((op >> 3) & 7, op & 7, size), size)
        an = (op >> 9) & 7
        self.a[an] = (self.a[an] + s) & M32

    def op_suba(self, op):
        size = 4 if op & 0x100 else 2
        s = sx(self.ea_read((op >> 3) & 7, op & 7, size), size)
        an = (op >> 9) & 7
        self.a[an] = (self.a[an] - s) & M32

    def _x_operands(self, op, size):
        rx, ry = (op >> 9) & 7, op & 7
        if op & 8:
            dec = lambda r: 2 if (r == 7 and size == 1) else size  # noqa: E731
            self.a[ry] = (self.a[ry] - dec(ry)) & M32
            s = self.rd(self.a[ry], size)
            self.a[rx] = (self.a[rx] - dec(rx)) & M32
            return s, self.a[rx]
        return self.d[ry] & MASK[size], -1 - rx

    def op_addx(self, op):
        size = (1, 2, 4)[(op >> 6) & 3]
        s, l = self._x_operands(op, size)
        self.wr(l, size, self.add_core(s, self.rd(l, size), size, self.x, addx=True))

    def op_subx(self, op):
        size = (1, 2, 4)[(op >> 6) & 3]
        s, l = self._x_operands(op, size)
        self.wr(l, size, self.sub_core(s, self.rd(l, size), size, self.x, subx=True))

    # B: CMP/EOR
    def _decB(self, op):
        opm = (op >> 6) & 7
        if opm in (3, 7):
            return self.op_cmpa
        if opm < 3:
            return self.op_cmp
        if (op >> 3) & 7 == 1:
            return self.op_cmpm
        return self.op_eor

    def op_cmp(self, op):
        size = (1, 2, 4)[(op >> 6) & 3]
        s = self.ea_read((op >> 3) & 7, op & 7, size)
        self.sub_core(s, self.d[(op >> 9) & 7] & MASK[size], size, setx=False)

    def op_cmpa(self, op):
        size = 4 if op & 0x100 else 2
        s = sx(self.ea_read((op >> 3) & 7, op & 7, size), size) & M32
        self.sub_core(s, self.a[(op >> 9) & 7], 4, setx=False)

    def op_cmpm(self, op):
        size = (1, 2, 4)[(op >> 6) & 3]
        s = self.rd(self.ea_addr(3, op & 7, size), size)
        d = self.rd(self.ea_addr(3, (op >> 9) & 7, size), size)
        self.sub_core(s, d, size, setx=False)

    def op_eor(self, op):
        dn = (op >> 9) & 7
        size = (1, 2, 4)[(op >> 6) & 3]
        l = self.loc((op >> 3) & 7, op & 7, size)
        r = self.rd(l, size) ^ (self.d[dn] & MASK[size])
        self.wr(l, size, r)
        self.logic_flags(r, size)

    # C: AND/MUL/ABCD/EXG
    def _decC(self, op):
        opm = (op >> 6) & 7
        if opm == 3:
            return self.op_mulu
        if opm == 7:
            return self.op_muls
        if op & 0x1F0 == 0x100:
            return self.op_abcd
        if op & 0x1F8 in (0x140, 0x148, 0x188):
            return self.op_exg
        return self.op_and

    def op_and(self, op):
        self._logic(op, lambda a, b: a & b)

    def op_mulu(self, op):
        s = self.ea_read((op >> 3) & 7, op & 7, 2)
        dn = (op >> 9) & 7
        r = (self.d[dn] & M16) * s
        self.d[dn] = r & M32
        self.logic_flags(r, 4)
        self.cycles += 60

    def op_muls(self, op):
        s = s16(self.ea_read((op >> 3) & 7, op & 7, 2))
        dn = (op >> 9) & 7
        r = (s16(self.d[dn]) * s) & M32
        self.d[dn] = r
        self.logic_flags(r, 4)
        self.cycles += 60

    def op_exg(self, op):
        rx, ry = (op >> 9) & 7, op & 7
        mode = op & 0x1F8
        if mode == 0x140:
            self.d[rx], self.d[ry] = self.d[ry], self.d[rx]
        elif mode == 0x148:
            self.a[rx], self.a[ry] = self.a[ry], self.a[rx]
        else:
            self.d[rx], self.a[ry] = self.a[ry], self.d[rx]

    # E: deslocamentos/rotações
    def _decE(self, op):
        if (op >> 6) & 3 == 3:
            return self.op_shift_mem
        return self.op_shift_reg

    def op_shift_reg(self, op):
        size = (1, 2, 4)[(op >> 6) & 3]
        r = op & 7
        cnt = (op >> 9) & 7
        if op & 0x20:
            cnt = self.d[cnt] & 63
        else:
            cnt = cnt or 8
        kind = (op >> 3) & 3
        left = bool(op & 0x100)
        v = self.d[r] & MASK[size]
        res = self._shift(kind, left, v, cnt, size)
        self.wr(-1 - r, size, res)
        self.cycles += 2 * cnt

    def op_shift_mem(self, op):
        kind = (op >> 9) & 3
        left = bool(op & 0x100)
        l = self.loc((op >> 3) & 7, op & 7, 2)
        self.wr(l, 2, self._shift(kind, left, self.rd(l, 2), 1, 2))

    def _shift(self, kind, left, v, cnt, size):
        m, msb = MASK[size], MSB[size]
        bits = size * 8
        self.v = 0
        if kind == 0:  # AS
            if cnt == 0:
                self.c = 0
                self.nz(v, size)
                return v
            if left:
                # V se o MSB mudar em algum momento
                vflag = 0
                for _ in range(cnt):
                    out = 1 if v & msb else 0
                    v = (v << 1) & m
                    if (1 if v & msb else 0) != out:
                        vflag = 1
                    self.c = self.x = out
                self.v = vflag
            else:
                sign = v & msb
                for _ in range(cnt):
                    self.c = self.x = v & 1
                    v = (v >> 1) | sign
            self.nz(v, size)
            return v
        if kind == 1:  # LS
            if cnt == 0:
                self.c = 0
                self.nz(v, size)
                return v
            if left:
                if cnt > bits:
                    self.c = self.x = 0
                    v = 0
                else:
                    self.c = self.x = (v >> (bits - cnt)) & 1
                    v = (v << cnt) & m
            else:
                if cnt > bits:
                    self.c = self.x = 0
                    v = 0
                else:
                    self.c = self.x = (v >> (cnt - 1)) & 1
                    v = v >> cnt
            self.nz(v, size)
            return v
        if kind == 2:  # ROX
            for _ in range(cnt):
                if left:
                    out = 1 if v & msb else 0
                    v = ((v << 1) | self.x) & m
                else:
                    out = v & 1
                    v = (v >> 1) | (msb if self.x else 0)
                self.x = out
            self.c = self.x
            self.nz(v, size)
            return v
        # RO
        if cnt == 0:
            self.c = 0
            self.nz(v, size)
            return v
        for _ in range(cnt):
            if left:
                out = 1 if v & msb else 0
                v = ((v << 1) | out) & m
            else:
                out = v & 1
                v = (v >> 1) | (msb if out else 0)
            self.c = out
        self.nz(v, size)
        return v

    def _decA(self, op):
        return None

    def _decF(self, op):
        return None
