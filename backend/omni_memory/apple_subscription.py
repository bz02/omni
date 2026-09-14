"""Current Apple subscription status, with official certificate/JWS verification."""
from __future__ import annotations

import asyncio
import os
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

import httpx
from fastapi import HTTPException


@dataclass(frozen=True)
class VerifiedEntitlement:
    original_transaction_id: str
    premium_until: int


class AppleSubscriptionVerifier:
    def __init__(self, *, verifier=None, client=None, products=(), clock=time.time):
        self.verifier, self.client, self.products, self.clock = verifier, client, frozenset(products), clock

    @property
    def configured(self):
        return bool(self.verifier and self.client and self.products)

    @classmethod
    def from_env(cls, *, clock=time.time):
        names = ("OMNI_APPLE_BUNDLE_ID", "OMNI_APPLE_IAP_KEY_PATH", "OMNI_APPLE_IAP_KEY_ID", "OMNI_APPLE_ISSUER_ID",
                 "OMNI_APPLE_ROOT_CERTIFICATES", "OMNI_APPLE_PLUS_PRODUCT_IDS", "OMNI_APPLE_STORE_ENVIRONMENT")
        values = [os.environ.get(name, "") for name in names]
        if not all(values):
            return cls(clock=clock)
        bundle, path, key, issuer, roots, products, environment = values
        if environment not in ("Production", "Sandbox"):
            raise ValueError("Apple store environment must explicitly be Production or Sandbox.")
        from appstoreserverlibrary.api_client import AsyncAppStoreServerAPIClient
        from appstoreserverlibrary.models.Environment import Environment
        from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
        app_id = os.environ.get("OMNI_APPLE_APP_ID", "")
        if environment == "Production" and not app_id:
            raise ValueError("OMNI_APPLE_APP_ID is required in Production.")
        env = Environment(environment)
        verifier = SignedDataVerifier([Path(p).read_bytes() for p in roots.split(os.pathsep)], True, env, bundle,
                                      int(app_id) if app_id else None)
        client = AsyncAppStoreServerAPIClient(Path(path).read_bytes(), key, issuer, bundle, env)
        # Apple's library exposes its HTTP client; use a bounded private connection without proxy env or redirects.
        client.http_client = httpx.AsyncClient(timeout=10, follow_redirects=False, trust_env=False)
        return cls(verifier=verifier, client=client, products=[p.strip() for p in products.split(",") if p.strip()], clock=clock)

    async def _decode(self, signed, *, renewal=False):
        if not isinstance(signed, str) or not 1 <= len(signed) <= 32768:
            raise HTTPException(422, "A signed App Store transaction is required.")
        try:
            # Official verifier includes online certificate revocation checks, which use blocking I/O.
            method = self.verifier.verify_and_decode_renewal_info if renewal else self.verifier.verify_and_decode_signed_transaction
            return await asyncio.to_thread(method, signed)
        except Exception:
            raise HTTPException(422, "The App Store transaction could not be verified.") from None

    @staticmethod
    def _same_account(transaction, subject):
        try:
            return uuid.UUID(transaction.appAccountToken) == uuid.UUID(subject)
        except (AttributeError, ValueError, TypeError):
            return False

    async def verify(self, subject, signed_transaction):
        if not self.configured:
            raise HTTPException(503, "App Store subscription verification is not configured.")
        transaction = await self._decode(signed_transaction)
        if not self._same_account(transaction, subject):
            raise HTTPException(403, "This purchase is not linked to the signed-in Omni account.")
        if transaction.productId not in self.products or not transaction.originalTransactionId:
            raise HTTPException(422, "This purchase does not provide Omni Plus.")
        return await self.status(subject, str(transaction.originalTransactionId))

    async def status(self, subject, original_transaction_id):
        if not self.configured:
            raise HTTPException(503, "App Store subscription verification is not configured.")
        if not isinstance(original_transaction_id, str) or not original_transaction_id.isdigit() or len(original_transaction_id) > 64:
            raise HTTPException(422, "Invalid App Store transaction identifier.")
        try:
            response = await self.client.get_all_subscription_statuses(original_transaction_id)
        except Exception:
            raise HTTPException(503, "App Store subscription verification is temporarily unavailable.") from None
        maximum, now = 0, int(self.clock())
        groups = response.data or []
        if len(groups) > 100:
            raise HTTPException(503, "App Store subscription verification is temporarily unavailable.")
        for group in groups:
            if len(group.lastTransactions or []) > 100:
                raise HTTPException(503, "App Store subscription verification is temporarily unavailable.")
            for value in group.lastTransactions or []:
                transaction = await self._decode(value.signedTransactionInfo)
                if not self._same_account(transaction, subject) or transaction.productId not in self.products:
                    continue
                if str(transaction.originalTransactionId) != original_transaction_id:
                    continue
                status = getattr(value.status, "value", value.status)
                if status not in (1, 4) or transaction.revocationDate is not None or transaction.isUpgraded:
                    continue
                expiration = transaction.expiresDate
                if status == 4:
                    signed_renewal = getattr(value, "signedRenewalInfo", None)
                    if not signed_renewal:
                        continue
                    renewal = await self._decode(signed_renewal, renewal=True)
                    if (str(renewal.originalTransactionId) != original_transaction_id
                            or renewal.productId != transaction.productId
                            or (renewal.appAccountToken is not None and not self._same_account(renewal, subject))):
                        continue
                    expiration = renewal.gracePeriodExpiresDate
                if type(expiration) is int and expiration // 1000 > now:
                    maximum = max(maximum, expiration // 1000)
        return VerifiedEntitlement(original_transaction_id, maximum)
