"""Only synthetic adult accounts. No real messages, profiles or external calls."""
import json
import uuid
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from omni_memory.app import create_app
from omni_memory.auth import issue_session
from omni_memory.dating import DatingService
from omni_memory.service import MemoryService

SECRET = "synthetic-only-dating-tests-32chars-96ABq"


@pytest.fixture
def system(tmp_path):
    now = datetime(2026, 9, 30, 12, tzinfo=timezone.utc).timestamp()
    memory = MemoryService(tmp_path / "dating.db", secret=SECRET, clock=lambda: now, chat_limit=50)
    dating = DatingService(memory, enabled=True)
    client = TestClient(create_app(memory, managed_accounts=False, dating_service=dating))
    headers = lambda who: {"Authorization": "Bearer " + issue_session(who, SECRET, now=int(now))}
    def profile(who, *, approve=True, **changes):
        p = dict(name=who.title(), birth_date="1995-04-03", city="New York", gender="woman", seeking=["woman", "man", "nonbinary"], age_min=18, age_max=100, intention="long_term", bio="I like exploring bookstores and parks.", visible=True, consent_version="dating-v1")
        p.update(changes)
        response = client.put("/v1/dating/profile", headers=headers(who), json={"expected_revision": 0, "profile": p})
        assert response.status_code == 200, response.text
        with memory.db() as db:
            row = dating.row(db, who)
        if approve:
            dating.moderate(row["id"], revision=row["revision"], approved=True)
        return row["id"]
    return memory, dating, client, headers, profile


def test_only_opted_in_reviewed_adults_are_visible_and_birthdays_are_private(system):
    _, _, client, h, p = system
    p("alice"); bob = p("bob", birth_date="1990-06-08")
    p("pending", approve=False); p("hidden", visible=False)
    result = client.get("/v1/dating/discover", headers=h("alice"))
    assert result.status_code == 200
    cards = result.json()["profiles"]
    assert [c["id"] for c in cards] == [bob]
    assert not any(key in result.text for key in ["birth_date", "1990-06-08", "subject", "seeking"])
    assert cards[0]["pairing"]["method"] == "omni-connect-v2"


def test_mutual_preferences_and_adult_boundary(system):
    _, _, client, h, p = system
    p("alice", seeking=["man"], age_min=25, age_max=40)
    p("wronggender", gender="woman")
    p("wrongage", gender="man", birth_date="2005-01-01")
    p("oneway", gender="man", seeking=["man"])
    valid = p("bob", gender="man")
    assert [r["id"] for r in client.get("/v1/dating/discover", headers=h("alice")).json()["profiles"]] == [valid]
    sample = client.get("/v1/dating/profile", headers=h("alice")).json()["profile"]
    sample["birth_date"] = "2008-10-01"
    assert client.put("/v1/dating/profile", headers=h("young"), json={"expected_revision": 0, "profile": sample}).status_code == 422
    sample["birth_date"] = "2008-09-30"
    assert client.put("/v1/dating/profile", headers=h("adulttoday"), json={"expected_revision": 0, "profile": sample}).status_code == 200


def make_match(client, h, alice, bob):
    first = client.post(f"/v1/dating/profiles/{bob}/like", headers=h("alice"))
    assert first.json() == {"matched": False, "match_id": None}
    assert client.get("/v1/dating/matches", headers=h("bob")).json()["matches"] == []
    second = client.post(f"/v1/dating/profiles/{alice}/like", headers=h("bob"))
    assert second.json()["matched"] is True
    return second.json()["match_id"]


def test_mutual_like_chat_idempotency_and_unrelated_account_isolation(system):
    _, _, client, h, p = system
    a, b = p("alice"), p("bob")
    match = make_match(client, h, a, b)
    assert client.post(f"/v1/dating/profiles/{b}/like", headers=h("alice")).json()["match_id"] == match
    path = f"/v1/dating/matches/{match}/messages"
    body = {"id": str(uuid.uuid4()), "text": "Hello, I liked your bookstore idea."}
    assert client.post(path, headers=h("alice"), json=body).status_code == 200
    assert client.post(path, headers=h("alice"), json=body).status_code == 200
    result = client.get(path, headers=h("bob")).json()["messages"]
    assert len(result) == 1 and result[0]["mine"] is False
    assert client.get(path, headers=h("eve")).status_code == 404
    assert client.post(path, headers=h("eve"), json=body).status_code == 404
    assert client.post(path, headers=h("bob"), json=body).status_code == 409


