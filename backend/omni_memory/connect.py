"""Consent-based compatibility invitations. Scores are disclosed creative indices."""
from __future__ import annotations
import hashlib
import json
import secrets
import uuid
from datetime import date, datetime, timezone
from typing import Literal
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator
from lunar_python import Solar
from lunar_python.util import LunarUtil
def age_on(birthday, today):
    return today.year - birthday.year - ((today.month, today.day) < (birthday.month, birthday.day))

def calendar_sign(birthday):
    signs = ['Capricorn','Aquarius','Pisces','Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius']
    boundaries = [20,19,21,20,21,21,23,23,23,23,22,22]
    return signs[(birthday.month - 1 + int(birthday.day >= boundaries[birthday.month - 1])) % 12]


CONSENT = 'connect-v1'
class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)

class ConnectProfile(Input):
    name: str = Field(min_length=1, max_length=40)
    birth_date: date
    mbti: str = 'unknown'
    five_element: Literal['auto', 'wood', 'fire', 'earth', 'metal', 'water'] = 'auto'
    intention: Literal['long_term', 'exploring', 'casual', 'friendship'] = 'long_term'
    communication: Literal['talk_it_out', 'time_to_think', 'mix'] = 'mix'
    social: Literal['quiet', 'outgoing', 'mix'] = 'mix'
    value: Literal['growth', 'stability', 'adventure', 'family', 'creativity'] = 'growth'
    consent_version: Literal['connect-v1']

    @field_validator('mbti')
    @classmethod
    def mbti_type(cls, v):
        if v == 'unknown': return v
        v = v.upper()
        if len(v) != 4 or any(c not in choices for c, choices in zip(v, ['EI', 'NS', 'FT', 'JP'])):
            raise ValueError('Choose a valid personality type or unknown.')
        return v

class ProfilePut(Input):
    expected_revision: StrictInt = Field(ge=0)
    profile: ConnectProfile
class InviteCreate(Input):
    id: uuid.UUID
    kind: Literal['dating', 'friendship']
class Token(Input):
    token: str = Field(pattern=r'^[A-Za-z0-9_-]{43}$')
class InviteAccept(Token):
    profile: ConnectProfile
    share_consent: StrictBool
    receipt: str = Field(pattern=r'^[A-Za-z0-9_-]{43}$')

ELEMENTS = {'木': 'wood', '火': 'fire', '土': 'earth', '金': 'metal', '水': 'water'}
SIGN_ELEMENTS = dict(zip(['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces'], ['fire','earth','air','water'] * 3))
GENERATES = {'wood': 'fire', 'fire': 'earth', 'earth': 'metal', 'metal': 'water', 'water': 'wood'}

def normalize(p, today):
    age = age_on(p.birth_date, today)
    if not 18 <= age <= 100:
        raise HTTPException(422, 'Connect is for adults aged 18 to 100.')
    # Declared civil-date/noon convention, not an exact Ba Zi or beneficial element.
    stem = Solar.fromYmdHms(p.birth_date.year, p.birth_date.month, p.birth_date.day, 12, 0, 0).getLunar().getDayGan()
    result = p.model_dump(mode='json', exclude={'birth_date', 'consent_version', 'five_element'})
    result.update(sign=calendar_sign(p.birth_date), element=p.five_element if p.five_element != 'auto' else ELEMENTS[LunarUtil.WU_XING_GAN[stem]],
                  element_basis='self_reported' if p.five_element != 'auto' else 'civil_date_day_stem', age=age)
    return result

