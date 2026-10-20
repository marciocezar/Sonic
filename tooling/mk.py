"""make help — lista alvos documentados (linhas `alvo: ## descrição` do Makefile)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402

if __name__ == "__main__":
    text = wslib.safe_path("Makefile").read_text(encoding="utf-8")
    print("sonic-megadrive — interface única (GNU Make). Uso: make <alvo> [VAR=valor]\n")
    for m in re.finditer(r"^([a-zA-Z0-9_-]+):[^\n#]*## (.*)$", text, re.M):
        print(f"  {m.group(1):22s} {m.group(2)}")
    print("\nVariáveis: PROFILE, COMPONENTS, PORT, DEVICE, REPLAY, TARGET, STATUS, NOTES, ANDROID_HOME, JAVA_HOME, IOS_TEAM_ID")
