'use strict';
const $=id=>document.getElementById(id), node=(tag,value)=>{const n=document.createElement(tag);n.textContent=value;return n;};
let token='', person='alex', envelope=null, currentMatch=null, pendingMessage=null, busy=false;
const blobs=[];
let history=[], before=null, replyTo=null;
async function api(path,method='GET',body){const r=await fetch(path,{method,headers:{'Authorization':'Bearer '+token,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),cache:'no-store'});if(!r.ok){const e=await r.json();throw Error(typeof e.detail==='string'?e.detail:'Check your birth time, time zone and profile fields.');}return r.json();}
function status(s){$('status').textContent=s;}
function show(id){for(const v of ['discover','profile','matches','invite'])$(v).hidden=v!==id;status('');}
async function act(work){if(busy)return;busy=true;$('person').disabled=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);try{await work();}catch(e){status(e.message);}finally{busy=false;$('person').disabled=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}}
function button(label,work,secondary=false){const b=node('button',label);if(secondary)b.className='secondary';b.onclick=()=>act(work);return b;}
async function portrait(id,name){if(!id){const n=node('div',name.slice(0,1));n.className='placeholder';n.append(node('small','A person, beyond a picture.'));return n;}const r=await fetch('/v1/dating/photos/'+id,{headers:{Authorization:'Bearer '+token},cache:'no-store'});if(!r.ok)return portrait(null,name);const url=URL.createObjectURL(await r.blob());blobs.push(url);const img=new Image();img.src=url;img.alt='Profile photo of '+name;img.className='portrait';return img;}
function report(r){const d=node('details','');d.className='report';d.append(node('summary','Why we might connect'));for(const lens of r.dimensions){d.append(node('h3',lens.title+' · '+(lens.score===null?'Not provided':lens.score+'/100')),node('p',lens.explanation),node('p','Ask: '+lens.prompt));}d.append(node('p',r.disclaimer));return d;}
async function load(){while(blobs.length)URL.revokeObjectURL(blobs.pop());envelope=await api('/v1/dating/profile');const [discovery,likes,matches]=await Promise.all([api('/v1/dating/discover'),api('/v1/dating/likes'),api('/v1/dating/matches')]);$('cards').replaceChildren();const p=discovery.profiles[0];if(!p){$('cards').append(node('h2',envelope.status==='approved'?'Room for a new connection.':'Your profile is awaiting review.'),node('p',envelope.status==='approved'?'No new profiles match both people’s preferences. Your saved likes and matches are still below.':'Open My profile and simulate approval to continue this local demo.'));}else{const c=node('article','');c.className='card';c.append(await portrait(p.photo_id,p.name),node('h2',p.name+', '+p.age),node('p',p.city+' · '+'Here for friendship'),node('p',p.bio));const score=node('p',p.pairing.score+' / 100 · Conversation fit');score.className='score';c.append(score,node('p',p.pairing.report.strengths[0]),report(p.pairing.report));const actions=node('div','');actions.className='actions';actions.append(button('Pass',async()=>{await api('/v1/dating/profiles/'+p.id+'/pass','POST');await load();status('Passed. This profile stays out of recommendations.');},true),button('Let’s connect',async()=>{const r=await api('/v1/dating/profiles/'+p.id+'/like','POST');await load();status(r.matched?'It’s a mutual connection! Open Connections to talk.':'Request saved. Switch people and connect back to open a conversation.');}));c.append(actions);$('cards').append(c);}
$('likes').replaceChildren(...likes.profiles.map(p=>{const r=node('div','');r.className='row';r.append(node('span',p.name),button('Withdraw request',async()=>{await api('/v1/dating/profiles/'+p.id+'/like','DELETE');await load();status('Request withdrawn.');},true));return r;}));
renderInbox(matches.matches);
const f=$('profile-form');for(const [k,v] of Object.entries(envelope.profile)){const input=f.elements[k];if(!input)continue;if(k==='seeking')input.value=v.length===3?'all':v[0];else if(k==='visible')input.checked=v;else input.value=v??'';}
$('review-status').textContent='Profile status: '+envelope.status;$('own-photo').replaceChildren(await portrait(envelope.photo_id,envelope.profile.name));}
async function switchPerson(){person=$('person').value;$('message').value='';$('send-message').textContent='Send message';const r=await fetch('/demo/session/'+person);token=(await r.json()).token;currentMatch=null;pendingMessage=null;history=[];before=null;replyTo=null;$('chat').hidden=true;$('invite-link').removeAttribute('href');$('invite-link').textContent='';await load();show('discover');}
for(const id of ['discover','profile','matches','invite'])$(id+'-tab').onclick=()=>show(id);
$('person').onchange=()=>act(switchPerson);
for(const zone of Intl.supportedValuesOf('timeZone')){const o=node('option',zone.replaceAll('_',' '));o.value=zone;$('zone').append(o);}
for(const type of ['unknown','ENFJ','ENFP','ENTJ','ENTP','ESFJ','ESFP','ESTJ','ESTP','INFJ','INFP','INTJ','INTP','ISFJ','ISFP','ISTJ','ISTP']){const o=node('option',type==='unknown'?'Not sure':type);o.value=type;$('mbti').append(o);}
$('profile-form').onsubmit=e=>{e.preventDefault();act(async()=>{const p={...envelope.profile,...Object.fromEntries(new FormData(e.target))};p.birth_date=envelope.profile.birth_date;p.birth_time=p.birth_time||null;p.birth_longitude=null;p.birth_fold=null;p.age_min=Number(p.age_min);p.age_max=Number(p.age_max);p.seeking=['man','woman','nonbinary'];p.consent_version='friends-v1';p.visible=e.target.elements.visible.checked;await api('/v1/dating/profile','PUT',{expected_revision:envelope.revision,profile:p});await load();status('Saved. If public details changed, simulate approval below to try discovery.');});};
$('upload').onclick=()=>act(async()=>{const f=$('photo').files[0];if(!f)throw Error('Choose a photo first.');if(f.size>1048576)throw Error('Choose a JPEG or PNG up to 1 MB.');const bytes=new Uint8Array(await f.arrayBuffer());let raw='';for(const b of bytes)raw+=String.fromCharCode(b);await api('/v1/dating/profile/photo','PUT',{expected_revision:envelope.revision,image:btoa(raw)});await load();status('Photo saved locally. Simulate approval to include it in discovery.');});
$('remove-photo').onclick=()=>act(async()=>{await api('/v1/dating/profile/photo','DELETE',{expected_revision:envelope.revision});await load();status('Photo removed.');});
$('review').onclick=()=>act(async()=>{await api('/demo/review/'+person,'POST');await load();status('Local demo profile approved. Production uses a private operator review.');});
function renderInbox(matches){
$('match-list').replaceChildren(...matches.map(m=>button((m.pinned?'📌 ':'')+m.profile.name+(m.unread_count?' · '+m.unread_count+' unread':'')+' — '+(m.last_message||'Say hello'),async()=>{currentMatch=m;pendingMessage=null;history=[];before=null;replyTo=null;await chat();})));
if(!matches.length)$('match-list').append(node('p','Your mutual connections will appear here.'));
}
function replyLabel(){ $('reply-preview').textContent=replyTo?'Replying: '+replyTo.text:'';$('cancel-reply').hidden=!replyTo; }
async function chat(older=false){
if(!currentMatch)return;
const path='/v1/dating/matches/'+currentMatch.id;
const data=await api(path+'/history','POST',{before:older?before:null});
const oldLast=history.at(-1)?.sequence;
if(!older&&oldLast&&data.messages[0]?.sequence>oldLast+1)history=[];
if(older||!history.length)before=data.next_before;
const merged=new Map(history.map(m=>[m.id,m]));for(const m of data.messages)merged.set(m.id,m);
history=[...merged.values()].sort((a,b)=>a.sequence-b.sequence);
$('chat').hidden=false;$('chat-title').textContent=currentMatch.profile.name;$('opener').textContent=currentMatch.profile.pairing.prompt;
$('older').hidden=before===null;$('pin').textContent=data.pinned?'Unpin conversation':'Pin conversation';$('receipts').checked=data.read_receipts;
$('messages').replaceChildren(...history.map(m=>{const row=node('div','');row.className='bubble '+(m.mine?'mine':'theirs');if(m.reply_preview)row.append(node('blockquote',m.reply_preview));row.append(node('p',m.text),node('small',new Date(m.created_at*1000).toLocaleString()+(m.mine?(m.seen?' · Seen':' · Sent'):'')),button('Reply',async()=>{replyTo=m;replyLabel();$('message').focus();},true));return row;}));
replyLabel();
if(!older&&data.messages.length){await api(path+'/read','POST',{sequence:data.messages.at(-1).sequence});if(oldLast!==history.at(-1)?.sequence)$('messages').scrollTop=$('messages').scrollHeight;}
}
$('older').onclick=()=>act(()=>chat(true));
$('cancel-reply').onclick=()=>{replyTo=null;replyLabel();};
$('pin').onclick=()=>act(async()=>{await api('/v1/dating/matches/'+currentMatch.id+'/settings','PATCH',{pinned:$('pin').textContent==='Pin conversation'});await chat();renderInbox((await api('/v1/dating/matches')).matches);});
$('receipts').onchange=()=>act(async()=>{await api('/v1/dating/matches/'+currentMatch.id+'/settings','PATCH',{read_receipts:$('receipts').checked});await chat();});
$('message-form').onsubmit=e=>{e.preventDefault();act(async()=>{if(!currentMatch)return;const draft=$('message').value.trim();if(!draft&&!pendingMessage)return;if(!pendingMessage)pendingMessage={id:crypto.randomUUID(),text:draft,reply_to:replyTo?.id||null};try{await api('/v1/dating/matches/'+currentMatch.id+'/messages','POST',pendingMessage);}catch(e){$('send-message').textContent='Retry message';throw e;}if($('message').value.trim()===pendingMessage.text)$('message').value='';pendingMessage=null;replyTo=null;$('send-message').textContent='Send message';await chat();});};
setInterval(()=>{if(!token||busy||document.hidden||$('matches').hidden)return;act(async()=>{renderInbox((await api('/v1/dating/matches')).matches);if(currentMatch)await chat();});},5000);
$('unmatch').onclick=()=>act(async()=>{if(!currentMatch||!confirm('End this connection and delete this local demo conversation?'))return;await api('/v1/dating/matches/'+currentMatch.id,'DELETE');currentMatch=null;$('chat').hidden=true;await load();status('Connection ended. Future contact is blocked.');});
$('create-invite').onclick=()=>act(async()=>{const state=await api('/v1/connect');const {name,birth_date,birth_time,birth_timezone,birth_place,birth_longitude,birth_fold,mbti,intention,communication,social,value}=envelope.profile;await api('/v1/connect/profile','PUT',{expected_revision:state.revision,profile:{name,birth_date,birth_time,birth_timezone,birth_place,birth_longitude,birth_fold,mbti,intention,communication,social,value,consent_version:'connect-v1'}});const i=await api('/v1/connect/invitations','POST',{id:crypto.randomUUID(),kind:'friendship'});const a=$('invite-link');a.href=location.origin+'/connect#invite='+i.token;a.textContent='Open private invitation →';status('This demo invitation only opens on this Mac.');});
act(switchPerson);
