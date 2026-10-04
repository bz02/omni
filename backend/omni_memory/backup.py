"""Operator-only consistent SQLite snapshot. Never expose as an HTTP endpoint."""
from contextlib import closing
import argparse
import os
import sqlite3
from pathlib import Path


def backup(source, destination):
    source, destination = Path(source).resolve(strict=True), Path(destination).absolute()
    if source == destination:
        raise ValueError('Choose a new, private backup destination.')
    # Refuse overwrite, including symlinks. Never copy only the DB file in WAL mode.
    fd = os.open(str(destination), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    os.close(fd)
    try:
        with closing(sqlite3.connect(source.as_uri()+'?mode=ro', uri=True, timeout=15)) as live:
            with closing(sqlite3.connect(destination, timeout=15)) as snapshot:
                live.backup(snapshot, pages=256)
                if snapshot.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                    raise RuntimeError('Backup integrity check failed.')
    except Exception:
        destination.unlink()
        raise
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source'); parser.add_argument('destination')
    args = parser.parse_args()
    backup(args.source, args.destination)
    print('Private database snapshot created and verified.')
