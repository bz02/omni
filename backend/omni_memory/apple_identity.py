"""Sign in with Apple verification. Only fixed Apple endpoints receive credentials."""
from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import os
import time
from dataclasses import dataclass
from pathlib import Path

import httpx
import jwt
from fastapi import HTTPException


@dataclass(frozen=True)
class AppleIdentity:
    subject: str
    refresh_token: str | None = None


class AppleIdentityVerifier:
    def __init__(self, audience="", *, team_id="", key_id="", private_key: bytes = b"", clock=time.time,
                 transport=None, require_exchange=True):
        self.audience, self.team_id, self.key_id, self.private_key = audience, team_id, key_id, private_key
        self.clock, self.transport, self.require_exchange = clock, transport, require_exchange
        self._keys, self._keys_until, self._last_fetch = {}, 0, -1000
        self._lock = None

    @classmethod
    def from_env(cls, *, clock=time.time):
        path = os.environ.get("OMNI_APPLE_SIGNIN_KEY_PATH", "")
        return cls(os.environ.get("OMNI_APPLE_BUNDLE_ID", ""), team_id=os.environ.get("OMNI_APPLE_TEAM_ID", ""),
                   key_id=os.environ.get("OMNI_APPLE_SIGNIN_KEY_ID", ""),
                   private_key=Path(path).read_bytes() if path else b"", clock=clock)

    @property
    def configured(self):
        return bool(self.audience and (not self.require_exchange or (self.team_id and self.key_id and self.private_key)))

    async def _request(self, method, path, **kwargs):
        try:
            async with httpx.AsyncClient(timeout=10, follow_redirects=False, transport=self.transport, trust_env=False) as client:
                async with client.stream(method, "https://appleid.apple.com/auth/" + path, **kwargs) as response:
                    if response.status_code != 200:
                        raise HTTPException(503, "Apple account verification is temporarily unavailable.")
                    chunks, size = [], 0
                    async for chunk in response.aiter_bytes():
                        size += len(chunk)
                        if size > 65536:
                            raise ValueError()
                        chunks.append(chunk)
                    if path == "revoke":
                        return {}
                    value = json.loads(b"".join(chunks))
                    if not isinstance(value, dict):
                        raise ValueError()
                    return value
        except (httpx.HTTPError, ValueError, TypeError):
            raise HTTPException(503, "Apple account verification is temporarily unavailable.") from None

    async def _key(self, kid):
        now = int(self.clock())
        if kid in self._keys and now < self._keys_until:
            return self._keys[kid]
        if self._lock is None:
            self._lock = asyncio.Lock()
        async with self._lock:
            if kid in self._keys and now < self._keys_until:
                return self._keys[kid]
            # Bound unknown-key attacks; a newly rotated Apple key may require a one-minute retry.
            if now - self._last_fetch < 60:
                raise HTTPException(401, "Apple identity could not be verified.")
            self._last_fetch = now
            values = (await self._request("GET", "keys")).get("keys")
            try:
                if not isinstance(values, list) or not 1 <= len(values) <= 20:
                    raise ValueError()
                keys = {}
                for value in values:
                    if value.get("alg") == "RS256" and value.get("kty") == "RSA" and value.get("use") == "sig":
                        key = jwt.PyJWK.from_dict(value).key
                        if key.key_size >= 2048:
                            keys[value["kid"]] = key
                self._keys, self._keys_until = keys, now + 3600
            except (ValueError, TypeError, KeyError, AttributeError, jwt.PyJWTError):
                raise HTTPException(503, "Apple account verification is temporarily unavailable.") from None
            if kid not in self._keys:
                raise HTTPException(401, "Apple identity could not be verified.")
            return self._keys[kid]

    async def _verify_token(self, token, nonce_hash):
        try:
            if not isinstance(token, str) or not 1 <= len(token) <= 16384:
                raise ValueError()
            header = jwt.get_unverified_header(token)
            if header.get("alg") != "RS256" or not isinstance(header.get("kid"), str) or len(header["kid"]) > 128:
                raise ValueError()
            claims = jwt.decode(token, await self._key(header["kid"]), algorithms=["RS256"], audience=self.audience,
                                issuer="https://appleid.apple.com", options={"verify_exp": False, "verify_iat": False,
                                "verify_nbf": False, "require": ["sub", "iat", "exp", "aud", "iss", "nonce"]})
            now = int(self.clock())
            if (claims.get("aud") != self.audience or type(claims["iat"]) is not int or type(claims["exp"]) is not int
                    or not now - 600 <= claims["iat"] <= now + 30 or not now < claims["exp"]
                    or not isinstance(claims["sub"], str) or not 1 <= len(claims["sub"]) <= 256
                    or not isinstance(claims["nonce"], str) or not hmac.compare_digest(claims["nonce"], nonce_hash)):
                raise ValueError()
            if "nbf" in claims and (type(claims["nbf"]) is not int or claims["nbf"] > now):
                raise ValueError()
            return claims["sub"]
        except (ValueError, TypeError, KeyError, jwt.PyJWTError):
            raise HTTPException(401, "Apple identity could not be verified.") from None

    def _client_secret(self):
        now = int(self.clock())
        try:
            return jwt.encode({"iss": self.team_id, "iat": now, "exp": now + 120,
                               "aud": "https://appleid.apple.com", "sub": self.audience}, self.private_key,
                              algorithm="ES256", headers={"kid": self.key_id})
        except (ValueError, TypeError, jwt.PyJWTError):
            raise HTTPException(503, "Apple account verification is not configured.") from None

    async def verify(self, identity_token, nonce_hash, authorization_code=None):
        if not self.configured:
            raise HTTPException(503, "Apple account verification is not configured.")
        subject = await self._verify_token(identity_token, nonce_hash)
        if not self.require_exchange:
            return AppleIdentity(subject)
        if not isinstance(authorization_code, str) or not 1 <= len(authorization_code) <= 4096:
            raise HTTPException(422, "An Apple authorization code is required.")
        value = await self._request("POST", "token", data={"client_id": self.audience, "client_secret": self._client_secret(),
                                     "code": authorization_code, "grant_type": "authorization_code"})
        verified_subject = await self._verify_token(value.get("id_token"), nonce_hash)
        refresh = value.get("refresh_token")
        if verified_subject != subject or not isinstance(refresh, str) or not 1 <= len(refresh) <= 8192:
            raise HTTPException(401, "Apple identity could not be verified.")
        return AppleIdentity(subject, refresh)

    async def revoke(self, refresh_token):
        if not refresh_token or not self.configured:
            raise HTTPException(503, "Apple account revocation is not configured.")
        await self._request("POST", "revoke", data={"client_id": self.audience, "client_secret": self._client_secret(),
                            "token": refresh_token, "token_type_hint": "refresh_token"})
