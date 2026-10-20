"""make doctor — pré-requisitos por SO (somente leitura; não instala nada)."""
from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

rows = []


def row(name, ok, detail, need="", blocks=""):
    rows.append({"item": name, "ok": bool(ok), "detail": detail, "remediation": need, "blocks": blocks})
    print(f"{'OK ' if ok else '-- '} {name:28s} {detail}" + (f"  -> {need}" if not ok and need else ""))


def ver(cmd):
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return (cp.stdout or cp.stderr).strip().splitlines()[0]
    except Exception:  # noqa: BLE001
        return ""


def main():
    lock = wslib.read_lock()
    print(f"Host: {platform.system()} {platform.release()} {platform.machine()} | workspace: {wslib.WORKSPACE_ROOT}\n")
    rom = wslib.find_rom()
    row("ROM deste jogo", rom is not None, wslib.ROM_NAME if rom else "ausente (raiz ou roms/)", "copie o arquivo para a raiz", "análise/paridade")
    row("Python 3", sys.version_info >= (3, 9), platform.python_version())
    row("GNU Make", True, ver(["make", "--version"]) or "?", "Windows: MSYS2 (pacman -S make)")
    g = wslib.godot_bin()
    row(f"Godot {lock['godot.version']}", g is not None, ver([str(g), "--headless", "--version"]) if g else "ausente",
        "make bootstrap COMPONENTS=godot", "run/test/build")
    row("Export templates", (wslib.templates_dir() / "version.txt").is_file(), wslib.rel(wslib.templates_dir()),
        "make bootstrap COMPONENTS=templates", "build-*")
    row("REA local", wslib.safe_path("tooling/rea/node_modules/rea-agents/scripts/rea.mjs").is_file(), f"rea-agents {lock['rea.version']}",
        "make bootstrap COMPONENTS=rea")
    row("Ghidra local", wslib.safe_path(f"tooling/ghidra/ghidra_{lock['ghidra.version']}_PUBLIC").is_dir(), lock["ghidra.version"],
        "make bootstrap COMPONENTS=ghidra")
    row("Node.js", shutil.which("node") is not None, ver(["node", "--version"]), "necessário apenas para REA")
    row("sandbox-exec (macOS)", shutil.which("sandbox-exec") is not None, "isolamento REA/Ghidra", "sem sandbox: REA/Ghidra não rodam")
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ""
    row("ANDROID_HOME", bool(sdk) and Path(sdk, "platform-tools").is_dir(), sdk or "não definido",
        "defina ANDROID_HOME (ver .env.example)", "build-android")
    row("JDK 17+", bool(os.environ.get("JAVA_HOME")) or shutil.which("java") is not None, ver(["java", "-version"]), "defina JAVA_HOME", "android")
    if platform.system() == "Darwin":
        row("Xcode", shutil.which("xcodebuild") is not None, ver(["xcodebuild", "-version"]), "instale o Xcode", "ios")
    row("IOS_TEAM_ID", bool(os.environ.get("IOS_TEAM_ID")), "definido" if os.environ.get("IOS_TEAM_ID") else "não definido",
        "necessário apenas para IPA assinado", "ios-archive")
    row("Windows host p/ teste", platform.system() == "Windows", "build Windows é exportada aqui; execução exige Windows/VM")
    wslib.write_json(wslib.safe_path("reports/qa/doctor.json"), {"timestamp": wslib.now_iso(), "host": wslib.host_info(), "rows": rows})
    return 0


if __name__ == "__main__":
    sys.exit(main())
