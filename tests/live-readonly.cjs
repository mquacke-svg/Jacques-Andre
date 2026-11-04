// Read-only HTTP publication check. Does not create accounts, submit orders or edit catalog.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const origin = 'https://case-garage.fun';
const jar = new Map();
async function get(path) {
  const res = await fetch(origin + path, {redirect:'manual',headers:{Cookie:[...jar].map(([k,v])=>`${k}=${v}`).join('; ')}});
  for (const cookie of res.headers.getSetCookie()) { const part=cookie.split(';')[0], i=part.indexOf('='); jar.set(part.slice(0,i),part.slice(i+1)); }
  return res;
}
(async()=>{
  const assets = new Set();
  for (const path of ['/','/menu','/cart','/checkout','/login','/privacy','/terms','/cookies']) {
    const res=await get(path); assert.equal(res.status,200,path); assert.equal(res.headers.get('x-bakery-release'),'php-v1');
    const html=await res.text(); assert.ok(!html.includes('/_next/'),path);
    assert.ok(!/Warning:|Fatal error:|Parse error:/.test(html),path);
    for (const match of html.matchAll(/(?:src|href)="(\/(?:products|images|fonts)\/[^"?]+|\/[^/"?]+\.(?:svg|css|js))/g)) assets.add(match[1]);
  }
  assert.equal((await get('/account')).status,303);
  const adminResponse = await get('/admin');
  // Beget may require its normal JavaScript cookie before /admin reaches PHP.
  if (adminResponse.status === 200 && !adminResponse.headers.get('x-bakery-release')) {
    assert.match(await adminResponse.text(), /document\.cookie='beget=begetok'/);
    console.log('Admin route: Beget browser cookie check; verified separately in browser');
  } else assert.equal(adminResponse.status,303);
  assert.equal((await get('/not-existing')).status,404);
  const list=[...assets];
  // Small batches avoid needless hosting load.
  for(let i=0;i<list.length;i+=6) await Promise.all(list.slice(i,i+6).map(async path=>{assert.equal((await get(path)).status,200,path);}));
  for (const name of ['style.css','app.js']) {
    const body=Buffer.from(await (await get('/'+name)).arrayBuffer());
    assert.equal(crypto.createHash('sha256').update(body).digest('hex'),crypto.createHash('sha256').update(fs.readFileSync('public/'+name)).digest('hex'),name);
  }
  console.log(`LIVE PASSED: 8 pages, private-route redirects, 404, ${assets.size} assets, CSS/JS exact hashes, PHP release marker`);
})().catch(error=>{console.error(error.message);process.exitCode=1;});