def test_block_and_report_remove_both_directions_and_queue_for_operator(system):
    memory, _, client, h, p = system
    a, b = p("alice"), p("bob")
    match = make_match(client, h, a, b)
    response = client.post(f"/v1/dating/profiles/{b}/report", headers=h("alice"), json={"reason": "scam", "detail": "Asked for money."})
    assert response.json() == {"blocked": True, "reported": True}
    assert client.get(f"/v1/dating/matches/{match}/messages", headers=h("bob")).status_code == 404
    for who, other in [("alice", b), ("bob", a)]:
        assert client.get("/v1/dating/discover", headers=h(who)).json()["profiles"] == []
        assert client.post(f"/v1/dating/profiles/{other}/like", headers=h(who)).status_code == 404
    with memory.db() as db:
        assert db.execute("SELECT reason,status FROM dating_reports").fetchone()[:] == ("scam", "pending")


def test_revisions_review_invalidation_and_stale_resurrection(system):
    memory, dating, client, h, p = system
    identifier = p("alice")
    envelope = client.get("/v1/dating/profile", headers=h("alice")).json()
    original_revision = envelope["revision"]
    envelope["profile"]["bio"] = "A new introduction that needs review."
    body = {"expected_revision": original_revision, "profile": envelope["profile"]}
    response = client.put("/v1/dating/profile", headers=h("alice"), json=body)
    assert response.json()["status"] == "pending"
    with pytest.raises(ValueError):
        dating.moderate(identifier, revision=original_revision, approved=True)
    assert client.put("/v1/dating/profile", headers=h("alice"), json=body).status_code == 409
    body["expected_revision"] = response.json()["revision"]
    assert client.delete("/v1/dating/profile", headers=h("alice")).status_code == 200
    assert client.put("/v1/dating/profile", headers=h("alice"), json=body).status_code == 409
    assert client.get("/v1/dating/profile", headers=h("alice")).json()["profile"] is None


def test_export_and_account_data_erase_include_dating_but_preserve_other_profile(system):
    _, _, client, h, p = system
    a, b = p("alice"), p("bob")
    match = make_match(client, h, a, b)
    client.post(f"/v1/dating/matches/{match}/messages", headers=h("alice"), json={"id": str(uuid.uuid4()), "text": "Hello there"})
    exported = client.get("/v1/account/export", headers=h("alice")).json()
    assert exported["dating"]["profile"]["profile"]["name"] == "Alice"
    assert len(exported["dating"]["messages_sent"]) == 1
    assert client.delete("/v1/account/data", headers=h("alice")).status_code == 200
    assert client.get("/v1/dating/profile", headers=h("alice")).json()["profile"] is None
    assert client.get("/v1/dating/profile", headers=h("bob")).json()["profile"]["name"] == "Bob"
    assert client.get("/v1/dating/matches", headers=h("bob")).json()["matches"] == []


def test_auth_and_production_feature_gate(system):
    _, dating, client, h, p = system
    assert client.get("/v1/dating/profile").status_code == 401
    p("alice")
    dating.enabled = False
    assert client.get("/v1/dating/profile", headers=h("alice")).json()["discovery_enabled"] is False
    assert client.get("/v1/dating/discover", headers=h("alice")).status_code == 503
    # Always retain the ability to erase personal data, even while discovery is disabled.
    assert client.delete("/v1/dating/profile", headers=h("alice")).status_code == 200


def test_strict_validation_does_not_echo_sensitive_inputs(system):
    _, _, client, h, _ = system
    response = client.put("/v1/dating/profile", headers=h("alice"), json={"expected_revision": 0, "profile": {"birth_date": "secret-invalid-birthday"}})
    assert response.status_code == 422 and "secret-invalid-birthday" not in response.text


def test_pass_persists_unlike_removes_only_pending_like_and_match_requires_unmatch(system):
    _, _, c,h,p=system
    a,b,d=p('alice'),p('bob'),p('dana')
    assert c.post(f'/v1/dating/profiles/{d}/pass',headers=h('alice')).status_code==200
    assert [r['id'] for r in c.get('/v1/dating/discover',headers=h('alice')).json()['profiles']]==[b]
    c.post(f'/v1/dating/profiles/{b}/like',headers=h('alice'))
    assert len(c.get('/v1/dating/likes',headers=h('alice')).json()['profiles'])==1
    assert c.delete(f'/v1/dating/profiles/{b}/like',headers=h('alice')).status_code==200
    assert c.get('/v1/dating/likes',headers=h('alice')).json()['profiles']==[]
    match=make_match(c,h,a,b)
    assert c.delete(f'/v1/dating/profiles/{b}/like',headers=h('alice')).status_code==409
    assert c.post(f'/v1/dating/profiles/{b}/pass',headers=h('alice')).status_code==409
    assert c.get(f'/v1/dating/matches/{match}/messages',headers=h('bob')).status_code==200


