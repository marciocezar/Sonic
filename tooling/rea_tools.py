"""make rea-check | ghidra-analyze | rea-analyze

- REA (rea-agents, instalado localmente em tooling/rea) roda SEMPRE dentro do sandbox-exec,
  com HOME isolado em work/rea-home. Decisão do usuário (2026-10-18): não executar REA fora do
  sandbox. Como o lançador de processos do REA falha com EPERM ao iniciar o Java sob sandbox,
  a análise profunda via provider Ghidra fica BLOQUEADA e isso é registrado honestamente.
- Ghidra headless roda dentro do sandbox (sem rede, escrita só em work/ghidra*).
- Somente uma cópia somente-leitura da ROM deste jogo (work/rea/sonic.bin) é analisada.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import evidence  # noqa: E402
import sandbox  # noqa: E402
import wslib  # noqa: E402

REA_JS = "tooling/rea/node_modules/rea-agents/scripts/rea.mjs"


def ghidra_home() -> Path:
    lock = wslib.read_lock()
    return wslib.safe_path(f"tooling/ghidra/ghidra_{lock['ghidra.version']}_PUBLIC")


def java_home() -> str:
    env = os.environ.get("JAVA_HOME")
    if env:
        return env
    for v in ("25", "21"):
        cp = subprocess.run(["/usr/libexec/java_home", "-v", v], capture_output=True, text=True)
        if cp.returncode == 0:
            return cp.stdout.strip()
    return ""


def rom_copy() -> Path:
    rom = wslib.require_rom()
    d = wslib.ensure_dir("work", "rea")
    dst = d / "sonic.bin"
    if not dst.exists() or wslib.sha256_file(dst) != wslib.sha256_file(rom):
        if dst.exists():
            os.chmod(dst, 0o644)
            dst.unlink()
        shutil.copyfile(rom, dst)
        os.chmod(dst, 0o444)
    return dst


def rea_cmd(args):
    node = wslib.which("node")
    if not node:
        return None
    env = {"HOME": str(wslib.ensure_dir("work", "rea-home")), "GHIDRA_INSTALL_DIR": str(ghidra_home()),
           "JAVA_HOME": java_home(), "NO_COLOR": "1"}
    cmd = sandbox.wrap([node, str(wslib.safe_path(REA_JS))] + args,
                       [wslib.safe_path("work/rea"), wslib.safe_path("work/rea-home")], "rea")
    return cmd, env


def run_rea(args, timeout=600):
    rc = rea_cmd(args)
    if rc is None or rc[0] is None:
        return None, "node ou sandbox-exec ausente"
    cmd, env = rc
    e = dict(os.environ)
    e.update(env)
    cp = subprocess.run(cmd, capture_output=True, text=True, env=e, timeout=timeout)
    return cp, None


def check():
    ok = True
    p = wslib.safe_path(REA_JS)
    if not p.is_file():
        print("REA: AUSENTE (rode `make bootstrap COMPONENTS=rea`)")
        return 2
    cp, err = run_rea(["--version"])
    print("REA versão:", (cp.stdout.strip() if cp else err))
    cp, err = run_rea(["doctor", "--provider", "ghidra", "--format", "json"])
    report = {"timestamp": wslib.now_iso(), "sandbox": sandbox.available()}
    if cp is not None:
        try:
            d = json.loads(cp.stdout)
            checks = {c["name"]: {"ok": c["ok"], "detail": c.get("detail", "")} for c in d.get("scope_checks", [])}
        except json.JSONDecodeError:
            checks = {"parse_error": {"ok": False, "detail": cp.stdout[:500]}}
        report["doctor"] = checks
        for k, v in checks.items():
            print(f"  {'OK ' if v['ok'] else 'NOK'} {k}: {str(v['detail'])[:120]}")
        ok = all(v["ok"] for k, v in checks.items() if k.startswith("ghidra"))
    gh = ghidra_home()
    natives = gh / "Ghidra/Features/Decompiler/os/mac_arm_64/decompile"
    report["ghidra_installed"] = (gh / "support/analyzeHeadless").is_file()
    report["ghidra_native_decompiler"] = natives.is_file()
    report["java_home"] = java_home()
    print("Ghidra headless:", report["ghidra_installed"], "| decompilador nativo:", report["ghidra_native_decompiler"])
    wslib.write_json(wslib.safe_path("reports/analysis/rea-check.json"), report)
    if not ok:
        print("REA provider Ghidra: NÃO PRONTO sob sandbox (ver reports/analysis/rea-check.json).")
        print("Política: REA não roda fora do sandbox (decisão do usuário). Alternativa: make ghidra-analyze.")
    return 0  # check informa; não falha o fluxo


def ghidra():
    gh = ghidra_home()
    head = gh / "support" / "analyzeHeadless"
    if not head.is_file():
        wslib.die("Ghidra ausente: make bootstrap COMPONENTS=ghidra", 2)
    rom = rom_copy()
    proj = wslib.ensure_dir("work", "ghidra-proj")
    ghome = wslib.ensure_dir("work", "ghidra-home")
    out = wslib.ensure_dir("private", "extracted", "ghidra")
    # projeto descartável: recria para idempotência
    for f in proj.iterdir():
        if f.is_dir():
            shutil.rmtree(f)
        else:
            f.unlink()
    # sementes: PCs executados nos traces + destinos de tabelas de salto (rotinas de objetos nunca executadas)
    import static_seeds
    seed_file = out / "seeds.txt"
    n_static = static_seeds.write_seed_file(rom.read_bytes(), wslib.safe_path("private/extracted/coverage_pcs.txt"), seed_file)
    wslib.info(f"sementes estáticas (tabelas de salto): {n_static}")
    cmd = [str(head), str(proj), "sonic", "-import", str(rom),
           "-loader", "BinaryLoader", "-loader-baseAddr", "0x0",
           "-processor", "68000:BE:32:default",
           "-scriptPath", str(wslib.safe_path("tooling/ghidra_scripts")),
           "-preScript", "SonicSeedEntries.java", str(seed_file),
           "-postScript", "SonicExport.java", str(out),
           "-max-cpu", "4"]
    wrapped = sandbox.wrap(cmd, [proj, ghome, out, wslib.safe_path("work/sandbox")], "ghidra")
    if wrapped is None:
        wslib.die("sandbox indisponível neste SO; Ghidra não será executado sem isolamento", 2)
    env = {"HOME": str(ghome), "JAVA_HOME": java_home(), "MAXMEM": "3G",
           "_JAVA_OPTIONS": f"-Duser.home={ghome}"}
    log = wslib.safe_path("work/ghidra-proj/headless.log")
    rc = wslib.run(wrapped, env=env, timeout=1800, log=log)
    funcs = out / "ghidra-functions.csv"
    summary = {"timestamp": wslib.now_iso(), "exit_code": rc, "processor": "68000:BE:32:default",
               "loader": "BinaryLoader base 0x0", "sandbox": True}
    if funcs.is_file():
        lines = funcs.read_text().splitlines()[1:]
        summary["functions"] = len(lines)
        listing = out / "ghidra-listing.txt"
        summary["instructions"] = sum(1 for _ in open(listing)) if listing.is_file() else 0
    wslib.write_json(wslib.safe_path("reports/analysis/ghidra-summary.json"), summary)
    print(json.dumps(summary, indent=2))
    return 0 if rc == 0 and funcs.is_file() else 1


def analyze():
    rom = wslib.require_rom()
    sha = wslib.sha256_file(rom)
    ev = evidence.Collector("EV-REA", sha, "REA 6.7.0 (tooling/rea, sandbox-exec)")
    copy = rom_copy()
    results = {"timestamp": wslib.now_iso(), "rea": {}, "ghidra": None}
    # 1) REA inspect-artifact (sem provider): detecção de formato
    cp, err = run_rea(["inspect-artifact", str(copy), "--format", "json"])
    if cp is not None:
        results["rea"]["inspect_artifact"] = {"exit": cp.returncode, "stdout": cp.stdout[:2000]}
        try:
            msg = json.loads(cp.stdout).get("message", "")
        except json.JSONDecodeError:
            msg = cp.stdout[:200]
        ev.add("ferramenta", "work/rea/sonic.bin", f"REA inspect-artifact sobre a ROM: exit={cp.returncode}; '{msg}'",
               "CONFIRMADO_BINARIO", "alta",
               "REA não reconhece ROM Mega Drive bruta por cabeçalho; exige --target-format raw-binary + provider")
    # 2) REA analyze raw-binary m68k (precisa de provider Ghidra/Hopper/IDA)
    cp, err = run_rea(["analyze", str(copy), "--target-format", "raw-binary", "--architecture", "m68k",
                       "--entry-point", "0x0", "--format", "json"], timeout=900)
    if cp is not None:
        status = "ok" if cp.returncode == 0 else "falhou"
        results["rea"]["analyze_raw_m68k"] = {"exit": cp.returncode, "stdout": cp.stdout[:4000]}
        reason = ""
        try:
            d = json.loads(cp.stdout)
            rej = d.get("details", {}).get("rejections", [])
            reason = "; ".join(f"{r.get('provider_id')}:{r.get('code')}" for r in rej)[:300]
        except json.JSONDecodeError:
            pass
        ev.add("ferramenta", "work/rea/sonic.bin",
               f"REA analyze --target-format raw-binary --architecture m68k: {status} ({reason})",
               "BLOQUEADO" if cp.returncode else "CONFIRMADO_BINARIO", "alta",
               "provider Ghidra rejeitado sob sandbox (java spawn EPERM); usuário negou execução sem sandbox")
    # 3) Ghidra headless direto (complementar)
    rc = ghidra()
    summ = json.loads(wslib.safe_path("reports/analysis/ghidra-summary.json").read_text())
    results["ghidra"] = summ
    if rc == 0:
        ev.add("ferramenta", "0x000000-0x07FFFF",
               f"Ghidra 12.1.4 headless (68000:BE:32, BinaryLoader, vetores semeados) recuperou {summ.get('functions')} funções e {summ.get('instructions')} instruções",
               "CONFIRMADO_BINARIO", "media",
               "auto-análise do Ghidra; fronteiras de função não verificadas manualmente; sem descompilação")
    else:
        ev.add("ferramenta", "-", "Ghidra headless falhou", "BLOQUEADO", "alta", "ver work/ghidra-proj/headless.log")
    evidence.replace_source("rea_tools", ev.rows)
    wslib.write_json(wslib.safe_path("reports/analysis/rea-analyze.json"), results)
    print("relatório: reports/analysis/rea-analyze.json")
    return 0 if rc == 0 else 1


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    sys.exit({"check": check, "ghidra": ghidra, "analyze": analyze}[cmd]())
