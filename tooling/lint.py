"""make lint | make format-check (Python + GDScript, sem dependências externas)."""
from __future__ import annotations

import py_compile
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

PY_DIRS = ["tooling", "tests"]
GD_DIRS = ["game/src", "game/tests"]
TEXT_EXT = {".py", ".gd", ".md", ".cfg", ".json", ".tscn", ".godot"}


def files(dirs, exts):
    for d in dirs:
        base = wslib.safe_path(d)
        for p in sorted(wslib.iter_files(base)):
            skip = {"__pycache__", "ghidra_scripts", "rea", "godot", "ghidra", "node_modules"}
            if p.suffix in exts and not (skip & set(p.relative_to(wslib.WORKSPACE_ROOT).parts)):
                yield p


def lint() -> int:
    bad = 0
    for p in files(PY_DIRS, {".py"}):
        try:
            py_compile.compile(str(p), doraise=True, cfile=str(wslib.safe_path("work/pyc") / (p.stem + ".pyc")))
        except py_compile.PyCompileError as e:
            print("PYFAIL", wslib.rel(p), e.msg[:200])
            bad += 1
        txt = p.read_text(encoding="utf-8")
        for i, line in enumerate(txt.splitlines(), 1):
            if len(line) > 140:
                print(f"PYWARN {wslib.rel(p)}:{i} linha com {len(line)} colunas")
    g = wslib.godot_bin()
    if g is None:
        print("BLOCKED: Godot ausente para lint GDScript")
        return 2
    wslib.godot_refresh(quiet=False)
    cp = subprocess.run([str(g), "--headless", "--path", str(wslib.safe_path("game")), "--", "--lint"],
                        capture_output=True, text=True, timeout=600)
    out = cp.stdout + cp.stderr
    for l in out.splitlines():
        if l.startswith(("LINT", "LINTFAIL")) or "SCRIPT ERROR" in l or "Parse Error" in l:
            print(l)
    if cp.returncode != 0 or "SCRIPT ERROR" in out:
        bad += 1
    print("lint:", "OK" if bad == 0 else f"{bad} falha(s)")
    return 0 if bad == 0 else 1


def fmt() -> int:
    bad = 0
    for p in list(files(PY_DIRS + GD_DIRS + ["docs"], TEXT_EXT)) + [wslib.safe_path("Makefile")]:
        b = p.read_bytes()
        rel = wslib.rel(p)
        if b"\r\n" in b:
            print("FMT CRLF", rel); bad += 1
        if b and not b.endswith(b"\n"):
            print("FMT sem newline final", rel); bad += 1
        for i, line in enumerate(b.decode("utf-8", "replace").split("\n"), 1):
            if line.rstrip() != line and p.suffix != ".md":
                print(f"FMT espaço final {rel}:{i}"); bad += 1
                break
            if p.suffix == ".gd" and line.startswith("    "):
                print(f"FMT GDScript deve indentar com tabs {rel}:{i}"); bad += 1
                break
            if p.suffix == ".py" and line.startswith("\t"):
                print(f"FMT Python deve indentar com espaços {rel}:{i}"); bad += 1
                break
    print("format-check:", "OK" if bad == 0 else f"{bad} problema(s)")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(lint() if (sys.argv[1:] or ["lint"])[0] == "lint" else fmt())