def photo_data():
    import base64,io
    from PIL import Image
    image=Image.new('RGB',(200,300),'green'); output=io.BytesIO()
    exif=Image.Exif();exif[270]='private metadata must be removed'
    image.save(output,format='JPEG',exif=exif)
    return base64.b64encode(output.getvalue()).decode()


def test_optional_photo_moderation_access_control_metadata_and_deletion(system):
    import io
    from PIL import Image
    memory,dating,c,h,p=system
    a,b=p('alice'),p('bob');p('eve',seeking=['man'])
    env=c.get('/v1/dating/profile',headers=h('alice')).json()
    upload=c.put('/v1/dating/profile/photo',headers=h('alice'),json={'expected_revision':env['revision'],'image':photo_data()})
    assert upload.status_code==200,upload.text
    uploaded=upload.json(); identifier=uploaded['photo_id']
    assert uploaded['status']=='pending'
    path=f'/v1/dating/photos/{identifier}'
    assert c.get(path).status_code==401
    assert c.get(path,headers=h('bob')).status_code==404
    image=c.get(path,headers=h('alice'))
    assert image.headers['cache-control']=='no-store'
    with Image.open(io.BytesIO(image.content)) as decoded: assert not decoded.getexif()
    with pytest.raises(ValueError): dating.moderate(a,revision=env['revision'],approved=True)
    dating.moderate(a,revision=uploaded['revision'],approved=True)
    assert c.get(path,headers=h('bob')).status_code==200
    assert c.get(path,headers=h('eve')).status_code==404
    assert c.get('/v1/dating/discover',headers=h('bob')).json()['profiles'][0]['photo_id']==identifier
    assert c.get('/v1/account/export',headers=h('alice')).json()['dating']['photo']['mime_type']=='image/jpeg'
    c.post(f'/v1/dating/profiles/{a}/block',headers=h('bob'))
    assert c.get(path,headers=h('bob')).status_code==404
    revision=c.get('/v1/dating/profile',headers=h('alice')).json()['revision']
    assert c.request('DELETE','/v1/dating/profile/photo',headers=h('alice'),json={'expected_revision':revision-1}).status_code==409
    assert c.request('DELETE','/v1/dating/profile/photo',headers=h('alice'),json={'expected_revision':revision}).status_code==200
    assert c.get(path,headers=h('alice')).status_code==404


def test_invalid_photo_rejected_and_account_deletion_removes_photo(system):
    memory,dating,c,h,p=system
    p('alice'); env=c.get('/v1/dating/profile',headers=h('alice')).json()
    body={'expected_revision':env['revision'],'image':'not-a-photo'}
    assert c.put('/v1/dating/profile/photo',headers=h('alice'),json=body).status_code==422
    body['image']=photo_data()
    assert c.put('/v1/dating/profile/photo',headers=h('alice'),json=body).status_code==200
    c.delete('/v1/account/data',headers=h('alice'))
    with memory.db() as db: assert db.execute('SELECT COUNT(*) FROM dating_photos').fetchone()[0]==0


def test_recommendations_prioritize_real_preferences_and_explain_all_lenses(system):
    _,_,c,h,p=system
    birth=dict(birth_time='13:25',birth_timezone='America/New_York',birth_longitude=-74,mbti='INFJ')
    p('alice',**birth)
    aligned=p('aligned',**birth)
    p('different',intention='casual',communication='time_to_think',social='outgoing',value='adventure',**birth)
    cards=c.get('/v1/dating/discover',headers=h('alice')).json()['profiles']
    assert cards[0]['id']==aligned
    assert len(cards[0]['pairing']['report']['dimensions'])==7
    assert cards[0]['pairing']['report']['dimensions'][5]['score'] is not None
    assert '13:25' not in str(cards) and 'birth_longitude' not in str(cards)


def test_friendship_is_all_gender_and_separate_from_existing_dating_pool(system):
    _,_,c,h,p=system
    p('alex',intention='friendship',consent_version='friends-v1',gender='man',seeking=['woman'])
    same_gender=p('sam',intention='friendship',consent_version='friends-v1',gender='man',seeking=['woman'])
    unspecified=p('river',intention='friendship',consent_version='friends-v1',gender='unspecified')
    p('legacy',gender='woman',seeking=['man'])
    p('agefilter',intention='friendship',consent_version='friends-v1',age_min=50)
    cards=c.get('/v1/dating/discover',headers=h('alex')).json()['profiles']
    assert {v['id'] for v in cards} == {same_gender,unspecified}
    assert all(v['pairing']['report']['kind']=='friendship' for v in cards)
    assert all(v['pairing']['report']['recommended'] for v in cards)
    assert c.post(f'/v1/dating/profiles/{same_gender}/like',headers=h('alex')).status_code==200
    # Dating consent must not silently become consent to all-gender friendship discovery.
    old=c.get('/v1/dating/profile',headers=h('legacy')).json()
    old['profile']['intention']='friendship'
    assert c.put('/v1/dating/profile',headers=h('legacy'),json={'expected_revision':old['revision'],'profile':old['profile']}).status_code==422
    old['profile']['consent_version']='friends-v1'
    assert c.put('/v1/dating/profile',headers=h('legacy'),json={'expected_revision':old['revision'],'profile':old['profile']}).json()['status']=='pending'


