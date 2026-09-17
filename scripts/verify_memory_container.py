"""Disposable Linux/Docker acceptance test. No Apple or model calls/credentials."""
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid


def main():
    image = sys.argv[1]
    suffix = uuid.uuid4().hex[:12]
    name, volume = "omni-memory-ci-" + suffix, "omni-memory-data-ci-" + suffix
    env = dict(os.environ, OMNI_MEMORY_SESSION_SECRET=secrets.token_urlsafe(48))

    def docker(*args, capture=False, check=True):
        return subprocess.run(["docker", *args], check=check, env=env, text=True,
                              stdout=subprocess.PIPE if capture else subprocess.DEVNULL).stdout

    def start():
        docker("run", "--detach", "--name", name, "--mount", f"type=volume,source={volume},target=/var/data",
               "--publish", "127.0.0.1::10000", "--env", "PORT=10000", "--env", "OMNI_MEMORY_SESSION_SECRET",
               "--env", "OMNI_MEMORY_DB=/var/data/omni/memory.sqlite3", image)
        address = docker("port", name, "10000/tcp", capture=True).strip()
        base = "http://" + address
        for _ in range(60):
            try:
                with urllib.request.urlopen(base + "/health", timeout=2) as response:
                    if response.status == 200 and json.load(response) == {"status": "ok"}:
                        return base
            except (OSError, ValueError):
                pass
            time.sleep(0.5)
        # Container logs contain no real credentials or content in this synthetic test.
        print(docker("logs", name, capture=True, check=False))
        raise RuntimeError("The production entrypoint did not become healthy.")

    def expect_status(base, path, status, method="GET"):
        request = urllib.request.Request(base + path, method=method)
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                actual = response.status
        except urllib.error.HTTPError as error:
            actual = error.code
        assert actual == status, (path, actual, status)

    try:
        docker("volume", "create", volume)
        base = start()
        identity = json.loads(docker("exec", name, "python", "-c",
            "import json; print(json.dumps(open('/proc/1/status').read().splitlines()))", capture=True))
        uid_line = next(line for line in identity if line.startswith("Uid:"))
        gid_line = next(line for line in identity if line.startswith("Gid:"))
        assert set(uid_line.split()[1:]) == {"10001"}, uid_line
        assert set(gid_line.split()[1:]) == {"1000"}, gid_line
        assert "NoNewPrivs:\t1" in identity
        expect_status(base, "/v1/memory", 401)
        expect_status(base, "/v1/auth/challenge", 503, "POST")
        docker("exec", "--user", "10001:1000", name, "python", "-c",
               "from omni_memory.service import MemoryService; MemoryService.from_env().provision('synthetic-restart-check', 0)")
        # Recreate the container: overlay files alone cannot make this pass.
        docker("rm", "--force", name)
        base = start()
        value = docker("exec", "--user", "10001:1000", name, "python", "-c",
            "import os,sqlite3; db=sqlite3.connect(os.environ['OMNI_MEMORY_DB']); "
            "print(db.execute(\"SELECT COUNT(*) FROM accounts WHERE subject='synthetic-restart-check'\").fetchone()[0])", capture=True)
        assert value.strip() == "1", "The database did not survive container recreation."
        expect_status(base, "/v1/memory", 401)
        print("Verified: non-root application, no privilege escalation, closed authentication, persistent database across container recreation.")
    finally:
        docker("rm", "--force", name, check=False)
        docker("volume", "rm", volume, check=False)


if __name__ == "__main__":
    main()
