"""Real synthetic certificate chains; no credentials, Apple calls or test-environment bypass."""
import base64
import json
from types import SimpleNamespace

import jwt
import pytest
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
from fastapi import HTTPException

from omni_memory.accounts import AccountService
from omni_memory.apple_subscription import AppleSubscriptionVerifier, DualEnvironmentSubscriptions
from omni_memory.models import MemoryCreate
from test_accounts import BUNDLE, PRODUCT, make_store_signer, run, system


def dual_store(accounts, clock, subject):
    sandbox, sign = make_store_signer(clock)
    roots = sandbox._chain_verifier.root_certificates
    verifiers = {"Sandbox": sandbox,
                 "Production": SignedDataVerifier(roots, False, Environment.PRODUCTION, BUNDLE, 6812658396)}
    state, services = {}, {}
    for environment, verifier in verifiers.items():
        current = {"signed": sign(subject, environment=environment), "renewal": None, "status": 1,
                   "calls": [], "decodes": 0, "error": False}
        state[environment] = current

        class CountingVerifier:
            def __init__(self, delegate, value):
                self.delegate, self.value = delegate, value

            def verify_and_decode_signed_transaction(self, signed):
                self.value["decodes"] += 1
                return self.delegate.verify_and_decode_signed_transaction(signed)

            def verify_and_decode_renewal_info(self, signed):
                return self.delegate.verify_and_decode_renewal_info(signed)

        class Client:
            def __init__(self, value):
                self.value = value

            async def get_all_subscription_statuses(self, original):
                self.value["calls"].append(original)
                if self.value["error"]:
                    raise RuntimeError("Synthetic outage")
                return SimpleNamespace(data=[SimpleNamespace(lastTransactions=[SimpleNamespace(
                    signedTransactionInfo=self.value["signed"], signedRenewalInfo=self.value["renewal"], status=self.value["status"])])])

        services[environment] = AppleSubscriptionVerifier(verifier=CountingVerifier(verifier, current), client=Client(current),
                                                          products=[PRODUCT], environment=environment, clock=clock)
    accounts.subscriptions = DualEnvironmentSubscriptions(services)
    return state, sign


@pytest.mark.parametrize("environment", ["Production", "Sandbox"])
def test_both_signed_environments_route_to_matching_status_api_and_persist(system, environment):
    accounts, memory, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    result = run(accounts.subscription(user["account_id"], state[environment]["signed"]))
    assert result["premium_active"]
    assert len(state[environment]["calls"]) == 1
    other = "Sandbox" if environment == "Production" else "Production"
    assert not state[other]["calls"]
    with memory.db() as db:
        row = db.execute("SELECT * FROM account_subscriptions").fetchone()
        assert row["environment"] == environment
    clock.now += 301
    state[environment]["status"] = 5
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert len(state[environment]["calls"]) == 2 and not state[other]["calls"]
    assert not accounts.session(user["account_id"])["premium_active"]


@pytest.mark.parametrize("kind", ["tampered", "unsigned", "wrong_bundle", "wrong_chain"])
def test_invalid_signatures_or_bundle_never_fall_back_to_sandbox(system, kind):
    accounts, _, clock, login, _ = system
    user = login()
    state, sign = dual_store(accounts, clock, user["account_id"])
    signed = state["Sandbox"]["signed"]
    if kind == "tampered":
        parts = signed.split(".")
        claims = jwt.decode(signed, options={"verify_signature": False})
        claims["expiresDate"] += 100000
        parts[1] = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
        signed = ".".join(parts)
    elif kind == "unsigned":
        signed = jwt.encode({"environment": "Sandbox", "bundleId": BUNDLE}, "", algorithm="none")
    elif kind == "wrong_bundle":
        signed = sign(user["account_id"], bundleId="different.app")
    else:
        _, foreign_sign = make_store_signer(clock)
        signed = foreign_sign(user["account_id"])
    with pytest.raises(HTTPException) as failure:
        run(accounts.subscription(user["account_id"], signed))
    assert failure.value.status_code == 422
    assert state["Sandbox"]["decodes"] == 0
    assert all(not value["calls"] for value in state.values())
    assert not accounts.session(user["account_id"])["premium_active"]


@pytest.mark.parametrize("environment", ["Xcode", "LocalTesting", "Unrecognized"])
def test_non_apple_store_environments_never_gain_entitlement(system, environment):
    accounts, _, clock, login, _ = system
    user = login()
    state, sign = dual_store(accounts, clock, user["account_id"])
    with pytest.raises(HTTPException) as failure:
        run(accounts.subscription(user["account_id"], sign(user["account_id"], environment=environment)))
    assert failure.value.status_code == 422
    assert all(not value["calls"] for value in state.values())


