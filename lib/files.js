// Uploaded file storage.
// - No STORAGE_BUCKET: files live in the local uploads folder (development).
// - STORAGE_BUCKET set: any S3-compatible object storage (Cloudflare R2, AWS S3,
//   Backblaze B2, MinIO...). Requests are signed with AWS Signature V4, so no SDK is needed.
const fs=require('fs');
const path=require('path');
const https=require('https');
const http=require('http');
const crypto=require('crypto');

const sha256=(v)=>crypto.createHash('sha256').update(v).digest('hex');
const hmac=(key,v)=>crypto.createHmac('sha256',key).update(v).digest();
const encodeKey=(key)=>key.split('/').map(s=>encodeURIComponent(s).replace(/[!'()*]/g,c=>'%'+c.charCodeAt(0).toString(16).toUpperCase())).join('/');

// AWS Signature Version 4 for a request with no query string. Signs every header passed in.
function signV4({method,url,headers,region,accessKeyId,secretAccessKey,service='s3',payloadHash='UNSIGNED-PAYLOAD',date=new Date()}){
  const amzDate=date.toISOString().replace(/[:-]|\.\d{3}/g,'');
  const day=amzDate.slice(0,8);
  const all={...headers,host:url.host,'x-amz-content-sha256':payloadHash,'x-amz-date':amzDate};
  const names=Object.keys(all).map(h=>h.toLowerCase()).sort();
  const lower=Object.fromEntries(Object.entries(all).map(([k,v])=>[k.toLowerCase(),String(v).trim().replace(/\s+/g,' ')]));
  const signedHeaders=names.join(';');
  const canonical=[method,url.pathname,'',names.map(n=>`${n}:${lower[n]}\n`).join(''),signedHeaders,payloadHash].join('\n');
  const scope=`${day}/${region}/${service}/aws4_request`;
  const toSign=['AWS4-HMAC-SHA256',amzDate,scope,sha256(canonical)].join('\n');
  const key=hmac(hmac(hmac(hmac('AWS4'+secretAccessKey,day),region),service),'aws4_request');
  const signature=crypto.createHmac('sha256',key).update(toSign).digest('hex');
  return {...all,authorization:`AWS4-HMAC-SHA256 Credential=${accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`};
}

function localFiles(dir){
  fs.mkdirSync(dir,{recursive:true});
  const full=(key)=>path.join(dir,path.basename(key));
  return {
    kind:'local',
    async put(key,sourcePath){fs.renameSync(sourcePath,full(key));},
    async read(key,start,end){const f=full(key);if(!fs.existsSync(f))throw Object.assign(new Error('File missing'),{status:404});return fs.createReadStream(f,{start,end});},
  };
}

function s3Files(cfg){
  const region=cfg.region||'auto';
  const base=new URL(cfg.endpoint||`https://s3.${region}.amazonaws.com`);
  const objectUrl=(key)=>new URL(`${base.pathname.replace(/\/$/,'')}/${encodeURIComponent(cfg.bucket)}/${encodeKey((cfg.prefix||'')+key)}`,base);
  function send(method,key,headers,body){
    const url=objectUrl(key);
    const signed=signV4({method,url,headers,region,accessKeyId:cfg.accessKeyId,secretAccessKey:cfg.secretAccessKey});
    return new Promise((resolve,reject)=>{
      const req=(url.protocol==='http:'?http:https).request(url,{method,headers:signed},resolve);
      req.on('error',reject);
      if(body)body.pipe(req);else req.end();
    });
  }
  async function failure(res,what){let detail='';for await(const c of res)detail+=c;const code=/<Code>([^<]+)<\/Code>/.exec(detail)?.[1]||res.statusCode;return Object.assign(new Error(`Object storage ${what} failed (${code})`),{status:res.statusCode===404?404:502});}
  return {
    kind:'s3',
    async put(key,sourcePath,contentType){
      const size=fs.statSync(sourcePath).size;
      try{
        const res=await send('PUT',key,{'content-length':size,'content-type':contentType||'application/octet-stream'},fs.createReadStream(sourcePath));
        if(res.statusCode!==200)throw await failure(res,'upload');
        res.resume();
      }finally{fs.rmSync(sourcePath,{force:true});}
    },
    async read(key,start,end){
      const res=await send('GET',key,{range:`bytes=${start}-${end}`});
      if(res.statusCode!==200&&res.statusCode!==206)throw await failure(res,'download');
      return res;
    },
  };
}

function openFiles({uploadsDir}){
  const e=process.env;
  if(!e.STORAGE_BUCKET)return localFiles(uploadsDir);
  for(const k of ['STORAGE_ACCESS_KEY_ID','STORAGE_SECRET_ACCESS_KEY'])if(!e[k])throw new Error(`${k} is required when STORAGE_BUCKET is set`);
  return s3Files({endpoint:e.STORAGE_ENDPOINT,bucket:e.STORAGE_BUCKET,region:e.STORAGE_REGION,accessKeyId:e.STORAGE_ACCESS_KEY_ID,secretAccessKey:e.STORAGE_SECRET_ACCESS_KEY,prefix:e.STORAGE_PREFIX||''});
}

module.exports={openFiles,signV4};
