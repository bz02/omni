"""Opt-in adult discovery. No imported contacts, fabricated people or inferred preferences."""
from __future__ import annotations

import base64
import io
import binascii
import json
import os
import uuid
from datetime import date, datetime, timezone
from typing import Literal, Optional

from fastapi import HTTPException
from PIL import Image, ImageOps, UnidentifiedImageError
from .birth import BirthInput
from .connect import ConnectProfile, normalize, report
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator, model_validator


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


Gender = Literal["woman", "man", "nonbinary"]


class DatingProfile(BirthInput, Input):
    name: str = Field(min_length=1, max_length=40)
    birth_date: date
    mbti: str = 'unknown'
    communication: Literal['talk_it_out', 'time_to_think', 'mix'] = 'mix'
    social: Literal['quiet', 'outgoing', 'mix'] = 'mix'
    value: Literal['growth', 'stability', 'adventure', 'family', 'creativity'] = 'growth'
    @field_validator('mbti')
    @classmethod
    def valid_type(cls, value): return ConnectProfile.mbti_type(value)

    city: str = Field(min_length=2, max_length=80)
    gender: Literal["woman", "man", "nonbinary", "unspecified"] = "unspecified"
    seeking: list[Gender] = Field(default_factory=lambda: ["woman", "man", "nonbinary"], min_length=1, max_length=3)
    age_min: StrictInt = Field(ge=18, le=100)
    age_max: StrictInt = Field(ge=18, le=100)
    intention: Literal["friendship", "long_term", "exploring", "casual"] = "friendship"
    bio: str = Field(min_length=10, max_length=500)
    visible: StrictBool = False
    consent_version: Literal["dating-v1", "friends-v1"]

    @model_validator(mode="after")
    def valid_preferences(self):
        if self.age_min > self.age_max or len(set(self.seeking)) != len(self.seeking):
            raise ValueError("Invalid preferences.")
        if self.intention == 'friendship' and self.consent_version != 'friends-v1':
            raise ValueError('Confirm the friendship discovery consent before joining.')
        if self.intention != 'friendship' and self.gender == 'unspecified':
            raise ValueError('Existing dating discovery needs a self-described gender.')
        return self


class ProfilePut(Input):
    expected_revision: StrictInt = Field(ge=0)
    profile: DatingProfile


class PhotoDelete(Input):
    expected_revision: StrictInt = Field(ge=0)

class PhotoPut(Input):
    expected_revision: StrictInt = Field(ge=0)
    image: str = Field(min_length=1, max_length=1_400_000)


def clean_photo(encoded):
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > 1_048_576: raise ValueError()
        with Image.open(io.BytesIO(raw), formats=['JPEG', 'PNG']) as original:
            if original.width * original.height > 12_000_000 or min(original.size) < 100 or getattr(original, 'n_frames', 1) != 1:
                raise ValueError()
            original.load()
            oriented = ImageOps.exif_transpose(original).convert('RGB')
            oriented.thumbnail((1000, 1000))
            # Fresh pixels discard all EXIF/GPS/comments/profiles, including metadata in PNG.
            clean = Image.new('RGB', oriented.size)
            clean.paste(oriented)
            output = io.BytesIO(); clean.save(output, format='JPEG', quality=85)
            return output.getvalue()
    except (ValueError, OSError, binascii.Error, UnidentifiedImageError, Image.DecompressionBombError):
        raise HTTPException(422, 'Choose a JPEG or PNG photo, at least 100 pixels, up to 1 MB and 12 megapixels.')


def compatibility(p, today):
    keys = ConnectProfile.model_fields.keys()
    return normalize(ConnectProfile(**{k: v for k, v in p.items() if k in keys and k != 'consent_version'}, consent_version='connect-v1'), today)


class MessagePut(Input):
    id: uuid.UUID  # client-generated id makes a lost response safe to retry
    text: str = Field(min_length=1, max_length=1000)
    reply_to: Optional[uuid.UUID] = None


class HistoryQuery(Input):
    before: Optional[StrictInt] = Field(default=None, ge=1)
    limit: StrictInt = Field(default=30, ge=1, le=50)

class ChatRead(Input):
    sequence: StrictInt = Field(ge=0)

class ChatSettings(Input):
    pinned: Optional[StrictBool] = None
    read_receipts: Optional[StrictBool] = None

