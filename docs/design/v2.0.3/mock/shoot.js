const {chromium}=require('playwright');const fs=require('fs'),path=require('path');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1080,height:2400}});
for(const f of fs.readdirSync(__dirname).filter(f=>f.endsWith('.html'))){await p.goto('file://'+path.join(__dirname,f));await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(250);await p.screenshot({path:path.join(__dirname,f.replace('.html','.png'))});console.log(f)}
await b.close()})();