@pytest.mark.parametrize("environment", ["Production", "Sandbox"])
@pytest.mark.parametrize("change", [{"appAccountToken": "00000000-0000-0000-0000-000000000099"}, {"productId": "different.product"}])
def test_both_environments_reject_other_accounts_and_products(system, environment, change):
    accounts, _, clock, login, _ = system
    user = login()
    state, sign = dual_store(accounts, clock, user["account_id"])
    with pytest.raises(HTTPException):
        run(accounts.subscription(user["account_id"], sign(user["account_id"], environment=environment, **change)))
    assert all(not value["calls"] for value in state.values())
    assert not accounts.session(user["account_id"])["premium_active"]


@pytest.mark.parametrize("response_part", ["transaction", "renewal", "outage"])
def test_production_status_failure_or_cross_environment_payload_cannot_fall_back(system, response_part):
    accounts, _, clock, login, _ = system
    user = login()
    state, sign = dual_store(accounts, clock, user["account_id"])
    submitted = state["Production"]["signed"]
    if response_part == "transaction":
        state["Production"]["signed"] = state["Sandbox"]["signed"]
    elif response_part == "renewal":
        state["Production"]["status"] = 4
        state["Production"]["renewal"] = sign(user["account_id"], gracePeriodExpiresDate=(clock.now + 3600) * 1000)
    else:
        state["Production"]["error"] = True
    with pytest.raises(HTTPException):
        run(accounts.subscription(user["account_id"], submitted))
    assert state["Sandbox"]["decodes"] == 0 and not state["Sandbox"]["calls"]
    assert not accounts.session(user["account_id"])["premium_active"]


def test_two_environments_do_not_overwrite_each_other_and_restart_keeps_routing(system):
    accounts, memory, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    for environment in ("Production", "Sandbox"):
        run(accounts.subscription(user["account_id"], state[environment]["signed"]))
    with memory.db() as db:
        assert db.execute("SELECT COUNT(*) FROM account_subscriptions").fetchone()[0] == 2
    # The same transaction number in distinct signed environments is namespaced.
    accounts = AccountService(memory, identity_verifier=accounts.identity, subscription_verifier=accounts.subscriptions)
    clock.now += 301
    state["Sandbox"]["error"] = True
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert accounts.session(user["account_id"])["premium_active"]
    assert all(len(value["calls"]) == 2 for value in state.values())
    state["Production"]["status"] = 5
    clock.now += 301
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert not accounts.session(user["account_id"])["premium_active"]


def test_same_environment_purchase_binding_cannot_move_to_another_account(system):
    accounts, _, clock, login, _ = system
    user, other = login(), login("other")
    state, sign = dual_store(accounts, clock, user["account_id"])
    run(accounts.subscription(user["account_id"], state["Production"]["signed"]))
    state["Production"]["signed"] = sign(other["account_id"], environment="Production")
    with pytest.raises(HTTPException) as failure:
        run(accounts.subscription(other["account_id"], state["Production"]["signed"]))
    assert failure.value.status_code == 403
    # A genuinely signed other-environment transaction with that number remains a separate purchase.
    state["Sandbox"]["signed"] = sign(other["account_id"])
    assert run(accounts.subscription(other["account_id"], state["Sandbox"]["signed"]))["premium_active"]


def test_disabled_environment_cannot_reuse_previously_cached_paid_lease(system):
    accounts, _, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    run(accounts.subscription(user["account_id"], state["Sandbox"]["signed"]))
    accounts.subscriptions = accounts.subscriptions.services["Production"]
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert not accounts.session(user["account_id"])["premium_active"]
    assert not state["Production"]["calls"]
    with pytest.raises(HTTPException):
        run(accounts.subscriptions.status(user["account_id"], "10000000000001", environment="Sandbox"))


def test_legacy_schema_invalidates_unattributed_lease_without_deleting_user_data(system):
    accounts, memory, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    run(accounts.subscription(user["account_id"], state["Sandbox"]["signed"]))
    memory.set_settings(user["account_id"], True)
    note = memory.create_memory(user["account_id"], MemoryCreate(kind="preference", text="Synthetic note", confirmed=True))
    with memory.db() as db:
        db.execute("DROP TABLE account_subscriptions")
        db.execute("""CREATE TABLE account_subscriptions (subject TEXT PRIMARY KEY REFERENCES account_identities(subject),
            original_transaction_id TEXT UNIQUE NOT NULL, premium_until INTEGER NOT NULL, checked_at INTEGER NOT NULL)""")
        db.execute("INSERT INTO account_subscriptions VALUES(?,?,?,?)", (user["account_id"], "10000000000001", clock.now + 86400, clock.now))
    accounts = AccountService(memory, identity_verifier=accounts.identity, subscription_verifier=accounts.subscriptions)
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert not accounts.session(user["account_id"])["premium_active"]
    assert memory.export(user["account_id"])["memories"][0]["id"] == note["id"]
    assert len(state["Sandbox"]["calls"]) == 1 and not state["Production"]["calls"]
    run(accounts.subscription(user["account_id"], state["Sandbox"]["signed"]))
    assert accounts.session(user["account_id"])["premium_active"]
    with memory.db() as db:
        rows = db.execute("SELECT environment FROM account_subscriptions").fetchall()
        assert [row[0] for row in rows] == ["Sandbox"]


