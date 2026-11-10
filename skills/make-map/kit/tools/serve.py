"""Serve the pack to Roblox Studio on http://127.0.0.1:8777 (this computer only). Method by fwjelaa (FWJ STUDIOS).

    python kit/tools/run.py serve

MapKit's installer and MapKit.run fetch the kit and the map specs from here. Leave it running while building.
.secrets/, .git/ and *.key files are never served."""
import functools
import http.server
import os
import socket

PORT = 8777
PACK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NEVER = os.path.join(PACK, "__never__")


def blocked(real_path):
    real_path = os.path.realpath(real_path)
    try:
        rel = os.path.relpath(os.path.normcase(real_path), os.path.normcase(os.path.realpath(PACK)))
    except ValueError:  # another drive
        return True
    parts = rel.split(os.sep)
    return parts[0] == ".." or ".secrets" in parts or ".git" in parts or real_path.lower().endswith(".key")


class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        real = os.path.realpath(super().translate_path(path))
        return NEVER if blocked(real) else real

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass


class ExclusiveServer(http.server.ThreadingHTTPServer):
    # Measured on Windows: the default (address reuse on) lets a second `serve` bind the same port silently,
    # so Studio could be fed another copy of the pack. Exclusive bind makes the second one fail loudly.
    allow_reuse_address = False

    def server_bind(self):
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


def make_server(port=PORT):
    return ExclusiveServer(("127.0.0.1", port), functools.partial(Handler, directory=PACK))


def serve(port=PORT):
    try:
        httpd = make_server(port)
    except OSError:
        raise SystemExit(f"port {port} is in use: another `run.py serve` is probably running already (stop it first)")
    with httpd:
        print(f"Serving {PACK} to Studio on http://127.0.0.1:{port} (Ctrl+C to stop)", flush=True)
        httpd.serve_forever()
