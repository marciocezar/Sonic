"""Isolamento de ferramentas de terceiros (REA, Ghidra) no macOS via sandbox-exec.

Perfil gerado: sem rede, escrita apenas em diretórios de análise dentro de work/ (+ temporários
do sistema), leitura negada a diretórios sensíveis do usuário. Em outros SOs não há sandbox
equivalente implementado: os alvos falham com diagnóstico em vez de rodar sem isolamento.
Limites: CPU/tempo por timeout do subprocess; RAM limitada pelo -Xmx do Java no Ghidra.
"""
from __future__ import annotations

import os
import platform
import shutil
from pathlib import Path
from typing import List, Optional

import wslib

SENSITIVE = [".ssh", ".aws", ".azure", ".gnupg", "Documents", "OneDrive", "Library/Keychains",
             ".config/gcloud", ".kube", ".docker", ".claude", ".npmrc", ".netrc"]


def available() -> bool:
    return platform.system() == "Darwin" and shutil.which("sandbox-exec") is not None


def profile(write_dirs: List[Path], name: str) -> Path:
    home = Path(os.path.expanduser("~"))
    writes = "".join(f' (subpath "{wslib.safe_path(d)}")' for d in write_dirs)
    reads = "".join(f' (subpath "{home / s}")' for s in SENSITIVE)
    text = (
        "(version 1)\n(allow default)\n(deny network*)\n"
        "(deny file-write* (require-not (require-any" + writes +
        ' (subpath "/private/var/folders") (subpath "/private/tmp") (literal "/dev/null")'
        ' (literal "/dev/tty") (literal "/dev/dtracehelper"))))\n'
        "(deny file-read*" + reads + ")\n"
    )
    p = wslib.safe_path("work", "sandbox", f"{name}.sb")
    wslib.write_text(p, text)
    return p


def wrap(cmd: List[str], write_dirs: List[Path], name: str) -> Optional[List[str]]:
    if not available():
        return None
    return ["sandbox-exec", "-f", str(profile(write_dirs, name))] + cmd
