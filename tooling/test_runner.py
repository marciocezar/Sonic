"""make test-unit | make test-touch — testes Python (unittest) e GDScript headless."""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402


def godot_suite(name: str) -> int:
    g = wslib.godot_bin()
    if g is None:
        print("BLOCKED: Godot ausente (make bootstrap)")
        return 2
    wslib.godot_refresh(quiet=False)
    cp = subprocess.run([str(g), "--headless", "--path", str(wslib.safe_path("game")), "--script",
                         "res://tests/test_main.gd", "--", f"--suite={name}"],
                        capture_output=True, text=True, timeout=900)
    out = "\n".join(l for l in cp.stdout.splitlines() if l.startswith(("PASS", "FAIL", "SUITE", "TOTAL")))
    print(out)
    errs = [l for l in (cp.stdout + cp.stderr).splitlines() if "SCRIPT ERROR" in l]
    if errs:
        print("\n".join(errs[:10]))
    wslib.write_text(wslib.safe_path(f"reports/qa/godot-{name}-tests.txt"), out + "\n")
    return cp.returncode if not errs else 1


def progression() -> int:
    """Carrega as 19 fases a partir da ROM do usuário (sem levelpacks) e percorre a sequência original."""
    import os
    g = wslib.godot_bin()
    rom = wslib.find_rom()
    if g is None or rom is None:
        print("BLOCKED: Godot ou ROM ausente")
        return 2
    wslib.godot_refresh(quiet=True)
    env = {k: v for k, v in os.environ.items() if k != "SONIC_LEVELPACKS"}
    cp = subprocess.run([str(g), "--headless", "--path", str(wslib.safe_path("game")), "--",
                         f"--rom={rom}", "--levelpacks=", "--test-progression=1"],
                        capture_output=True, text=True, timeout=900, env=env)
    line = next((l for l in cp.stdout.splitlines() if l.startswith("progressao:")), "")
    got = [x.split(":")[0] for x in line[len("progressao:"):].strip().split(",") if x]
    expected = ["ghz1", "ghz2", "ghz3", "mz1", "mz2", "mz3", "syz1", "syz2", "syz3", "lz1", "lz2", "lz3",
                "slz1", "slz2", "slz3", "sbz1", "sbz2", "sbz3", "fz"]
    ok = got == expected and all(x.endswith(":true") for x in line[len("progressao:"):].strip().split(","))
    print(("PASS" if ok else "FAIL") + " progressao ROM -> " + " > ".join(got))
    wslib.write_text(wslib.safe_path("reports/qa/progression.txt"), line + "\n")
    return 0 if ok and cp.returncode == 0 else 1


def main(kind: str) -> int:
    if kind == "unit":
        suite = unittest.defaultTestLoader.discover(str(wslib.safe_path("tests/unit")), pattern="test_*.py")
        res = unittest.TextTestRunner(verbosity=1).run(suite)
        rc_py = 0 if res.wasSuccessful() else 1
        rc_gd = godot_suite("unit")
        return rc_py or rc_gd
    if kind == "touch":
        return godot_suite("touch")
    if kind == "rom":
        import os
        rom = wslib.find_rom()
        if rom:
            os.environ["SONIC_ROM"] = str(rom)
        packs = wslib.safe_path("private/extracted/levelpacks")
        if packs.is_dir():
            os.environ["SONIC_LEVELPACKS"] = str(packs)
        return godot_suite("rom")
    if kind == "progression":
        return progression()
    if kind == "bench":
        import os
        packs = wslib.safe_path("private/extracted/levelpacks")
        if packs.is_dir():
            os.environ["SONIC_LEVELPACKS"] = str(packs)
        return godot_suite("bench")
    wslib.die(f"tipo desconhecido: {kind}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "unit"))
