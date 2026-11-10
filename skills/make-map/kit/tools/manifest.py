"""assets.json read-modify-write that two run.py commands can do at once. Method by fwjelaa (FWJ STUDIOS).

Measured 2026-10-25: `run.py sky` writing while a model batch ran erased two models' ids, and a reader could catch
the file half-written. Every writer goes through update(): an exclusive lock file, a fresh read, the change, a temp
file and an atomic replace, so readers (Studio through `serve`) always see a whole file."""
import json
import os
import time
from pathlib import Path

STALE_SECONDS = 120  # a lock this old belongs to a run that crashed


def _lock(lock, timeout):
    t0 = time.monotonic()
    while True:
        try:
            return os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except (FileExistsError, PermissionError):  # Windows says PermissionError while the holder deletes it
            try:
                if time.time() - lock.stat().st_mtime > STALE_SECONDS:
                    lock.unlink()
                    continue
            except (FileNotFoundError, PermissionError):
                pass
            if time.monotonic() - t0 > timeout:
                raise SystemExit(f"{lock} is held by another run.py command; if none is running, delete the file")
            time.sleep(0.02)


def _replace(tmp, path):
    for _ in range(50):  # Windows refuses while another process has the file open for a moment (serve reading it)
        try:
            os.replace(tmp, path)
            return
        except PermissionError:
            time.sleep(0.02)
    os.replace(tmp, path)


def update(path, fn, timeout=60):
    """Lock, read path (a missing file is {}), call fn(data) to change it in place, write it back; returns fn's result."""
    path = Path(path)
    lock = path.with_name(path.name + ".lock")
    fd = _lock(lock, timeout)
    try:
        os.close(fd)
        data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        result = fn(data)
        tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
        tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        _replace(tmp, path)
        return result
    finally:
        try:
            lock.unlink()
        except FileNotFoundError:
            pass
