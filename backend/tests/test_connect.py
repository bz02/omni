import json
from datetime import datetime, timezone
from uuid import uuid4
import secrets
import pytest
from fastapi.testclient import TestClient
from omni_memory.app import create_app
from omni_memory.auth import issue_session
from omni_memory.service import MemoryService
from omni_memory.connect import ConnectProfile, normalize, report

SECRET='synthetic-connect-tests-only-32chars1234'
def profile(**kw):
    return dict(name='Alex', birth_date='1995-04-03', mbti='INFJ', five_element='auto', intention='long_term', communication='mix', social='quiet', value='growth', consent_version='connect-v1', **kw)
@pytest.fixture
def system(tmp_path):
    now=[datetime(2026,10,3,12,tzinfo=timezone.utc).timestamp()]
    m=MemoryService(tmp_path/'connect.db',secret=SECRET,clock=lambda:now[0])
    c=TestClient(create_app(m,managed_accounts=False))
    h=lambda s:{'Authorization':'Bearer '+issue_session(s,SECRET,now=int(now[0]))}
    assert c.put('/v1/connect/profile',headers=h('alice'),json={'expected_revision':0,'profile':profile()}).status_code==200
    return m,c,h,now

def invite(c,h,kind='dating'):
    r=c.post('/v1/connect/invitations',headers=h('alice'),json={'id':str(uuid4()),'kind':kind})
    assert r.status_code==200,r.text
    return r.json()
def accept(c,i,**changes):
    p=profile();p.update(changes)
    token=secrets.token_urlsafe(32)
    body={'token':i['token'],'receipt':token,'profile':p,'share_consent':True}
    r=c.post('/connect/api/accept',json=body)
    return r,token,body

def test_full_invite_shared_report_recommendation_and_withdrawal(system):
    m,c,h,_=system;i=invite(c,h)
    opened=c.post('/connect/api/open',json={'token':i['token']})
    assert opened.json()['name']=='Alex'
    assert 'birth_date' not in opened.text and 'mbti' not in opened.text
    r,receipt,body=accept(c,i);assert r.status_code==200,r.text
    assert r.json()['recommended'] and len(r.json()['dimensions'])==7
    state=c.get('/v1/connect',headers=h('alice')).json()
    assert state['invitations'][0]['report']==r.json()
    assert c.get('/v1/connect',headers=h('other')).json()['invitations']==[]
    assert c.post('/connect/api/report',json={'token':receipt}).json()==r.json()
    assert c.post('/connect/api/revoke',json={'token':receipt}).status_code==200
    assert c.get('/v1/connect',headers=h('alice')).json()['invitations']==[]
    assert c.post('/connect/api/report',json={'token':receipt}).status_code==404

def test_one_use_idempotent_retry_and_secret_separation(system):
    m,c,h,_=system;i=invite(c,h);r,receipt,body=accept(c,i)
    assert c.post('/connect/api/accept',json=body).json()==r.json()
    body['receipt']=secrets.token_urlsafe(32)
    assert c.post('/connect/api/accept',json=body).status_code==409
    assert c.post('/connect/api/report',json={'token':i['token']}).status_code==404
    assert c.post('/connect/api/open',json={'token':i['token']}).status_code==409
    with m.db() as db:
        row=dict(db.execute('SELECT * FROM connect_invites').fetchone())
    assert i['token'] not in json.dumps(row) and receipt not in json.dumps(row)
    assert 'birth_date' not in row['guest'] and '1995-04-03' not in row['guest']

def test_owner_isolation_and_profile_conflict(system):
    m,c,h,_=system;i=invite(c,h)
    assert c.delete('/v1/connect/invitations/'+i['id'],headers=h('other')).status_code==200
    assert c.post('/connect/api/open',json={'token':i['token']}).status_code==200
    assert c.put('/v1/connect/profile',headers=h('alice'),json={'expected_revision':0,'profile':profile()}).status_code==409
    assert c.get('/v1/connect').status_code==401
    assert c.delete('/v1/connect',headers=h('alice')).json()['profile'] is None
    assert c.post('/connect/api/open',json={'token':i['token']}).status_code==404

@pytest.mark.parametrize('changes',[{'birth_date':'2010-01-01'},{'birth_date':'2030-01-01'},{'mbti':'NOPE'},{'birth_date':'not-a-date'},{'consent_version':'old'}])
def test_invalid_and_underage_are_not_saved(system,changes):
    m,c,h,_=system;i=invite(c,h);r,_,_=accept(c,i,**changes)
    assert r.status_code==422
    assert c.get('/v1/connect',headers=h('alice')).json()['invitations'][0]['status']=='waiting'

def test_expiry_pending_and_complete(system):
    m,c,h,now=system;i=invite(c,h);now[0]+=7*86400
    assert c.post('/connect/api/open',json={'token':i['token']}).status_code==404
    i=invite(c,h);r,receipt,_=accept(c,i);now[0]+=90*86400
    assert c.post('/connect/api/report',json={'token':receipt}).status_code==404

def test_explicit_consent_and_no_echo_of_invalid_values(system):
    _,c,h,_=system;i=invite(c,h)
    body={'token':i['token'],'receipt':secrets.token_urlsafe(32),'profile':profile(),'share_consent':False}
    assert c.post('/connect/api/accept',json=body).status_code==422
    body['profile']['mbti']='sensitive-unexpected-value'
    r=c.post('/connect/api/accept',json=body)
    assert 'sensitive-unexpected-value' not in r.text

def test_goals_outweigh_symbolic_lenses_and_unknown_type_is_excluded():
    today=datetime(2026,10,3).date();a=normalize(ConnectProfile(**profile()),today)
    b={**a,'mbti':'unknown'};r=report(a,b,'dating')
    assert r['dimensions'][-1]['score'] is None
    assert r['score']>=80
    b['intention']='casual'
    assert not report(a,b,'dating')['recommended']
    assert report(a,a,'friendship')['recommended']
    assert report(a,a,'friendship')['recommendation'] == 'On a similar wavelength'
    assert report(a,b,'dating')['score']==report(b,a,'dating')['score']

def test_public_page_headers_and_payload_limits(system):
    _,c,_,_=system
    r=c.get('/connect');assert r.status_code==200
    assert r.headers['cache-control']=='no-store'
    assert "script-src 'self'" in r.headers['content-security-policy']
    assert r.headers['referrer-policy']=='no-referrer'
    assert c.get('/public/connect.js').status_code==200
    assert c.post('/connect/api/open',content='x'*131073).status_code==413

def test_account_deletion_foreign_keys_remove_connect_records(system):
    m,c,h,_=system;i=invite(c,h);accept(c,i)
    with m.db() as db: db.execute('DELETE FROM accounts WHERE subject=?',('alice',))
    assert c.post('/connect/api/open',json={'token':i['token']}).status_code==404
