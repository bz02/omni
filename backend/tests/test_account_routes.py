"""Full HTTP contracts using synthetic signed Apple tokens, certificates and local transports."""
import hashlib

from fastapi.testclient import TestClient

from omni_memory.app import create_app
from omni_memory.auth import issue_session
from omni_memory.sync import SnapshotService
from test_accounts import SECRET, apple_token, store, system
from test_memory_sync import snapshot


def login_http(client, clock, subject="synthetic-apple-sub"):
    challenge = client.post("/v1/auth/challenge")
    assert challenge.status_code == 200 and challenge.headers["cache-control"] == "no-store"
    value = challenge.json()
    token = apple_token(clock, hashlib.sha256(value["nonce"].encode()).hexdigest(), subject)
    response = client.post("/v1/auth/apple", json={"challenge_id": value["challenge_id"], "identity_token": token})
    assert response.status_code == 200, response.text
    return response.json()


def test_managed_http_login_subscription_snapshot_export_erase_and_logout(system):
    accounts, memory, clock, _, _ = system
    with TestClient(create_app(memory, account_service=accounts)) as client:
        user = login_http(client, clock)
        headers = {"Authorization": "Bearer " + user["access_token"]}
        other = login_http(client, clock, "other")
        other_headers = {"Authorization": "Bearer " + other["access_token"]}
        assert client.get("/v1/account/session", headers=headers).json()["premium_active"] is False
        current, _ = store(accounts, clock, user["account_id"])
        paid = client.post("/v1/account/subscription", headers=headers, json={"signed_transaction": current["signed"]})
        assert paid.status_code == 200 and paid.json()["premium_active"]
        archive = snapshot(user["account_id"])
        put = client.put("/v1/memory/snapshot", headers=headers, json={"expected_revision": 0, "archive": archive})
        assert put.status_code == 200, put.text
        assert put.json()["revision"] == 1
        assert client.get("/v1/memory/snapshot", headers=headers).json()["archive"]["memories"][0]["text"] == archive["memories"][0]["text"]
        assert client.get("/v1/memory/snapshot", headers=other_headers).json()["archive"] is None
        assert client.put("/v1/memory/snapshot", headers=other_headers, json={"expected_revision": 0, "archive": archive}).status_code == 403
        exported = client.get("/v1/account/export", headers=headers)
        assert exported.status_code == 200 and exported.json()["memory_snapshot"]["revision"] == 1
        deleted = client.request("DELETE", "/v1/memory/snapshot", headers=headers, json={"expected_revision": 1})
        assert deleted.status_code == 200 and deleted.json() == {"revision": 2, "archive": None}
        assert client.put("/v1/memory/snapshot", headers=headers, json={"expected_revision": 1, "archive": archive}).status_code == 409
        assert client.put("/v1/memory/snapshot", headers=headers, json={"expected_revision": 2, "archive": archive}).status_code == 200
        assert client.delete("/v1/account/data", headers=headers).status_code == 200
        assert client.get("/v1/memory/snapshot", headers=headers).json()["archive"] is None
        logout = client.post("/v1/auth/logout", headers=headers, json={"refresh_token": user["refresh_token"]})
        assert logout.status_code == 200
        denied = client.get("/v1/account/export", headers=headers)
        assert denied.status_code == 401 and denied.headers["cache-control"] == "no-store"
        assert client.get("/v1/account/session", headers=other_headers).status_code == 200


def test_http_defaults_reject_legacy_premium_spoof_and_refresh_replay_and_account_delete(system):
    accounts, memory, clock, _, _ = system
    with TestClient(create_app(memory, account_service=accounts)) as client:
        user = login_http(client, clock)
        legacy = "Bearer " + issue_session(user["account_id"], SECRET, now=clock.now)
        assert client.get("/v1/memory", headers={"Authorization": legacy}).status_code == 401
        headers = {"Authorization": "Bearer " + user["access_token"]}
        spoof = client.post("/v1/account/subscription", headers=headers, json={"signed_transaction": "sensitive-synthetic-claim", "premium": True})
        assert spoof.status_code == 422 and "sensitive-synthetic-claim" not in spoof.text
        rotated = client.post("/v1/auth/refresh", json={"refresh_token": user["refresh_token"]})
        assert rotated.status_code == 200
        new_headers = {"Authorization": "Bearer " + rotated.json()["access_token"]}
        assert client.get("/v1/memory", headers=headers).status_code == 401
        assert client.get("/v1/memory", headers=new_headers).status_code == 200
        assert client.post("/v1/auth/refresh", json={"refresh_token": user["refresh_token"]}).status_code == 401
        assert client.get("/v1/memory", headers=new_headers).status_code == 401
        again = login_http(client, clock)
        final_headers = {"Authorization": "Bearer " + again["access_token"]}
        assert client.delete("/v1/account", headers=final_headers).status_code == 200
        assert client.get("/v1/account/session", headers=final_headers).status_code == 401
        assert client.post("/v1/auth/refresh", json={"refresh_token": again["refresh_token"]}).status_code == 401


def test_http_logout_while_model_pending_prevents_chat_content_resurrection(system):
    accounts, memory, clock, _, _ = system
    with TestClient(create_app(memory, account_service=accounts)) as client:
        user = login_http(client, clock)
        headers = {"Authorization": "Bearer " + user["access_token"]}
        current, _ = store(accounts, clock, user["account_id"])
        assert client.post("/v1/account/subscription", headers=headers, json={"signed_transaction": current["signed"]}).status_code == 200
        assert client.patch("/v1/memory/settings", headers=headers, json={"enabled": True}).status_code == 200
        class LogoutResponder:
            async def respond(self, message, memories, history, *, suggest_memories=False):
                accounts.logout(user["account_id"], user["refresh_token"])
                return {"content": "Synthetic reply after logout; must not persist.", "memory_suggestions": []}
        memory.responder = LogoutResponder()
        response = client.post("/v1/chat", headers=headers, json={"message": "Synthetic personal context", "persist": True})
        assert response.status_code == 401
        with memory.db() as db:
            assert db.execute("SELECT COUNT(*) FROM messages WHERE subject=?", (user["account_id"],)).fetchone()[0] == 0
            assert db.execute("SELECT COUNT(*) FROM conversations WHERE subject=?", (user["account_id"],)).fetchone()[0] == 0


def test_http_revocation_between_principal_and_content_transaction_blocks_write(system, monkeypatch):
    accounts, memory, clock, _, _ = system
    with TestClient(create_app(memory, account_service=accounts)) as client:
        user = login_http(client, clock)
        headers = {"Authorization": "Bearer " + user["access_token"]}
        current, _ = store(accounts, clock, user["account_id"])
        assert client.post("/v1/account/subscription", headers=headers, json={"signed_transaction": current["signed"]}).status_code == 200
        original = SnapshotService.put

        def revoke_then_write(service, subject, data):
            # FastAPI has already authenticated, then dispatches this sync route
            # to its thread pool. The request guard must propagate to that thread.
            accounts.logout(subject, user["refresh_token"])
            return original(service, subject, data)

        monkeypatch.setattr(SnapshotService, "put", revoke_then_write)
        response = client.put("/v1/memory/snapshot", headers=headers,
                              json={"expected_revision": 0, "archive": snapshot(user["account_id"])})
        assert response.status_code == 401
        with memory.db() as db:
            assert db.execute("SELECT COUNT(*) FROM native_snapshots WHERE subject=?", (user["account_id"],)).fetchone()[0] == 0
