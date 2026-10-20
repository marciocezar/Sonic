"""make bootstrap — instala dependências SOMENTE dentro do workspace.

Componentes (todos com versão fixada e hash verificado em tooling/versions.lock):
  godot      editor Godot (macOS universal) em tooling/godot/, modo auto-contido (_sc_)
  templates  export templates em editor_data/ do modo auto-contido (não usa ~/Library)
  rea        rea-agents via `npm --prefix tooling/rea --ignore-scripts` (sem `setup`, sem MCP global)
  ghidra     Ghidra oficial em tooling/ghidra/ (provider nativo; usa o JDK do sistema)

Uso: python3 tooling/bootstrap.py [godot templates rea ghidra]   (chamado pelo Makefile)
Consentimento: o download foi aprovado pelo usuário em 2026-10-18 (ver docs/security).
"""
from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

DL = wslib.ensure_dir("work", "downloads")


def download(url: str, dest: Path, size: int) -> Path:
    dest = wslib.safe_path(dest)
    if dest.is_file() and dest.stat().st_size == size:
        wslib.info(f"já baixado: {wslib.rel(dest)}")
        return dest
    tmp = dest.with_suffix(dest.suffix + ".part")
    curl = wslib.which("curl")
    if curl:
        rc = subprocess.run([curl, "-fsSL", "--retry", "3", "-C", "-", "-o", str(tmp), url]).returncode
        if rc != 0:
            wslib.die(f"download falhou ({rc}): {url}")
    else:
        import urllib.request
        with urllib.request.urlopen(url) as r, open(tmp, "wb") as f:  # nosec - URL fixa do lock
            shutil.copyfileobj(r, f)
    tmp.replace(dest)
    if dest.stat().st_size != size:
        wslib.die(f"tamanho inesperado para {dest.name}: {dest.stat().st_size} != {size}")
    return dest


def verify(path: Path, algo: str, expected: str) -> None:
    got = wslib.hash_file(path, algo)
    if got.lower() != expected.lower():
        path.unlink(missing_ok=True)
        wslib.die(f"HASH INVÁLIDO {path.name}: {algo} {got} != {expected}; arquivo removido")
    wslib.info(f"{algo} OK {path.name}")


def safe_extract_zip(zpath: Path, dest: Path) -> None:
    dest = wslib.safe_path(dest)
    with zipfile.ZipFile(zpath) as z:
        for m in z.infolist():
            target = (dest / m.filename).resolve()
            target.relative_to(dest)  # bloqueia zip-slip
        z.extractall(dest)
        for m in z.infolist():
            mode = (m.external_attr >> 16) & 0o777
            if mode:
                os.chmod(dest / m.filename, mode)


def do_godot(lock):
    if platform.system() != "Darwin":
        wslib.die("bootstrap automático do editor está implementado para macOS; em outro SO, defina GODOT_BIN (ver docs/operations).", 2)
    app = wslib.godot_dir() / "Godot.app"
    if (app / "Contents/MacOS/Godot").is_file():
        wslib.info("Godot já instalado")
    else:
        z = download(lock["godot.editor.url"], DL / Path(lock["godot.editor.url"]).name, int(lock["godot.editor.size"]))
        verify(z, "sha512", lock["godot.editor.sha512"])
        wslib.godot_dir().mkdir(parents=True, exist_ok=True)
        # ditto preserva bundle, permissões e symlinks internos do .app
        subprocess.run(["ditto", "-x", "-k", str(z), str(wslib.godot_dir())], check=True)
    # modo auto-contido: configurações/templates ficam dentro de tooling/godot
    (app / "Contents/MacOS/._sc_").touch()
    (app / "Contents/MacOS/_sc_").touch()
    out = subprocess.run([str(app / "Contents/MacOS/Godot"), "--headless", "--version"],
                         capture_output=True, text=True, timeout=120)
    wslib.info("godot --version: " + out.stdout.strip())


def do_templates(lock):
    tdir = wslib.templates_dir()
    if (tdir / "version.txt").is_file():
        wslib.info(f"templates já instalados em {wslib.rel(tdir)}")
        return
    z = download(lock["godot.templates.url"], DL / Path(lock["godot.templates.url"]).name, int(lock["godot.templates.size"]))
    verify(z, "sha512", lock["godot.templates.sha512"])
    stage = wslib.safe_path("work/templates_stage")
    if stage.exists():
        shutil.rmtree(stage)
    safe_extract_zip(z, stage)
    tdir.parent.mkdir(parents=True, exist_ok=True)
    if tdir.exists():
        shutil.rmtree(tdir)
    shutil.move(str(stage / "templates"), str(tdir))
    shutil.rmtree(stage, ignore_errors=True)
    wslib.info(f"templates instalados: {wslib.rel(tdir)} ({len(list(tdir.iterdir()))} arquivos)")


