"""Revocable first-party accounts. Public inputs cannot grant Plus or choose an owner."""
from __future__ import annotations

import hashlib
import hmac
import os
import secrets
import uuid
from contextlib import nullcontext

import jwt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import HTTPException

from .apple_identity import AppleIdentityVerifier
from .apple_subscription import AppleSubscriptionVerifier, STORE_ENVIRONMENTS
from .auth import AUDIENCE, valid_secret, verify_session

ACCESS_TTL = 900
REFRESH_TTL = 30 * 86400
ENTITLEMENT_TTL = 300


class AccountService:
    def __init__(self, memory_service, *, identity_verifier=None, subscription_verifier=None):
        self.memory = memory_service
        self.identity = identity_verifier or AppleIdentityVerifier.from_env(clock=memory_service.clock)
        self.subscriptions = subscription_verifier or AppleSubscriptionVerifier.from_env(clock=memory_service.clock)
        with self.memory.db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS account_identities (
                    subject TEXT PRIMARY KEY REFERENCES accounts(subject), identity_hash TEXT UNIQUE NOT NULL,
                    apple_refresh BLOB, deleting INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS account_sessions (
                    refresh_hash TEXT PRIMARY KEY, subject TEXT NOT NULL REFERENCES account_identities(subject),
                    access_hash TEXT UNIQUE NOT NULL, family TEXT NOT NULL, access_expires INTEGER NOT NULL,
                    refresh_expires INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS account_challenges (
                    id TEXT PRIMARY KEY, nonce_hash TEXT NOT NULL, expires INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS account_auth_rates (
                    key TEXT NOT NULL, minute INTEGER NOT NULL, count INTEGER NOT NULL, PRIMARY KEY(key,minute));
            """)
        # Keep schema replacement and entitlement invalidation in one real transaction.
        with self.memory.db() as db:
            columns = {row["name"] for row in db.execute("PRAGMA table_info(account_subscriptions)")}
            legacy = bool(columns and "environment" not in columns)
            if legacy:
                db.execute("ALTER TABLE account_subscriptions RENAME TO account_subscriptions_legacy")
            db.execute("""CREATE TABLE IF NOT EXISTS account_subscriptions (
                subject TEXT NOT NULL REFERENCES account_identities(subject),
                environment TEXT NOT NULL CHECK(environment IN ('','Production','Sandbox')),
                original_transaction_id TEXT NOT NULL, premium_until INTEGER NOT NULL DEFAULT 0,
                checked_at INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(subject,environment),
                UNIQUE(environment,original_transaction_id))""")
            if legacy:
                # An old row has no signed environment evidence. Preserve the binding for re-verification,
                # but never infer its environment from the current deployment or retain its paid lease.
                db.execute("""INSERT INTO account_subscriptions
                    SELECT subject,'',original_transaction_id,0,0 FROM account_subscriptions_legacy""")
                db.execute("""UPDATE accounts SET premium_until=0,revision=revision+1
                    WHERE subject IN (SELECT subject FROM account_subscriptions_legacy)""")
                db.execute("DROP TABLE account_subscriptions_legacy")

        # Keep ownership even if a user replaces the active subscription chain.
        # This makes an unbound guest receipt claimable by only one live Omni account.
        with self.memory.db() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS account_purchase_owners (
                environment TEXT NOT NULL CHECK(environment IN ('Production','Sandbox')),
                original_transaction_id TEXT NOT NULL,
                subject TEXT NOT NULL REFERENCES account_identities(subject),
                PRIMARY KEY(environment,original_transaction_id))""")
            db.execute("""INSERT OR IGNORE INTO account_purchase_owners
                SELECT environment,original_transaction_id,subject FROM account_subscriptions
                WHERE environment IN ('Production','Sandbox')""")

    def _now(self):
        return int(self.memory.clock())

    def _ready(self):
        if not valid_secret(self.memory.secret):
            raise HTTPException(503, "Account authentication is not configured.")

    def _digest(self, value, domain="token"):
        return hmac.new(self.memory.secret.encode(), (domain + ":" + value).encode(), hashlib.sha256).hexdigest()

    def _crypt(self):
        return AESGCM(hmac.new(self.memory.secret.encode(), b"omni.apple-refresh.v1", hashlib.sha256).digest())

    def _encrypt(self, value, subject):
        if value is None:
            return None
        nonce = os.urandom(12)
        return nonce + self._crypt().encrypt(nonce, value.encode(), subject.encode())

    def _decrypt(self, value, subject):
        try:
            return self._crypt().decrypt(value[:12], value[12:], subject.encode()).decode()
        except Exception:
            raise HTTPException(503, "Account revocation is temporarily unavailable.") from None

    def rate_auth(self, client_key, *, limit=20):
        """Pass a trusted connection address, never a client-provided forwarding header."""
        self._ready()
        now, key = self._now(), self._digest(str(client_key)[:256], "auth-rate")
        with self.memory.db() as db:
            db.execute("DELETE FROM account_auth_rates WHERE minute<?", (now // 60 - 2,))
            row = db.execute("SELECT count FROM account_auth_rates WHERE key=? AND minute=?", (key, now // 60)).fetchone()
            if row and row[0] >= limit:
                raise HTTPException(429, "Please wait before trying again.", headers={"Retry-After": "60"})
            if not row and db.execute("SELECT COUNT(*) FROM account_auth_rates").fetchone()[0] >= 10000:
                raise HTTPException(503, "Account sign-in is temporarily unavailable.")
            db.execute("INSERT OR REPLACE INTO account_auth_rates VALUES(?,?,?)", (key, now // 60, (row[0] if row else 0) + 1))

    def challenge(self, rate_key):
        self.rate_auth(rate_key)
        if not self.identity.configured:
            raise HTTPException(503, "Apple account verification is not configured.")
        identifier, nonce, expiration = str(uuid.uuid4()), secrets.token_urlsafe(32), self._now() + 300
        with self.memory.db() as db:
            db.execute("DELETE FROM account_challenges WHERE expires<=?", (self._now(),))
            if db.execute("SELECT COUNT(*) FROM account_challenges").fetchone()[0] >= 10000:
                raise HTTPException(503, "Account sign-in is temporarily unavailable.")
            db.execute("INSERT INTO account_challenges VALUES(?,?,?)", (identifier, hashlib.sha256(nonce.encode()).hexdigest(), expiration))
        return {"challenge_id": identifier, "nonce": nonce, "expires_at": expiration}

    async def sign_in(self, challenge_id, identity_token, authorization_code=None):
        self._ready()
        if not self.identity.configured:
            raise HTTPException(503, "Apple account verification is not configured.")
        # Consume before the first network await: failed, replayed and simultaneous attempts cannot share a nonce.
        with self.memory.db() as db:
            row = db.execute("SELECT * FROM account_challenges WHERE id=?", (challenge_id,)).fetchone()
            if not row or row["expires"] <= self._now():
                raise HTTPException(401, "Start a new Apple sign-in request.")
            db.execute("DELETE FROM account_challenges WHERE id=?", (challenge_id,))
            nonce_hash = row["nonce_hash"]
        verified = await self.identity.verify(identity_token, nonce_hash, authorization_code)
        identifier = self._digest(verified.subject, "apple-subject")
        with self.memory.db() as db:
            row = db.execute("SELECT * FROM account_identities WHERE identity_hash=?", (identifier,)).fetchone()
            if row and row["deleting"]:
                raise HTTPException(409, "Account deletion is in progress.")
            subject = row["subject"] if row else str(uuid.uuid4())
            self.memory.account(db, subject)
            if row:
                if verified.refresh_token:
                    db.execute("UPDATE account_identities SET apple_refresh=? WHERE subject=?", (self._encrypt(verified.refresh_token, subject), subject))
            else:
                db.execute("INSERT INTO account_identities(subject,identity_hash,apple_refresh) VALUES(?,?,?)",
                           (subject, identifier, self._encrypt(verified.refresh_token, subject)))
            return self._new_session(db, subject)

    def _new_session(self, db, subject, *, family=None, refresh_expires=None):
        now = self._now()
        db.execute("DELETE FROM account_sessions WHERE refresh_expires<=?", (now,))
        # Keep a bounded number of device families; replacing oldest is a revocation, never a reassignment.
        if family is None:
            families = db.execute("SELECT family,MIN(refresh_expires) AS expiry FROM account_sessions WHERE subject=? AND revoked=0 GROUP BY family ORDER BY expiry", (subject,)).fetchall()
            for old in families[:-9]:
                db.execute("UPDATE account_sessions SET revoked=1 WHERE family=?", (old["family"],))
        token = jwt.encode({"sub": subject, "iat": now, "exp": now + ACCESS_TTL, "aud": AUDIENCE,
                            "jti": str(uuid.uuid4())}, self.memory.secret, algorithm="HS256")
        refresh = secrets.token_urlsafe(48)
        db.execute("INSERT INTO account_sessions VALUES(?,?,?,?,?,?,0)", (self._digest(refresh), subject, self._digest(token),
                   family or str(uuid.uuid4()), now + ACCESS_TTL, refresh_expires or now + REFRESH_TTL))
        # Once an entire device family is revoked, no replay can resurrect it; remove its tombstones.
        db.execute("DELETE FROM account_sessions WHERE subject=? AND family NOT IN (SELECT family FROM account_sessions WHERE subject=? AND revoked=0)", (subject, subject))
        return {"account_id": subject, "access_token": token, "refresh_token": refresh, "expires_at": now + ACCESS_TTL}

    def refresh(self, refresh_token):
        self._ready()
        if not isinstance(refresh_token, str) or not 32 <= len(refresh_token) <= 256:
            raise HTTPException(401, "Sign in to your account again.")
        invalid, result = False, None
        with self.memory.db() as db:
            row = db.execute("SELECT s.*,i.deleting FROM account_sessions s JOIN account_identities i ON i.subject=s.subject WHERE refresh_hash=?",
                             (self._digest(refresh_token),)).fetchone()
            if not row or row["refresh_expires"] <= self._now() or row["deleting"]:
                invalid = True
            elif row["revoked"]:
                # A replay after rotation revokes the whole family, including the new access token.
                db.execute("UPDATE account_sessions SET revoked=1 WHERE family=?", (row["family"],))
                self.memory.bump(db, row["subject"])
                invalid = True
            elif db.execute("SELECT COUNT(*) FROM account_sessions WHERE family=?", (row["family"],)).fetchone()[0] >= 4096:
                db.execute("UPDATE account_sessions SET revoked=1 WHERE family=?", (row["family"],))
                self.memory.bump(db, row["subject"])
                invalid = True
            else:
                db.execute("UPDATE account_sessions SET revoked=1 WHERE refresh_hash=?", (row["refresh_hash"],))
                result = self._new_session(db, row["subject"], family=row["family"], refresh_expires=row["refresh_expires"])
        if invalid:
            raise HTTPException(401, "Sign in to your account again.")
        return result

    def assert_active(self, authorization, db=None):
        subject = verify_session(authorization, self.memory.secret, now=self._now())
        with (nullcontext(db) if db is not None else self.memory.db()) as connection:
            row = connection.execute("SELECT s.revoked,s.access_expires,i.deleting FROM account_sessions s JOIN account_identities i ON i.subject=s.subject WHERE s.subject=? AND access_hash=?",
                                     (subject, self._digest(authorization[7:]))).fetchone()
            if not row or row["revoked"] or row["deleting"] or row["access_expires"] <= self._now():
                raise HTTPException(401, "Sign in to your account again.")
        return subject

    async def authorize(self, authorization):
        subject = self.assert_active(authorization)
        with self.memory.db() as db:
            rows = db.execute("SELECT * FROM account_subscriptions WHERE subject=?", (subject,)).fetchall()
        for row in rows:
            if row["environment"] not in self.subscriptions.environments or self._now() - row["checked_at"] < ENTITLEMENT_TTL:
                continue
            try:
                verified = await self.subscriptions.status(subject, row["original_transaction_id"], environment=row["environment"])
                self._save_entitlement(subject, verified, authorization=authorization)
            except HTTPException as error:
                if error.status_code == 401:
                    raise
                # An outage removes only this environment's paid lease; it cannot override another verified purchase.
                with self.memory.db() as db:
                    db.execute("UPDATE account_subscriptions SET checked_at=0 WHERE subject=? AND environment=? AND original_transaction_id=?",
                               (subject, row["environment"], row["original_transaction_id"]))
        with self.memory.db() as db:
            self.assert_active(authorization, db=db)
            self._update_lease(db, subject)
        return self.assert_active(authorization)

    def logout(self, subject, refresh_token):
        with self.memory.db() as db:
            row = db.execute("SELECT family FROM account_sessions WHERE subject=? AND refresh_hash=?",
                             (subject, self._digest(refresh_token))).fetchone()
            if row:
                db.execute("UPDATE account_sessions SET revoked=1 WHERE family=?", (row["family"],))
                self.memory.bump(db, subject)
        return {"logged_out": True}

    def session(self, subject):
        with self.memory.db() as db:
            row = db.execute("SELECT a.*,i.deleting FROM accounts a JOIN account_identities i ON i.subject=a.subject WHERE a.subject=?", (subject,)).fetchone()
            if not row or row["deleting"]:
                raise HTTPException(401, "Sign in to your account again.")
            subscriptions = db.execute("SELECT * FROM account_subscriptions WHERE subject=?", (subject,)).fetchall()
            active = self.memory.paid(row)
            expirations = [value["premium_until"] for value in subscriptions
                           if value["environment"] in self.subscriptions.environments
                           and min(value["premium_until"], value["checked_at"] + ENTITLEMENT_TTL) > self._now()]
            active = active and bool(expirations)
            return {"account_id": subject, "premium_until": max(expirations) if active else None, "premium_active": active}

    def _update_lease(self, db, subject):
        rows = db.execute("SELECT * FROM account_subscriptions WHERE subject=?", (subject,)).fetchall()
        lease = max((min(row["premium_until"], row["checked_at"] + ENTITLEMENT_TTL) for row in rows
                     if row["environment"] in self.subscriptions.environments), default=0)
        db.execute("UPDATE accounts SET premium_until=?,revision=revision+1 WHERE subject=? AND premium_until<>?", (lease, subject, lease))

    def _save_entitlement(self, subject, verified, *, authorization=None):
        if verified.environment not in STORE_ENVIRONMENTS or verified.environment not in self.subscriptions.environments:
            raise HTTPException(422, "The App Store environment is not enabled.")
        with self.memory.db() as db:
            if authorization:
                self.assert_active(authorization, db=db)
            row = db.execute("SELECT deleting FROM account_identities WHERE subject=?", (subject,)).fetchone()
            if not row or row[0]:
                raise HTTPException(401, "Sign in to your account again.")
            # Insert and check under the same write transaction: concurrent claims
            # cannot assign a guest purchase to two accounts.
            db.execute("INSERT OR IGNORE INTO account_purchase_owners VALUES(?,?,?)",
                       (verified.environment, verified.original_transaction_id, subject))
            owner = db.execute("SELECT subject FROM account_purchase_owners WHERE environment=? AND original_transaction_id=?",
                               (verified.environment, verified.original_transaction_id)).fetchone()
            if owner and owner[0] != subject:
                raise HTTPException(403, "This purchase is linked to another Omni account.")
            db.execute("""INSERT INTO account_subscriptions VALUES(?,?,?,?,?) ON CONFLICT(subject,environment)
                DO UPDATE SET original_transaction_id=excluded.original_transaction_id,premium_until=excluded.premium_until,checked_at=excluded.checked_at""",
                       (subject, verified.environment, verified.original_transaction_id, verified.premium_until, self._now()))
            db.execute("DELETE FROM account_subscriptions WHERE subject=? AND environment=''", (subject,))
            self._update_lease(db, subject)

    async def subscription(self, subject, signed_transaction, *, authorization=None):
        verified = await self.subscriptions.verify(subject, signed_transaction)
        self._save_entitlement(subject, verified, authorization=authorization)
        return self.session(subject)

    async def delete_account(self, subject):
        with self.memory.db() as db:
            row = db.execute("SELECT * FROM account_identities WHERE subject=?", (subject,)).fetchone()
            if not row or row["deleting"]:
                raise HTTPException(401, "Sign in to your account again.")
            if self.identity.require_exchange and not row["apple_refresh"]:
                raise HTTPException(409, "Sign in with Apple again before deleting your account.")
            encrypted = row["apple_refresh"]
            db.execute("UPDATE account_identities SET deleting=1 WHERE subject=?", (subject,))
            self.memory.bump(db, subject)
        try:
            if encrypted:
                await self.identity.revoke(self._decrypt(encrypted, subject))
        except BaseException:
            with self.memory.db() as db:
                db.execute("UPDATE account_identities SET deleting=0 WHERE subject=?", (subject,))
            raise
        with self.memory.db() as db:
            # Delete content, opaque identifier, subscriptions and every device session atomically.
            db.execute("DELETE FROM memories WHERE subject=?", (subject,))
            db.execute("DELETE FROM conversations WHERE subject=?", (subject,))
            if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='native_snapshots'").fetchone():
                db.execute("DELETE FROM native_snapshots WHERE subject=?", (subject,))
            db.execute("DELETE FROM account_sessions WHERE subject=?", (subject,))
            db.execute("DELETE FROM account_subscriptions WHERE subject=?", (subject,))
            db.execute("DELETE FROM account_purchase_owners WHERE subject=?", (subject,))
            db.execute("DELETE FROM account_identities WHERE subject=?", (subject,))
            db.execute("DELETE FROM rate_limits WHERE subject=?", (subject,))
            db.execute("DELETE FROM accounts WHERE subject=?", (subject,))
        return {"deleted": True, "apple_access_revoked": bool(encrypted)}