def test_chat_history_receipts_quotes_restart_and_deletion(system):
    memory, dating, client, h, p = system
    match=make_match(client,h,p('alice'),p('bob'))
    path=f'/v1/dating/matches/{match}'
    ids=[]
    for n in range(35):
        body={'id':str(uuid.uuid4()),'text':f'Message {n}'}; ids.append(body['id'])
        assert client.post(path+'/messages',headers=h('alice'),json=body).status_code==200
    inbox=lambda who: client.get('/v1/dating/matches',headers=h(who)).json()['matches'][0]
    assert inbox('bob')['unread_count']==35 and inbox('bob')['last_message']=='Message 34'
    page=client.post(path+'/history',headers=h('bob'),json={}).json()
    assert [m['sequence'] for m in page['messages']]==list(range(6,36))
    assert page['has_more'] and page['next_before']==6
    older=client.post(path+'/history',headers=h('bob'),json={'before':6}).json()
    assert [m['sequence'] for m in older['messages']]==list(range(1,6)) and not older['has_more']
    for seq in [35,2]: assert client.post(path+'/read',headers=h('bob'),json={'sequence':seq}).status_code==200
    assert inbox('bob')['unread_count']==0
    messages=lambda who: client.get(path+'/messages',headers=h(who)).json()['messages']
    assert not any(m['seen'] for m in messages('alice'))
    assert client.patch(path+'/settings',headers=h('bob'),json={'read_receipts':True,'pinned':True}).status_code==200
    assert all(m['seen'] for m in messages('alice'))
    assert inbox('bob')['pinned'] and not inbox('alice')['pinned']
    body={'id':str(uuid.uuid4()),'text':'A reply','reply_to':ids[0]}
    for _ in range(2): assert client.post(path+'/messages',headers=h('bob'),json=body).status_code==200
    assert messages('alice')[-1]['reply_preview']=='Message 0' and messages('alice')[-1]['sequence']==36
    reopened=MemoryService(memory.database,secret=SECRET,clock=memory.clock)
    assert DatingService(reopened,enabled=True).messages('alice',match)['messages'][-1]['id']==body['id']
    assert client.patch(path+'/settings',headers=h('eve'),json={'pinned':True}).status_code==404
    assert client.post(path+'/read',headers=h('eve'),json={'sequence':1}).status_code==404
    assert client.post(path+'/read',headers=h('bob'),json={'sequence':100}).status_code==422
    assert client.post(path+'/messages',headers=h('bob'),json={'id':str(uuid.uuid4()),'text':'Invalid quote','reply_to':str(uuid.uuid4())}).status_code==404
    client.delete(path,headers=h('alice'))
    with memory.db() as db:
        assert db.execute('SELECT COUNT(*) FROM dating_chat_state').fetchone()[0]==0
        assert db.execute('SELECT COUNT(*) FROM dating_messages').fetchone()[0]==0


def test_chat_concurrent_retry_and_legacy_migration(system):
    from concurrent.futures import ThreadPoolExecutor
    from omni_memory.dating import MessagePut
    memory, dating, client, h, p=system
    match=make_match(client,h,p('alice'),p('bob'))
    message=MessagePut(id=uuid.uuid4(),text='One message, simultaneous retries')
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert all(r['sent'] for r in pool.map(lambda _:dating.send('alice',match,message),range(4)))
    assert len(dating.messages('bob',match)['messages'])==1
    with memory.db() as db:
        assert db.execute('PRAGMA journal_mode').fetchone()[0]=='wal'
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
        db.execute('DROP TABLE dating_chat_state'); db.execute('DROP TABLE dating_messages')
        db.execute('CREATE TABLE dating_messages(id TEXT PRIMARY KEY,match_id TEXT NOT NULL REFERENCES dating_matches(id) ON DELETE CASCADE,sender TEXT NOT NULL,text TEXT NOT NULL,created_at REAL NOT NULL)')
        db.execute('INSERT INTO dating_messages VALUES(?,?,?,?,?)',(str(message.id),match,'alice','Preserve me',memory.clock()))
    migrated=DatingService(memory,enabled=True)
    assert migrated.messages('bob',match)['messages'][0]['text']=='Preserve me'
    assert migrated.messages('bob',match)['messages'][0]['sequence']==1
