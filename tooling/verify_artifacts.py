"""make verify-artifacts — verifica formato/estrutura real dos artefatos em dist/ (não confunde com teste).

Checa magic numbers e estrutura: .app (Mach-O) dentro do zip, PE do Windows + PCK, Web (HTML/JS/WASM/PCK),
APK (manifesto, dex, libs, assinatura v2+), projeto Xcode (pbxproj + pck) e IPA quando existir.
Saída: reports/build/artifacts.json. Exit 1 se algum artefato presente estiver malformado; ausentes = NOT_BUILT.
"""
from __future__ import annotations

import struct
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

MIN_SIZE = 100_000
MACHO = {b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xce\xfa\xed\xfe"}


def check_macos(res):
    z = wslib.safe_path("dist/macos/MegadrivePlatformerLab.zip")
    if not z.is_file():
        return "NOT_BUILT"
    with zipfile.ZipFile(z) as zf:
        names = zf.namelist()
        exe = [n for n in names if ".app/Contents/MacOS/" in n and not n.endswith("/")]
        plist = [n for n in names if n.endswith(".app/Contents/Info.plist")]
        res["entries"] = len(names)
        if not exe or not plist:
            res["error"] = "bundle .app incompleto"
            return "MALFORMED"
        head = zf.read(exe[0])[:4]
        res["macho_magic"] = head.hex()
        info = zf.read(plist[0]).decode(errors="replace")
        res["bundle_id_ok"] = "org.local.research.soniclike" in info
        if head not in MACHO or not res["bundle_id_ok"]:
            return "MALFORMED"
    res["files"] = [{"path": wslib.rel(z), "size": z.stat().st_size, "sha256": wslib.sha256_file(z)}]
    return "OK" if z.stat().st_size > MIN_SIZE else "MALFORMED"


def check_windows(res):
    exe = wslib.safe_path("dist/windows/MegadrivePlatformerLab.exe")
    pck = wslib.safe_path("dist/windows/MegadrivePlatformerLab.pck")
    if not exe.is_file():
        return "NOT_BUILT"
    data = exe.read_bytes()[:4096]
    ok = data[:2] == b"MZ"
    if ok:
        off = struct.unpack("<I", data[0x3C:0x40])[0]
        full = exe.read_bytes()[off:off + 6]
        ok = full[:4] == b"PE\0\0"
        res["machine"] = hex(struct.unpack("<H", full[4:6])[0])
    pck_ok = pck.is_file() and pck.read_bytes()[:4] == b"GDPC"
    res["pe_ok"], res["pck_ok"] = ok, pck_ok
    res["files"] = [{"path": wslib.rel(p), "size": p.stat().st_size, "sha256": wslib.sha256_file(p)} for p in (exe, pck) if p.is_file()]
    return "OK" if ok and pck_ok and exe.stat().st_size > MIN_SIZE else "MALFORMED"


def check_web(res):
    d = wslib.safe_path("dist/web")
    if not (d / "index.html").is_file():
        return "NOT_BUILT"
    wasm = d / "index.wasm"
    pck = d / "index.pck"
    js = d / "index.js"
    res["wasm_ok"] = wasm.is_file() and wasm.read_bytes()[:4] == b"\0asm"
    res["pck_ok"] = pck.is_file() and pck.read_bytes()[:4] == b"GDPC"
    res["js_ok"] = js.is_file() and js.stat().st_size > 10_000
    emb = d / "index.embed.js"
    res["file_protocol_embed"] = emb.is_file() and emb.read_bytes()[:22] == b"window.__GODOT_EMBED={"
    res["file_protocol_loader"] = "index.embed.js" in (d / "index.html").read_text(errors="replace")
    res["files"] = [{"path": wslib.rel(p), "size": p.stat().st_size, "sha256": wslib.sha256_file(p)}
                    for p in sorted(d.iterdir()) if p.is_file()]
    ok = res["wasm_ok"] and res["pck_ok"] and res["js_ok"] and res["file_protocol_embed"] and res["file_protocol_loader"]
    return "OK" if ok else "MALFORMED"


def check_android(res):
    apk = wslib.safe_path("dist/android/MegadrivePlatformerLab-debug.apk")
    if not apk.is_file():
        return "NOT_BUILT"
    with zipfile.ZipFile(apk) as z:
        names = set(z.namelist())
    res["manifest"] = "AndroidManifest.xml" in names
    res["dex"] = any(n.endswith(".dex") for n in names)
    res["libs"] = sorted({n.split("/")[1] for n in names if n.startswith("lib/") and n.count("/") >= 2})
    res["game_assets"] = sum(1 for n in names if n.startswith("assets/"))
    raw = apk.read_bytes()
    res["signature_v2_block"] = b"APK Sig Block 42" in raw
    res["files"] = [{"path": wslib.rel(apk), "size": apk.stat().st_size, "sha256": wslib.sha256_file(apk)}]
    res["signing"] = "debug (keystore local de depuração); release exige keystore própria"
    ok = res["manifest"] and res["dex"] and "arm64-v8a" in res["libs"] and res["signature_v2_block"]
    return "OK" if ok else "MALFORMED"


def check_ios(res):
    d = wslib.safe_path("dist/ios")
    proj = list(d.glob("*.xcodeproj/project.pbxproj")) if d.is_dir() else []
    if not proj:
        return "NOT_BUILT"
    pck = list(d.glob("*.pck"))
    txt = proj[0].read_text(errors="replace")
    res["pbxproj_ok"] = "PBXProject" in txt and "org.local.research.soniclike" in txt
    res["pck_ok"] = bool(pck) and pck[0].read_bytes()[:4] == b"GDPC"
    res["xcframework"] = [p.name for p in d.glob("*.xcframework")]
    ipa = list(d.glob("*.ipa"))
    res["ipa"] = [p.name for p in ipa] or "não gerado (exige assinatura)"
    res["files"] = [{"path": wslib.rel(p), "size": p.stat().st_size, "sha256": wslib.sha256_file(p)} for p in proj + pck]
    return "OK" if res["pbxproj_ok"] and res["pck_ok"] else "MALFORMED"


def main():
    out = {"timestamp": wslib.now_iso(), "note": "Verificação estrutural; não implica teste de execução.", "targets": {}}
    bad = 0
    for name, fn in [("macos", check_macos), ("windows", check_windows), ("web", check_web),
                     ("android", check_android), ("ios", check_ios)]:
        res = {}
        try:
            st = fn(res)
        except Exception as e:  # noqa: BLE001
            st, res["error"] = "MALFORMED", str(e)
        res["result"] = st
        out["targets"][name] = res
        bad += st == "MALFORMED"
        print(f"{name:8s} {st}")
    wslib.write_json(wslib.safe_path("reports/build/artifacts.json"), out)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