def report(a, b, kind):
    dimensions = []
    def add(key, title, score, weight, why, prompt):
        dimensions.append(dict(key=key, title=title, score=score, weight=weight, explanation=why, prompt=prompt))
    same_goal = a['intention'] == b['intention']
    goal = 90 if same_goal else 65 if 'exploring' in (a['intention'], b['intention']) else 35
    add('intentions', 'Relationship goals', goal, 40, 'You named the same relationship goal.' if same_goal else 'Your goals differ. Clarify expectations before treating this as a romantic recommendation.', 'What are you hoping this connection could become?')
    comm = 88 if a['communication'] == b['communication'] else 75 if 'mix' in (a['communication'], b['communication']) else 55
    add('communication', 'Communication rhythm', comm, 20, 'Your stated pacing is similar.' if comm == 88 else 'Agree on when to talk and when to take space; a different pace does not mean a lack of interest.', 'When something feels off, do you want to talk now or think first?')
    shared = a['value'] == b['value']
    add('values', 'Shared priorities', 90 if shared else 65, 15, f"You both prioritize {a['value']}." if shared else f"One prioritizes {a['value']}; the other {b['value']}. Make room for both.", 'What does your top priority look like in an ordinary week?')
    add('social', 'Time together', 88 if a['social'] == b['social'] else 75 if 'mix' in (a['social'], b['social']) else 55, 10, 'Based on your own preferred social pace, not your personality label.', 'What balance of quiet time, friends and dates feels good to you?')
    x, y = SIGN_ELEMENTS[a['sign']], SIGN_ELEMENTS[b['sign']]
    zodiac = 80 if x == y else 75 if {x, y} in [{'fire','air'}, {'earth','water'}] else 60
    add('zodiac', 'Zodiac lens', zodiac, 7, f"{a['sign']} + {b['sign']}. Approximate calendar Sun signs: same element 80, fire/air or earth/water 75, other combinations 60. Births near a sign boundary need exact time verification.", 'Where do your different approaches make life more interesting?')
    x, y = a['element'], b['element']
    element_score = 80 if x == y else 85 if GENERATES[x] == y or GENERATES[y] == x else 60
    add('elements', 'Five-element lens', element_score, 5, f"{x.title()} + {y.title()}. Same element 80, a generating pair 85, other pairs 60. Auto uses the civil birth date's day stem at noon, without true-solar-time correction; it is not a full Ba Zi chart or Xi/Yong Shen.", 'How can one of you support the other without doing all the giving?')
    mbti = None if 'unknown' in (a['mbti'], b['mbti']) else 60 + 5 * sum(x == y for x,y in zip(a['mbti'],b['mbti']))
    add('personality', 'Personality lens', mbti, 3, f"{a['mbti'].upper() if a['mbti'] != 'unknown' else 'Not provided'} + {b['mbti'].upper() if b['mbti'] != 'unknown' else 'Not provided'}. Optional self-reported four-letter type; no type is an ideal partner. Similarity index: 60 + 5 per shared letter. Unknown types are excluded, not penalized.", 'What do people often misunderstand about how you recharge or decide?')
    used = [d for d in dimensions if d['score'] is not None]
    score = round(sum(d['score'] * d['weight'] for d in used) / sum(d['weight'] for d in used))
    eligible = kind == 'dating' and 'friendship' not in (a['intention'], b['intention']) and goal >= 65
    strengths = [d['explanation'] for d in dimensions[:4] if d['score'] >= 80]
    friction = [d['explanation'] for d in dimensions[:4] if d['score'] < 80]
    return dict(method='omni-connect-v1', score=score, recommendation='Worth a conversation' if eligible and score >= 75 else 'Explore with curiosity' if eligible else 'Clarify your intentions' if kind == 'dating' else 'Build your friendship',
                recommended=eligible, names=[a['name'], b['name']], kind=kind, dimensions=dimensions,
                strengths=strengths or ['You have different starting points. Curiosity matters more than similarity.'],
                friction=friction or ['Similar answers do not guarantee chemistry. Check how you feel in real conversations.'],
                date_idea='Try a quiet coffee and a walk, with an easy way for either person to leave.' if 'quiet' in (a['social'], b['social']) else 'Try a daytime museum or bookstore visit and compare the things that caught your attention.',
                disclaimer='A creative conversation-fit index, not a probability of love, safety or relationship success. Goals and stated preferences carry 85% of the weight; zodiac, five elements and personality carry 15%. Missing personality is excluded and remaining weights are normalized. Profiles are self-reported. Reports use the details shared at invitation time.')

def digest(raw): return hashlib.sha256(raw.encode()).hexdigest()

