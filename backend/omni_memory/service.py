from __future__ import annotations

import os
import re
import sqlite3
import time
import uuid
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException

from .models import ChatRequest, MemoryCreate, MemoryUpdate
from .provider import ResponsesResponder, validated_suggestions


def stamp() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def item(row):
    return {key: row[key] for key in row.keys() if key != "subject"}


class MemoryService:
    def __init__(self, database: str | Path, *, secret: str = "", responder=None, clock=time.time, chat_limit: int = 10):
        self.database = Path(database)
        self.secret = secret
        self.responder = responder or ResponsesResponder()
        self.clock = clock
        self.chat_limit = chat_limit
        self.request_guard = ContextVar("omni_memory_request_guard", default=None)
        self.database.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        # Create with private permissions before sqlite opens it, including on first boot.
        descriptor = os.open(str(self.database), os.O_CREAT | os.O_RDWR, 0o600)
        os.close(descriptor)
        os.chmod(self.database, 0o600)
        with self.content_db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS accounts (
                    subject TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 0,
                    revision INTEGER NOT NULL DEFAULT 0, premium_until INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS conversations (
                    subject TEXT NOT NULL, id TEXT NOT NULL, title TEXT NOT NULL,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                    PRIMARY KEY(subject,id), FOREIGN KEY(subject) REFERENCES accounts(subject));
                CREATE TABLE IF NOT EXISTS memories (
                    subject TEXT NOT NULL, id TEXT NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL,
                    source_conversation_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                    PRIMARY KEY(subject,id), FOREIGN KEY(subject) REFERENCES accounts(subject),
                    FOREIGN KEY(subject,source_conversation_id) REFERENCES conversations(subject,id) ON DELETE CASCADE);
                CREATE TABLE IF NOT EXISTS messages (
                    subject TEXT NOT NULL, id TEXT NOT NULL, conversation_id TEXT NOT NULL,
                    role TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL,
                    sequence INTEGER NOT NULL, PRIMARY KEY(subject,id),
                    FOREIGN KEY(subject,conversation_id) REFERENCES conversations(subject,id) ON DELETE CASCADE);
                CREATE TABLE IF NOT EXISTS rate_limits (
                    subject TEXT NOT NULL, bucket TEXT NOT NULL, minute INTEGER NOT NULL, count INTEGER NOT NULL,
                    PRIMARY KEY(subject,bucket));
            """)

    @classmethod
    def from_env(cls):
        return cls(os.environ.get("OMNI_MEMORY_DB", "./data/memory.sqlite3"), secret=os.environ.get("OMNI_MEMORY_SESSION_SECRET", ""))

    @contextmanager
    def db(self):
        db = sqlite3.connect(self.database, timeout=5)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("PRAGMA secure_delete=ON")
        try:
            db.execute("BEGIN IMMEDIATE")
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    @contextmanager
    def content_db(self):
        """Recheck a request's session inside every content transaction.

        ContextVar follows FastAPI's thread dispatch. Account lifecycle code uses
        db() directly and performs its own checks, including deletion rollback.
        """
        with self.db() as db:
            guard = self.request_guard.get()
            if guard is not None:
                guard(db)
            yield db

    def account(self, db, subject):
        db.execute("INSERT OR IGNORE INTO accounts(subject) VALUES(?)", (subject,))
        return db.execute("SELECT * FROM accounts WHERE subject=?", (subject,)).fetchone()

    def paid(self, account):
        return account["premium_until"] > self.clock()

    def require_paid(self, account):
        if not self.paid(account):
            raise HTTPException(403, "An active server-verified Plus subscription is required.")

    def bump(self, db, subject):
        db.execute("UPDATE accounts SET revision=revision+1 WHERE subject=?", (subject,))

    def provision(self, subject: str, premium_until: int):
        """Trusted operator/account integration only. There is deliberately no HTTP endpoint."""
        from .auth import SUBJECT
        if not SUBJECT.fullmatch(subject) or type(premium_until) is not int or premium_until < 0:
            raise ValueError("An opaque subject and nonnegative expiration timestamp are required.")
        with self.content_db() as db:
            self.account(db, subject)
            db.execute("UPDATE accounts SET premium_until=?, revision=revision+1 WHERE subject=?", (premium_until, subject))

    def rate(self, subject, bucket="api"):
        limit = self.chat_limit if bucket == "chat" else 120
        minute = int(self.clock()) // 60
        with self.content_db() as db:
            prior = db.execute("SELECT * FROM rate_limits WHERE subject=? AND bucket=?", (subject, bucket)).fetchone()
            count = prior["count"] if prior and prior["minute"] == minute else 0
            if count >= limit:
                raise HTTPException(429, "Please wait before trying again.", headers={"Retry-After": "60"})
            db.execute("INSERT OR REPLACE INTO rate_limits(subject,bucket,minute,count) VALUES(?,?,?,?)", (subject, bucket, minute, count + 1))

    def settings(self, subject):
        with self.content_db() as db:
            account = self.account(db, subject)
            return {"enabled": bool(account["enabled"]), "premium_active": self.paid(account), "revision": account["revision"]}

    def set_settings(self, subject, enabled: bool):
        with self.content_db() as db:
            account = self.account(db, subject)
            if enabled:
                self.require_paid(account)
            db.execute("UPDATE accounts SET enabled=?,revision=revision+1 WHERE subject=?", (int(enabled), subject))
        return self.settings(subject)

    def memories(self, subject):
        with self.content_db() as db:
            account = self.account(db, subject)
            values = db.execute("SELECT * FROM memories WHERE subject=? ORDER BY updated_at DESC,id", (subject,)).fetchall()
            return {"items": [item(row) for row in values], "revision": account["revision"]}

    def create_memory(self, subject, data: MemoryCreate):
        with self.content_db() as db:
            account = self.account(db, subject)
            self.require_paid(account)
            if not account["enabled"]:
                raise HTTPException(409, "Enable memory before saving a new memory.")
            if db.execute("SELECT COUNT(*) FROM memories WHERE subject=?", (subject,)).fetchone()[0] >= 100:
                raise HTTPException(409, "Memory is full. Remove an item before saving another.")
            if data.source_conversation_id:
                self.conversation_row(db, subject, data.source_conversation_id)
            identifier, now = str(uuid.uuid4()), stamp()
            db.execute("INSERT INTO memories VALUES(?,?,?,?,?,?,?)", (subject, identifier, data.kind, data.text, data.source_conversation_id, now, now))
            self.bump(db, subject)
            return item(db.execute("SELECT * FROM memories WHERE subject=? AND id=?", (subject, identifier)).fetchone())

    def update_memory(self, subject, identifier, data: MemoryUpdate):
        with self.content_db() as db:
            row = db.execute("SELECT * FROM memories WHERE subject=? AND id=?", (subject, identifier)).fetchone()
            if not row:
                raise HTTPException(404, "Memory not found.")
            # Corrections and deletion remain available after subscription expiration.
            db.execute("UPDATE memories SET text=?,kind=?,updated_at=? WHERE subject=? AND id=?", (data.text, data.kind or row["kind"], stamp(), subject, identifier))
            self.bump(db, subject)
            return item(db.execute("SELECT * FROM memories WHERE subject=? AND id=?", (subject, identifier)).fetchone())

    def delete_memory(self, subject, identifier):
        with self.content_db() as db:
            result = db.execute("DELETE FROM memories WHERE subject=? AND id=?", (subject, identifier))
            if not result.rowcount:
                raise HTTPException(404, "Memory not found.")
            self.bump(db, subject)
        return {"deleted": True}

    def conversation_row(self, db, subject, identifier):
        row = db.execute("SELECT * FROM conversations WHERE subject=? AND id=?", (subject, identifier)).fetchone()
        if not row:
            raise HTTPException(404, "Conversation not found.")
        return row

    def conversations(self, subject):
        with self.content_db() as db:
            return {"items": [item(row) for row in db.execute("SELECT * FROM conversations WHERE subject=? ORDER BY updated_at DESC,id", (subject,)).fetchall()]}

    def conversation(self, subject, identifier):
        with self.content_db() as db:
            row = self.conversation_row(db, subject, identifier)
            turns = db.execute("SELECT id,role,content,created_at FROM messages WHERE subject=? AND conversation_id=? ORDER BY sequence", (subject, identifier)).fetchall()
            return {"conversation": item(row), "messages": [dict(turn) for turn in turns]}

    def delete_conversations(self, subject, identifier=None):
        with self.content_db() as db:
            self.account(db, subject)
            if identifier is not None:
                self.conversation_row(db, subject, identifier)
                db.execute("DELETE FROM conversations WHERE subject=? AND id=?", (subject, identifier))
            else:
                db.execute("DELETE FROM conversations WHERE subject=?", (subject,))
            self.bump(db, subject)
        return {"deleted": True}

    def export(self, subject):
        with self.content_db() as db:
            account = self.account(db, subject)
            return {"schema_version": 1, "exported_at": stamp(), "settings": {"enabled": bool(account["enabled"])},
                    "memories": [item(row) for row in db.execute("SELECT * FROM memories WHERE subject=? ORDER BY created_at,id", (subject,))],
                    "conversations": [item(row) for row in db.execute("SELECT * FROM conversations WHERE subject=? ORDER BY created_at,id", (subject,))],
                    "messages": [item(row) for row in db.execute("SELECT * FROM messages WHERE subject=? ORDER BY conversation_id,sequence", (subject,))]}

    def erase(self, subject):
        with self.content_db() as db:
            self.account(db, subject)
            db.execute("DELETE FROM memories WHERE subject=?", (subject,))
            db.execute("DELETE FROM conversations WHERE subject=?", (subject,))
            db.execute("UPDATE accounts SET enabled=0,revision=revision+1 WHERE subject=?", (subject,))
        return {"deleted": True}

    def relevant(self, rows, message):
        # Small bounded corpus: local lexical ranking, no external embedding store.
        tokens = set(re.findall(r"[\w]+", message.casefold()))
        def score(row):
            words = set(re.findall(r"[\w]+", row["text"].casefold()))
            return (len(tokens & words), row["kind"] == "profile", row["updated_at"])
        ranked = sorted(rows, key=score, reverse=True)
        selected, characters = [], 0
        for row in ranked:
            if len(selected) >= 6:
                break
            if (score(row)[0] > 0 or row["kind"] == "profile") and characters + len(row["text"]) <= 3000:
                selected.append(item(row))
                characters += len(row["text"])
        return selected

    async def chat(self, subject, request: ChatRequest, *, request_guard=None):
        self.rate(subject, "chat")
        with self.content_db() as db:
            if request_guard is not None:
                request_guard(db)
            account = self.account(db, subject)
            self.require_paid(account)
            revision = account["revision"]
            persisted = request.persist and not request.temporary and bool(account["enabled"])
            suggest_memories = request.suggest_memories and not request.temporary and (not request.persist or bool(account["enabled"]))
            memories, history = [], []
            if not request.persist:
                memories = [value.model_dump() for value in request.local_context] if not request.temporary else []
                history = [value.model_dump() for value in request.local_history]
            elif persisted:
                rows = db.execute("SELECT * FROM memories WHERE subject=?", (subject,)).fetchall()
                memories = self.relevant(rows, request.message)
                if request.conversation_id:
                    self.conversation_row(db, subject, request.conversation_id)
                    history = [dict(row) for row in db.execute("SELECT role,content FROM messages WHERE subject=? AND conversation_id=? ORDER BY sequence DESC LIMIT 8", (subject, request.conversation_id)).fetchall()][::-1]
            elif request.conversation_id:
                raise HTTPException(409, "Memory is off. Start a new conversation.")

        # Network occurs outside the database transaction. No user turn is saved yet.
        draft = await self.responder.respond(request.message, memories, history, suggest_memories=suggest_memories)
        answer = draft["content"]
        suggestions = validated_suggestions(draft.get("memory_suggestions"), request.message) if suggest_memories else []
        now = stamp()
        reply = {"id": str(uuid.uuid4()), "role": "assistant", "content": answer, "created_at": now}
        conversation_id = None
        with self.content_db() as db:
            if request_guard is not None:
                request_guard(db)
            account = self.account(db, subject)
            self.require_paid(account)
            if account["revision"] != revision:
                raise HTTPException(409, "Memory changed during this reply. Please retry.")
            if persisted:
                conversation_id = request.conversation_id or str(uuid.uuid4())
                if request.conversation_id:
                    self.conversation_row(db, subject, conversation_id)
                else:
                    if db.execute("SELECT COUNT(*) FROM conversations WHERE subject=?", (subject,)).fetchone()[0] >= 200:
                        raise HTTPException(409, "Conversation storage is full. Export or remove a conversation first.")
                    db.execute("INSERT INTO conversations VALUES(?,?,?,?,?)", (subject, conversation_id, request.message[:60], now, now))
                count = db.execute("SELECT COUNT(*) FROM messages WHERE subject=? AND conversation_id=?", (subject, conversation_id)).fetchone()[0]
                if count >= 200:
                    raise HTTPException(409, "This conversation is full. Start a new conversation.")
                db.execute("INSERT INTO messages VALUES(?,?,?,?,?,?,?)", (subject, str(uuid.uuid4()), conversation_id, "user", request.message, now, count))
                db.execute("INSERT INTO messages VALUES(?,?,?,?,?,?,?)", (subject, reply["id"], conversation_id, "assistant", answer, now, count + 1))
                db.execute("UPDATE conversations SET updated_at=? WHERE subject=? AND id=?", (now, subject, conversation_id))
                self.bump(db, subject)
        return {"conversation_id": conversation_id, "message": reply, "used_memory_ids": [value["id"] for value in memories], "persisted": persisted,
                "memory_suggestions": suggestions}