@pytest.mark.parametrize("mode", ["Xcode", "LocalTesting", "production", "Both"])
def test_configuration_rejects_implicit_or_unsigned_modes(monkeypatch, mode):
    for name in ("BUNDLE_ID", "IAP_KEY_PATH", "IAP_KEY_ID", "ISSUER_ID", "ROOT_CERTIFICATES", "PLUS_PRODUCT_IDS"):
        monkeypatch.setenv("OMNI_APPLE_" + name, "synthetic-placeholder")
    monkeypatch.setenv("OMNI_APPLE_STORE_ENVIRONMENT", mode)
    with pytest.raises(ValueError):
        AppleSubscriptionVerifier.from_env()


def test_dual_configuration_requires_production_app_id_before_opening_any_files(monkeypatch):
    for name in ("BUNDLE_ID", "IAP_KEY_PATH", "IAP_KEY_ID", "ISSUER_ID", "ROOT_CERTIFICATES", "PLUS_PRODUCT_IDS"):
        monkeypatch.setenv("OMNI_APPLE_" + name, "synthetic-placeholder")
    monkeypatch.setenv("OMNI_APPLE_STORE_ENVIRONMENT", "ProductionAndSandbox")
    monkeypatch.delenv("OMNI_APPLE_APP_ID", raising=False)
    with pytest.raises(ValueError, match="OMNI_APPLE_APP_ID"):
        AppleSubscriptionVerifier.from_env()


def test_dual_configuration_builds_two_strict_official_verifiers(monkeypatch, tmp_path):
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from test_accounts import Clock

    sandbox, _ = make_store_signer(Clock())
    root_path, key_path = tmp_path / "synthetic-root.der", tmp_path / "synthetic-key.p8"
    root_path.write_bytes(sandbox._chain_verifier.root_certificates[0])
    key_path.write_bytes(ec.generate_private_key(ec.SECP256R1()).private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    values = {"BUNDLE_ID": BUNDLE, "IAP_KEY_PATH": str(key_path), "IAP_KEY_ID": "SYNTHETIC_KEY",
              "ISSUER_ID": "synthetic-issuer", "ROOT_CERTIFICATES": str(root_path), "PLUS_PRODUCT_IDS": PRODUCT,
              "STORE_ENVIRONMENT": "ProductionAndSandbox", "APP_ID": "6812658396"}
    for name, value in values.items():
        monkeypatch.setenv("OMNI_APPLE_" + name, value)
    service = AppleSubscriptionVerifier.from_env()
    assert isinstance(service, DualEnvironmentSubscriptions) and service.configured
    for name, single in service.services.items():
        assert single.verifier._enable_online_checks is True
        assert single.verifier._environment.value == name
        assert single.verifier._bundle_id == BUNDLE
        assert single.verifier._app_apple_id == 6812658396
        run(single.client.http_client.aclose())


@pytest.mark.parametrize("environment", ["Production", "Sandbox"])
@pytest.mark.parametrize("changes", [{"expiresDate": 1799999999000}, {"revocationDate": 1800000000000}, {"isUpgraded": True}])
def test_dual_environment_keeps_expiration_revocation_and_upgrade_checks(system, environment, changes):
    accounts, _, clock, login, _ = system
    user = login()
    state, sign = dual_store(accounts, clock, user["account_id"])
    state[environment]["signed"] = sign(user["account_id"], environment=environment, **changes)
    assert not run(accounts.subscription(user["account_id"], state[environment]["signed"]))["premium_active"]


def test_refresh_without_verified_environment_never_probes_an_apple_api(system):
    accounts, _, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    for environment in (None, "", "Xcode", "LocalTesting"):
        with pytest.raises(HTTPException):
            run(accounts.subscriptions.status(user["account_id"], "10000000000001", environment=environment))
    assert all(not value["calls"] for value in state.values())


def test_missing_configuration_does_not_keep_cached_paid_access(system):
    accounts, _, clock, login, _ = system
    user = login()
    state, _ = dual_store(accounts, clock, user["account_id"])
    run(accounts.subscription(user["account_id"], state["Production"]["signed"]))
    accounts.subscriptions.services["Sandbox"].client = None
    assert not accounts.subscriptions.configured
    run(accounts.authorize("Bearer " + user["access_token"]))
    assert not accounts.session(user["account_id"])["premium_active"]