class ConnectService:
    def __init__(self, memory):
        self.memory = memory
        with memory.db() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS connect_profiles(subject TEXT PRIMARY KEY REFERENCES accounts(subject) ON DELETE CASCADE, revision INTEGER NOT NULL, data TEXT);
            CREATE TABLE IF NOT EXISTS connect_invites(id TEXT PRIMARY KEY, subject TEXT NOT NULL REFERENCES accounts(subject) ON DELETE CASCADE, token_hash TEXT UNIQUE NOT NULL, kind TEXT NOT NULL, own TEXT NOT NULL, created REAL NOT NULL, expires REAL NOT NULL, guest TEXT, receipt_hash TEXT UNIQUE);
            CREATE INDEX IF NOT EXISTS connect_owner ON connect_invites(subject);
            ''')

    def today(self): return datetime.fromtimestamp(self.memory.clock(), timezone.utc).date()
    def purge(self, db): db.execute('DELETE FROM connect_invites WHERE expires<=?', (self.memory.clock(),))
    def state(self, subject):
        with self.memory.content_db() as db:
            self.purge(db)
            row = db.execute('SELECT * FROM connect_profiles WHERE subject=?', (subject,)).fetchone()
            invitations = []
            for r in db.execute('SELECT * FROM connect_invites WHERE subject=? ORDER BY created DESC', (subject,)):
                invitations.append(dict(id=r['id'], kind=r['kind'], expires_at=r['expires'], created_at=r['created'], status='complete' if r['guest'] else 'waiting', report=report(json.loads(r['own']), json.loads(r['guest']), r['kind']) if r['guest'] else None))
            invitations.sort(key=lambda i: (i['report'] is None, -(i['report']['score'] if i['report'] else 0)))
            return dict(revision=row['revision'] if row else 0, profile=json.loads(row['data']) if row and row['data'] else None, invitations=invitations)

    def save(self, subject, data):
        normalize(data.profile, self.today())
        with self.memory.content_db() as db:
            self.memory.account(db, subject)
            row = db.execute('SELECT * FROM connect_profiles WHERE subject=?', (subject,)).fetchone()
            if data.expected_revision != (row['revision'] if row else 0): raise HTTPException(409, 'Reload your profile before saving.')
            db.execute('INSERT INTO connect_profiles VALUES(?,?,?) ON CONFLICT(subject) DO UPDATE SET revision=excluded.revision,data=excluded.data', (subject, data.expected_revision+1, data.profile.model_dump_json()))
        return self.state(subject)

    def create(self, subject, data):
        token = secrets.token_urlsafe(32)
        with self.memory.content_db() as db:
            self.purge(db)
            row = db.execute('SELECT data FROM connect_profiles WHERE subject=?', (subject,)).fetchone()
            if not row or not row['data']: raise HTTPException(409, 'Save your own Connect profile first.')
            own = normalize(ConnectProfile.model_validate_json(row['data']), self.today())
            if db.execute('SELECT 1 FROM connect_invites WHERE id=?', (str(data.id),)).fetchone(): raise HTTPException(409, 'This invite was already created. Create a new one if its link was lost.')
            if db.execute('SELECT COUNT(*) FROM connect_invites WHERE subject=?', (subject,)).fetchone()[0] >= 100: raise HTTPException(429, 'Remove an old invitation or report first (limit 100).')
            expires = self.memory.clock() + 7 * 86400
            db.execute('INSERT INTO connect_invites VALUES(?,?,?,?,?,?,?,?,?)', (str(data.id), subject, digest(token), data.kind, json.dumps(own), self.memory.clock(), expires, None, None))
        return dict(id=str(data.id), token=token, expires_at=expires)

    def remove(self, subject, identifier):
        with self.memory.content_db() as db:
            db.execute('DELETE FROM connect_invites WHERE subject=? AND id=?', (subject, str(identifier)))
        return {'deleted': True}

    def erase(self, subject):
        with self.memory.content_db() as db:
            db.execute('DELETE FROM connect_invites WHERE subject=?', (subject,))
            db.execute('UPDATE connect_profiles SET data=NULL,revision=revision+1 WHERE subject=?', (subject,))
        return self.state(subject)

    def invitation(self, db, token):
        self.purge(db)
        r = db.execute('SELECT * FROM connect_invites WHERE token_hash=?', (digest(token),)).fetchone()
        if not r: raise HTTPException(404, 'This invitation expired or was removed. Ask for a new link.')
        return r

    def open(self, token):
        with self.memory.db() as db:
            r = self.invitation(db, token)
            if r['guest']: raise HTTPException(409, 'This one-person invitation has already been used.')
            return dict(name=json.loads(r['own'])['name'], kind=r['kind'], expires_at=r['expires'])

    def accept(self, data):
        if not data.share_consent: raise HTTPException(422, 'Confirm sharing before continuing.')
        guest = normalize(data.profile, self.today())
        with self.memory.db() as db:
            r = self.invitation(db, data.token)
            if r['guest']:
                if not secrets.compare_digest(r['receipt_hash'], digest(data.receipt)): raise HTTPException(409, 'This invitation was already used.')
                guest = json.loads(r['guest'])  # safe retry after a lost response; do not overwrite
            else:
                if db.execute('SELECT 1 FROM connect_invites WHERE receipt_hash=?', (digest(data.receipt),)).fetchone():
                    raise HTTPException(409, 'Please open a fresh invitation and try again.')
                expires = self.memory.clock() + 90 * 86400
                db.execute('UPDATE connect_invites SET guest=?,receipt_hash=?,expires=? WHERE id=?', (json.dumps(guest), digest(data.receipt), expires, r['id']))
            result = report(json.loads(r['own']), guest, r['kind'])
        return result

    def receipt(self, token, revoke=False):
        with self.memory.db() as db:
            self.purge(db)
            r = db.execute('SELECT * FROM connect_invites WHERE receipt_hash=?', (digest(token),)).fetchone()
            if not r: raise HTTPException(404, 'This report expired or was removed.')
            if revoke:
                db.execute('DELETE FROM connect_invites WHERE id=?', (r['id'],))
                return {'deleted': True}
            return report(json.loads(r['own']), json.loads(r['guest']), r['kind'])
