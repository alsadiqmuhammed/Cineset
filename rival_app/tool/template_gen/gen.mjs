import { chromium } from 'playwright';
import fs from 'fs';
const out = process.argv[2];
const only = process.argv[3];
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args:['--allow-file-access-from-files'] });
const p = await b.newPage();
p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>{if(m.type()==='error')console.log('CONSOLE',m.text())});
await p.goto('file://' + process.cwd() + '/tpl4/gen.html');
const fams = await p.evaluate(()=>window.FAMS);
const meta = {};let v=0;
for (const sec of ['dental','beauty']) for (const fam of fams) {
  if (only && fam!==only) continue;
  for (const pal of ['L','D']) for (const fmt of ['post','story','square']) {
    const r = await p.evaluate(a => window.render(...a), [sec,fam,pal,fmt,v++]);
    const name = `${sec}_${fam}_${pal==='L'?'light':'dark'}_${fmt}`;
    fs.writeFileSync(`${out}/${name}.png`, Buffer.from(r.png.split(',')[1],'base64'));
    delete r.png; meta[name] = {...r,sec,fam,pal,fmt};
  }
}
fs.writeFileSync(`${out}/meta.json`, JSON.stringify(meta));
await b.close();
