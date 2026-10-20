"""make security-check | make check-no-rom-in-dist

security-check: escopo do workspace, .gitignore, links simbólicos que saem do workspace,
                varredura simples de segredos, permissões do original, isolamento declarado.
no-rom-in-dist: garante que dist/ e game/ não contêm a ROM, trechos dela (assinatura do cabeçalho)
                nem arquivos privados extraídos (hash), inclusive dentro de .zip/.apk/.aab/.ipa.
"""
from __future__ import annotations

import io
import json
import os
import re
import stat
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

GITIGNORE_REQUIRED = ["*.md.rom", "/Sonic The Hedgehog (USA, Europe).md", "roms/", "private/", "work/", "dist/",
                      "*.keystore", "*.jks", "*.p12", "*.mobileprovision", ".env", "*.log"]
SECRET_PATTERNS = [
    re.compile(rb"-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----"),
    re.compile(rb"AKIA[0-9A-Z]{16}"),
    re.compile(rb"ghp_[0-9A-Za-z]{36}"),
    re.compile(rb"sk-[A-Za-z0-9]{32,}"),
    re.compile(rb"(?i)(password|passwd|secret)\s*[:=]\s*['\"][^'\"]{6,}['\"]"),
]
SKIP_DIRS = {"work", "private", "dist", ".godot", "node_modules", "godot", "ghidra", "rea", ".git", "__pycache__"}
ROM_SIGNATURE = b"SEGA MEGA DRIVE (C)SEGA 1991.APRSONIC THE"


def scan_secrets() -> list:
    hits = []
    for root, dirs, files in os.walk(wslib.WORKSPACE_ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fn in files:
            p = Path(root, fn)
            if p.suffix in (".png", ".wav", ".md") and p.name != "README.md":
                continue
            if p.stat().st_size > 2_000_000 or p.name == wslib.ROM_NAME:
                continue
            try:
                data = p.read_bytes()
            except OSError:
                continue
            for pat in SECRET_PATTERNS:
                if pat.search(data):
                    hits.append({"file": wslib.rel(p), "pattern": pat.pattern.decode(errors="replace")[:40]})
    return hits


def scan_symlinks() -> list:
    bad = []
    for root, dirs, files in os.walk(wslib.WORKSPACE_ROOT):
        dirs[:] = [d for d in dirs if d not in {".git"}]
        for n in dirs + files:
            p = Path(root, n)
            if p.is_symlink():
                try:
                    wslib.safe_path(p)
                except wslib.ScopeError:
                    bad.append(str(p))
    return bad


def security_check() -> int:
    issues, notes = [], []
    gi = wslib.safe_path(".gitignore")
    text = gi.read_text() if gi.is_file() else ""
    for pat in GITIGNORE_REQUIRED:
        if pat not in text:
            issues.append(f".gitignore sem o padrão obrigatório: {pat}")
    rom = wslib.find_rom()
    if rom is None:
        notes.append("ROM ausente (análises dependentes ficam BLOQUEADAS)")
    else:
        mode = rom.stat().st_mode
        if mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
            issues.append("ROM original com permissão de escrita (execute `make bootstrap COMPONENTS=protect`)")
        else:
            notes.append("ROM original somente leitura")
    links = scan_symlinks()
    for l in links:
        issues.append(f"link simbólico saindo do workspace: {l}")
    secrets = scan_secrets()
    for s in secrets:
        issues.append(f"possível segredo em {s['file']} ({s['pattern']})")
    env = wslib.safe_path(".env")
    if env.exists():
        notes.append(".env local presente (ignorado pelo git; não é lido por padrão)")
    rep = {"timestamp": wslib.now_iso(), "workspace": str(wslib.WORKSPACE_ROOT), "issues": issues, "notes": notes,
           "isolation": {"rea": "sandbox-exec obrigatório (deep analysis BLOQUEADA por EPERM)",
                         "ghidra": "sandbox-exec sem rede, escrita só em work/",
                         "rom_execution": "somente no interpretador 68000 próprio (sem execução nativa)"}}
    wslib.write_json(wslib.safe_path("reports/qa/security-check.json"), rep)
    for n in notes:
        print("INFO ", n)
    for i in issues:
        print("FALHA", i)
    print("security-check:", "OK" if not issues else f"{len(issues)} problema(s)")
    return 0 if not issues else 1


def _private_hashes() -> set:
    hs = set()
    rom = wslib.find_rom()
    if rom:
        hs.add(wslib.sha256_file(rom))
    for d in ("private",):
        base = wslib.safe_path(d)
        if base.is_dir():
            for p in wslib.iter_files(base):
                if p.stat().st_size >= 256:
                    hs.add(wslib.sha256_file(p))
    return hs


_TAGS: list = []


def _private_tags() -> list:
    """Dados extraídos carregam o SHA-256 da ROM de origem (campo source_sha256)."""
    if not _TAGS:
        rom = wslib.find_rom()
        if rom:
            # marca de dados extraídos: campo "source_sha256" com o hash (o hash sozinho é usado legitimamente
            # pelo importador para validar a revisão da ROM do usuário e não é conteúdo protegido)
            h = wslib.sha256_file(rom)
            _TAGS.append(f'"source_sha256": "{h}"'.encode())
            _TAGS.append(f'"source_sha256":"{h}"'.encode())
    return _TAGS


def _scan_blob(name: str, data: bytes, hashes: set, findings: list, depth: int = 0) -> None:
    import hashlib
    if hashlib.sha256(data).hexdigest() in hashes:
        findings.append(f"{name}: hash idêntico a arquivo privado/ROM")
    if ROM_SIGNATURE in data:
        findings.append(f"{name}: contém assinatura do cabeçalho da ROM")
    for tag in _private_tags():
        if tag in data:
            findings.append(f"{name}: contém o SHA-256 da ROM (marca de dados extraídos privados)")
            break
    if depth < 2 and data[:4] == b"PK\x03\x04":
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                for info in z.infolist():
                    if info.file_size > 200_000_000:
                        continue
                    _scan_blob(f"{name}!{info.filename}", z.read(info), hashes, findings, depth + 1)
        except zipfile.BadZipFile:
            pass


def no_rom_in_dist() -> int:
    hashes = _private_hashes()
    findings = []
    scanned = 0
    for d in ("dist", "game"):
        base = wslib.safe_path(d)
        if not base.is_dir():
            continue
        for p in wslib.iter_files(base):
            if ".godot" in p.parts:
                continue
            if p.stat().st_size > 400_000_000:
                continue
            scanned += 1
            _scan_blob(wslib.rel(p), p.read_bytes(), hashes, findings)
    rep = {"timestamp": wslib.now_iso(), "files_scanned": scanned, "private_hashes": len(hashes), "findings": findings}
    wslib.write_json(wslib.safe_path("reports/qa/check-no-rom-in-dist.json"), rep)
    for f in findings:
        print("FALHA", f)
    print(f"check-no-rom-in-dist: {scanned} arquivos verificados, {len(findings)} achado(s)")
    return 0 if not findings else 1


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    sys.exit(no_rom_in_dist() if cmd == "no-rom-in-dist" else security_check())