class ReportPut(Input):
    reason: Literal["underage", "harassment", "scam", "sexual_content", "impersonation", "other"]
    detail: str = Field(default="", max_length=1000)


SIGNS = ["Capricorn", "Aquarius", "Pisces", "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius"]
BOUNDARIES = [20, 19, 21, 20, 21, 21, 23, 23, 23, 23, 22, 22]


def calendar_sign(birthday):
    # Approximate calendar ranges, explicitly not an ephemeris or exact natal chart.
    index = birthday.month - 1 + int(birthday.day >= BOUNDARIES[birthday.month - 1])
    return SIGNS[index % 12]


def pairing(first, second):
    signs = [calendar_sign(first), calendar_sign(second)]
    elements = {"Aries": "Fire", "Leo": "Fire", "Sagittarius": "Fire", "Taurus": "Earth", "Virgo": "Earth", "Capricorn": "Earth", "Gemini": "Air", "Libra": "Air", "Aquarius": "Air", "Cancer": "Water", "Scorpio": "Water", "Pisces": "Water"}
    a, b = [elements[s] for s in signs]
    complementary = {a, b} in [{"Fire", "Air"}, {"Earth", "Water"}]
    score = 80 if a == b else 75 if complementary else 60
    return {"score": score, "signs": signs, "method": "calendar-sun-sign-v1",
            "explanation": "Symbolic conversation starter using approximate Sun-sign date ranges: same element 80, Fire/Air or Earth/Water 75, other pairings 60. Not a probability of relationship success or an exact birth-chart calculation. Signs near a boundary need birth time verification.",
            "prompt": "What helps you feel understood when someone approaches life differently?" if score == 60 else "What do you enjoy sharing, and where do you need your own space?"}


def age_on(birthday, today):
    return today.year - birthday.year - ((today.month, today.day) < (birthday.month, birthday.day))


def erase_dating(db, subject):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE name='dating_profiles'").fetchone():
        return
    # Remove the person's shared content and pair records. No other user's private profile is erased.
    db.execute("DELETE FROM dating_matches WHERE first=? OR second=?", (subject, subject))
    db.execute("DELETE FROM dating_likes WHERE sender=? OR receiver=?", (subject, subject))
    db.execute("DELETE FROM dating_blocks WHERE sender=? OR receiver=?", (subject, subject))
    db.execute("DELETE FROM dating_reports WHERE sender=? OR receiver=?", (subject, subject))
    db.execute("DELETE FROM dating_passes WHERE sender=? OR receiver=?", (subject, subject))
    db.execute("DELETE FROM dating_photos WHERE subject=?", (subject,))
    # A revision tombstone prevents a stale editor from recreating an erased profile.
    db.execute("UPDATE dating_profiles SET data=NULL,revision=revision+1,status='draft' WHERE subject=?", (subject,))


