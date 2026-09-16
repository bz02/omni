"""Synthetic RSA/JWS certificates and local HTTP transports; no Apple credentials or purchases."""
import asyncio
import base64
import hashlib
import json
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from urllib.parse import parse_qs

import httpx
import jwt
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import NameOID, ObjectIdentifier
from fastapi import HTTPException

from omni_memory.accounts import AccountService
from omni_memory.apple_identity import AppleIdentityVerifier
from omni_memory.apple_subscription import AppleSubscriptionVerifier
from omni_memory.auth import issue_session
from omni_memory.models import MemoryCreate
from omni_memory.service import MemoryService

SECRET = "synthetic-account-tests-Only-7x82xD09fA624kzR"
BUNDLE = "omni.ai.Omni"
PRODUCT = "omni.plus.monthly"
RSA = rsa.generate_private_key(public_exponent=65537, key_size=2048)
JWK = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(RSA.public_key())) | {"kid": "synthetic-apple-key", "alg": "RS256", "use": "sig"}


class Clock:
    now = 1800000000
    def __call__(self):
        return self.now


def run(value):
    return asyncio.run(value)


def apple_token(clock, nonce_hash, subject="synthetic-apple-sub", **changes):
    claims = {"iss": "https://appleid.apple.com", "aud": BUNDLE, "sub": subject,
              "iat": clock.now, "exp": clock.now + 300, "nonce": nonce_hash}
    claims.update(changes)
    return jwt.encode(claims, RSA, algorithm="RS256", headers={"kid": JWK["kid"]})


@pytest.fixture
def system(tmp_path):
    clock = Clock()
    requests = []
    def handler(request):
        requests.append(request)
        assert str(request.url) == "https://appleid.apple.com/auth/keys"
        return httpx.Response(200, json={"keys": [JWK]})
    identity = AppleIdentityVerifier(BUNDLE, require_exchange=False, clock=clock, transport=httpx.MockTransport(handler))
    memory = MemoryService(tmp_path / "private" / "memory.db", secret=SECRET, clock=clock)
    accounts = AccountService(memory, identity_verifier=identity, subscription_verifier=AppleSubscriptionVerifier(clock=clock))
    def login(subject="synthetic-apple-sub"):
        challenge = accounts.challenge("synthetic-client")
        token = apple_token(clock, hashlib.sha256(challenge["nonce"].encode()).hexdigest(), subject)
        return run(accounts.sign_in(challenge["challenge_id"], token))
    return accounts, memory, clock, login, requests


def test_signed_identity_creates_stable_private_uuid_with_unique_device_sessions(system):
    accounts, memory, _, login, requests = system
    first, second, other = login(), login(), login("another-apple-sub")
    assert str(uuid.UUID(first["account_id"])) == first["account_id"]
    assert first["account_id"] == second["account_id"] != other["account_id"]
    assert first["access_token"] != second["access_token"]
    assert len(requests) == 1
    assert run(accounts.authorize("Bearer " + first["access_token"])) == first["account_id"]
    with memory.db() as db:
        identity = dict(db.execute("SELECT * FROM account_identities WHERE subject=?", (first["account_id"],)).fetchone())
        rows = [dict(r) for r in db.execute("SELECT * FROM account_sessions")]
    assert "synthetic-apple-sub" not in str(identity)
    assert first["refresh_token"] not in str(rows) and first["access_token"] not in str(rows)
    assert accounts.session(first["account_id"])["premium_active"] is False


