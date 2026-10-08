// Persistence for the in-memory `db` object.
// - No DATABASE_URL: a local JSON file (development).
// - DATABASE_URL set: PostgreSQL. Every record is a row in `cineset_records`
//   (collection, id, data jsonb). The app works on the in-memory copy and
//   save() writes only the rows that changed since the last successful write.
const fs=require('fs');
const path=require('path');

function readJsonFile(file){try{return JSON.parse(fs.readFileSync(file,'utf8'));}catch{return null;}}
function normalize(data,empty){const db=data&&typeof data==='object'?data:{};for(const k of Object.keys(empty))if(!Array.isArray(db[k]))db[k]=[];return db;}

function jsonStore({dbPath,empty}){
  fs.mkdirSync(path.dirname(dbPath),{recursive:true});
  const db=normalize(readJsonFile(dbPath)||structuredClone(empty),empty);
  const save=()=>{const tmp=dbPath+'.tmp';fs.writeFileSync(tmp,JSON.stringify(db,null,2));fs.renameSync(tmp,dbPath);};
  return {kind:'json',db,save,flush:async()=>{},close:async()=>{}};
}

async function postgresStore({databaseUrl,ssl,empty,importFrom}){
  const {Pool}=require('pg');
  const pool=new Pool({connectionString:databaseUrl,ssl:ssl==='no-verify'?{rejectUnauthorized:false}:undefined,max:5});
  pool.on('error',e=>console.error('PostgreSQL pool error:',e.message));
  await pool.query(`CREATE TABLE IF NOT EXISTS cineset_records(
    collection text NOT NULL,
    id text NOT NULL,
    data jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(collection,id))`);

  const db=normalize({},empty);
  // Last persisted JSON per row, used to find what changed.
  const persisted=new Map(Object.keys(empty).map(k=>[k,new Map()]));
  const {rows}=await pool.query('SELECT collection,id,data FROM cineset_records ORDER BY collection,id');
  for(const r of rows){if(!persisted.has(r.collection))continue;db[r.collection].push(r.data);persisted.get(r.collection).set(r.id,JSON.stringify(r.data));}
  // Keep newest-first collections in the order the app expects.
  db.notifications.sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt)));
  db.aiPlans.sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt)));

  // First start against an empty database: bring over the local JSON data, if any.
  let imported=false;
  if(!rows.length&&importFrom){const local=readJsonFile(importFrom);if(local&&Array.isArray(local.users)&&local.users.length){Object.assign(db,normalize(local,empty));imported=true;}}

  let running=null,again=false;
  async function writeChanges(){
    const upserts=[],deletes=[],next=new Map();
    for(const [col,known] of persisted){
      const now=new Map();
      for(const rec of db[col]){if(!rec||rec.id==null)continue;const id=String(rec.id),json=JSON.stringify(rec);now.set(id,json);if(known.get(id)!==json)upserts.push([col,id,json]);}
      for(const id of known.keys())if(!now.has(id))deletes.push([col,id]);
      next.set(col,now);
    }
    if(!upserts.length&&!deletes.length)return;
    const client=await pool.connect();
    try{
      await client.query('BEGIN');
      for(const [col,id,json] of upserts)await client.query('INSERT INTO cineset_records(collection,id,data,updated_at) VALUES($1,$2,$3::jsonb,now()) ON CONFLICT(collection,id) DO UPDATE SET data=EXCLUDED.data,updated_at=now()',[col,id,json]);
      for(const [col,id] of deletes)await client.query('DELETE FROM cineset_records WHERE collection=$1 AND id=$2',[col,id]);
      await client.query('COMMIT');
    }catch(e){await client.query('ROLLBACK').catch(()=>{});throw e;}
    finally{client.release();}
    // Only mark rows as persisted once the transaction committed, so a failed write is retried on the next save.
    for(const [col,now] of next)persisted.set(col,now);
  }
  function flush(){
    if(running){again=true;return running;}
    running=(async()=>{
      try{do{again=false;await writeChanges();}while(again);}
      catch(e){console.error('Saving to PostgreSQL failed (will retry on next change):',e.message);}
      finally{running=null;}
    })();
    return running;
  }
  // save() is called synchronously after each change; batch the writes that happen in the same tick.
  let scheduled=false;
  const save=()=>{if(scheduled)return;scheduled=true;setImmediate(()=>{scheduled=false;flush();});};
  if(imported){console.log('Imported local data/db.json into PostgreSQL.');await flush();}
  return {kind:'postgres',db,save,flush,close:async()=>{await flush();await pool.end();}};
}

async function openStore({empty,dbPath}){
  const databaseUrl=process.env.DATABASE_URL;
  if(!databaseUrl)return jsonStore({dbPath,empty});
  return postgresStore({databaseUrl,ssl:process.env.DATABASE_SSL,empty,importFrom:dbPath});
}

module.exports={openStore};
