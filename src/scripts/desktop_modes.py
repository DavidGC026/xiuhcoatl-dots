#!/usr/bin/env python3
"""A logind inhibitor scoped to a Quickshell pipe, never to saved settings.

Quickshell runs ``desktop_modes.py inhibit`` with stdin enabled. Closing that
pipe, sending SIGTERM, or losing the caller releases the inhibitor. The lease
also monitors this supervisor so SIGKILL cannot leave a sleeping orphan behind.
Only the child started *after* systemd-inhibit acquires its FD reports ready.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time


def emit(**data: object) -> None:
    print(json.dumps(data, ensure_ascii=False), flush=True)


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        # An unreaped dead parent also no longer owns an active presentation.
        return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0] != "Z"
    except (ProcessLookupError, FileNotFoundError):
        return False
    except PermissionError:
        return True


def lease(owner: int) -> int:
    # The logind FD belongs to systemd-inhibit and this child. Exiting closes it.
    emit(ready=True)
    while alive(owner):
        time.sleep(0.2)
    return 0


def supervise(inhibitor: str = "systemd-inhibit") -> int:
    owner = os.getppid()
    stopping = False

    def stop(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGHUP, stop)
    # Linux sends SIGTERM when QProcess dies, including on a shell crash.
    ctypes.CDLL(None).prctl(1, signal.SIGTERM, 0, 0, 0)
    if os.getppid() != owner:
        return 0

    command = [inhibitor, "--what=idle:sleep", "--mode=block", "--who=Xiuhcóatl",
               "--why=Modo presentación", "--", sys.executable, str(Path(__file__).resolve()),
               "_lease", str(os.getpid())]
    child: subprocess.Popen[bytes] | None = None
    try:
        child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, start_new_session=True)
        selector = selectors.DefaultSelector()
        selector.register(sys.stdin.buffer, selectors.EVENT_READ, "owner")
        selector.register(child.stdout, selectors.EVENT_READ, "out")
        selector.register(child.stderr, selectors.EVENT_READ, "err")
        errors = b""
        ready = False
        deadline = time.monotonic() + 10
        while not stopping and alive(owner):
            for key, _mask in selector.select(0.2):
                data = os.read(key.fileobj.fileno(), 4096)
                if not data:
                    selector.unregister(key.fileobj)
                    if key.data == "owner":
                        stopping = True
                elif key.data == "out" and b'"ready": true' in data:
                    ready = True
                    emit(ready=True)
                elif key.data == "err":
                    errors = (errors + data)[-4096:]
            if stopping:
                break
            if child.poll() is not None:
                # Drain remaining diagnostics before reporting failure.
                errors += child.stderr.read() or b""
                emit(error=errors.decode(errors="replace").strip() or "El inhibidor terminó inesperadamente.")
                return 1
            if not ready and time.monotonic() >= deadline:
                emit(error="No se pudo confirmar la protección contra suspensión.")
                return 1
        return 0
    except (OSError, ValueError) as error:
        emit(error=str(error))
        return 1
    finally:
        if child is not None:
            try:
                # Kill the lease too when systemd-inhibit does not exec it.
                os.killpg(child.pid, signal.SIGTERM)
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=2)
            except ProcessLookupError:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("inhibit", "_lease"))
    parser.add_argument("owner", nargs="?", type=int)
    args = parser.parse_args()
    if args.action == "_lease":
        if args.owner is None or args.owner < 2:
            parser.error("_lease requiere el PID de su supervisor")
        return lease(args.owner)
    return supervise()


if __name__ == "__main__":
    raise SystemExit(main())
