"""Render-only mount bootstrap; application code always runs as UID 10001."""
from __future__ import annotations

import ctypes
import os
from pathlib import Path
import ssl
import sys
import tempfile

DATA = Path("/var/data/omni")
UID, GID = 10001, 1000


def main():
    os.umask(0o077)
    if not os.path.ismount("/var/data"):
        raise RuntimeError("A persistent disk must be mounted at /var/data.")
    if os.environ.get("OMNI_MEMORY_DB") != str(DATA / "memory.sqlite3"):
        raise RuntimeError("The configured database must use the persistent Omni directory.")
    if DATA.is_symlink() or (DATA.exists() and not DATA.is_dir()):
        raise RuntimeError("The persistent Omni directory is invalid.")
    if os.geteuid() == 0:
        DATA.mkdir(mode=0o700, exist_ok=True)
        os.chown(DATA, UID, GID)
        os.chmod(DATA, 0o700)
        os.setgroups([GID])
        os.setgid(GID)
        os.setuid(UID)
    if os.geteuid() != UID or os.getegid() != GID:
        raise RuntimeError("The service must run with the dedicated non-root identity.")
    # Linux PR_SET_NO_NEW_PRIVS. No subsequent child may regain elevated privileges.
    if ctypes.CDLL(None, use_errno=True).prctl(38, 1, 0, 0, 0) != 0:
        raise RuntimeError("Cannot disable privilege escalation.")
    with tempfile.TemporaryFile(dir=DATA) as probe:
        probe.write(b"writable")
        probe.flush()

    # Render secret files accept text. Convert public Apple PEM roots to the DER
    # format required by Apple's library, in a fresh private ephemeral directory.
    raw = os.environ.get("OMNI_RENDER_ROOT_CERTIFICATE_PEM_FILES", "")
    if raw:
        files = raw.split(os.pathsep)
        if not 1 <= len(files) <= 5:
            raise RuntimeError("Configure one to five Apple root certificate PEM files.")
        directory = Path(tempfile.mkdtemp(prefix="omni-apple-roots-"))
        converted = []
        for index, value in enumerate(files):
            source = Path(value)
            if source.parent != Path("/etc/secrets") or not source.is_file() or source.stat().st_size > 16384:
                raise RuntimeError("Apple root PEM files must be available in Render secret files.")
            der = ssl.PEM_cert_to_DER_cert(source.read_text(encoding="ascii"))
            destination = directory / f"root-{index}.der"
            destination.write_bytes(der)
            converted.append(str(destination))
        os.environ["OMNI_APPLE_ROOT_CERTIFICATES"] = os.pathsep.join(converted)

    port = os.environ.get("PORT", "10000")
    if not port.isdigit() or not 1024 <= int(port) <= 65535:
        raise RuntimeError("Invalid service port.")
    os.execv(sys.executable, [sys.executable, "-m", "uvicorn", "omni_memory.app:create_app", "--factory",
             "--host", "0.0.0.0", "--port", port, "--workers", "1", "--limit-concurrency", "32",
             "--no-access-log", "--no-proxy-headers"])


if __name__ == "__main__":
    main()
