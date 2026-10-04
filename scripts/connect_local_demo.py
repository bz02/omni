"""Loopback-only sandbox for Connect. Never install this script on the production server."""
from pathlib import Path
import sys
import uuid
import secrets
from datetime import datetime, timezone
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from fastapi import HTTPException, Request
from fastapi.responses import FileResponse
import uvicorn
from omni_memory.app import create_app
from omni_memory.service import MemoryService
from omni_memory.dating import DatingService, DatingProfile, ProfilePut
from omni_memory.connect import ConnectService, ConnectProfile, ProfilePut as ConnectPut
from omni_memory.auth import issue_session

ROOT = Path(__file__).resolve().parent / 'connect-demo'
# A disposable, local-only database and secret, separate from production accounts.
memory = MemoryService('/private/tmp/omni-friends-preview.sqlite3', secret='synthetic-connect-preview-only-32chars')
dating = DatingService(memory, enabled=True)
app = create_app(memory, managed_accounts=False, dating_service=dating)
people = {'alex': ('Alex', 'man', ['woman'], 'INFJ'), 'jamie': ('Jamie', 'woman', ['man'], 'ENFP'), 'riley': ('Riley', 'man', ['man'], 'INTJ')}
for key, (name, gender, seeking, mbti) in people.items():
    subject = 'local-demo-' + key
    if not dating.get(subject)['profile']:
        env = dating.put(subject, ProfilePut(expected_revision=dating.get(subject)['revision'], profile=DatingProfile(
            name=name, birth_date='1995-04-03' if key=='alex' else '1996-06-08', birth_time='13:25',birth_timezone='America/Los_Angeles',birth_longitude=-122.42,birth_place='San Francisco',
            mbti=mbti, city='San Francisco', gender=gender,seeking=['woman','man','nonbinary'],age_min=25,age_max=40,intention='friendship',bio='Bookstore wanderer. Weekend coffee walks and good conversations.',visible=True,consent_version='friends-v1')))
        with memory.db() as db: row=dating.row(db,subject)
        dating.moderate(row['id'],revision=env['revision'],approved=True)

@app.middleware('http')
async def loopback_only(request: Request, call_next):
    if request.headers.get('host') not in {'127.0.0.1:8765','localhost:8765'}:
        from fastapi.responses import JSONResponse
        return JSONResponse({'detail':'Local demo only.'},status_code=403)
    response=await call_next(request)
    response.headers['Cache-Control']='no-store'
    return response

@app.get('/demo')
def page(): return FileResponse(ROOT/'index.html',headers={'Content-Security-Policy':"default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'"})
@app.get('/demo/app.js')
def script(): return FileResponse(ROOT/'app.js',media_type='application/javascript')
@app.get('/demo/style.css')
def style(): return FileResponse(ROOT/'style.css',media_type='text/css')
@app.get('/demo/session/{person}')
def session(person: str):
    if person not in people: raise HTTPException(404)
    return {'token': issue_session('local-demo-'+person,memory.secret,now=int(memory.clock())), 'name':people[person][0]}
@app.post('/demo/review/{person}')
def review(person: str, request: Request):
    if request.headers.get('origin') not in {'http://127.0.0.1:8765','http://localhost:8765'} or person not in people: raise HTTPException(403)
    with memory.db() as db: row=dating.row(db,'local-demo-'+person)
    dating.moderate(row['id'],revision=row['revision'],approved=True)
    return {'reviewed':True}

if __name__=='__main__': uvicorn.run(app,host='127.0.0.1',port=8765,access_log=False)
