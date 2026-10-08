// Phone-specific UI for CINESET: in-page dialogs, file viewer, settings (backup, Claude key),
// Android back button, and saving files through the native bridge (window.CinesetNative).
(function(){
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const fmtBytes=(n)=>{n=Number(n)||0;if(n<1024)return n+' B';if(n<1048576)return (n/1024).toFixed(0)+' KB';if(n<1073741824)return (n/1048576).toFixed(1)+' MB';return (n/1073741824).toFixed(2)+' GB';};

  function overlay(cls,html){const box=document.createElement('div');box.className=cls;box.innerHTML=html;document.body.appendChild(box);return box;}
  function dialog(message,buttons){
    return new Promise(resolve=>{
      const box=overlay('modal cs-dialog',`<div class="modalbox" role="alertdialog" aria-modal="true"><p class="cs-msg"></p><div class="modal-actions"></div></div>`);
      box.querySelector('.cs-msg').textContent=String(message);
      const actions=box.querySelector('.modal-actions');
      buttons.forEach(([label,value,primary])=>{const b=document.createElement('button');b.className='btn'+(primary?' primary':'');b.textContent=label;b.onclick=()=>{box.remove();resolve(value);};actions.appendChild(b);});
      box._cancel=()=>{box.remove();resolve(buttons.find(b=>b[1]===false)?false:undefined);};
      actions.lastChild?.focus();
    });
  }
  window.alert=(msg)=>{dialog(msg,[['OK',true,true]]);};
  window.cinesetConfirm=(msg,yes='Delete')=>dialog(msg,[['Cancel',false],[yes,true,true]]);

  // ---------- saving files to the phone ----------
  const pendingSaves=new Map();
  window.__cinesetSaved=(token,ok)=>{const done=pendingSaves.get(token);pendingSaves.delete(token);done?.(!!ok);};
  async function saveToPhone(blob,name,mime){
    const N=window.CinesetNative;
    if(!N){const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;document.body.appendChild(a);a.click();a.remove();return true;}
    const token=N.beginSave(name,mime||blob.type||'application/octet-stream');
    const CHUNK=768*1024; // multiple of 3, so each chunk base64-encodes on its own
    for(let off=0;off<blob.size;off+=CHUNK){
      const part=await new Promise((res,rej)=>{const r=new FileReader();r.onload=()=>res(String(r.result).split(',')[1]||'');r.onerror=()=>rej(r.error);r.readAsDataURL(blob.slice(off,off+CHUNK));});
      if(!N.appendChunk(token,part))throw new Error('Could not prepare the file.');
    }
    return new Promise(resolve=>{pendingSaves.set(token,resolve);N.finishSave(token);});
  }
  window.cinesetSaveToPhone=saveToPhone;

  // ---------- file viewer ----------
  async function openFile(id){
    const f=cinesetLocal.fileInfo(id);const url=cinesetLocal.fileUrl(id);
    if(!f)return;
    let preview='<div class="notice">Preview isn\'t available for this file type. Save it to the phone to open it with another app.</div>';
    if(!url)preview='<div class="notice error">This file is no longer stored on this phone.</div>';
    else if(f.mime.startsWith('video/'))preview=`<video class="cs-preview" controls playsinline src="${url}"></video>`;
    else if(f.mime.startsWith('image/'))preview=`<img class="cs-preview" alt="${esc(f.originalName)}" src="${url}">`;
    else if(f.mime.startsWith('audio/'))preview=`<audio controls src="${url}"></audio>`;
    const box=overlay('cs-sheet',`<div class="cs-sheet-head"><div><b>${esc(f.originalName)}</b><div class="small">${fmtBytes(f.size)} · ${esc(f.mime)}</div></div><button class="btn" data-cs-close>Close</button></div><div class="cs-sheet-body">${preview}</div>${url?'<div class="cs-sheet-foot"><button class="btn primary" data-cs-save>Save to phone</button></div>':''}`);
    box.querySelector('[data-cs-close]').onclick=()=>box.remove();
    box.querySelector('[data-cs-save]')?.addEventListener('click',async e=>{e.target.disabled=true;e.target.textContent='Saving…';try{const ok=await saveToPhone(await cinesetLocal.fileBlob(id),f.originalName,f.mime);e.target.textContent=ok?'Saved':'Save to phone';}catch(err){alert(err.message);e.target.textContent='Save to phone';}e.target.disabled=false;});
  }

  // ---------- public portfolio preview ----------
  window.cinesetShowPublic=async function(creatorId){
    const r=await (await fetch('/api/public/portfolio/'+creatorId)).json();
    const box=overlay('cs-sheet cs-public',`<div class="cs-sheet-head"><div><div class="eyebrow">PUBLIC PORTFOLIO PREVIEW</div><b>${esc(r.creator?.name)}</b></div><button class="btn" data-cs-close>Close</button></div><div class="cs-sheet-body"><div class="portfolioGrid">${(r.items||[]).map(w=>`<article class="work"><div class="cover ${esc(w.coverColor)}">${esc(w.type)}</div><div class="workbody"><div class="eyebrow">${esc(w.year)}</div><h2>${esc(w.title)}</h2><p>${esc(w.description)}</p></div></article>`).join('')||'<div class="notice">No public work yet.</div>'}</div></div>`);
    box.querySelector('[data-cs-close]').onclick=()=>box.remove();
  };

  // ---------- settings ----------
  window.cinesetSettingsCards=function(){
    const key=cinesetLocal.hasClaudeKey();
    return `<section class="card section"><div class="sectiontitle">Data on this phone</div>
      <p class="small">Projects, clients, finance records and uploaded files are stored only on this phone. Nothing is sent to a server. Uninstalling the app or clearing its data deletes them, so export a backup regularly.</p>
      <div class="cs-stats" id="csStorage">Checking storage…</div>
      <div class="actions cs-wrap"><button class="btn primary" id="csExport">Export backup</button><button class="btn" id="csExportLight">Export without files</button><label class="btn" for="csImport">Restore from backup</label><input id="csImport" type="file" accept="application/json,.json" hidden></div>
    </section>
    <section class="card section"><div class="sectiontitle">Claude AI</div>
      <p class="small">${key?'Claude writes your production plans. It needs internet; everything else works offline.':'The AI Assistant uses a built-in template. Add an Anthropic API key to have Claude write full production plans (needs internet; usage is billed to your Anthropic account).'}</p>
      <div class="field"><label for="csKey">Anthropic API key</label><input id="csKey" type="password" autocomplete="off" placeholder="${key?'Key saved on this phone':'sk-ant-…'}"></div>
      <div class="actions cs-wrap"><button class="btn primary" id="csSaveKey">Save key</button>${key?'<button class="btn" id="csRemoveKey">Remove key</button>':''}</div>
    </section>
    <section class="card section"><div class="sectiontitle">About</div><p class="small">CINESET for Android · version 2.0.0 · works offline</p></section>`;
  };
  window.cinesetBindSettings=async function(){
    const est=await cinesetLocal.storageEstimate();
    const el=document.getElementById('csStorage');
    if(el)el.innerHTML=`<div><b>${fmtBytes(cinesetLocal.filesTotalBytes())}</b><div class="small">Uploaded files</div></div>${est?.quota?`<div><b>${fmtBytes(est.usage)}</b><div class="small">App storage used</div></div><div><b>${fmtBytes(Math.max(0,est.quota-est.usage))}</b><div class="small">Available to the app</div></div>`:''}`;
    const exportWith=async(includeFiles,btn)=>{const label=btn.textContent;btn.disabled=true;btn.textContent='Preparing…';try{const blob=await cinesetLocal.exportBackup(includeFiles);const ok=await saveToPhone(blob,`cineset-backup-${new Date().toISOString().slice(0,10)}.json`,'application/json');if(ok)alert('Backup saved. Keep it somewhere safe, such as Google Drive.');}catch(e){alert(e.message);}btn.disabled=false;btn.textContent=label;};
    document.getElementById('csExport')?.addEventListener('click',e=>exportWith(true,e.currentTarget));
    document.getElementById('csExportLight')?.addEventListener('click',e=>exportWith(false,e.currentTarget));
    document.getElementById('csImport')?.addEventListener('change',async e=>{const file=e.target.files[0];e.target.value='';if(!file)return;
      if(!(await cinesetConfirm('Restoring replaces everything on this phone with the backup. Continue?','Restore')))return;
      try{const r=await cinesetLocal.importBackup(file);await dialog(`Restored ${r.projects} projects, ${r.users} accounts and ${r.files} files. Sign in again to continue.`,[['OK',true,true]]);location.reload();}catch(err){alert(err.message);}});
    document.getElementById('csSaveKey')?.addEventListener('click',async()=>{const v=document.getElementById('csKey').value.trim();if(!v)return alert('Paste your Anthropic API key first.');if(!/^sk-ant-/.test(v))return alert('That doesn\'t look like an Anthropic API key. Keys start with sk-ant-.');await cinesetLocal.setClaudeKey(v);alert('Key saved on this phone.');render();});
    document.getElementById('csRemoveKey')?.addEventListener('click',async()=>{if(!(await cinesetConfirm('Remove the Claude API key from this phone?','Remove')))return;await cinesetLocal.setClaudeKey('');render();});
  };

  // ---------- clicks handled for the whole app ----------
  document.addEventListener('click',async e=>{
    const open=e.target.closest('[data-openfile]');if(open){e.preventDefault();openFile(open.dataset.openfile);return;}
    if(e.target.closest('#loadSample')){const b=e.target.closest('#loadSample');b.disabled=true;b.textContent='Loading…';await cinesetLocal.loadSample();demoMode=true;login();return;}
    const ext=e.target.closest('a[href^="http"]');if(ext&&window.CinesetNative){e.preventDefault();window.CinesetNative.openExternal(ext.href);}
  });

  // ---------- Android back button ----------
  // Returns true when the app handled it; false lets Android close the app.
  window.cinesetBack=function(){
    const layers=[...document.querySelectorAll('.cs-dialog,.cs-sheet,.modal')];
    const top=layers[layers.length-1];
    if(top){if(top._cancel)top._cancel();else top.remove();return true;}
    if(typeof me!=='undefined'&&me&&view!=='dashboard'){view='dashboard';render();return true;}
    if(typeof me==='undefined'||!me){const back=document.getElementById('backToLogin');if(back){back.click();return true;}}
    return false;
  };

  // Keep the selected tab visible in the scrolling tab bar on phones.
  new MutationObserver(()=>{document.querySelector('.navbtn.active')?.scrollIntoView({block:'nearest',inline:'center'});}).observe(document.getElementById('app'),{childList:true});
  // Save pending changes when the app goes to the background.
  document.addEventListener('visibilitychange',()=>{if(document.hidden)cinesetLocal.flush();});
})();
