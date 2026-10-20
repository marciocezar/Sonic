"""Biblioteca comum dos scripts do workspace sonic-megadrive (Python 3 stdlib).

Regras centrais:
- Toda leitura/escrita passa por `safe_path`, que resolve o caminho canônico e
  recusa qualquer destino fora de WORKSPACE_ROOT (traversal, `..`, symlinks).
- O único arquivo de origem é ROM_NAME, procurado apenas na raiz e em `roms/`.
- Os scripts só devem ser chamados por alvos do Makefile.
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional

ROM_NAME = "Sonic The Hedgehog (USA, Europe).md"
WORKSPACE_ROOT = Path(__file__).resolve().parent.parent

PRIVATE_DIRS = ("private", "work")
FORBIDDEN_HOME_DIRS = (".ssh", ".aws", ".azure", "OneDrive", "Documents", ".gnupg", ".config/gcloud")


class ScopeError(RuntimeError):
    pass


def safe_path(*parts: str | os.PathLike, must_exist: bool = False) -> Path:
    """Resolve um caminho relativo ao workspace e garante que fique dentro dele."""
    p = Path(*parts)
    if not p.is_absolute():
        p = WORKSPACE_ROOT / p
    resolved = p.resolve()
    try:
        resolved.relative_to(WORKSPACE_ROOT)
    except ValueError as exc:
        raise ScopeError(f"caminho fora do workspace recusado: {p} -> {resolved}") from exc
    if must_exist and not resolved.exists():
        raise FileNotFoundError(str(resolved))
    return resolved


def rel(p: Path) -> str:
    return str(Path(p).resolve().relative_to(WORKSPACE_ROOT))


def find_rom() -> Optional[Path]:
    """Procura somente o arquivo deste jogo na raiz e em roms/ (sem glob)."""
    for cand in (WORKSPACE_ROOT / ROM_NAME, WORKSPACE_ROOT / "roms" / ROM_NAME):
        if cand.is_symlink():
            # links simbólicos para fora do workspace são recusados
            safe_path(cand)
        if cand.is_file():
            return safe_path(cand)
    return None


def require_rom() -> Path:
    rom = find_rom()
    if rom is None:
        die(f"ROM ausente: '{ROM_NAME}' não está na raiz nem em roms/. Registrado como BLOQUEADO.", 3)
    return rom


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def hash_file(path: Path, algo: str) -> str:
    h = hashlib.new(algo)
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def read_lock() -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in safe_path("tooling/versions.lock").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def host_info() -> Dict[str, str]:
    return {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "python": platform.python_version(),
    }


def ensure_dir(*parts: str) -> Path:
    d = safe_path(*parts)
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_json(path: Path, data) -> None:
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=False) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def die(msg: str, code: int = 1) -> None:
    print(f"ERRO: {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg: str) -> None:
    print(f"[sonic-megadrive] {msg}", flush=True)


# --- ferramentas locais -----------------------------------------------------

def godot_dir() -> Path:
    return safe_path("tooling/godot")


def godot_bin() -> Optional[Path]:
    """Binário Godot local (tooling/godot) ou GODOT_BIN informado (não secreto)."""
    env = os.environ.get("GODOT_BIN")
    if env:
        p = Path(env)
        return p if p.is_file() else None
    sysname = platform.system()
    if sysname == "Darwin":
        p = godot_dir() / "Godot.app" / "Contents" / "MacOS" / "Godot"
    elif sysname == "Windows":
        p = godot_dir() / "Godot.exe"
    else:
        p = godot_dir() / "godot"
    return p if p.is_file() else None


def templates_dir() -> Path:
    lock = read_lock()
    sysname = platform.system()
    # modo auto-contido (_sc_): dados do editor ficam ao lado do binário
    # modo auto-contido: no macOS o editor usa tooling/godot/editor_data (ao lado do .app)
    base = godot_dir()
    return base / "editor_data" / "export_templates" / lock["godot.templates.dirname"]


def run(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 1800, env: Optional[dict] = None,
        log: Optional[Path] = None) -> int:
    """Executa um comando sem shell, com timeout, opcionalmente registrando log."""
    info("exec: " + " ".join(_q(c) for c in cmd))
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        cp = subprocess.run(cmd, cwd=str(cwd) if cwd else None, timeout=timeout, env=e,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except subprocess.TimeoutExpired:
        print(f"timeout após {timeout}s", file=sys.stderr)
        return 124
    out = cp.stdout.decode("utf-8", "replace")
    if log is not None:
        write_text(log, out)
    sys.stdout.write(out[-6000:])
    return cp.returncode


def _q(s: str) -> str:
    return f'"{s}"' if (" " in s or "'" in s) else s


def which(name: str) -> Optional[str]:
    return shutil.which(name)


def iter_files(root: Path) -> Iterable[Path]:
    root = safe_path(root)
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        for fn in filenames:
            yield Path(dirpath) / fn


def godot_refresh(quiet: bool = True) -> int:
    """Atualiza o cache de classes/importação do projeto Godot (necessário após novos class_name)."""
    g = godot_bin()
    if g is None:
        return 2
    cp = subprocess.run([str(g), "--headless", "--path", str(safe_path("game")), "--import"],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    out = cp.stdout.decode("utf-8", "replace")
    errs = [l for l in out.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
    if errs and not quiet:
        print("\n".join(errs[:20]))
    return cp.returncode
