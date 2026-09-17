"""Synthetic account snapshots only; no identity, Apple or model network calls."""

import copy
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from omni_memory.service import MemoryService
from omni_memory.sync import SnapshotArchive, SnapshotPut, SnapshotService


def snapshot(owner):
    memory_id, conversation_id, message_id = map(str, (uuid4(), uuid4(), uuid4()))
    return {"version": 1, "ownerID": owner, "settings": {"enabled": True, "saveHistory": True},
            "memories": [{"id": memory_id, "kind": "preference", "text": "I prefer quiet walks.",
                          "createdAt": "2026-09-13T18:00:00Z", "updatedAt": "2026-09-13T18:00:00Z",
                          "sourceConversationID": conversation_id, "sourceMessageID": message_id, "confirmedByUser": True}],
            "conversations": [{"id": conversation_id, "title": "A first date", "createdAt": "2026-09-13T18:00:00Z",
                               "updatedAt": "2026-09-13T18:00:01Z", "messages": [
                                   {"id": message_id, "role": "user", "text": "I prefer quiet walks.", "date": "2026-09-13T18:00:00Z", "usedMemoryIDs": []},
                                   {"id": str(uuid4()), "role": "assistant", "text": "Where would you enjoy walking?", "date": "2026-09-13T18:00:01Z", "usedMemoryIDs": [memory_id]}]}]}


@pytest.fixture
def sync(tmp_path):
    service = MemoryService(tmp_path / "memory.db", clock=lambda: 1000)
    owners = [str(uuid4()), str(uuid4())]
    for owner in owners:
        service.provision(owner, 2000)
    return service, SnapshotService(service), owners


def put(service, owner, data, revision=0):
    return service.put(owner, SnapshotPut(expected_revision=revision, archive=SnapshotArchive.model_validate(data)))


def test_cross_device_snapshot_roundtrip_and_owner_isolation(sync):
    service, store, (alice, bob) = sync
    original = snapshot(alice)
    first = put(store, alice, original)
    assert first["revision"] == 1
    restarted = SnapshotService(MemoryService(service.database, clock=lambda: 1000))
    assert restarted.get(alice) == first
    assert restarted.get(bob) == {"revision": 0, "archive": None}
    assert first["archive"]["conversations"][0]["messages"] == original["conversations"][0]["messages"]
    with pytest.raises(HTTPException) as error:
        put(store, bob, original)
    assert error.value.status_code == 403
    assert store.get(alice) == first


def test_compare_and_swap_rejects_stale_edits_and_real_concurrent_writers(sync):
    _, store, (alice, _) = sync
    original = snapshot(alice)
    put(store, alice, original)
    def change(text):
        candidate = copy.deepcopy(original)
        candidate["memories"][0]["text"] = text
        try:
            return put(store, alice, candidate, revision=1)["revision"]
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(change, ["I prefer morning walks.", "I prefer evening walks."]))
    assert sorted(results) == [2, 409]
    assert store.get(alice)["revision"] == 2


def test_delete_tombstone_prevents_offline_resurrection(sync):
    _, store, (alice, bob) = sync
    original = snapshot(alice)
    put(store, alice, original)
    put(store, bob, snapshot(bob))
    with pytest.raises(HTTPException) as error:
        store.delete(alice, expected_revision=0)
    assert error.value.status_code == 409
    assert store.delete(alice, expected_revision=1) == {"revision": 2, "archive": None}
    with pytest.raises(HTTPException) as error:
        put(store, alice, original, revision=1)
    assert error.value.status_code == 409
    assert store.get(alice) == {"revision": 2, "archive": None}
    assert store.get(bob)["archive"] is not None


def test_expired_users_can_download_correct_delete_and_disable_existing_data(sync):
    service, store, (alice, _) = sync
    original = snapshot(alice)
    put(store, alice, original)
    service.provision(alice, 0)
    assert store.get(alice)["archive"] is not None
    changed = copy.deepcopy(original)
    changed["memories"][0]["text"] = "I prefer shorter walks now."
    changed["settings"]["enabled"] = False
    assert put(store, alice, changed, revision=1)["revision"] == 2
    assert store.delete(alice, expected_revision=2)["archive"] is None