class DatingService:
    def __init__(self, memory, *, enabled=None):
        self.memory = memory
        self.enabled = os.environ.get("OMNI_DATING_ENABLED") == "true" if enabled is None else enabled
        with memory.db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS dating_profiles (
                    subject TEXT PRIMARY KEY REFERENCES accounts(subject) ON DELETE CASCADE,
                    id TEXT UNIQUE NOT NULL, revision INTEGER NOT NULL, data TEXT, status TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS dating_photos (
                    subject TEXT PRIMARY KEY REFERENCES accounts(subject) ON DELETE CASCADE,
                    id TEXT UNIQUE NOT NULL, image BLOB NOT NULL);
                CREATE TABLE IF NOT EXISTS dating_passes (
                    sender TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    receiver TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, PRIMARY KEY(sender,receiver));
                CREATE TABLE IF NOT EXISTS dating_likes (
                    sender TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    receiver TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    PRIMARY KEY(sender,receiver));
                CREATE TABLE IF NOT EXISTS dating_matches (
                    id TEXT PRIMARY KEY, first TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    second TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, UNIQUE(first,second));
                CREATE TABLE IF NOT EXISTS dating_messages (
                    id TEXT NOT NULL, match_id TEXT NOT NULL REFERENCES dating_matches(id) ON DELETE CASCADE,
                    sender TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    text TEXT NOT NULL, created_at REAL NOT NULL, PRIMARY KEY(match_id,id));
                CREATE TABLE IF NOT EXISTS dating_blocks (
                    sender TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    receiver TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, PRIMARY KEY(sender,receiver));
                CREATE TABLE IF NOT EXISTS dating_reports (
                    id TEXT PRIMARY KEY, sender TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    receiver TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    reason TEXT NOT NULL, detail TEXT NOT NULL, created_at REAL NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending');
            """)

        # Transactional additive migration: preserve all older messages and pair records.
        with memory.db() as db:
            columns = {r['name'] for r in db.execute('PRAGMA table_info(dating_messages)')}
            if 'sequence' not in columns:
                db.execute('ALTER TABLE dating_messages ADD COLUMN sequence INTEGER')
                db.execute('UPDATE dating_messages SET sequence=rowid')
            if 'reply_to' not in columns:
                db.execute('ALTER TABLE dating_messages ADD COLUMN reply_to TEXT')
            for statement in """
                CREATE UNIQUE INDEX IF NOT EXISTS dating_message_sequence ON dating_messages(match_id,sequence);
                CREATE INDEX IF NOT EXISTS dating_message_sender ON dating_messages(sender,match_id);
                CREATE INDEX IF NOT EXISTS dating_match_first ON dating_matches(first);
                CREATE INDEX IF NOT EXISTS dating_match_second ON dating_matches(second);
                CREATE TABLE IF NOT EXISTS dating_chat_state (
                    match_id TEXT NOT NULL REFERENCES dating_matches(id) ON DELETE CASCADE,
                    subject TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE,
                    last_read INTEGER NOT NULL DEFAULT 0,
                    pinned INTEGER NOT NULL DEFAULT 0, read_receipts INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY(match_id,subject));
            """.split(";"):
                if statement.strip(): db.execute(statement)

    def available(self):
        if not self.enabled:
            raise HTTPException(503, "Friend discovery is not open yet.")

    def today(self):
        return datetime.fromtimestamp(self.memory.clock(), timezone.utc).date()

    def row(self, db, subject):
        return db.execute("SELECT * FROM dating_profiles WHERE subject=?", (subject,)).fetchone()

    def envelope(self, row, db=None):
        return {"revision": row["revision"] if row else 0, "profile": DatingProfile.model_validate_json(row["data"]).model_dump(mode="json") if row and row["data"] else None,
                "status": row["status"] if row else "draft", "discovery_enabled": self.enabled,
                "photo_id": self.photo_id(db, row['subject']) if db is not None and row else None}

    def get(self, subject):
        with self.memory.content_db() as db:
            return self.envelope(self.row(db, subject), db)

    def put(self, subject, data):
        self.available()
        if not 18 <= age_on(data.profile.birth_date, self.today()) <= 100:
            raise HTTPException(422, "Connect is for adults aged 18 and older.")
        with self.memory.content_db() as db:
            self.memory.account(db, subject)
            row = self.row(db, subject)
            if data.expected_revision != (row["revision"] if row else 0):
                raise HTTPException(409, "This profile changed. Reload before editing.")
            old = json.loads(row["data"]) if row and row["data"] else None
            new = data.profile.model_dump(mode="json")
            # Age cannot be changed on a published identity to evade eligibility checks.
            if old and old["birth_date"] != new["birth_date"]:
                raise HTTPException(409, "Contact support to correct your Connect birth date.")
            unchanged = old and all(old[k] == new[k] for k in ["name", "birth_date", "city", "gender", "bio", "intention"])
            status = row["status"] if unchanged and row["status"] in {"approved", "suspended"} else "pending"
            if row and row["status"] == "suspended":
                status = "suspended"
            db.execute("INSERT INTO dating_profiles VALUES(?,?,?,?,?) ON CONFLICT(subject) DO UPDATE SET revision=excluded.revision,data=excluded.data,status=excluded.status",
                       (subject, row["id"] if row else str(uuid.uuid4()), data.expected_revision + 1, json.dumps(new), status))
            self.memory.bump(db, subject)
            return self.envelope(self.row(db, subject), db)

    def delete(self, subject):
        with self.memory.content_db() as db:
            erase_dating(db, subject)
            self.memory.bump(db, subject)
            return self.envelope(self.row(db, subject), db)

    def active(self, row, *, visible=True):
        if not row or not row["data"] or row["status"] != "approved":
            return False
        p = json.loads(row["data"])
        return (not visible or p["visible"]) and 18 <= age_on(date.fromisoformat(p["birth_date"]), self.today()) <= 100

    def blocked(self, db, a, b):
        return db.execute("SELECT 1 FROM dating_blocks WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?)", (a, b, b, a)).fetchone() is not None

    def eligible(self, a, b):
        a, b = json.loads(a["data"]), json.loads(b["data"])
        age_a, age_b = [age_on(date.fromisoformat(p["birth_date"]), self.today()) for p in [a, b]]
        ages_fit = a["age_min"] <= age_b <= a["age_max"] and b["age_min"] <= age_a <= b["age_max"]
        if 'friendship' in (a['intention'], b['intention']):
            return ages_fit and a['intention'] == b['intention'] == 'friendship'
        return a["gender"] in b["seeking"] and b["gender"] in a["seeking"] and a["age_min"] <= age_b <= a["age_max"] and b["age_min"] <= age_a <= b["age_max"]

    def public(self, row, own, db):
        p, a = json.loads(row["data"]), json.loads(own["data"])
        result = report(compatibility(a, self.today()), compatibility(p, self.today()), 'friendship' if a['intention'] == p['intention'] == 'friendship' else 'dating')
        return {"id": row["id"], "name": p["name"], "age": age_on(date.fromisoformat(p["birth_date"]), self.today()),
                "city": p["city"], "bio": p["bio"], "intention": p["intention"],
                "photo_id": self.photo_id(db, row['subject']),
                "pairing": dict(score=result['score'], signs=[calendar_sign(date.fromisoformat(v['birth_date'])) for v in [a,p]],
                    method=result['method'], explanation=result['disclaimer'], prompt=result['dimensions'][1]['prompt'], report=result)}

    def discover(self, subject):
        self.available()
        with self.memory.content_db() as db:
            own = self.row(db, subject)
            if not self.active(own):
                return {"profiles": [], "status": "profile_not_discoverable"}
            # Bound each page; do not expose a user count or internal account identifiers.
            rows = db.execute("SELECT p.* FROM dating_profiles p WHERE p.subject!=? AND p.status='approved' AND p.data IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dating_likes l WHERE l.sender=? AND l.receiver=p.subject) AND NOT EXISTS(SELECT 1 FROM dating_passes x WHERE x.sender=? AND x.receiver=p.subject) ORDER BY p.id LIMIT 500", (subject, subject, subject)).fetchall()
            candidates = [self.public(r, own, db) for r in rows if self.active(r) and self.eligible(own, r) and not self.blocked(db, subject, r["subject"])]
            candidates.sort(key=lambda p: (-p["pairing"]["score"], p["id"]))
            return {"profiles": candidates[:20], "status": "ready"}

    def target(self, db, identifier, subject):
        row = db.execute("SELECT * FROM dating_profiles WHERE id=? AND subject!=? AND data IS NOT NULL", (identifier, subject)).fetchone()
        if not row:
            raise HTTPException(404, "This profile is unavailable.")
        return row

    def like(self, subject, identifier):
        self.available()
        with self.memory.content_db() as db:
            own, target = self.row(db, subject), self.target(db, identifier, subject)
            if not self.active(own) or not self.active(target) or not self.eligible(own, target) or self.blocked(db, subject, target["subject"]):
                raise HTTPException(404, "This profile is unavailable.")
            db.execute("DELETE FROM dating_passes WHERE sender=? AND receiver=?", (subject, target['subject']))
            db.execute("INSERT OR IGNORE INTO dating_likes VALUES(?,?)", (subject, target["subject"]))
            reciprocal = db.execute("SELECT 1 FROM dating_likes WHERE sender=? AND receiver=?", (target["subject"], subject)).fetchone()
            match_id = None
            if reciprocal:
                first, second = sorted([subject, target["subject"]])
                db.execute("INSERT OR IGNORE INTO dating_matches VALUES(?,?,?)", (str(uuid.uuid4()), first, second))
                match_id = db.execute("SELECT id FROM dating_matches WHERE first=? AND second=?", (first, second)).fetchone()[0]
            return {"matched": bool(reciprocal), "match_id": match_id}

    def pass_profile(self, subject, identifier):
        self.available()
        with self.memory.content_db() as db:
            own, target = self.row(db, subject), self.target(db, identifier, subject)
            if not self.active(own) or not self.active(target) or not self.eligible(own, target) or self.blocked(db, subject, target['subject']):
                raise HTTPException(404, 'This profile is unavailable.')
            if db.execute('SELECT 1 FROM dating_matches WHERE (first=? AND second=?) OR (first=? AND second=?)', (subject,target['subject'],target['subject'],subject)).fetchone():
                raise HTTPException(409, 'Use Unmatch to end an existing match.')
            db.execute('INSERT OR IGNORE INTO dating_passes VALUES(?,?)', (subject, target['subject']))
            db.execute('DELETE FROM dating_likes WHERE sender=? AND receiver=?', (subject, target['subject']))
        return {'passed': True}

    def likes(self, subject):
        self.available()
        with self.memory.content_db() as db:
            own = self.row(db, subject)
            if not self.active(own, visible=False): return {'profiles': []}
            rows = db.execute('SELECT p.* FROM dating_profiles p JOIN dating_likes l ON l.receiver=p.subject WHERE l.sender=? AND NOT EXISTS(SELECT 1 FROM dating_likes r WHERE r.sender=p.subject AND r.receiver=?) LIMIT 100', (subject,subject))
            return {'profiles': [self.public(r, own, db) for r in rows if self.active(r) and self.eligible(own,r) and not self.blocked(db,subject,r['subject'])]}

    def unlike(self, subject, identifier):
        with self.memory.content_db() as db:
            target = self.target(db, identifier, subject)
            if db.execute('SELECT 1 FROM dating_matches WHERE (first=? AND second=?) OR (first=? AND second=?)', (subject,target['subject'],target['subject'],subject)).fetchone():
                raise HTTPException(409, 'Use Unmatch to end an existing match.')
            db.execute('DELETE FROM dating_likes WHERE sender=? AND receiver=?', (subject,target['subject']))
        return {'removed': True}

    def photo_id(self, db, subject):
        row = db.execute('SELECT id FROM dating_photos WHERE subject=?', (subject,)).fetchone()
        return row['id'] if row else None

    def put_photo(self, subject, data):
        self.available()
        image = clean_photo(data.image)
        with self.memory.content_db() as db:
            own = self.row(db, subject)
            if not own or not own['data'] or own['revision'] != data.expected_revision:
                raise HTTPException(409, 'Save or reload your profile before adding a photo.')
            db.execute('INSERT INTO dating_photos VALUES(?,?,?) ON CONFLICT(subject) DO UPDATE SET id=excluded.id,image=excluded.image', (subject,str(uuid.uuid4()),image))
            db.execute("UPDATE dating_profiles SET status=CASE WHEN status='suspended' THEN status ELSE 'pending' END,revision=revision+1 WHERE subject=?", (subject,))
            return self.envelope(self.row(db,subject), db)

    def remove_photo(self, subject, revision):
        with self.memory.content_db() as db:
            own = self.row(db,subject)
            if not own or own['revision'] != revision: raise HTTPException(409, 'Reload your profile before removing its photo.')
            db.execute('DELETE FROM dating_photos WHERE subject=?', (subject,))
            db.execute('UPDATE dating_profiles SET revision=revision+1 WHERE subject=?', (subject,))
            return self.envelope(self.row(db,subject), db)

    def photo(self, subject, identifier):
        with self.memory.content_db() as db:
            row = db.execute('SELECT * FROM dating_photos WHERE id=?', (identifier,)).fetchone()
            if not row: raise HTTPException(404, 'Photo unavailable.')
            if row['subject'] != subject:
                self.available()
                own, other = self.row(db,subject), self.row(db,row['subject'])
                matched = db.execute('SELECT 1 FROM dating_matches WHERE (first=? AND second=?) OR (first=? AND second=?)', (subject,row['subject'],row['subject'],subject)).fetchone()
                allowed = self.active(own, visible=not bool(matched)) and self.active(other, visible=not bool(matched)) and (bool(matched) or self.eligible(own,other))
                if not allowed or self.blocked(db,subject,row['subject']): raise HTTPException(404, 'Photo unavailable.')
            return row['image']

    def matches(self, subject):
        self.available()
        with self.memory.content_db() as db:
            own = self.row(db, subject)
            if not self.active(own, visible=False):
                return {"matches": []}
            result = []
            for match in db.execute("SELECT m.* FROM dating_matches m LEFT JOIN dating_chat_state s ON s.match_id=m.id AND s.subject=? WHERE m.first=? OR m.second=? ORDER BY COALESCE(s.pinned,0) DESC, (SELECT MAX(created_at) FROM dating_messages WHERE match_id=m.id) DESC, m.id LIMIT 100", (subject, subject, subject)):
                other = match["second"] if match["first"] == subject else match["first"]
                row = self.row(db, other)
                if self.active(row, visible=False) and not self.blocked(db, subject, other):
                    state = self.chat_state(db, subject, match['id'])
                    latest = db.execute('SELECT text,created_at FROM dating_messages WHERE match_id=? ORDER BY sequence DESC LIMIT 1', (match['id'],)).fetchone()
                    unread = db.execute('SELECT COUNT(*) FROM dating_messages WHERE match_id=? AND sender!=? AND sequence>?', (match['id'],subject,state['last_read'])).fetchone()[0]
                    result.append({"id": match["id"], "profile": self.public(row, own, db),
                                   "last_message": latest['text'][:120] if latest else None, "updated_at": latest['created_at'] if latest else 0,
                                   "unread_count": unread, "pinned": bool(state['pinned'])})
            result.sort(key=lambda r: (not r['pinned'], -r['updated_at'], r['id']))
            return {"matches": result}

    def match(self, db, subject, identifier):
        row = db.execute("SELECT * FROM dating_matches WHERE id=? AND (first=? OR second=?)", (identifier, subject, subject)).fetchone()
        if not row:
            raise HTTPException(404, "This match is unavailable.")
        other = row["second"] if row["first"] == subject else row["first"]
        if not all(self.active(self.row(db, s), visible=False) for s in [subject, other]) or self.blocked(db, subject, other):
            raise HTTPException(404, "This match is unavailable.")
        return row

    def chat_state(self, db, subject, identifier):
        row = db.execute('SELECT * FROM dating_chat_state WHERE match_id=? AND subject=?', (identifier,subject)).fetchone()
        return dict(row) if row else {'last_read':0, 'pinned':0, 'read_receipts':0}

    def messages(self, subject, identifier, query=None):
        self.available()
        query = query or HistoryQuery()
        with self.memory.content_db() as db:
            match = self.match(db, subject, identifier)
            other = match['second'] if match['first'] == subject else match['first']
            state = self.chat_state(db,subject,identifier)
            other_state = self.chat_state(db,other,identifier)
            rows = db.execute('SELECT * FROM dating_messages WHERE match_id=? AND (? IS NULL OR sequence<?) ORDER BY sequence DESC LIMIT ?', (identifier,query.before,query.before,query.limit+1)).fetchall()
            more = len(rows)>query.limit
            rows = rows[:query.limit]
            messages=[]
            for r in reversed(rows):
                quoted = db.execute('SELECT text,sender FROM dating_messages WHERE match_id=? AND id=?', (identifier,r['reply_to'])).fetchone() if r['reply_to'] else None
                messages.append(dict(id=r['id'],text=r['text'],mine=r['sender']==subject,created_at=r['created_at'],sequence=r['sequence'],
                    seen=bool(r['sender']==subject and other_state['read_receipts'] and other_state['last_read']>=r['sequence']),
                    reply_to=r['reply_to'], reply_preview=quoted['text'][:160] if quoted else None))
            return dict(messages=messages, has_more=more, next_before=rows[-1]['sequence'] if more else None,
                        read_receipts=bool(state['read_receipts']), pinned=bool(state['pinned']),
                        peer_read_through=other_state['last_read'] if other_state['read_receipts'] else None)

    def mark_read(self, subject, identifier, data):
        self.available()
        with self.memory.content_db() as db:
            self.match(db,subject,identifier)
            if data.sequence and not db.execute('SELECT 1 FROM dating_messages WHERE match_id=? AND sequence=?',(identifier,data.sequence)).fetchone():
                raise HTTPException(422,'Only displayed messages can be marked read.')
            db.execute('INSERT INTO dating_chat_state(match_id,subject,last_read) VALUES(?,?,?) ON CONFLICT(match_id,subject) DO UPDATE SET last_read=MAX(last_read,excluded.last_read)', (identifier,subject,data.sequence))
        return {'read':True}

    def chat_settings(self, subject, identifier, data):
        self.available()
        with self.memory.content_db() as db:
            self.match(db,subject,identifier)
            db.execute('INSERT OR IGNORE INTO dating_chat_state(match_id,subject) VALUES(?,?)',(identifier,subject))
            if data.pinned is not None:
                db.execute('UPDATE dating_chat_state SET pinned=? WHERE match_id=? AND subject=?',(data.pinned,identifier,subject))
            if data.read_receipts is not None:
                db.execute('UPDATE dating_chat_state SET read_receipts=? WHERE match_id=? AND subject=?',(data.read_receipts,identifier,subject))
        return {'saved':True}

    def send(self, subject, identifier, data):
        self.available()
        self.memory.rate(subject, "direct-message")
        with self.memory.content_db() as db:
            self.match(db, subject, identifier)
            previous = db.execute("SELECT * FROM dating_messages WHERE match_id=? AND id=?", (identifier, str(data.id))).fetchone()
            if previous:
                if previous["sender"] != subject or previous["text"] != data.text or previous["reply_to"] != (str(data.reply_to) if data.reply_to else None):
                    raise HTTPException(409, "This message identifier was already used.")
            else:
                if db.execute("SELECT COUNT(*) FROM dating_messages WHERE match_id=?", (identifier,)).fetchone()[0] >= 20000:
                    raise HTTPException(409, "This conversation has reached its storage limit.")
                if data.reply_to and not db.execute('SELECT 1 FROM dating_messages WHERE match_id=? AND id=?', (identifier,str(data.reply_to))).fetchone():
                    raise HTTPException(404,'The message you replied to is unavailable.')
                sequence = db.execute('SELECT COALESCE(MAX(sequence),0)+1 FROM dating_messages WHERE match_id=?', (identifier,)).fetchone()[0]
                db.execute("INSERT INTO dating_messages(id,match_id,sender,text,created_at,sequence,reply_to) VALUES(?,?,?,?,?,?,?)", (str(data.id), identifier, subject, data.text, self.memory.clock(),sequence,str(data.reply_to) if data.reply_to else None))
            return {"sent": True, "id": str(data.id)}

    def unmatch(self, subject, identifier):
        with self.memory.content_db() as db:
            row = self.match(db, subject, identifier)
            # Explicit unmatch prevents immediate rediscovery unless blocks are later cleared by the owner.
            other = row["second"] if row["first"] == subject else row["first"]
            self.block_in_db(db, subject, other)
            return {"deleted": True}

    def block_in_db(self, db, subject, other):
        db.execute("INSERT OR IGNORE INTO dating_blocks VALUES(?,?)", (subject, other))
        db.execute("DELETE FROM dating_likes WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?)", (subject, other, other, subject))
        db.execute("DELETE FROM dating_matches WHERE (first=? AND second=?) OR (first=? AND second=?)", (subject, other, other, subject))

    def block(self, subject, identifier, report=None):
        with self.memory.content_db() as db:
            target = self.target(db, identifier, subject)
            if report:
                # One open report per pair: bounded, and resubmission cannot spam the queue.
                existing = db.execute("SELECT 1 FROM dating_reports WHERE sender=? AND receiver=? AND status='pending'", (subject, target["subject"])).fetchone()
                if not existing:
                    db.execute("INSERT INTO dating_reports(id,sender,receiver,reason,detail,created_at) VALUES(?,?,?,?,?,?)", (str(uuid.uuid4()), subject, target["subject"], report.reason, report.detail, self.memory.clock()))
            self.block_in_db(db, subject, target["subject"])
            return {"blocked": True, "reported": report is not None}

    def export(self, subject):
        with self.memory.content_db() as db:
            return {"profile": self.envelope(self.row(db, subject), db),
                    "photo": self.export_photo(db, subject),
                    "conversation_settings": [dict(r) for r in db.execute("SELECT match_id,last_read,pinned,read_receipts FROM dating_chat_state WHERE subject=?", (subject,))],
                    "messages_sent": [dict(r) for r in db.execute("SELECT id,match_id,text,created_at,sequence,reply_to FROM dating_messages WHERE sender=?", (subject,))]}

    def export_photo(self, db, subject):
        row = db.execute('SELECT image FROM dating_photos WHERE subject=?', (subject,)).fetchone()
        return {'mime_type': 'image/jpeg', 'base64': base64.b64encode(row['image']).decode()} if row else None

    def moderate(self, identifier, *, revision, approved):
        """Trusted operator only. No public route; recheck the exact reviewed revision."""
        with self.memory.db() as db:
            row = db.execute("SELECT * FROM dating_profiles WHERE id=?", (identifier,)).fetchone()
            if not row or not row["data"] or row["revision"] != revision:
                raise ValueError("The profile changed; review the current revision.")
            db.execute("UPDATE dating_profiles SET status=?,revision=revision+1 WHERE id=?", ("approved" if approved else "suspended", identifier))