@pytest.mark.parametrize("changes", [
    {"aud": "wrong.app"}, {"iss": "https://attacker.example"}, {"nonce": "wrong"},
    {"exp": 1799999999}, {"iat": 1800000099}, {"iat": True}, {"exp": "1800000300"},
    {"sub": ""}, {"aud": [BUNDLE, "another-app"]}, {"nbf": 1800000500},
])
def test_identity_claim_validation_and_nonce_consumption(system, changes):
    accounts, _, clock, _, _ = system
    challenge = accounts.challenge("synthetic-client")
    nonce = hashlib.sha256(challenge["nonce"].encode()).hexdigest()
    with pytest.raises(HTTPException) as result:
        run(accounts.sign_in(challenge["challenge_id"], apple_token(clock, nonce, **changes)))
    assert result.value.status_code == 401
    with pytest.raises(HTTPException):
        run(accounts.sign_in(challenge["challenge_id"], apple_token(clock, nonce)))


def test_signature_tampering_and_algorithm_confusion_rejected(system):
    accounts, _, clock, _, _ = system
    for kind in ("tamper", "hs256", "unknown-key"):
        challenge = accounts.challenge("synthetic-client")
        nonce = hashlib.sha256(challenge["nonce"].encode()).hexdigest()
        valid = apple_token(clock, nonce)
        if kind == "tamper":
            parts = valid.split(".")
            decoded = jwt.decode(valid, options={"verify_signature": False})
            decoded["sub"] = "changed-subject"
            parts[1] = base64.urlsafe_b64encode(json.dumps(decoded).encode()).rstrip(b"=").decode()
            bad = ".".join(parts)
        elif kind == "hs256":
            bad = jwt.encode(jwt.decode(valid, options={"verify_signature": False}), "synthetic-attacker-secret", algorithm="HS256")
        else:
            bad = jwt.encode(jwt.decode(valid, options={"verify_signature": False}), RSA, algorithm="RS256", headers={"kid": "unknown"})
        with pytest.raises(HTTPException) as result:
            run(accounts.sign_in(challenge["challenge_id"], bad))
        assert result.value.status_code == 401


def test_challenge_expiration_and_rate_limit(system):
    accounts, _, clock, _, _ = system
    challenge = accounts.challenge("synthetic-client")
    clock.now += 301
    with pytest.raises(HTTPException) as expired:
        run(accounts.sign_in(challenge["challenge_id"], "unused"))
    assert expired.value.status_code == 401
    for _ in range(20):
        accounts.challenge("rate-client")
    with pytest.raises(HTTPException) as rate:
        accounts.challenge("rate-client")
    assert rate.value.status_code == 429


def test_rotate_refresh_replay_revokes_family_but_not_other_device(system):
    accounts, _, _, login, _ = system
    first, other = login(), login()
    rotated = accounts.refresh(first["refresh_token"])
    with pytest.raises(HTTPException):
        accounts.assert_active("Bearer " + first["access_token"])
    assert accounts.assert_active("Bearer " + rotated["access_token"]) == first["account_id"]
    with pytest.raises(HTTPException):
        accounts.refresh(first["refresh_token"])
    with pytest.raises(HTTPException):
        accounts.assert_active("Bearer " + rotated["access_token"])
    assert accounts.assert_active("Bearer " + other["access_token"]) == other["account_id"]


def test_logout_revokes_access_immediately_and_scopes_refresh_owner(system):
    accounts, _, _, login, _ = system
    first, other = login(), login("other")
    accounts.logout(first["account_id"], other["refresh_token"])
    assert accounts.assert_active("Bearer " + other["access_token"]) == other["account_id"]
    accounts.logout(first["account_id"], first["refresh_token"])
    with pytest.raises(HTTPException):
        accounts.assert_active("Bearer " + first["access_token"])


def test_operator_signed_but_unregistered_session_is_rejected(system):
    accounts, _, clock, login, _ = system
    user = login()
    unregistered = issue_session(user["account_id"], SECRET, now=clock.now)
    with pytest.raises(HTTPException) as failure:
        run(accounts.authorize("Bearer " + unregistered))
    assert failure.value.status_code == 401


