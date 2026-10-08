// CINESET on-device backend. Answers the same /api routes as server.js, inside the app,
// and keeps everything on the phone: records and settings in IndexedDB, uploaded files as
// Blobs in IndexedDB. Exposed as window.cinesetLocal; window.fetch is routed here for /api/*.
(function(){
  const DB_NAME='cineset',SAMPLE_PASSWORD='Demo1234';
  const now=()=>new Date().toISOString();
  const rid=(p)=>p+'_'+Array.from(crypto.getRandomValues(new Uint8Array(9)),b=>b.toString(16).padStart(2,'0')).join('');
  const day=(offset)=>{const d=new Date();d.setDate(d.getDate()+offset);return d.toISOString().slice(0,10);};
  const S=(v,n)=>String(v??'').slice(0,n);
  const empty=()=>({users:[],workspaces:[],projects:[],comments:[],versions:[],approvals:[],files:[],portfolio:[],invites:[],team:[],calendar:[],quotes:[],invoices:[],contracts:[],notifications:[],aiPlans:[],session:null});

  // ---------- IndexedDB ----------
  let conn;
  const open=()=>new Promise((res,rej)=>{const r=indexedDB.open(DB_NAME,1);r.onupgradeneeded=()=>{const d=r.result;d.createObjectStore('kv');d.createObjectStore('files');};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error);});
  function idb(store,mode,fn){return new Promise((res,rej)=>{const t=conn.transaction(store,mode);const req=fn(t.objectStore(store));t.oncomplete=()=>res(req&&req.result);t.onerror=()=>rej(t.error);t.onabort=()=>rej(t.error||new Error('Storage write aborted'));});}
  const kvGet=(k)=>idb('kv','readonly',s=>s.get(k));
  const kvPut=(k,v)=>idb('kv','readwrite',s=>s.put(v,k));

  let db=empty(),settings={};
  const fileUrls=new Map();
  // Writes are queued so the newest state always lands last.
  let writing=Promise.resolve(),dirty=false;
  function save(){if(dirty)return;dirty=true;queueMicrotask(()=>{dirty=false;const snapshot=JSON.stringify(db);writing=writing.then(()=>kvPut('db',snapshot)).catch(e=>console.error('Saving failed',e));});}

  // ---------- passwords (PBKDF2-SHA256) ----------
  const hex=(buf)=>Array.from(new Uint8Array(buf),b=>b.toString(16).padStart(2,'0')).join('');
  async function hashPassword(password,saltHex){
    const salt=saltHex?Uint8Array.from(saltHex.match(/../g).map(h=>parseInt(h,16))):crypto.getRandomValues(new Uint8Array(16));
    const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(password),'PBKDF2',false,['deriveBits']);
    const bits=await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt,iterations:150000},key,256);
    return {passwordSalt:hex(salt),passwordHash:hex(bits)};
  }
  async function checkPassword(user,password){if(!user?.passwordSalt)return false;const {passwordHash}=await hashPassword(password,user.passwordSalt);return passwordHash===user.passwordHash;}
  const randomPassword=()=>Array.from(crypto.getRandomValues(new Uint8Array(8)),b=>'abcdefghjkmnpqrstuvwxyz23456789'[b%31]).join('');

  // ---------- sample data ----------
  async function sample(){
    const d=empty();
    const pw=await hashPassword(SAMPLE_PASSWORD);const pw2=await hashPassword(SAMPLE_PASSWORD);
    d.users=[{id:'u_creator',email:'creator@cineset.local',name:'CINESET Studio',role:'creator',...pw,createdAt:now()},{id:'u_client',email:'client@cineset.local',name:'Sarah Ahmed',role:'client',...pw2,createdAt:now()}];
    d.workspaces=[{id:'ws_demo',ownerId:'u_creator',name:'CINESET Studio',slug:'cineset-studio',createdAt:now()}];
    d.projects=[{id:'p_bmw',ownerId:'u_creator',clientId:'u_client',name:'BMW Campaign',type:'Commercial',status:'Reviewing',progress:78,createdAt:now()},{id:'p_oud',ownerId:'u_creator',clientId:'u_client',name:'Oud Perfume Launch',type:'Brand Film',status:'Planning',progress:10,createdAt:now()}];
    ['Treatment','Storyboard','First Cut','Final Delivery'].forEach((stage,i)=>{d.approvals.push({id:rid('ap'),projectId:'p_bmw',stage,status:i<2?'Approved':i===2?'Reviewing':'Pending',updatedAt:now()});d.approvals.push({id:rid('ap'),projectId:'p_oud',stage,status:i===0?'Reviewing':'Pending',updatedAt:now()});});
    const v2=rid('ver');
    d.versions=[{id:rid('ver'),projectId:'p_bmw',label:'V1',status:'Superseded',note:'Initial edit',createdAt:now()},{id:v2,projectId:'p_bmw',label:'V2',status:'Reviewing',note:'Slower transition + tighter grade',createdAt:now()}];
    d.comments=[{id:rid('com'),projectId:'p_bmw',versionId:v2,timecode:17,text:'Make this transition a little slower.',authorId:'u_client',resolved:false,createdAt:now()},{id:rid('com'),projectId:'p_bmw',versionId:v2,timecode:34,text:'Love the framing. Keep this shot.',authorId:'u_client',resolved:true,createdAt:now()}];
    d.portfolio=[{id:rid('port'),ownerId:'u_creator',title:'BMW Campaign',type:'Commercial',year:2026,description:'Automotive campaign with restrained camera movement and a cinematic finish.',coverColor:'midnight',public:true,createdAt:now()},{id:rid('port'),ownerId:'u_creator',title:'Brand Film',type:'Brand Film',year:2026,description:'A visual story built around atmosphere, texture and human performance.',coverColor:'silver',public:true,createdAt:now()}];
    d.team=[{id:rid('team'),ownerId:'u_creator',memberUserId:'u_client',role:'client',permissions:{projects:true,review:true,files:true,portfolio:false},createdAt:now()}];
    d.calendar=[{id:rid('cal'),ownerId:'u_creator',projectId:'p_bmw',title:'Shoot Day',date:day(5),time:'09:00',location:'Basra',notes:'Call time 08:30',createdAt:now()},{id:rid('cal'),ownerId:'u_creator',projectId:'p_oud',title:'Location scout',date:day(9),time:'16:30',location:'Old house, Baghdad',notes:'Check sunset angle',createdAt:now()}];
    d.quotes=[{id:rid('quo'),ownerId:'u_creator',projectId:'p_bmw',clientId:'u_client',number:'Q-2026-001',status:'Draft',currency:'USD',items:[{description:'Production package',qty:1,unit:5000}],total:5000,createdAt:now()}];
    d.invoices=[{id:rid('inv'),ownerId:'u_creator',projectId:'p_bmw',clientId:'u_client',number:'INV-2026-001',status:'Pending',currency:'USD',total:2500,dueDate:day(14),createdAt:now()}];
    d.contracts=[{id:rid('ctr'),ownerId:'u_creator',projectId:'p_bmw',clientId:'u_client',title:'Production Agreement',status:'Pending Signature',content:'Scope: one 30-second commercial and two 15-second cutdowns.\nDelivery: ProRes 422 HQ and H.264 masters.\nUsage: online and broadcast in the region for 12 months.\nPayment: 50% on signature, 50% on delivery.',createdAt:now()}];
    d.notifications=[{id:rid('n'),userId:'u_creator',type:'system',title:'Welcome to CINESET',message:'Sample data is loaded. Sign in as creator@cineset.local or client@cineset.local (password Demo1234).',projectId:'p_bmw',read:false,createdAt:now()}];
    return d;
  }

  // ---------- rules shared with server.js ----------
  const me=()=>db.users.find(u=>u.id===db.session)||null;
  const pub=(u)=>u?{id:u.id,email:u.email,name:u.name,role:u.role}:null;
  const forUser=(u,p)=>!!p&&(u.role==='creator'?p.ownerId===u.id:p.clientId===u.id);
  const ownerProject=(u,id)=>{const p=db.projects.find(x=>x.id===id);return p&&u.role==='creator'&&p.ownerId===u.id?p:null;};
  const clientIds=(u)=>{const s=new Set();db.team.forEach(t=>{if(t.ownerId===u.id&&t.role==='client')s.add(t.memberUserId);});db.projects.forEach(p=>{if(p.ownerId===u.id&&p.clientId)s.add(p.clientId);});return s;};
  function links(u,b){const projectId=b.projectId?String(b.projectId).trim():null;const project=projectId?ownerProject(u,projectId):null;if(projectId&&!project)return{error:'Project not found'};const clientId=b.clientId?String(b.clientId).trim():(project?.clientId||null);if(clientId&&!clientIds(u).has(clientId))return{error:'Client not found. Add them in Clients first.'};if(project?.clientId&&clientId&&clientId!==project.clientId)return{error:'Client is not on this project'};return{projectId,clientId};}
  function notify(userId,type,title,message,projectId=null){if(!userId)return;db.notifications.unshift({id:rid('n'),userId,type,title,message,projectId,read:false,createdAt:now()});db.notifications=db.notifications.slice(0,500);}

  // ---------- AI ----------
  const PLAN_SCHEMA={type:'object',properties:{treatment:{type:'string',description:'Creative treatment: concept, tone, visual references and how the piece should feel.'},shots:{type:'array',items:{type:'string'},description:'Ordered shot list. Each entry names the shot size/movement and what it shows.'},lighting:{type:'string',description:'Lighting approach and key setups.'},camera:{type:'string',description:'Camera, lens and movement approach.'},checklist:{type:'array',items:{type:'string'},description:'Concrete pre-production tasks to complete before the shoot.'}},required:['treatment','shots','lighting','camera','checklist'],additionalProperties:false};
  const SYSTEM=`You are a senior producer and director of photography helping a small production company plan shoots (commercials, music videos, brand films, documentaries, photography).
Given a client brief, write a practical production plan the crew can act on. Be specific to the brief: locations, time of day, talent, product and mood it describes. Where the brief leaves something open, choose a sensible option and say so briefly.
Keep the shot list to the shots actually needed (usually 6-15). Write in the same language as the brief.`;
  function templatePlan(brief){
    const b=brief.toLowerCase();const night=/night|ليل|evening|مساء/.test(b),sunset=/sunset|golden|غروب/.test(b),product=/perfume|عطر|car|سيارة|product|منتج|watch|ساعة/.test(b);
    return {treatment:`A cinematic piece built around: ${brief}. Keep the pace patient and let ${product?'the product':'the subject'} carry the frame; texture and light do the storytelling.`,
      shots:['Wide establishing shot of the location',sunset?'Silhouette against the low sun':'Slow push-in on the main subject',product?'Macro detail of the product surface':'Close-up on hands and expression','Tracking shot following the subject through the space',product?'Hero product shot on a clean surface':'Medium shot of the key performance moment','Closing wide as the light fades'],
      lighting:night?'Practical lamps in frame, one soft key from 45°, haze for depth.':sunset?'Natural backlight at golden hour, bounce for fill, negative fill on the shadow side.':'Large soft key through diffusion, negative fill, subtle hair light.',
      camera:'Full-frame cinema camera, 35mm and 85mm primes, 100mm macro for details; slider and gimbal for slow, intentional movement.',
      checklist:['Confirm location access and permits','Lock talent and crew call times','Prepare camera, lens and lighting package','Plan backup media and power','Confirm delivery formats and aspect ratios']};
  }
  async function claudePlan(brief){
    const SDK=window.AnthropicSDK;const Anthropic=SDK?.default||SDK;
    if(!Anthropic)throw Object.assign(new Error('Claude library is missing from this build.'),{status:500});
    const client=new Anthropic({apiKey:settings.anthropicKey,dangerouslyAllowBrowser:true,timeout:120000,maxRetries:2});
    let response;
    try{
      response=await client.beta.messages.create({model:'claude-opus-5-5',max_tokens:16000,betas:['server-side-fallback-2026-07-01'],fallbacks:'default',output_config:{effort:'medium',format:{type:'json_schema',schema:PLAN_SCHEMA}},system:SYSTEM,messages:[{role:'user',content:`Client brief:\n\n${brief}`}]});
    }catch(e){
      if(e instanceof Anthropic.AuthenticationError)throw Object.assign(new Error('Claude rejected the API key. Check it in Settings.'),{status:502});
      if(e instanceof Anthropic.RateLimitError)throw Object.assign(new Error('Claude is busy right now. Try again in a minute.'),{status:503});
      if(e instanceof Anthropic.APIConnectionError)throw Object.assign(new Error('No internet connection. Claude needs internet; the rest of CINESET works offline.'),{status:503});
      if(e instanceof Anthropic.APIError)throw Object.assign(new Error(`Claude request failed (${e.status??'network'}).`),{status:502});
      throw e;
    }
    if(response.stop_reason==='refusal')throw Object.assign(new Error('Claude declined to plan this brief.'),{status:422});
    if(response.stop_reason==='max_tokens')throw Object.assign(new Error('The plan was too long. Try a shorter brief.'),{status:502});
    let r;try{r=JSON.parse(response.content.filter(x=>x.type==='text').map(x=>x.text).join(''));}catch{throw Object.assign(new Error('Claude returned an unreadable plan. Try again.'),{status:502});}
    const str=(v)=>String(v??''),list=(v)=>Array.isArray(v)?v.map(str).filter(Boolean):[];
    return {source:'claude',model:response.model,result:{treatment:str(r.treatment),shots:list(r.shots),lighting:str(r.lighting),camera:str(r.camera),checklist:list(r.checklist)}};
  }

  // ---------- routes ----------
  class Reply{constructor(status,body){this.status=status;this.body=body;}}
  const ok=(b)=>new Reply(200,b),err=(s,m)=>new Reply(s,{error:m});

  async function route(method,path,body){
    const u=me();let m;
    if(method==='GET'&&path==='/api/health')return ok({ok:true,service:'CINESET',version:'2.0.0-mobile',env:'device',demo:db.users.some(x=>x.email==='creator@cineset.local')});
    if(method==='GET'&&path==='/api/auth/me')return u?ok({user:pub(u)}):err(401,'Unauthorized');
    if(method==='POST'&&path==='/api/auth/login'){const email=S(body.email).trim().toLowerCase();const x=db.users.find(y=>y.email===email);if(!x||!(await checkPassword(x,String(body.password||''))))return err(401,'Invalid email or password');db.session=x.id;save();return ok({user:pub(x)});}
    if(method==='POST'&&path==='/api/auth/logout'){db.session=null;save();return ok({ok:true});}
    if(method==='POST'&&path==='/api/auth/register'){const email=S(body.email).trim().toLowerCase(),name=S(body.name,120).trim(),pw=String(body.password||'');if(!/^\S+@\S+\.\S+$/.test(email)||!name||pw.length<8)return err(400,'Name, valid email and password (8+ chars) are required');if(db.users.some(x=>x.email===email))return err(409,'Email already exists');const x={id:rid('user'),email,name,role:'creator',...(await hashPassword(pw)),createdAt:now()};db.users.push(x);db.workspaces.push({id:rid('ws'),ownerId:x.id,name:name+' Workspace',createdAt:now()});db.session=x.id;save();return ok({user:pub(x)});}
    if(!u&&!path.startsWith('/api/public/'))return err(401,'Unauthorized');

    if(method==='GET'&&path==='/api/projects')return ok(db.projects.filter(x=>forUser(u,x)));
    if(method==='POST'&&path==='/api/projects'){if(u.role!=='creator')return err(403,'Creator only');const email=S(body.clientEmail).trim().toLowerCase();let client=null;if(email){const allowed=clientIds(u);client=db.users.find(x=>x.role==='client'&&x.email===email&&allowed.has(x.id));if(!client)return err(400,'No client with that email in your workspace. Add them in Clients first.');}const p={id:rid('proj'),ownerId:u.id,clientId:client?.id||null,name:S(body.name||'Untitled Project',120).trim(),type:S(body.type||'Commercial',60),status:'Planning',progress:0,createdAt:now()};db.projects.push(p);['Treatment','Storyboard','First Cut','Final Delivery'].forEach((stage,i)=>db.approvals.push({id:rid('ap'),projectId:p.id,stage,status:i===0?'Reviewing':'Pending',updatedAt:now()}));if(client)notify(client.id,'project','New project',`You were added to ${p.name}.`,p.id);save();return ok(p);}
    if(method==='GET'&&(m=path.match(/^\/api\/projects\/([^/]+)$/))){const q=db.projects.find(x=>x.id===m[1]);if(!forUser(u,q))return err(404,'Not found');const name=(id)=>db.users.find(x=>x.id===id)?.name||'';return ok({project:q,owner:name(q.ownerId),client:q.clientId?name(q.clientId):'',comments:db.comments.filter(x=>x.projectId===q.id).map(c=>({...c,authorName:name(c.authorId)||'User'})),versions:db.versions.filter(x=>x.projectId===q.id),approvals:db.approvals.filter(x=>x.projectId===q.id),files:db.files.filter(x=>x.projectId===q.id),events:db.calendar.filter(x=>x.projectId===q.id),quotes:db.quotes.filter(x=>x.projectId===q.id),invoices:db.invoices.filter(x=>x.projectId===q.id),contracts:db.contracts.filter(x=>x.projectId===q.id)});}
    if(method==='POST'&&(m=path.match(/^\/api\/projects\/([^/]+)\/comments$/))){const q=db.projects.find(x=>x.id===m[1]);if(!forUser(u,q))return err(404,'Not found');const t=S(body.text).trim();if(!t)return err(400,'Comment required');const c={id:rid('com'),projectId:q.id,versionId:body.versionId||null,timecode:Math.max(0,Number(body.timecode)||0),text:t.slice(0,2000),authorId:u.id,resolved:false,createdAt:now()};db.comments.push(c);notify(u.role==='creator'?q.clientId:q.ownerId,'comment','New feedback',`${u.name} added feedback on ${q.name}.`,q.id);save();return ok({...c,authorName:u.name});}
    if(method==='PATCH'&&(m=path.match(/^\/api\/comments\/([^/]+)$/))){const c=db.comments.find(x=>x.id===m[1]),q=c&&db.projects.find(x=>x.id===c.projectId);if(!c||!forUser(u,q))return err(404,'Not found');c.resolved=!!body.resolved;save();return ok(c);}
    if(method==='POST'&&(m=path.match(/^\/api\/projects\/([^/]+)\/versions$/))){const q=ownerProject(u,m[1]);if(!q)return err(404,'Not found');db.versions.filter(x=>x.projectId===q.id&&x.status==='Reviewing').forEach(x=>x.status='Superseded');const v={id:rid('ver'),projectId:q.id,label:S(body.label||`V${db.versions.filter(x=>x.projectId===q.id).length+1}`,30),status:'Reviewing',note:S(body.note,1000),createdAt:now()};db.versions.push(v);q.status='Reviewing';notify(q.clientId,'version','New version ready',`${v.label} is ready for review.`,q.id);save();return ok(v);}
    if(method==='PATCH'&&(m=path.match(/^\/api\/approvals\/([^/]+)$/))){const a=db.approvals.find(x=>x.id===m[1]),q=a&&db.projects.find(x=>x.id===a.projectId);if(!a||!forUser(u,q))return err(404,'Not found');const allowed=u.role==='client'?['Approved','Changes Requested']:['Approved','Reviewing','Pending','Changes Requested'];if(!allowed.includes(body.status))return err(400,'Invalid status');a.status=body.status;a.updatedAt=now();if(a.status==='Approved'){const remain=db.approvals.filter(x=>x.projectId===q.id&&x.status!=='Approved').length;q.progress=Math.min(100,q.progress+25);q.status=remain===0?'Delivered':'Reviewing';}if(u.role==='client')notify(q.ownerId,'approval','Approval updated',`${u.name} updated ${a.stage} to ${a.status}.`,q.id);save();return ok(a);}

    if(method==='GET'&&path==='/api/clients'){if(u.role!=='creator')return err(403,'Creator only');const allowed=clientIds(u);return ok(db.users.filter(x=>x.role==='client'&&allowed.has(x.id)).map(c=>({id:c.id,name:c.name,email:c.email,projects:db.projects.filter(q=>q.ownerId===u.id&&q.clientId===c.id).length})));}
    if(method==='POST'&&path==='/api/invites'){
      // On a phone there is no inbox: the client account is created here, with a one-time password for the creator to pass on.
      if(u.role!=='creator')return err(403,'Creator only');const email=S(body.email).trim().toLowerCase();if(!/^\S+@\S+\.\S+$/.test(email))return err(400,'Valid email required');
      let x=db.users.find(y=>y.email===email);let note;
      if(x&&x.role!=='client')return err(409,'That email belongs to a creator account');
      if(!x){const password=randomPassword();x={id:rid('user'),email,name:email.split('@')[0],role:'client',...(await hashPassword(password)),createdAt:now()};db.users.push(x);note=`Client account created for ${email}.\n\nPassword: ${password}\n\nGive them this password so they can sign in on this phone. It is shown only once.`;}
      else note=`${email} already has a client account on this phone and is now in your workspace.`;
      if(!db.team.some(t=>t.ownerId===u.id&&t.memberUserId===x.id))db.team.push({id:rid('team'),ownerId:u.id,memberUserId:x.id,role:'client',permissions:{projects:true,review:true,files:true,portfolio:false},createdAt:now()});
      db.invites.push({id:rid('invite'),ownerId:u.id,email,acceptedAt:now(),createdAt:now()});save();
      return ok({inviteUrl:'',emailed:false,demoNote:note});
    }
    if(method==='GET'&&path==='/api/team'){if(u.role!=='creator')return err(403,'Creator only');return ok(db.team.filter(t=>t.ownerId===u.id).map(t=>({...t,user:pub(db.users.find(x=>x.id===t.memberUserId))})));}
    if(method==='PATCH'&&(m=path.match(/^\/api\/team\/([^/]+)$/))){if(u.role!=='creator')return err(403,'Creator only');const t=db.team.find(x=>x.id===m[1]&&x.ownerId===u.id);if(!t)return err(404,'Not found');t.permissions=Object.assign({},t.permissions,body.permissions||{});save();return ok(t);}

    if(method==='GET'&&path==='/api/portfolio')return ok(db.portfolio.filter(x=>x.ownerId===u.id));
    if(method==='POST'&&path==='/api/portfolio'){if(u.role!=='creator')return err(403,'Creator only');const w={id:rid('port'),ownerId:u.id,title:S(body.title||'Untitled',120),type:S(body.type||'Project',60),year:Number(body.year)||new Date().getFullYear(),description:S(body.description,1000),coverColor:S(body.coverColor||'midnight',30),public:body.public!==false,createdAt:now()};db.portfolio.push(w);save();return ok(w);}
    if(method==='DELETE'&&(m=path.match(/^\/api\/portfolio\/([^/]+)$/))){if(u.role!=='creator')return err(403,'Creator only');const i=db.portfolio.findIndex(x=>x.id===m[1]&&x.ownerId===u.id);if(i<0)return err(404,'Not found');db.portfolio.splice(i,1);save();return ok({ok:true});}
    if(method==='GET'&&(m=path.match(/^\/api\/public\/portfolio\/([^/]+)$/))){const c=db.users.find(x=>x.id===m[1]&&x.role==='creator');if(!c)return err(404,'Not found');return ok({creator:{id:c.id,name:c.name},items:db.portfolio.filter(x=>x.ownerId===c.id&&x.public)});}

    if(method==='GET'&&path==='/api/calendar')return ok(db.calendar.filter(e=>u.role==='creator'?e.ownerId===u.id:db.projects.some(p=>p.id===e.projectId&&p.clientId===u.id)));
    if(method==='POST'&&path==='/api/calendar'){if(u.role!=='creator')return err(403,'Creator only');const t=links(u,{projectId:body.projectId});if(t.error)return err(400,t.error);const ev={id:rid('cal'),ownerId:u.id,projectId:t.projectId,title:S(body.title||'Event',120),date:S(body.date,20),time:S(body.time,20),location:S(body.location,180),notes:S(body.notes,1000),createdAt:now()};db.calendar.push(ev);const p=db.projects.find(x=>x.id===ev.projectId);if(p)notify(p.clientId,'calendar','Schedule updated',`${ev.title} was added to ${p.name}.`,p.id);save();return ok(ev);}
    if(method==='DELETE'&&(m=path.match(/^\/api\/calendar\/([^/]+)$/))){if(u.role!=='creator')return err(403,'Creator only');const i=db.calendar.findIndex(x=>x.id===m[1]&&x.ownerId===u.id);if(i<0)return err(404,'Not found');db.calendar.splice(i,1);save();return ok({ok:true});}

    for(const [col,label] of [['quotes','quote'],['invoices','invoice'],['contracts','contract']]){
      if(method==='GET'&&path===`/api/${col}`)return ok(db[col].filter(x=>u.role==='creator'?x.ownerId===u.id:x.clientId===u.id));
      if(method==='POST'&&path===`/api/${col}`){if(u.role!=='creator')return err(403,'Creator only');const t=links(u,body);if(t.error)return err(400,t.error);let rec;const year=new Date().getFullYear();
        if(col==='quotes'){const items=Array.isArray(body.items)?body.items.map(x=>({description:S(x.description||'Item',200),qty:Number(x.qty)||1,unit:Number(x.unit)||0})):[];rec={id:rid('quo'),ownerId:u.id,projectId:t.projectId,clientId:t.clientId,number:`Q-${year}-${String(db.quotes.length+1).padStart(3,'0')}`,status:'Draft',currency:'USD',items,total:items.reduce((s,x)=>s+x.qty*x.unit,0),createdAt:now()};}
        else if(col==='invoices')rec={id:rid('inv'),ownerId:u.id,projectId:t.projectId,clientId:t.clientId,number:`INV-${year}-${String(db.invoices.length+1).padStart(3,'0')}`,status:'Pending',currency:'USD',total:Number(body.total)||0,dueDate:S(body.dueDate,20),createdAt:now()};
        else rec={id:rid('ctr'),ownerId:u.id,projectId:t.projectId,clientId:t.clientId,title:S(body.title||'Production Agreement',160),status:'Pending Signature',content:S(body.content,10000),createdAt:now()};
        db[col].push(rec);notify(rec.clientId,label,`New ${label}`,col==='contracts'?`${rec.title} is ready for review.`:`${label==='quote'?'Quote':'Invoice'} ${rec.number} is ready.`,rec.projectId);save();return ok(rec);}
      if(method==='PATCH'&&(m=path.match(new RegExp(`^/api/${col}/([^/]+)$`)))){const rec=db[col].find(x=>x.id===m[1]);if(!rec)return err(404,'Not found');if((u.role==='creator'&&rec.ownerId!==u.id)||(u.role==='client'&&rec.clientId!==u.id))return err(403,'Forbidden');if(col==='contracts'&&u.role==='client'&&!['Signed','Changes Requested'].includes(body.status))return err(400,'Invalid status');rec.status=S(body.status||rec.status,40);if(u.role==='client')notify(rec.ownerId,label,`${label[0].toUpperCase()+label.slice(1)} update`,`${u.name} marked ${rec.number||rec.title} as ${rec.status}.`,rec.projectId);save();return ok(rec);}
    }

    if(method==='GET'&&path==='/api/notifications')return ok(db.notifications.filter(n=>n.userId===u.id));
    if(method==='PATCH'&&(m=path.match(/^\/api\/notifications\/([^/]+)$/))){const n=db.notifications.find(x=>x.id===m[1]&&x.userId===u.id);if(!n)return err(404,'Not found');n.read=true;save();return ok(n);}
    if(method==='POST'&&path==='/api/ai/production-plan'){const brief=S(body.brief).trim();if(!brief)return err(400,'Brief required');if(brief.length>4000)return err(400,'Brief is too long (4000 characters max)');const out=settings.anthropicKey?await claudePlan(brief):{source:'baseline',result:templatePlan(brief)};const plan={id:rid('ai'),ownerId:u.id,brief,source:out.source,model:out.model,createdAt:now(),result:out.result};db.aiPlans.unshift(plan);db.aiPlans=db.aiPlans.slice(0,200);save();return ok(plan);}
    return err(404,'Not found');
  }

  async function upload(path,init){
    const u=me();const m=path.match(/^\/api\/projects\/([^/]+)\/files$/);const q=u&&m&&db.projects.find(x=>x.id===m[1]);
    if(!u)return err(401,'Unauthorized');if(!q||!forUser(u,q)||u.role!=='creator')return err(403,'Creator only');
    const h=new Headers(init.headers||{});const blob=init.body instanceof Blob?init.body:new Blob([init.body||'']);
    const f={id:rid('file'),projectId:q.id,ownerId:q.ownerId,uploadedBy:u.id,originalName:S(h.get('X-Filename')||'upload.bin',180).replace(/[^\p{L}\p{N}._ -]/gu,'_'),mime:h.get('Content-Type')||blob.type||'application/octet-stream',size:blob.size,createdAt:now()};
    try{await idb('files','readwrite',s=>s.put(blob,f.id));}catch(e){return err(507,'Not enough space on the phone to save this file.');}
    fileUrls.set(f.id,URL.createObjectURL(blob));db.files.push(f);notify(q.clientId,'file','New file',`${f.originalName} was added to ${q.name}.`,q.id);save();
    return ok({id:f.id,originalName:f.originalName,mime:f.mime,size:f.size});
  }

  // ---------- backup ----------
  const toB64=(blob)=>new Promise((res,rej)=>{const r=new FileReader();r.onload=()=>res(String(r.result).split(',')[1]||'');r.onerror=()=>rej(r.error);r.readAsDataURL(blob);});
  async function exportBackup(includeFiles){
    const files=[];
    if(includeFiles)for(const f of db.files){const blob=await idb('files','readonly',s=>s.get(f.id));if(blob)files.push({id:f.id,mime:f.mime,data:await toB64(blob)});}
    const data={...db,session:null};
    return new Blob([JSON.stringify({format:'cineset-backup',version:1,exportedAt:now(),data,files})],{type:'application/json'});
  }
  async function importBackup(file){
    let parsed;try{parsed=JSON.parse(await file.text());}catch{throw new Error('This file is not a CINESET backup.');}
    if(parsed?.format!=='cineset-backup'||!parsed.data||!Array.isArray(parsed.data.users))throw new Error('This file is not a CINESET backup.');
    const next=Object.assign(empty(),parsed.data,{session:null});
    for(const k of Object.keys(empty()))if(k!=='session'&&!Array.isArray(next[k]))next[k]=[];
    await idb('files','readwrite',s=>s.clear());
    for(const f of parsed.files||[]){const bin=atob(f.data);const bytes=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)bytes[i]=bin.charCodeAt(i);await idb('files','readwrite',s=>s.put(new Blob([bytes],{type:f.mime}),f.id));}
    db=next;await kvPut('db',JSON.stringify(db));
    return {users:db.users.length,projects:db.projects.length,files:(parsed.files||[]).length};
  }

  // ---------- public surface ----------
  const ready=(async()=>{
    conn=await open();
    try{const raw=await kvGet('db');if(raw){const parsed=JSON.parse(raw);db=Object.assign(empty(),parsed);}}catch(e){console.error('Could not read saved data',e);}
    settings=(await kvGet('settings'))||{};
    // Blobs read from IndexedDB are file-backed, so making URLs for all of them is cheap.
    for(const f of db.files){const blob=await idb('files','readonly',s=>s.get(f.id));if(blob)fileUrls.set(f.id,URL.createObjectURL(blob));}
    try{await navigator.storage?.persist?.();}catch{}
  })();

  window.cinesetLocal={
    ready,
    canLoadSample:()=>db.users.length===0,
    async loadSample(){db=await sample();await kvPut('db',JSON.stringify(db));},
    fileUrl:(id)=>fileUrls.get(id)||'',
    fileInfo:(id)=>db.files.find(f=>f.id===id)||null,
    async fileBlob(id){return idb('files','readonly',s=>s.get(id));},
    hasClaudeKey:()=>!!settings.anthropicKey,
    async setClaudeKey(key){settings={...settings,anthropicKey:String(key||'').trim()||undefined};await kvPut('settings',settings);},
    async storageEstimate(){try{return await navigator.storage.estimate();}catch{return null;}},
    filesTotalBytes:()=>db.files.reduce((s,f)=>s+(Number(f.size)||0),0),
    exportBackup,importBackup,
    async flush(){await writing;},
  };

  const realFetch=window.fetch.bind(window);
  window.fetch=async function(input,init={}){
    const url=typeof input==='string'?input:input.url;
    if(!url.startsWith('/api/'))return realFetch(input,init);
    await ready;
    const method=(init.method||'GET').toUpperCase();const path=url.split('?')[0];
    let reply;
    try{
      if(method==='POST'&&/\/files$/.test(path))reply=await upload(path,init);
      else{let body={};if(typeof init.body==='string'&&init.body){try{body=JSON.parse(init.body);}catch{return new Response(JSON.stringify({error:'Invalid JSON'}),{status:400});}}reply=await route(method,path,body);}
    }catch(e){reply=err(e.status||500,e.message||'Something went wrong');}
    return new Response(JSON.stringify(reply.body),{status:reply.status,headers:{'Content-Type':'application/json'}});
  };
})();