def do_rea(lock):
    npm = wslib.which("npm")
    if not npm:
        wslib.die("npm ausente; REA não pode ser instalado localmente", 2)
    prefix = wslib.ensure_dir("tooling", "rea")
    spec = f"{lock['rea.package']}@{lock['rea.version']}"
    rc = subprocess.run([npm, "install", "--prefix", str(prefix), "--no-audit", "--no-fund",
                         "--ignore-scripts", "--save-exact", spec]).returncode
    if rc != 0:
        wslib.die(f"npm install {spec} falhou ({rc})")
    import json
    pl = json.loads((prefix / "package-lock.json").read_text())
    got = pl["packages"].get("node_modules/rea-agents", {}).get("integrity")
    if got != lock["rea.integrity"]:
        wslib.die(f"integridade rea-agents divergente: {got}")
    wslib.info(f"rea-agents {lock['rea.version']} instalado em tooling/rea (integridade npm OK)")


def do_ghidra(lock):
    gdir = wslib.safe_path("tooling/ghidra")
    marker = gdir / f"ghidra_{lock['ghidra.version']}_PUBLIC"
    if marker.is_dir():
        wslib.info("Ghidra já instalado")
        return
    z = download(lock["ghidra.url"], DL / Path(lock["ghidra.url"]).name, int(lock["ghidra.size"]))
    verify(z, "sha256", lock["ghidra.sha256"])
    gdir.mkdir(parents=True, exist_ok=True)
    safe_extract_zip(z, gdir)
    wslib.info(f"Ghidra extraído em {wslib.rel(gdir)}")


def do_ghidra_natives(lock):
    """Compila o decompilador nativo do Ghidra (darwin/arm64 não vem no zip oficial).

    Usa o Makefile C++ incluído na própria distribuição e o compilador do Xcode (host).
    """
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        wslib.info("natives: apenas necessário em macOS arm64; ignorado")
        return
    base = wslib.safe_path(f"tooling/ghidra/ghidra_{lock['ghidra.version']}_PUBLIC/Ghidra/Features/Decompiler")
    out = base / "os" / "mac_arm_64"
    if (out / "decompile").is_file() and (out / "sleigh").is_file():
        wslib.info("natives Ghidra já compilados")
        return
    cpp = base / "src" / "decompile" / "cpp"
    jobs = str(os.cpu_count() or 4)
    # O Makefile do Ghidra escolhe as dependências por MAKECMDGOALS: um alvo por chamada.
    for goal in ("ghidra_opt", "sleigh_opt"):
        rc = subprocess.run(["make", "-j", jobs, "ARCH_TYPE=", goal], cwd=str(cpp)).returncode
        if rc != 0:
            wslib.die(f"compilação do decompilador Ghidra falhou em {goal} ({rc})")
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(cpp / "ghidra_opt", out / "decompile")
    shutil.copy2(cpp / "sleigh_opt", out / "sleigh")
    wslib.info(f"natives Ghidra instalados em {wslib.rel(out)}")


def do_protect(lock):
    """Deixa o arquivo original somente leitura (não altera o conteúdo)."""
    rom = wslib.find_rom()
    if rom is None:
        wslib.info("ROM ausente; nada a proteger")
        return
    os.chmod(rom, 0o444)
    wslib.info(f"original protegido (somente leitura): {wslib.rel(rom)}")


def main(argv):
    lock = wslib.read_lock()
    comps = argv or ["protect", "godot", "templates", "rea", "ghidra", "ghidra-natives"]
    table = {"godot": do_godot, "templates": do_templates, "rea": do_rea, "ghidra": do_ghidra,
             "ghidra-natives": do_ghidra_natives, "protect": do_protect}
    for c in comps:
        if c not in table:
            wslib.die(f"componente desconhecido: {c}")
        wslib.info(f"== bootstrap {c} ==")
        table[c](lock)
    wslib.write_json(wslib.safe_path("reports/build/bootstrap.json"),
                     {"timestamp": wslib.now_iso(), "components": comps, "host": wslib.host_info()})


if __name__ == "__main__":
    main(sys.argv[1:])