def test_access_and_refresh_expire(system):
    accounts, _, clock, login, _ = system
    user = login()
    clock.now += 900
    with pytest.raises(HTTPException):
        accounts.assert_active("Bearer " + user["access_token"])
    rotated = accounts.refresh(user["refresh_token"])
    clock.now += 30 * 86400
    with pytest.raises(HTTPException):
        accounts.refresh(rotated["refresh_token"])


def test_missing_apple_or_secret_configuration_fails_closed(tmp_path):
    memory = MemoryService(tmp_path / "empty.db", secret="")
    accounts = AccountService(memory, identity_verifier=AppleIdentityVerifier(), subscription_verifier=AppleSubscriptionVerifier())
    with pytest.raises(HTTPException) as failure:
        accounts.challenge("client")
    assert failure.value.status_code == 503
    memory.secret = SECRET
    with pytest.raises(HTTPException) as failure:
        accounts.challenge("client")
    assert failure.value.status_code == 503


def make_store_signer(clock):
    from appstoreserverlibrary.models.Environment import Environment
    from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
    now = datetime.fromtimestamp(clock.now, timezone.utc)
    keys = [ec.generate_private_key(ec.SECP256R1()) for _ in range(3)]
    names = [x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Synthetic " + name)]) for name in ("Root", "Intermediate", "Leaf")]
    certs = []
    for index in range(3):
        issuer_index = max(0, index - 1)
        builder = (x509.CertificateBuilder().subject_name(names[index]).issuer_name(names[issuer_index])
                   .public_key(keys[index].public_key()).serial_number(x509.random_serial_number())
                   .not_valid_before(now - timedelta(days=1)).not_valid_after(now + timedelta(days=365))
                   .add_extension(x509.BasicConstraints(ca=index < 2, path_length=(1 - index) if index < 2 else None), critical=True)
                   .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False,
                                               data_encipherment=False, key_agreement=False, key_cert_sign=index < 2,
                                               crl_sign=index < 2, encipher_only=False, decipher_only=False), critical=True)
                   .add_extension(x509.SubjectKeyIdentifier.from_public_key(keys[index].public_key()), critical=False)
                   .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(keys[issuer_index].public_key()), critical=False))
        if index:
            oid = "1.2.840.113635.100.6.2.1" if index == 1 else "1.2.840.113635.100.6.11.1"
            builder = builder.add_extension(x509.UnrecognizedExtension(ObjectIdentifier(oid), b"\x05\x00"), critical=False)
        certs.append(builder.sign(keys[issuer_index], hashes.SHA256()))
    verifier = SignedDataVerifier([certs[0].public_bytes(serialization.Encoding.DER)], False, Environment.SANDBOX, BUNDLE)
    chain = [base64.b64encode(cert.public_bytes(serialization.Encoding.DER)).decode() for cert in reversed(certs)]
    def sign(subject, **changes):
        payload = {"transactionId": "10000000000002", "originalTransactionId": "10000000000001", "bundleId": BUNDLE,
                   "productId": PRODUCT, "appAccountToken": subject, "environment": "Sandbox", "signedDate": clock.now * 1000,
                   "expiresDate": (clock.now + 86400) * 1000, "type": "Auto-Renewable Subscription", "isUpgraded": False}
        payload.update(changes)
        return jwt.encode(payload, keys[2], algorithm="ES256", headers={"x5c": chain})
    return verifier, sign


def store(accounts, clock, subject, *, status=1, **transaction_changes):
    verifier, sign = make_store_signer(clock)
    current = {"signed": sign(subject, **transaction_changes), "status": status, "calls": 0, "error": False, "hook": None, "renewal": None}
    class Client:
        async def get_all_subscription_statuses(self, original):
            current["calls"] += 1
            if current["hook"]:
                current["hook"]()
            if current["error"]:
                raise RuntimeError("Synthetic App Store outage")
            assert original == "10000000000001"
            return SimpleNamespace(data=[SimpleNamespace(lastTransactions=[SimpleNamespace(signedTransactionInfo=current["signed"], signedRenewalInfo=current["renewal"], status=current["status"])])])
    accounts.subscriptions = AppleSubscriptionVerifier(verifier=verifier, client=Client(), products=[PRODUCT], environment="Sandbox", clock=clock)
    return current, sign


