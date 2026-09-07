"""Keep the Wayland gamma owner tied to its Quickshell parent on Linux."""
import ctypes
import os
import signal
import sys


def main():
    temperature = int(sys.argv[1])
    if not 1000 <= temperature <= 6500:
        raise ValueError("Invalid colour temperature")
    parent = os.getppid()
    libc = ctypes.CDLL(None, use_errno=True)
    # PR_SET_PDEATHSIG survives exec: no orphan gamma owner after shell exit.
    if libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), "Could not bind night light to its parent")
    if parent == 1 or os.getppid() != parent:
        return
    os.execvp("gammastep", ["gammastep", "-m", "wayland", "-O",
                           str(temperature), "-g", "1.0", "-r"])


if __name__ == "__main__":
    main()
