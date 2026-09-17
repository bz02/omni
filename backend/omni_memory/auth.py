"""First-party session verification. This is not a public login endpoint."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import time

from fastapi import HTTPException

AUDIENCE = "omni-memory"
MAX_TTL = 900
SUBJECT = re.compile(r"[A-Za-z0-9_-]{1,128}\Z")


def valid_secret(secret: str) -> bool:
    return len(secret.encode()) >= 32 and len(set(secret)) >= 12


def b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def issue_session(subject: str, secret: str, *, now: int | None = None, ttl: int = 900) -> str:
    """Called only by a trusted account service or local operator, never by an API route."""
    if not valid_secret(secret) or not SUBJECT.fullmatch(subject) or not 1 <= ttl <= MAX_TTL:
        raise ValueError("A strong secret, opaque subject and TTL of 1–900 seconds are required.")
    now = int(time.time()) if now is None else now
    header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64(json.dumps({"sub": subject, "iat": now, "exp": now + ttl, "aud": AUDIENCE}, separators=(",", ":")).encode())
    signed = f"{header}.{payload}"
    return f"{signed}.{b64(hmac.new(secret.encode(), signed.encode(), hashlib.sha256).digest())}"


def verify_session(authorization: str, secret: str, *, now: int | None = None) -> str:
    if not valid_secret(secret):
        raise HTTPException(503, "Account authentication is not configured.")
    try:
        if len(authorization) > 4096 or not authorization.startswith("Bearer "):
            raise ValueError()
        header, payload, signature = authorization[7:].split(".")
        expected = b64(hmac.new(secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            raise ValueError()
        decode = lambda value: json.loads(base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)))
        meta, claims = decode(header), decode(payload)
        if meta != {"alg": "HS256", "typ": "JWT"}:
            raise ValueError()
        stamp = int(time.time()) if now is None else now
        if claims.get("aud") != AUDIENCE or not isinstance(claims.get("sub"), str) or not SUBJECT.fullmatch(claims["sub"]):
            raise ValueError()
        if type(claims.get("iat")) is not int or type(claims.get("exp")) is not int:
            raise ValueError()
        if not (claims["iat"] <= stamp < claims["exp"] <= claims["iat"] + MAX_TTL):
            raise ValueError()
        return claims["sub"]
    except (ValueError, TypeError, KeyError, UnicodeError, AttributeError):
        raise HTTPException(401, "A valid account session is required.") from None