def test_official_store_jws_real_chain_and_account_binding(system):
    accounts, memory, clock, login, _ = system
    user, other = login(), login("other")
    current, sign = store(accounts, clock, user["account_id"])
    response = run(accounts.subscription(user["account_id"], current["signed"]))
    assert response["premium_active"] and response["premium_until"] == clock.now + 86400
    with memory.db() as db:
        assert memory.account(db, user["account_id"])["premium_until"] == clock.now + 300
    with pytest.raises(HTTPException) as wrong:
        run(accounts.subscription(other["account_id"], current["signed"]))
    assert wrong.value.status_code == 403
    tampered = current["signed"].split(".")
    tampered[2] = ("B" if tampered[2][0] == "A" else "A") + tampered[2][1:]
    with pytest.raises(HTTPException) as invalid:
        run(accounts.subscription(user["account_id"], ".".join(tampered)))
    assert invalid.value.status_code == 422


@pytest.mark.parametrize("status,changes", [(2, {}), (3, {}), (4, {}), (5, {}), (1, {"revocationDate": 1800000000000}),
                                         (1, {"expiresDate": 1799999999000}), (1, {"isUpgraded": True})])
def test_expired_revoked_grace_retry_and_superseded_do_not_grant_plus(system, status, changes):
    accounts, _, clock, login, _ = system
    user = login()
    current, _ = store(accounts, clock, user["account_id"], status=status, **changes)
    response = run(accounts.subscription(user["account_id"], current["signed"]))
    assert response["premium_active"] is False


def test_subscription_refresh_catches_refund_and_upstream_failure_keeps_data_control(system):
    accounts, memory, clock, login, _ = system
    user = login()
    current, _ = store(accounts, clock, user["account_id"])
    run(accounts.subscription(user["account_id"], current["signed"]))
    memory.set_settings(user["account_id"], True)
    saved = memory.create_memory(user["account_id"], MemoryCreate(kind="preference", text="Quiet mornings", confirmed=True))
    clock.now += 301
    current["status"] = 5
    assert run(accounts.authorize("Bearer " + user["access_token"])) == user["account_id"]
    assert not accounts.session(user["account_id"])["premium_active"]
    current["status"] = 1
    run(accounts.subscription(user["account_id"], current["signed"]))
    clock.now += 301
    current["error"] = True
    assert run(accounts.authorize("Bearer " + user["access_token"])) == user["account_id"]
    assert not accounts.session(user["account_id"])["premium_active"]
    assert memory.export(user["account_id"])["memories"][0]["id"] == saved["id"]
    memory.delete_memory(user["account_id"], saved["id"])


def test_inflight_subscription_cannot_restore_logged_out_session(system):
    accounts, _, clock, login, _ = system
    user = login()
    current, _ = store(accounts, clock, user["account_id"])
    current["hook"] = lambda: accounts.logout(user["account_id"], user["refresh_token"])
    with pytest.raises(HTTPException) as expired:
        run(accounts.subscription(user["account_id"], current["signed"], authorization="Bearer " + user["access_token"]))
    assert expired.value.status_code == 401
    assert not accounts.session(user["account_id"])["premium_active"]


@pytest.mark.parametrize("change,active", [({}, True), ({"gracePeriodExpiresDate": 1799999999000}, False),
    ({"originalTransactionId": "10000000009999"}, False), ({"productId": "another.product"}, False),
    ({"appAccountToken": "00000000-0000-0000-0000-000000000099"}, False)])
