"""Tarefas Godot por trás dos alvos do Makefile (run, build-*, testes de plataforma).

Status de build em reports/build/status.json:
  NOT_STARTED | BUILT_NOT_TESTED | PASS | FAIL | BLOCKED
"Exportado" nunca é tratado como "testado". Nada é assinado para distribuição pública aqui.
Caminhos de SDK vêm apenas de variáveis não secretas: ANDROID_HOME/ANDROID_SDK_ROOT, JAVA_HOME,
IOS_TEAM_ID, IOS_PROVISIONING_UUID (ver .env.example).
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402
from rom_levels import REV00_SHA256  # noqa: E402

GAME = wslib.safe_path("game")
STATUS = wslib.safe_path("reports/build/status.json")
PRESETS = {"macos": "macOS", "windows": "Windows Desktop", "web": "Web", "android": "Android",
           "android-aab": "Android", "ios": "iOS"}
OUTPUTS = {
    "macos": "dist/macos/MegadrivePlatformerLab.zip",
    "windows": "dist/windows/MegadrivePlatformerLab.exe",
    "web": "dist/web/index.html",
    "android": "dist/android/MegadrivePlatformerLab-debug.apk",
    "android-aab": "dist/android/MegadrivePlatformerLab-release.aab",
    "ios": "dist/ios/MegadrivePlatformerLab.ipa",
}
REQUIRED = ["macos", "windows", "web", "android", "ios"]


def load_status() -> dict:
    if STATUS.is_file():
        return json.loads(STATUS.read_text())
    return {}


def set_status(target: str, status: str, notes: str = "", command: str = "", artifacts=None) -> None:
    st = load_status()
    st[target] = {"status": status, "timestamp": wslib.now_iso(), "command": command, "notes": notes,
                  "host": wslib.host_info(), "artifacts": artifacts or []}
    wslib.write_json(STATUS, st)


def artifact_list(paths) -> list:
    out = []
    for p in paths:
        p = wslib.safe_path(p)
        if p.is_file():
            out.append({"path": wslib.rel(p), "size": p.stat().st_size, "sha256": wslib.sha256_file(p)})
    return out


def need_godot():
    g = wslib.godot_bin()
    if g is None:
        wslib.die("Godot ausente: execute `make bootstrap` (ou defina GODOT_BIN).", 2)
    return g


def private_packs() -> str:
    d = wslib.safe_path("private/extracted/levelpacks")
    return str(d) if d.is_dir() else ""


# --- run --------------------------------------------------------------------------------

def run(profile: str) -> int:
    g = need_godot()
    wslib.godot_refresh()
    args = [str(g), "--path", str(GAME), "--", f"--profile={profile}", "--levelpacks="]
    rom = wslib.find_rom()
    if rom is not None:
        # mesmo conteúdo do build privado: zonas, arte, sprites e fundos lidos da ROM do workspace
        args.append(f"--rom={rom}")
        wslib.info("conteúdo original lido da ROM do workspace (igual ao build privado).")
    extra = os.environ.get("RUN_ARGS", "").split()
    args += extra
    wslib.info("abrindo o jogo (feche a janela para encerrar)")
    return subprocess.call(args)


# --- configuração Android ----------------------------------------------------------------

def android_env() -> tuple:
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ""
    if not sdk or not Path(sdk, "platform-tools").is_dir():
        return None, "ANDROID_HOME/ANDROID_SDK_ROOT não definido ou inválido (ver .env.example)"
    java = os.environ.get("JAVA_HOME", "")
    if not java:
        cp = subprocess.run(["/usr/libexec/java_home", "-v", "17"], capture_output=True, text=True) \
            if platform.system() == "Darwin" else None
        java = cp.stdout.strip() if cp and cp.returncode == 0 else ""
    if not java:
        return None, "JDK 17+ não encontrado (defina JAVA_HOME)"
    return {"sdk": sdk, "java": java}, ""


def ensure_debug_keystore(java: str) -> Path:
    """Keystore de DEPURAÇÃO local (credenciais padrão de debug Android, não secretas)."""
    ks = wslib.ensure_dir("work", "keys") / "debug.keystore"
    if not ks.is_file():
        keytool = str(Path(java, "bin", "keytool"))
        subprocess.run([keytool, "-genkeypair", "-v", "-keystore", str(ks), "-storepass", "android",
                        "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA", "-keysize", "2048",
                        "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US"],
                       check=True, capture_output=True)
    return ks


def write_editor_settings(env: dict) -> None:
    """Configura o editor auto-contido (tooling/godot/.../editor_data) com caminhos de SDK."""
    lock = wslib.read_lock()
    ver = ".".join(lock["godot.version"].split("-")[0].split(".")[:2])
    base = wslib.templates_dir().parent.parent
    path = base / f"editor_settings-{ver}.tres"
    lines = []
    if path.is_file():
        lines = [l for l in path.read_text().splitlines()
                 if not l.startswith("export/android/android_sdk_path")
                 and not l.startswith("export/android/java_sdk_path")]
    if not lines:
        lines = ['[gd_resource type="EditorSettings" format=3]', "", "[resource]"]
    lines.append(f'export/android/android_sdk_path = "{env["sdk"]}"')
    lines.append(f'export/android/java_sdk_path = "{env["java"]}"')
    path.write_text("\n".join(lines) + "\n")


# --- export ----------------------------------------------------------------------------------

PRIVATE_PACK = GAME / "private_pack"


def _private_out(target: str) -> Path:
    return wslib.safe_path(OUTPUTS[target].replace("dist/", "dist-private/", 1))


def _write_private_pack() -> bool:
    """Coloca o conteúdo do jogo (ROM REV00 do usuário) em game/private_pack só durante a exportação privada."""
    rom = wslib.find_rom()
    if rom is None:
        print("BLOCKED: ROM ausente no workspace")
        return False
    data = rom.read_bytes()
    if wslib.sha256_file(rom) != REV00_SHA256:
        print("BLOCKED: ROM não é a REV00 verificada")
        return False
    PRIVATE_PACK.mkdir(exist_ok=True)
    (PRIVATE_PACK / "content.bin").write_bytes(data)
    return True


def _remove_private_pack() -> None:
    if PRIVATE_PACK.is_dir():
        shutil.rmtree(PRIVATE_PACK)


def export_private(target: str) -> int:
    """Build PRIVADO (dist-private/): inclui o conteúdo do jogo. Uso pessoal; nunca compartilhar/publicar."""
    if not _write_private_pack():
        set_status(f"{target}-private", "BLOCKED", "ROM REV00 ausente")
        return 2
    try:
        return export(target, private=True)
    finally:
        _remove_private_pack()


def export(target: str, private: bool = False) -> int:
    if not private:
        _remove_private_pack()  # build público nunca leva o pacote privado
    g = need_godot()
    if not (wslib.templates_dir() / "version.txt").is_file():
        set_status(target, "BLOCKED", "export templates ausentes (make bootstrap)")
        wslib.die("export templates ausentes: make bootstrap COMPONENTS=templates", 2)
    out = _private_out(target) if private else wslib.safe_path(OUTPUTS[target])
    out.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    mode = "--export-release"
    if target in ("android", "android-aab"):
        aenv, why = android_env()
        if aenv is None:
            set_status(target, "BLOCKED", why)
            print(f"BLOCKED: {why}")
            return 2
        write_editor_settings(aenv)
        if target == "android":
            ks = ensure_debug_keystore(aenv["java"])
            env.update({"GODOT_ANDROID_KEYSTORE_DEBUG_PATH": str(ks), "GODOT_ANDROID_KEYSTORE_DEBUG_USER": "androiddebugkey",
                        "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD": "android"})
            mode = "--export-debug"
        else:
            need = ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
                    "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]
            missing = [k for k in need if not os.environ.get(k)]
            if missing or not (GAME / "android" / "build").is_dir():
                why = ("AAB exige build Gradle (template Android instalado em game/android/build, com download de "
                       "dependências Gradle mediante aprovação) e keystore de release via variáveis: " + ", ".join(missing or ["(template ausente)"]))
                set_status(target, "BLOCKED", why)
                print(f"BLOCKED: {why}")
                return 2
    if target == "ios":
        if platform.system() != "Darwin" or not shutil.which("xcodebuild"):
            set_status(target, "BLOCKED", "exportação iOS requer macOS + Xcode")
            return 2
    wslib.godot_refresh()
    preset = PRESETS[target]
    cmd = [str(g), "--headless", "--path", str(GAME), mode, preset, str(out)]
    ios_note = ""
    if target == "ios":
        team = os.environ.get("IOS_TEAM_ID", "")
        if not team:
            # O Godot exige um Team ID até para exportar só o projeto Xcode. Sem Team ID real usamos um
            # marcador explícito: o projeto compila para o Simulator sem assinatura, mas NÃO gera IPA.
            team = "0000000000"
            ios_note = "Team ID marcador 0000000000 (sem assinatura); IPA exige IOS_TEAM_ID real + provisioning. "
        _patch_ios_team(team)
    log = wslib.safe_path(f"reports/build/{target}-export.log")
    rc = wslib.run(cmd, env=env, timeout=1800, log=log)
    if target == "ios":
        _patch_ios_team("")
    produced = _produced(target, out)
    key = f"{target}-private" if private else target
    if rc != 0 or not produced:
        set_status(key, "FAIL", f"exportação falhou (exit {rc}); ver {wslib.rel(log)}", " ".join(cmd))
        print(f"FAIL: {key} (exit {rc})")
        return 1
    if target == "web":
        _write_web_embed(out.parent)
        _write_web_hosting_configs(out.parent)
    if private:
        set_status(key, "BUILT_NOT_TESTED", "build PRIVADO com o conteúdo do jogo (uso pessoal; não compartilhar)",
                   f"make build-private-{target}", artifact_list(produced))
        print(f"BUILT_NOT_TESTED: {key}: " + ", ".join(wslib.rel(p) for p in produced))
        return 0
    leak = subprocess.call([sys.executable, "-I", str(wslib.safe_path("tooling/security_check.py")), "no-rom-in-dist"])
    if leak != 0:
        set_status(target, "FAIL", "verificação de conteúdo privado em dist falhou")
        return 1
    set_status(target, "BUILT_NOT_TESTED", (ios_note if target == "ios" else "") + "exportado; teste em dispositivo/host pendente",
               f"make build-{target}", artifact_list(produced))
    print(f"BUILT_NOT_TESTED: {target}: " + ", ".join(wslib.rel(p) for p in produced))
    return 0


EMBED_FILES = ["index.wasm", "index.pck", "index.audio.worklet.js", "index.audio.position.worklet.js"]


def _write_web_embed(d: Path = None) -> None:
    """Gera dist/web/index.embed.js (base64 do wasm/pck/worklets) para abrir index.html por file://.

    Por file:// o navegador bloqueia fetch/addModule; a página (head_include) carrega este script SOMENTE nesse caso
    e atende as requisições do carregador do Godot com os dados embutidos. Por HTTP nada muda.
    """
    import base64
    d = d or wslib.safe_path("dist/web")
    parts = []
    for n in EMBED_FILES:
        f = d / n
        if f.is_file():
            parts.append(json.dumps(n) + ":" + json.dumps(base64.b64encode(f.read_bytes()).decode("ascii")))
    (d / "index.embed.js").write_text("window.__GODOT_EMBED={" + ",".join(parts) + "};\n", encoding="ascii")
    wslib.info(f"index.embed.js gerado ({(d / 'index.embed.js').stat().st_size / 1e6:.1f} MB) para execução via file://")


WEB_CONFIG = """<?xml version="1.0" encoding="utf-8"?>
<!-- Azure App Service (Windows/IIS). Gerado por make build-web / make package-web-azure.
     Não usar <remove> em .wasm/.pck: se a extensão não existe no mapa pai, o IIS recusa
     o web.config (500.19) e o site mostra a mensagem genérica de permissão. -->
