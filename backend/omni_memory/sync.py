"""Explicit, account-scoped snapshot sync. No background merge or guest import."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator, model_validator

MAX_SNAPSHOT_BYTES = 1_900_000


class SnapshotModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SnapshotSettings(SnapshotModel):
    enabled: StrictBool = False
    saveHistory: StrictBool = True


class SnapshotMemory(SnapshotModel):
    id: UUID
    kind: Literal["profile", "preference", "relationship", "goal"]
    text: str = Field(min_length=1, max_length=1000)
    createdAt: datetime
    updatedAt: datetime
    sourceConversationID: Optional[UUID] = None
    sourceMessageID: Optional[UUID] = None
    confirmedByUser: StrictBool

    @field_validator("confirmedByUser")
    @classmethod
    def confirmed(cls, value):
        if not value:
            raise ValueError("Only confirmed memories can sync.")
        return value

    @field_validator("text")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("A memory cannot be blank.")
        return value

    @field_validator("createdAt", "updatedAt", mode="before")
    @classmethod
    def iso_date(cls, value):
        return require_iso_date(value)


class SnapshotMessage(SnapshotModel):
    id: UUID
    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=16000)
    date: datetime
    usedMemoryIDs: list[UUID] = Field(default_factory=list, max_length=6)

    @field_validator("text")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("A message cannot be blank.")
        return value

    @field_validator("date", mode="before")
    @classmethod
    def iso_date(cls, value):
        return require_iso_date(value)


class SnapshotConversation(SnapshotModel):
    id: UUID
    title: str = Field(min_length=1, max_length=160)
    createdAt: datetime
    updatedAt: datetime
    messages: list[SnapshotMessage] = Field(min_length=1, max_length=2000)

    @field_validator("title")
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError("A title cannot be blank.")
        return value

    @field_validator("createdAt", "updatedAt", mode="before")
    @classmethod
    def iso_date(cls, value):
        return require_iso_date(value)


def require_iso_date(value):
    if not isinstance(value, str) or "T" not in value:
        raise ValueError("An ISO 8601 timestamp is required.")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        raise ValueError("An ISO 8601 timestamp is required.") from None
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("A timestamp must include its time zone.")
    return value


class SnapshotArchive(SnapshotModel):
    version: StrictInt
    ownerID: UUID
    settings: SnapshotSettings
    memories: list[SnapshotMemory] = Field(default_factory=list, max_length=2000)
    conversations: list[SnapshotConversation] = Field(default_factory=list, max_length=2000)

    @model_validator(mode="after")
    def invariants(self):
        if self.version != 1:
            raise ValueError("This snapshot version is not supported.")
        memories = {item.id: item for item in self.memories}
        conversations = {item.id: item for item in self.conversations}
        if len(memories) != len(self.memories) or len(conversations) != len(self.conversations):
            raise ValueError("Record IDs must be unique.")
        seen_messages = set()
        for conversation in self.conversations:
            for message in conversation.messages:
                if message.id in seen_messages:
                    raise ValueError("Message IDs must be unique.")
                seen_messages.add(message.id)
                if len(set(message.usedMemoryIDs)) != len(message.usedMemoryIDs):
                    raise ValueError("Citations must be unique.")
                if any(identifier not in memories for identifier in message.usedMemoryIDs):
                    raise ValueError("Citations must reference existing memories.")
                if message.role == "user" and message.usedMemoryIDs:
                    raise ValueError("Only assistant messages may cite context.")
        for memory in self.memories:
            if memory.sourceConversationID is None and memory.sourceMessageID is None:
                continue
            source = conversations.get(memory.sourceConversationID)
            if source is None or not any(message.id == memory.sourceMessageID and message.role == "user" for message in source.messages):
                raise ValueError("A memory source must be its owner's existing user message.")
        if len(json.dumps(self.model_dump(mode="json"), ensure_ascii=False).encode()) > MAX_SNAPSHOT_BYTES:
            raise ValueError("This snapshot is too large.")
        return self


class SnapshotPut(SnapshotModel):
    expected_revision: StrictInt = Field(ge=0)
    archive: SnapshotArchive


class SnapshotDelete(SnapshotModel):
    expected_revision: StrictInt = Field(ge=0)


class SnapshotService:
    def __init__(self, memory_service):
        self.service = memory_service
        with self.service.content_db() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS native_snapshots (
                subject TEXT PRIMARY KEY, revision INTEGER NOT NULL DEFAULT 0,
                archive TEXT, FOREIGN KEY(subject) REFERENCES accounts(subject))""")

    @staticmethod
    def subject(value):
        try:
            return str(UUID(value))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(403, "Sign in to an account before syncing memory.") from None

    @staticmethod
    def row(db, subject):
        return db.execute("SELECT revision,archive FROM native_snapshots WHERE subject=?", (subject,)).fetchone()

    @staticmethod
    def envelope(row):
        return {"revision": row["revision"] if row else 0,
                "archive": json.loads(row["archive"]) if row and row["archive"] is not None else None}

    def get(self, subject):
        subject = self.subject(subject)
        with self.service.content_db() as db:
            return self.envelope(self.row(db, subject))

    def put(self, subject, data: SnapshotPut):
        subject = self.subject(subject)
        if data.archive.ownerID != UUID(subject):
            raise HTTPException(403, "This snapshot belongs to a different account.")
        with self.service.content_db() as db:
            account = self.service.account(db, subject)
            current = self.envelope(self.row(db, subject))
            if current["revision"] != data.expected_revision:
                raise HTTPException(409, "Cloud memory changed. Review and download it before replacing it.")
            incoming = data.archive.model_dump(mode="json", exclude_none=True)
            if not self.service.paid(account):
                self.require_edits_only(current["archive"], incoming)
            revision = current["revision"] + 1
            db.execute("INSERT INTO native_snapshots(subject,revision,archive) VALUES(?,?,?) "
                       "ON CONFLICT(subject) DO UPDATE SET revision=excluded.revision,archive=excluded.archive",
                       (subject, revision, json.dumps(incoming, ensure_ascii=False, separators=(",", ":"))))
            self.service.bump(db, subject)
            return {"revision": revision, "archive": incoming}

    @staticmethod
    def require_edits_only(prior, incoming):
        prior = prior or {"settings": {"enabled": False}, "memories": [], "conversations": []}
        if incoming["settings"]["enabled"] and not prior["settings"]["enabled"]:
            raise HTTPException(403, "Plus is required to enable new memory use.")
        if not {item["id"] for item in incoming["memories"]} <= {item["id"] for item in prior["memories"]}:
            raise HTTPException(403, "Plus is required to sync new memories.")
        conversations = {item["id"]: item for item in prior["conversations"]}
        for conversation in incoming["conversations"]:
            old = conversations.get(conversation["id"])
            if old is None or not {item["id"] for item in conversation["messages"]} <= {item["id"] for item in old["messages"]}:
                raise HTTPException(403, "Plus is required to sync new conversations or messages.")

    def delete(self, subject, expected_revision: int):
        subject = self.subject(subject)
        if type(expected_revision) is not int or expected_revision < 0:
            raise HTTPException(422, "A valid cloud revision is required.")
        with self.service.content_db() as db:
            self.service.account(db, subject)
            current = self.envelope(self.row(db, subject))
            if current["revision"] != expected_revision:
                raise HTTPException(409, "Cloud memory changed. Review it before deleting it.")
            self.erase_in_db(db, subject)
            self.service.bump(db, subject)
            return self.envelope(self.row(db, subject))

    def erase_all_data(self, subject):
        subject = self.subject(subject)
        with self.service.content_db() as db:
            self.service.account(db, subject)
            db.execute("DELETE FROM memories WHERE subject=?", (subject,))
            db.execute("DELETE FROM conversations WHERE subject=?", (subject,))
            db.execute("UPDATE accounts SET enabled=0,revision=revision+1 WHERE subject=?", (subject,))
            self.erase_in_db(db, subject)
        return {"deleted": True}

    @staticmethod
    def erase_in_db(db, subject):
        """Legacy erase hook: retain the revision so an offline stale upload cannot revive data."""
        if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='native_snapshots'").fetchone():
            return
        db.execute("INSERT INTO native_snapshots(subject,revision,archive) VALUES(?,1,NULL) "
                   "ON CONFLICT(subject) DO UPDATE SET revision=native_snapshots.revision+1,archive=NULL", (subject,))

    @staticmethod
    def purge_account(db, subject):
        """Permanent account-deletion hook; caller must also revoke every account session."""
        if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='native_snapshots'").fetchone():
            db.execute("DELETE FROM native_snapshots WHERE subject=?", (subject,))