def test_official_signed_billing_grace_requires_matching_unexpired_renewal(system, change, active):
    accounts, _, clock, login, _ = system
    user = login()
    current, sign = store(accounts, clock, user["account_id"], status=4, expiresDate=(clock.now - 10) * 1000)
    # Same real synthetic Apple certificate chain signs both JWS payloads; official renewal decoder verifies it.
    values = {"gracePeriodExpiresDate": (clock.now + 3600) * 1000}
    values.update(change)
    current["renewal"] = sign(user["account_id"], **values)
    response = run(accounts.subscription(user["account_id"], current["signed"]))
    assert response["premium_active"] is active
    if active:
        assert response["premium_until"] == clock.now + 3600


def test_full_apple_oauth_exchange_encrypt_and_revoke_before_account_delete(tmp_path):
    clock, events, state = Clock(), [], {}
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    def handler(request):
        events.append(request.url.path)
        if request.url.path.endswith("keys"):
            return httpx.Response(200, json={"keys": [JWK]})
        data = parse_qs(request.content.decode())
        secret = jwt.decode(data["client_secret"][0], key.public_key(), algorithms=["ES256"], audience="https://appleid.apple.com",
                            options={"verify_exp": False, "verify_iat": False})
        assert secret["sub"] == BUNDLE and secret["iss"] == "SYNTHETIC_TEAM"
        if request.url.path.endswith("token"):
            assert data["code"] == ["synthetic-single-use-code"]
            return httpx.Response(200, json={"id_token": state["token"], "refresh_token": "synthetic-apple-refresh-secret"})
        assert data["token"] == ["synthetic-apple-refresh-secret"]
        if state.get("fail_revoke"):
            return httpx.Response(503)
        return httpx.Response(200)
    identity = AppleIdentityVerifier(BUNDLE, team_id="SYNTHETIC_TEAM", key_id="SYNTHETIC_KEY", private_key=pem,
                                     clock=clock, transport=httpx.MockTransport(handler))
    memory = MemoryService(tmp_path / "private.db", secret=SECRET, clock=clock)
    accounts = AccountService(memory, identity_verifier=identity, subscription_verifier=AppleSubscriptionVerifier(clock=clock))
    challenge = accounts.challenge("client")
    state["token"] = apple_token(clock, hashlib.sha256(challenge["nonce"].encode()).hexdigest())
    user = run(accounts.sign_in(challenge["challenge_id"], state["token"], "synthetic-single-use-code"))
    with memory.db() as db:
        encrypted = db.execute("SELECT apple_refresh FROM account_identities").fetchone()[0]
    assert b"synthetic-apple-refresh-secret" not in encrypted
    state["fail_revoke"] = True
    with pytest.raises(HTTPException) as failed:
        run(accounts.delete_account(user["account_id"]))
    assert failed.value.status_code == 503
    assert accounts.assert_active("Bearer " + user["access_token"]) == user["account_id"]
    state["fail_revoke"] = False
    result = run(accounts.delete_account(user["account_id"]))
    assert result == {"deleted": True, "apple_access_revoked": True}
    assert events[-1] == "/auth/revoke"
    with pytest.raises(HTTPException):
        accounts.assert_active("Bearer " + user["access_token"])
    with pytest.raises(HTTPException):
        accounts.refresh(user["refresh_token"])
    with memory.db() as db:
        assert db.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] == 0
        assert db.execute("SELECT COUNT(*) FROM account_identities").fetchone()[0] == 0


def test_delete_clears_native_snapshot_and_new_login_is_new_account(system):
    accounts, memory, _, login, _ = system
    user = login()
    with memory.db() as db:
        db.execute("CREATE TABLE native_snapshots(subject TEXT PRIMARY KEY, archive TEXT)")
        db.execute("INSERT INTO native_snapshots VALUES(?,?)", (user["account_id"], "synthetic-private-data"))
    run(accounts.delete_account(user["account_id"]))
    with memory.db() as db:
        assert db.execute("SELECT COUNT(*) FROM native_snapshots").fetchone()[0] == 0
    assert login()["account_id"] != user["account_id"]
