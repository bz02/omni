"""Current Apple subscription status, with official certificate/JWS verification."""
from __future__ import annotations

import asyncio
import os
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

import httpx
from appstoreserverlibrary.signed_data_verifier import VerificationException, VerificationStatus
from fastapi import HTTPException

STORE_ENVIRONMENTS = frozenset({"Production", "Sandbox"})


@dataclass(frozen=True)
class VerifiedEntitlement:
    original_transaction_id: str
    premium_until: int
    environment: str


class AppleSubscriptionVerifier:
    def __init__(self, *, verifier=None, client=None, products=(), environment=None, clock=time.time):
        self.verifier, self.client, self.products, self.clock = verifier, client, frozenset(products), clock
        self.environment = environment

    @property
    def environments(self):
        return (frozenset({self.environment})
                if self.environment in STORE_ENVIRONMENTS and self.verifier and self.client and self.products else frozenset())

    @property
    def configured(self):
        return bool(self.verifier and self.client and self.products and self.environments)

    @classmethod
    def from_env(cls, *, clock=time.time):
        names = ("OMNI_APPLE_BUNDLE_ID", "OMNI_APPLE_IAP_KEY_PATH", "OMNI_APPLE_IAP_KEY_ID", "OMNI_APPLE_ISSUER_ID",
                 "OMNI_APPLE_ROOT_CERTIFICATES", "OMNI_APPLE_PLUS_PRODUCT_IDS", "OMNI_APPLE_STORE_ENVIRONMENT")
        values = [os.environ.get(name, "") for name in names]
        if not all(values):
            return cls(clock=clock)
        bundle, path, key, issuer, roots, products, environment = values
        if environment not in (*STORE_ENVIRONMENTS, "ProductionAndSandbox"):
            raise ValueError("Apple store environment must explicitly be Production, Sandbox or ProductionAndSandbox.")
        from appstoreserverlibrary.api_client import AsyncAppStoreServerAPIClient
        from appstoreserverlibrary.models.Environment import Environment
        from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
        app_id = os.environ.get("OMNI_APPLE_APP_ID", "")
        environments = ("Production", "Sandbox") if environment == "ProductionAndSandbox" else (environment,)
        if "Production" in environments and (not app_id.isdigit() or int(app_id) <= 0):
            raise ValueError("OMNI_APPLE_APP_ID is required in Production.")
        root_certificates, private_key = [Path(p).read_bytes() for p in roots.split(os.pathsep)], Path(path).read_bytes()
        services = {}
        for name in environments:
            env = Environment(name)
            verifier = SignedDataVerifier(root_certificates, True, env, bundle, int(app_id) if app_id else None)
            client = AsyncAppStoreServerAPIClient(private_key, key, issuer, bundle, env)
            # Apple's library exposes its HTTP client; no proxy env or redirects receive credentials.
            client.http_client = httpx.AsyncClient(timeout=10, follow_redirects=False, trust_env=False)
            services[name] = cls(verifier=verifier, client=client, products=[p.strip() for p in products.split(",") if p.strip()],
                                 environment=name, clock=clock)
        return DualEnvironmentSubscriptions(services) if len(services) == 2 else services[environment]

    async def _decode(self, signed, *, renewal=False, allow_environment_mismatch=False):
        if not isinstance(signed, str) or not 1 <= len(signed) <= 32768:
            raise HTTPException(422, "A signed App Store transaction is required.")
        try:
            # Official verifier includes online certificate revocation checks, which use blocking I/O.
            method = self.verifier.verify_and_decode_renewal_info if renewal else self.verifier.verify_and_decode_signed_transaction
            return await asyncio.to_thread(method, signed)
        except VerificationException as error:
            # This status follows certificate/signature/bundle verification in Apple's library.
            # Only the dual-environment entry point may use it to select another strict verifier.
            if allow_environment_mismatch and error.status == VerificationStatus.INVALID_ENVIRONMENT:
                raise
            raise HTTPException(422, "The App Store transaction could not be verified.") from None
        except Exception:
            raise HTTPException(422, "The App Store transaction could not be verified.") from None

    @staticmethod
    def _same_account(transaction, subject):
        try:
            return uuid.UUID(transaction.appAccountToken) == uuid.UUID(subject)
        except (AttributeError, ValueError, TypeError):
            return False

    @classmethod
    def _account_eligible(cls, transaction, subject):
        # Guest StoreKit purchases legitimately omit appAccountToken. A verified
        # guest purchase is claimed once by AccountService's durable owner ledger.
        # A present token must still match; malformed/other-account tokens fail closed.
        return transaction.appAccountToken is None or cls._same_account(transaction, subject)

    async def verify(self, subject, signed_transaction):
        if not self.configured:
            raise HTTPException(503, "App Store subscription verification is not configured.")
        transaction = await self._decode(signed_transaction)
        return await self._verify_decoded(subject, transaction)

    async def _verify_decoded(self, subject, transaction):
        if not self._account_eligible(transaction, subject):
            raise HTTPException(403, "This purchase is not linked to the signed-in Omni account.")
        if transaction.productId not in self.products or not transaction.originalTransactionId:
            raise HTTPException(422, "This purchase does not provide Omni Plus.")
        return await self.status(subject, str(transaction.originalTransactionId))

    async def status(self, subject, original_transaction_id, *, environment=None):
        if not self.configured:
            raise HTTPException(503, "App Store subscription verification is not configured.")
        if environment is not None and environment != self.environment:
            raise HTTPException(422, "The App Store environment is not enabled.")
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
                if not self._account_eligible(transaction, subject) or transaction.productId not in self.products:
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
        return VerifiedEntitlement(original_transaction_id, maximum, self.environment)


class DualEnvironmentSubscriptions:
    """Accept Apple's signed review/sandbox purchases without weakening production verification."""

    def __init__(self, services):
        self.services = dict(services)
        if set(self.services) != STORE_ENVIRONMENTS or any(service.environment != name for name, service in self.services.items()):
            raise ValueError("Both strict App Store environments are required.")

    @property
    def configured(self):
        return all(service.configured for service in self.services.values())

    @property
    def environments(self):
        return STORE_ENVIRONMENTS if self.configured else frozenset()

    async def verify(self, subject, signed_transaction):
        if not self.configured:
            raise HTTPException(503, "App Store subscription verification is not configured.")
        production = self.services["Production"]
        try:
            transaction = await production._decode(signed_transaction, allow_environment_mismatch=True)
        except VerificationException as error:
            if error.status != VerificationStatus.INVALID_ENVIRONMENT:
                raise HTTPException(422, "The App Store transaction could not be verified.") from None
            # No unsigned environment field, client flag, general validation failure or API outage routes a purchase.
            return await self.services["Sandbox"].verify(subject, signed_transaction)
        return await production._verify_decoded(subject, transaction)

    async def status(self, subject, original_transaction_id, *, environment=None):
        if environment not in self.services:
            raise HTTPException(422, "Verify this App Store purchase again.")
        # Persisted environment came from successful JWS verification; never probe the other API on failure.
        return await self.services[environment].status(subject, original_transaction_id, environment=environment)