@pytest.mark.parametrize("addition", ["memory", "conversation", "message", "enable"])
def test_expired_users_cannot_add_content_or_enable_new_use(sync, addition):
    service, store, (alice, _) = sync
    original = snapshot(alice)
    original["settings"]["enabled"] = False
    put(store, alice, original)
    service.provision(alice, 0)
    incoming = copy.deepcopy(original)
    if addition == "memory":
        item = copy.deepcopy(incoming["memories"][0])
        item["id"] = str(uuid4())
        incoming["memories"].append(item)
    elif addition == "conversation":
        item = snapshot(alice)["conversations"][0]
        item["messages"] = item["messages"][:1]
        incoming["conversations"].append(item)
    elif addition == "message":
        incoming["conversations"][0]["messages"].append({"id": str(uuid4()), "role": "user", "text": "A new turn", "date": "2026-09-13T18:01:00Z"})
    else:
        incoming["settings"]["enabled"] = True
    with pytest.raises(HTTPException) as error:
        put(store, alice, incoming, revision=1)
    assert error.value.status_code == 403
    assert store.get(alice)["revision"] == 1


@pytest.mark.parametrize("damage", ["foreign_source", "assistant_source", "dangling_citation", "duplicate_message", "unconfirmed", "online_consent", "local_metadata", "numeric_date", "naive_date", "version"])
def test_schema_sources_citations_and_device_metadata_are_strict(sync, damage):
    _, store, (alice, _) = sync
    original = snapshot(alice)
    if damage == "foreign_source":
        original["memories"][0]["sourceConversationID"] = str(uuid4())
    elif damage == "assistant_source":
        original["memories"][0]["sourceMessageID"] = original["conversations"][0]["messages"][1]["id"]
    elif damage == "dangling_citation":
        original["conversations"][0]["messages"][1]["usedMemoryIDs"] = [str(uuid4())]
    elif damage == "duplicate_message":
        original["conversations"][0]["messages"][1]["id"] = original["conversations"][0]["messages"][0]["id"]
    elif damage == "unconfirmed":
        original["memories"][0]["confirmedByUser"] = False
    elif damage == "online_consent":
        original["settings"]["allowOnlineConversations"] = True
    elif damage == "local_metadata":
        original["localSync"] = {"cloudRevision": 999}
    elif damage == "numeric_date":
        original["memories"][0]["createdAt"] = 1800000000
    elif damage == "naive_date":
        original["memories"][0]["createdAt"] = "2026-09-13T18:00:00"
    else:
        original["version"] = 999
    with pytest.raises(ValidationError):
        put(store, alice, original)
    assert store.get(alice)["revision"] == 0


def test_snapshot_size_is_bounded_before_storage(sync):
    _, store, (alice, _) = sync
    data = snapshot(alice)
    for _ in range(125):
        data["conversations"][0]["messages"].append({"id": str(uuid4()), "role": "user", "text": "x" * 16000, "date": "2026-09-13T18:01:00Z"})
    with pytest.raises(ValidationError):
        put(store, alice, data)
    assert store.get(alice)["archive"] is None


def test_legacy_erase_and_account_purge_hooks_are_transactional(sync):
    service, store, (alice, bob) = sync
    put(store, alice, snapshot(alice))
    put(store, bob, snapshot(bob))
    assert store.erase_all_data(alice) == {"deleted": True}
    assert store.get(alice) == {"revision": 2, "archive": None}
    with service.db() as db:
        SnapshotService.purge_account(db, alice)
    assert store.get(alice) == {"revision": 0, "archive": None}
    assert store.get(bob)["revision"] == 1
    # Calling the hook before the feature has created its table is safe.
    with service.db() as db:
        db.execute("DROP TABLE native_snapshots")
        SnapshotService.erase_in_db(db, alice)
        SnapshotService.purge_account(db, alice)


def test_guest_subjects_cannot_enter_account_snapshot_storage(sync):
    _, store, _ = sync
    with pytest.raises(HTTPException) as error:
        store.get("guest")
    assert error.value.status_code == 403
