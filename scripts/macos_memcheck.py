import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import tempfile


def interrupted(_signal, _frame):
    raise SystemExit(130)


def main():
    original = Path(sys.argv[1]).resolve()
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    executable = None
    try:
        with tempfile.TemporaryDirectory(prefix="nvim-leaks-") as scratch:
            descriptor, name = tempfile.mkstemp(prefix=".nvim-leaks-", dir=original.parent)
            os.close(descriptor)
            executable = Path(name)
            shutil.copy2(original, executable)
            entitlements = Path(scratch) / "debug.plist"
            entitlements.write_bytes(plistlib.dumps({"com.apple.security.get-task-allow": True}))
            signed = subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", "--entitlements", str(entitlements), str(executable)],
                                    capture_output=True, text=True)
            if signed.returncode:
                print("Cannot prepare a debuggable copy for macOS leaks:", signed.stderr, flush=True)
                return signed.returncode
            print("Backend: macOS leaks (Valgrind does not support Apple Silicon macOS)", flush=True)
            print(f"Executable: {original}\nA temporary debug-signed copy is used; the original stays unchanged.\n", flush=True)
            result = subprocess.run(["/usr/bin/leaks", "--noContent", "--fullStacks", "--atExit", "--", str(executable), *sys.argv[2:]],
                                    env={**os.environ, "MallocStackLogging": "1"}, stdin=subprocess.DEVNULL)
            return result.returncode
    finally:
        if executable is not None:
            executable.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except OSError as error:
        print(f"Unable to run memory analysis: {error}", file=sys.stderr)
        sys.exit(1)
