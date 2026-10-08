// Builds the Android app's web assets from public/ plus the on-device backend.
// Output: mobile/android/app/src/main/assets/www/   Usage: node mobile/build-web.js
const fs=require('fs');
const path=require('path');
const root=path.join(__dirname,'..');
const out=path.join(__dirname,'android/app/src/main/assets/www');

let app=fs.readFileSync(path.join(root,'public/app.js'),'utf8');
// Point the server-only parts of the UI at their on-device equivalents.
const patches=[
  ['src="/api/files/${video.id}"','src="${cinesetLocal.fileUrl(video.id)}" playsinline'],
  ['<a class="btn" href="/api/files/${f.id}" target="_blank">Open</a>','<button class="btn" data-openfile="${f.id}">Open</button>'],
  ["if(confirm('Delete this work?'))","if(await cinesetConfirm('Delete this work?'))"],
  ["window.open('/p/'+me.id,'_blank')","cinesetShowPublic(me.id)"],
  ["closeModal();alert((r.emailed?","closeModal();if(r.demoNote){alert(r.demoNote);return render()}alert((r.emailed?"],
  ['<div class="notice">Before public launch, set a strong CINESET_SECRET, HTTPS, persistent storage and database backups.</div>`))}','`)+cinesetSettingsCards());cinesetBindSettings()}'],
  ["${demoMode?'<div class=\"notice\"><b>Demo Creator</b>","${cinesetLocal.canLoadSample()?'<button class=\"btn full\" type=\"button\" id=\"loadSample\">Try it with sample data</button>':''}${demoMode?'<div class=\"notice\"><b>Demo Creator</b>"],
  ['Clients join through an invite link from their creator.','Clients get their sign-in from their creator, under Clients → Invite client.'],
  ["'Generated plan · basic template (AI not connected)'","'Generated plan · built-in template (add a Claude key in Settings for full plans)'"],
  ['\nboot();\n','\ncinesetLocal.ready.then(boot);\n'],
];
for(const [from,to] of patches){
  const n=app.split(from).length-1;
  if(n!==1)throw new Error(`Expected exactly one match for patch, found ${n}: ${from.slice(0,70)}`);
  app=app.replace(from,()=>to);
}

fs.rmSync(out,{recursive:true,force:true});
fs.mkdirSync(path.join(out,'vendor'),{recursive:true});
fs.writeFileSync(path.join(out,'app.js'),app);
fs.copyFileSync(path.join(root,'public/style.css'),path.join(out,'style.css'));
for(const f of ['local-backend.js','mobile.js','mobile.css'])fs.copyFileSync(path.join(__dirname,'web',f),path.join(out,f));

// Anthropic SDK as a browser global (window.AnthropicSDK), used only when a Claude key is set.
require('esbuild').buildSync({
  stdin:{contents:"module.exports=require('@anthropic-ai/sdk');",resolveDir:root},
  bundle:true,format:'iife',globalName:'AnthropicSDK',platform:'browser',target:'chrome90',minify:true,
  outfile:path.join(out,'vendor/anthropic-sdk.js'),logLevel:'warning',
});

fs.writeFileSync(path.join(out,'index.html'),`<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self' https://api.anthropic.com">
<title>CINESET</title>
<link rel="stylesheet" href="style.css"><link rel="stylesheet" href="mobile.css">
</head><body>
<div id="app"><div class="boot"><div class="brand">CINESET</div><div class="spinner"></div></div></div>
<script src="vendor/anthropic-sdk.js"></script>
<script src="local-backend.js"></script>
<script src="app.js"></script>
<script src="mobile.js"></script>
</body></html>
`);
console.log('Built',path.relative(root,out));
