"""make web-serve — serve dist/web em http://127.0.0.1:PORT (somente local), com tipos MIME corretos.

Build Web sem threads: não exige COOP/COEP. Os cabeçalhos são enviados mesmo assim para permitir
testar variantes com threads. Ctrl+C encerra.
"""
from __future__ import annotations

import functools
import http.server
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wslib  # noqa: E402


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "text/javascript"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main(argv):
    nums = [a for a in argv if a.isdigit()]
    port = int(nums[0]) if nums else 8060
    root = wslib.safe_path("dist-private/web" if "--private" in argv else "dist/web")
    if not (root / "index.html").is_file():
        wslib.die(f"{wslib.rel(root)} ausente: execute make build-web (ou make build-private-web)", 2)
    bind = "0.0.0.0" if "--lan" in argv else "127.0.0.1"
    srv = http.server.ThreadingHTTPServer((bind, port), functools.partial(Handler, directory=str(root)))
    wslib.info(f"servindo {wslib.rel(root)} em http://{bind}:{port}/ (Ctrl+C para sair)")
    if "--open" in argv:
        import threading
        import webbrowser
        threading.Timer(0.5, lambda: webbrowser.open(f"http://127.0.0.1:{port}/")).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main(sys.argv[1:])
