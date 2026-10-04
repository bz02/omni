import sqlite3
import stat
import pytest
from omni_memory.backup import backup


def test_snapshot_includes_live_wal_and_refuses_overwrite(tmp_path):
    source=tmp_path/'source.db'; target=tmp_path/'snapshot.db'
    with sqlite3.connect(source) as live:
        live.execute('PRAGMA journal_mode=WAL')
        live.execute('CREATE TABLE messages(text TEXT)')
        live.execute("INSERT INTO messages VALUES('synthetic conversation')"); live.commit()
        backup(source,target)
        live.execute("INSERT INTO messages VALUES('later')"); live.commit()
        with sqlite3.connect(target) as restored:
            assert restored.execute('SELECT text FROM messages').fetchall()==[('synthetic conversation',)]
        assert stat.S_IMODE(target.stat().st_mode)==0o600
        with pytest.raises(FileExistsError): backup(source,target)