<configuration>
  <system.webServer>
    <defaultDocument enabled="true">
      <files>
        <clear />
        <add value="index.html" />
      </files>
    </defaultDocument>
    <directoryBrowse enabled="false" />
    <staticContent>
      <mimeMap fileExtension=".wasm" mimeType="application/wasm" />
      <mimeMap fileExtension=".pck" mimeType="application/octet-stream" />
    </staticContent>
    <security>
      <requestFiltering>
        <requestLimits maxAllowedContentLength="209715200" />
      </requestFiltering>
    </security>
  </system.webServer>
</configuration>
"""

SWA_CONFIG = {
    "navigationFallback": {"rewrite": "/index.html"},
    "mimeTypes": {".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "text/javascript"},
}


def _write_web_hosting_configs(d: Path = None) -> None:
    """web.config (Azure App Service Windows/IIS) e staticwebapp.config.json (Azure Static Web Apps)."""
    d = d or wslib.safe_path("dist/web")
    (d / "web.config").write_text(WEB_CONFIG, encoding="utf-8")
    (d / "staticwebapp.config.json").write_text(json.dumps(SWA_CONFIG, indent=2) + "\n", encoding="utf-8")
    wslib.info("web.config e staticwebapp.config.json gerados para hospedagem na Azure")


def _patch_ios_team(team: str) -> None:
    p = GAME / "export_presets.cfg"
    s = p.read_text()
    import re
    s = re.sub(r'application/app_store_team_id="[^"]*"', f'application/app_store_team_id="{team}"', s)
    p.write_text(s)


def _produced(target: str, out: Path = None) -> list:
    out = out or wslib.safe_path(OUTPUTS[target])
    d = out.parent
    if target == "macos":
        return [p for p in [out] if p.is_file()]
    if target == "windows":
        return [p for p in (d / "MegadrivePlatformerLab.exe", d / "MegadrivePlatformerLab.pck",
                            d / "MegadrivePlatformerLab.console.exe") if p.is_file()]
    if target == "web":
        return [p for p in sorted(d.iterdir()) if p.is_file()] if (d / "index.html").is_file() else []
    if target in ("android", "android-aab"):
        return [out] if out.is_file() else []
    if target == "ios":
        proj = list(d.glob("*.xcodeproj"))
        files = []
        for pj in proj:
            pbx = pj / "project.pbxproj"
            if pbx.is_file():
                files.append(pbx)
        pck = list(d.glob("*.pck"))
        return files + pck
    return []


# --- Web ---------------------------------------------------------------------------------------

def web_bundle() -> Path:
    """Pasta da Web jogável (19 fases). dist/web é só a Lab Zone, sem a ROM."""
    priv = wslib.safe_path("dist-private/web")
    if (priv / "index.html").is_file():
        return priv
    return wslib.safe_path("dist/web")


def web_mobile_check() -> int:
    d = web_bundle()
    report = {"timestamp": wslib.now_iso(), "checks": []}
    def chk(name, ok, detail=""):
        report["checks"].append({"check": name, "ok": bool(ok), "detail": detail})
        print(f"{'OK ' if ok else 'NOK'} {name} {detail}")
    if not (d / "index.html").is_file():
        print(f"{d} ausente: execute make build-web")
        return 2
    html = (d / "index.html").read_text(errors="replace")
    files = {p.name: p for p in d.iterdir()}
    wasm = [p for n, p in files.items() if n.endswith(".wasm")]
    pck = [p for n, p in files.items() if n.endswith(".pck")]
    chk("index.html presente", True)
    chk("WebAssembly presente", bool(wasm) and wasm[0].read_bytes()[:4] == b"\0asm", ", ".join(p.name for p in wasm))
    chk("PCK presente", bool(pck) and pck[0].read_bytes()[:4] == b"GDPC", ", ".join(p.name for p in pck))
    chk("viewport meta para mobile", "user-scalable=no" in html and "viewport-fit=cover" in html)
    chk("touch-action:none (sem rolagem/zoom por gesto)", "touch-action:none" in html)
    js = [p for n, p in files.items() if n.endswith(".js") and "worklet" not in n]
    jstext = js[0].read_text(errors="replace") if js else ""
    cfg = wslib.safe_path("game/export_presets.cfg").read_text()
    chk("build sem threads (não exige COOP/COEP/SharedArrayBuffer)", "variant/thread_support=false" in cfg)
    proj = wslib.safe_path("game/project.godot").read_text()
    chk("renderer Compatibility (WebGL 2)", 'renderer/rendering_method="gl_compatibility"' in proj)
    chk("compressão de textura para mobile (ETC2/ASTC)", "vram_texture_compression/for_mobile=true" in cfg)
    total = sum(p.stat().st_size for p in d.iterdir() if p.is_file())
    chk("tamanho total do bundle", True, f"{total/1e6:.1f} MB")
    report["note"] = ("Verificação estrutural. Carga real em Safari iOS e Chrome Android, multitoque e áudio "
                      "por gesto exigem aparelho físico: status BUILT_NOT_TESTED até sessão real.")
    wslib.write_json(wslib.safe_path("reports/qa/web-mobile-check.json"), report)
    ok = all(c["ok"] for c in report["checks"])
    st = load_status()
    for sub in ("web-ios-safari", "web-android-chrome"):
        if st.get(sub, {}).get("status") not in ("PASS", "FAIL"):
            set_status(sub, "BUILT_NOT_TESTED" if ok else "FAIL", report["note"], "make web-mobile-check")
    return 0 if ok else 1


class _Srv:
    def __init__(self, root: Path, port: int):
        import http.server
        import functools

        class H(http.server.SimpleHTTPRequestHandler):
            extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                              ".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "text/javascript"}

            def log_message(self, *a):
                pass
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(H, directory=str(root)))
        self.t = threading.Thread(target=self.httpd.serve_forever, daemon=True)

    def __enter__(self):
        self.t.start()
        return self

    def __exit__(self, *a):
        self.httpd.shutdown()


def test_web() -> int:
    d = web_bundle()
    if not (d / "index.html").is_file():
        print(f"{d} ausente: execute make build-web")
        set_status("web-desktop", "BLOCKED", "build web ausente")
        return 2
    port = 8761
    results = []
    with _Srv(d, port):
        time.sleep(0.3)
        for p in sorted(d.iterdir()):
            if not p.is_file():
                continue
            url = f"http://127.0.0.1:{port}/{p.name}"
            try:
                with urllib.request.urlopen(url, timeout=10) as r:  # nosec - servidor local
                    body = r.read()
                    results.append({"file": p.name, "status": r.status, "type": r.headers.get("Content-Type"),
                                    "bytes": len(body), "match": len(body) == p.stat().st_size})
            except Exception as e:  # noqa: BLE001
                results.append({"file": p.name, "error": str(e)})
    ok = all(r.get("status") == 200 and r.get("match") for r in results)
    wasm_ok = any(r["file"].endswith(".wasm") and r.get("type") == "application/wasm" for r in results)
    for r in results:
        print(r)
    rep = {"timestamp": wslib.now_iso(), "http_results": results, "ok": ok and wasm_ok,
           "note": "Smoke HTTP local. Execução no navegador (WebGL2/teclado) registrada em docs/qa quando realizada."}
    wslib.write_json(wslib.safe_path("reports/qa/test-web.json"), rep)
    st = load_status().get("web-desktop", {})
    if st.get("status") != "PASS":
        set_status("web-desktop", "BUILT_NOT_TESTED" if rep["ok"] else "FAIL",
                   "HTTP local OK; teste em navegador pendente/registrado separadamente", "make test-web")
    return 0 if rep["ok"] else 1


# --- Android --------------------------------------------------------------------------------------

def _adb() -> str:
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ""
    p = Path(sdk, "platform-tools", "adb")
    return str(p) if p.is_file() else (shutil.which("adb") or "")


def android_install(device: str = "") -> int:
    adb = _adb()
    apk = wslib.safe_path(OUTPUTS["android"])
    if not adb:
        print("BLOCKED: adb não encontrado (ANDROID_HOME)")
        return 2
    if not apk.is_file():
        print("APK ausente: make build-android")
        return 2
    devs = [l.split()[0] for l in subprocess.run([adb, "devices"], capture_output=True, text=True).stdout.splitlines()[1:]
            if l.strip().endswith("device")]
    if not devs:
        print("BLOCKED: nenhum aparelho/emulador Android conectado")
        set_status("android", load_status().get("android", {}).get("status", "BUILT_NOT_TESTED"),
                   "sem aparelho/emulador para instalar")
        return 2
    dev = device or devs[0]
    return subprocess.call([adb, "-s", dev, "install", "-r", str(apk)])


def test_android(device: str = "") -> int:
    rc = android_install(device)
    if rc != 0:
        return rc
    adb = _adb()
    dev = device or [l.split()[0] for l in subprocess.run([adb, "devices"], capture_output=True, text=True).stdout.splitlines()[1:] if l.strip().endswith("device")][0]
    subprocess.call([adb, "-s", dev, "shell", "monkey", "-p", "org.local.research.soniclike", "1"])
    time.sleep(6)
    pid = subprocess.run([adb, "-s", dev, "shell", "pidof", "org.local.research.soniclike"], capture_output=True, text=True).stdout.strip()
    shot = wslib.ensure_dir("reports", "qa") / "android-screen.png"
    with open(shot, "wb") as f:
        subprocess.call([adb, "-s", dev, "exec-out", "screencap", "-p"], stdout=f)
    ok = bool(pid)
    set_status("android", "PASS" if ok else "FAIL", f"instalado e iniciado em {dev}; pid={pid}; toque real pendente",
               "make test-android", artifact_list([OUTPUTS["android"]]))
    return 0 if ok else 1


# --- iOS -------------------------------------------------------------------------------------------

def ios_xcode() -> int:
    d = wslib.safe_path("dist/ios")
    proj = list(d.glob("*.xcodeproj"))
    if not proj:
        print("projeto Xcode ausente: make build-ios")
        return 2
    derived = wslib.ensure_dir("work", "ios-derived")
    log = wslib.safe_path("reports/build/ios-xcodebuild.log")
    cmd = ["xcodebuild", "-project", str(proj[0]), "-scheme", proj[0].stem, "-configuration", "Debug",
           "-sdk", "iphonesimulator", "-derivedDataPath", str(derived), "CODE_SIGNING_ALLOWED=NO",
           # o template oficial traz a fatia de Simulator só em x86_64 (verificado com lipo): roda via Rosetta
           "CODE_SIGNING_REQUIRED=NO", "ARCHS=x86_64", "ONLY_ACTIVE_ARCH=NO", "build"]
    rc = wslib.run(cmd, timeout=3600, log=log)
    apps = list(derived.glob("Build/Products/Debug-iphonesimulator/*.app"))
    if rc == 0 and apps:
        st = load_status().get("ios", {})
        set_status("ios", "BUILT_NOT_TESTED", f"projeto Xcode compilado para Simulator ({apps[0].name}); "
                   "IPA para aparelho exige Team ID/provisioning", "make ios-xcode", st.get("artifacts", []))
        return 0
    set_status("ios", "FAIL", f"xcodebuild falhou (exit {rc}); ver {wslib.rel(log)}", "make ios-xcode")
    return 1


def ios_archive() -> int:
    team = os.environ.get("IOS_TEAM_ID", "")
    prof = os.environ.get("IOS_PROVISIONING_UUID", "")
    if not team or not prof:
        print("BLOCKED: ios-archive exige IOS_TEAM_ID e IOS_PROVISIONING_UUID (perfil e certificado válidos no "
              "keychain do usuário). Nenhuma assinatura é simulada.")
        set_status("ios-ipa", "BLOCKED", "sem Team ID/provisioning")
        return 2
    d = wslib.safe_path("dist/ios")
    proj = list(d.glob("*.xcodeproj"))
    if not proj:
        print("projeto Xcode ausente: make build-ios")
        return 2
    archive = wslib.ensure_dir("work", "ios-archive") / "MegadrivePlatformerLab.xcarchive"
    rc = wslib.run(["xcodebuild", "-project", str(proj[0]), "-scheme", proj[0].stem, "-configuration", "Release",
                    "-archivePath", str(archive), f"DEVELOPMENT_TEAM={team}", f"PROVISIONING_PROFILE_SPECIFIER={prof}",
                    "archive"], timeout=3600, log=wslib.safe_path("reports/build/ios-archive.log"))
    set_status("ios-ipa", "BUILT_NOT_TESTED" if rc == 0 else "FAIL", "archive gerado" if rc == 0 else "archive falhou")
    return 0 if rc == 0 else 1


def test_ios() -> int:
    derived = wslib.safe_path("work/ios-derived")
    apps = list(derived.glob("Build/Products/Debug-iphonesimulator/*.app"))
    if not apps:
        print("app de Simulator ausente: make ios-xcode")
        return 2
    sims = json.loads(subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"],
                                     capture_output=True, text=True).stdout or "{}")
    booted = [d for rt in sims.get("devices", {}).values() for d in rt if d.get("state") == "Booted"]
    if not booted:
        print("BLOCKED: nenhum Simulator iOS iniciado (abra um Simulator e repita)")
        return 2
    udid = booted[0]["udid"]
    inst = subprocess.run(["xcrun", "simctl", "install", udid, str(apps[0])], capture_output=True, text=True)
    if inst.returncode != 0:
        why = inst.stderr.strip().splitlines()[1] if len(inst.stderr.strip().splitlines()) > 1 else inst.stderr.strip()
        print("BLOCKED: instalação no Simulator falhou: " + why)
        set_status("ios-simulator", "BLOCKED",
                   "Simulator recusou o app: o template iOS oficial do Godot 4.7.2 só traz fatia x86_64 para Simulator "
                   "e o Simulator do iOS 27 não executa x86_64. Requer template com arm64-simulator ou aparelho físico.",
                   "make test-ios")
        return 2
    lau = subprocess.run(["xcrun", "simctl", "launch", udid, "org.local.research.soniclike"], capture_output=True, text=True)
    if lau.returncode != 0:
        set_status("ios-simulator", "FAIL", "launch falhou: " + lau.stderr.strip()[:200], "make test-ios")
        return 1
    time.sleep(8)
    shot = wslib.ensure_dir("reports", "qa") / "ios-simulator.png"
    subprocess.call(["xcrun", "simctl", "io", udid, "screenshot", str(shot)])
    ok = shot.is_file() and shot.stat().st_size > 1000
    set_status("ios-simulator", "PASS" if ok else "FAIL",
               f"instalado e iniciado no Simulator {booted[0].get('name')}; aparelho físico pendente", "make test-ios")
    return 0 if ok else 1


# --- macOS ------------------------------------------------------------------------------------------

def test_macos() -> int:
    z = _private_out("macos")
    if not z.is_file():
        z = wslib.safe_path(OUTPUTS["macos"])
    if not z.is_file():
        print("zip macOS ausente: make build-macos")
        return 2
    if platform.system() != "Darwin":
        print("BLOCKED: requer host macOS")
        return 2
    dest = wslib.safe_path("work/macos-smoke")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    subprocess.run(["ditto", "-x", "-k", str(z), str(dest)], check=True)
    apps = list(dest.glob("*.app"))
    exe = next(iter((apps[0] / "Contents" / "MacOS").iterdir()))
    shot = wslib.ensure_dir("reports", "qa") / "macos-smoke.png"
    replay = wslib.safe_path("tests/platform/smoke_run.json")
    cp = subprocess.run([str(exe), "--", "--level=lab1", f"--autoplay={replay}", "--quit-after=240",
                         f"--screenshot={shot}"], capture_output=True, text=True, timeout=180)
    line = next((l for l in cp.stdout.splitlines() if l.startswith("smoke:")), "")
    print(line or cp.stdout[-800:])
    ok = cp.returncode == 0 and line != "" and shot.is_file()
    set_status("macos", "PASS" if ok else "FAIL",
               f"app exportado executado no host ({platform.mac_ver()[0]}, {platform.machine()}): {line}",
               "make test-macos", load_status().get("macos", {}).get("artifacts", []))
    return 0 if ok else 1


# --- agregados -------------------------------------------------------------------------------------

def build_supported() -> int:
    results = {}
    for t in ["macos", "windows", "web", "android", "ios"]:
        rc = export_private(t)
        results[t] = rc
    blocked = [t for t, rc in results.items() if rc == 2]
    failed = [t for t, rc in results.items() if rc == 1]
    print("\nResumo build-supported:")
    for t, rc in results.items():
        print(f"  {t}: {'OK (BUILT_NOT_TESTED)' if rc == 0 else ('BLOCKED' if rc == 2 else 'FAIL')}")
    wslib.write_json(wslib.safe_path("reports/build/build-supported.json"),
                     {"timestamp": wslib.now_iso(), "results": results, "blocked": blocked, "failed": failed})
    return 1 if failed else 0


def build_private_supported() -> int:
    results = {t: export_private(t) for t in ["macos", "windows", "web", "android", "ios"]}
    print("\nResumo build-private-supported (dist-private/, USO PESSOAL):")
    for t, rc in results.items():
        print(f"  {t}: {'OK (BUILT_NOT_TESTED)' if rc == 0 else ('BLOCKED' if rc == 2 else 'FAIL')}")
    return 1 if any(rc == 1 for rc in results.values()) else 0


def build_all() -> int:
    build_supported()
    st = load_status()
    missing = [t for t in REQUIRED if st.get(t, {}).get("status") not in ("BUILT_NOT_TESTED", "PASS")]
    if missing:
        print("build-all FALHOU: destinos não produzidos: " + ", ".join(missing))
        return 1
    print("build-all: os 5 destinos foram produzidos (não significa testados).")
    return 0


def package_web_azure() -> int:
    """dist-private/web-azure.zip: arquivos de dist-private/web com index.html NA RAIZ do zip.

    O zip fica fora de dist/ (check-no-rom-in-dist não varre dist-private/). Contém as 19 fases:
    publicar só num site privado (autenticação ou restrição por IP). index.embed.js fica de fora.
    O erro do IIS "You do not have permission..." aparece se o zip aninha uma pasta (web/index.html)
    ou se o web.config faz <remove> de um MIME que o IIS ainda não tem.
    """
    import zipfile
    d = wslib.safe_path("dist-private/web")
    if not (d / "index.html").is_file():
        print("FAIL: dist-private/web/index.html ausente (rode make build-web)")
        return 1
    _write_web_hosting_configs(d)
    out = wslib.safe_path("dist-private/web-azure.zip")
    names = []
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(d.iterdir()):
            if not f.is_file() or f.is_symlink() or f.name == "index.embed.js":
                continue
            if f.suffix.lower() in (".md", ".bin", ".gen", ".smd"):
                print(f"FAIL: arquivo solto suspeito em dist-private/web: {f.name}")
                return 1
            z.write(f, f.name)
            names.append(f.name)
    required = ["index.html", "index.js", "index.wasm", "index.pck", "web.config"]
    missing = [n for n in required if n not in names]
    if missing:
        print("FAIL: faltam no pacote: " + ", ".join(missing))
        return 1
    print(f"OK: {wslib.rel(out)} ({out.stat().st_size / 1e6:.1f} MB) sha256={wslib.sha256_file(out)}")
    print("    raiz do zip: " + ", ".join(names))
    print("    uso pessoal: site privado (Entra ID / restrição por IP). Não publicar em aberto.")
    print("    publicar: az webapp deploy --resource-group <grupo> --name <app> "
          "--src-path dist-private/web-azure.zip --type zip")
    print("    App Service Windows. No Linux o web.config é ignorado;")
    print("    use: pm2 serve /home/site/wwwroot --no-daemon")
    return 0


def web_azure_check(url: str) -> int:
    """Diagnostica um site publicado (URL informada pelo usuário): raiz, index.html, tipos MIME do wasm/pck."""
    import urllib.error
    import urllib.request
    if not url.startswith("https://") and not url.startswith("http://"):
        print("uso: make web-azure-check URL=https://<app>.azurewebsites.net/")
        return 2
    base = url if url.endswith("/") else url + "/"

    def get(path, method="GET"):
        req = urllib.request.Request(base + path, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                body = r.read(4096) if method == "GET" else b""
                return r.status, r.headers.get("Content-Type", ""), body
        except urllib.error.HTTPError as e:
            return e.code, e.headers.get("Content-Type", ""), e.read(4096)
        except Exception as e:  # noqa: BLE001
            return 0, str(e), b""

    ok = True
    root = get("")
    idx = get("index.html")
    print(f"/            -> {root[0]} {root[1]}")
    print(f"/index.html  -> {idx[0]} {idx[1]}")
    if idx[0] != 200:
        ok = False
        print("  ! index.html não está na raiz do site: publique dist-private/web-azure.zip (make package-web-azure)")
    elif root[0] != 200:
        ok = False
        print("  ! raiz sem documento padrão: falta web.config (Windows) ou o site é Linux (ver docs/platforms/web-desktop.md)")
    for name, want in (("index.wasm", "application/wasm"), ("index.pck", ""), ("index.js", "javascript")):
        st, ct, _ = get(name, "HEAD")
        print(f"/{name:<11} -> {st} {ct}")
        if st != 200 or (want and want not in ct):
            ok = False
            print(f"  ! {name}: esperado 200" + (f" com {want}" if want else ""))
    print("RESULTADO: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main(argv):
    if not argv:
        wslib.die("uso: godot_tasks.py <comando> [arg]")
    cmd, arg = argv[0], (argv[1] if len(argv) > 1 else "")
    table = {
        "run": lambda: run(arg or "fidelity"),
        "export": lambda: export(arg),
        "export-private": lambda: export_private(arg),
        "build-private-supported": build_private_supported,
        "web-mobile-check": web_mobile_check,
        "test-web": test_web,
        "android-install": lambda: android_install(arg),
        "test-android": lambda: test_android(arg),
        "ios-xcode": ios_xcode,
        "ios-archive": ios_archive,
        "test-ios": test_ios,
        "test-macos": test_macos,
        "build-supported": build_supported,
        "build-all": build_all,
        "package-web-azure": package_web_azure,
        "web-azure-check": lambda: web_azure_check(arg),
    }
    if cmd not in table:
        wslib.die(f"comando desconhecido: {cmd}")
    sys.exit(table[cmd]())


if __name__ == "__main__":
    main(sys.argv[1:])
