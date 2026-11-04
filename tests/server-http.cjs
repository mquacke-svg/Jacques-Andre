// Runs ONLY against the isolated CGI rehearsal, never the live shop database.
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const base = 'https://case-garage.fun/__bakery_php_probe_20261031/app';
const cookies = new Map();
async function request(path, data, jar = cookies) {
  const response = await fetch(base + path, {
    method: data ? 'POST' : 'GET', redirect: 'manual',
    headers: { Origin: 'https://case-garage.fun', Cookie: [...jar].map(([k,v])=>`${k}=${v}`).join('; ') },
    body: data ? (data instanceof FormData ? data : new URLSearchParams(data)) : undefined,
  });
  for (const cookie of response.headers.getSetCookie()) {
    assert.match(cookie, /secure/i);
    const first = cookie.split(';')[0], equal = first.indexOf('=');
    jar.set(first.slice(0, equal), first.slice(equal + 1));
  }
  return { status: response.status, location: response.headers.get('location'), html: await response.text() };
}
function field(html, name) {
  const match = html.match(new RegExp(`name="${name}" value="([^"]*)"`));
  assert.ok(match, name); return match[1];
}
(async()=>{
  let page = await request('/login?register=1'); assert.equal(page.status,200);
  const login = 'server.' + randomBytes(5).toString('hex'), password = randomBytes(16).toString('hex');
  let result = await request('/action',{_action:'register',csrf:field(page.html,'csrf'),login,password});
  assert.equal(result.status,303); assert.equal(result.location,'/account');
  page = await request('/account'); assert.equal(page.status,200); assert.ok(page.html.includes(login));
  result = await request('/action',{_action:'cart_add',csrf:field(page.html,'csrf'),productId:'e2e-pastry',quantity:'1',returnTo:'/cart'});
  assert.equal(result.status,303);
  page = await request('/checkout'); assert.equal(page.status,200);
  const locationId = page.html.match(/<option value="([^"]+)"/)[1];
  const body = {_action:'checkout',csrf:field(page.html,'csrf'),fulfillment:'pickup',locationId,
    fingerprint:field(page.html,'fingerprint'),idempotencyKey:field(page.html,'idempotencyKey'),
    name:'Проверка CGI',phone:'+79000000000',comment:'Изолированная проверка',consent:'on'};
  result = await request('/action',body); assert.equal(result.status,303); assert.match(result.location,/^\/orders\//);
  const order = result.location;
  page = await request(order); assert.equal(page.status,200); assert.ok(page.html.includes('105,50'));
  result = await request('/action',body); assert.equal(result.location,order);
  assert.equal((await request('/admin')).status,403);
  assert.equal((await request(order,undefined,new Map())).status,404);
  page = await request('/account');
  assert.equal((await request('/action',{_action:'logout',csrf:field(page.html,'csrf')})).status,303);
  page = await request('/login');
  result = await request('/action',{_action:'login',csrf:field(page.html,'csrf'),login,password});
  assert.equal(result.location,'/account');
  const adminPassword = randomBytes(20).toString('hex');
  execFileSync('ssh', ['-i', 'C:/Claude--Project/Test-site__Russian/.local/beget-bakery-deploy-20261030', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', 'mquacker@mquacker.beget.tech', '~/case-garage.fun/bakery-php-runtime/bin/php ~/case-garage.fun/bakery-php-v1/tests/e2e-fixture.php set-admin-password'], {input:JSON.stringify({adminPassword}), windowsHide:true,stdio:['pipe','pipe','pipe']});
  page = await request('/login?admin=1');
  result = await request('/action',{_action:'login',csrf:field(page.html,'csrf'),login:'e2e.admin',password:adminPassword,admin:'1'});
  assert.equal(result.location,'/admin');
  page = await request('/admin'); assert.equal(page.status,200);
  const upload = new FormData();
  upload.set('_action','admin_upload'); upload.set('csrf',field(page.html,'csrf')); upload.set('returnTo','/admin');
  upload.set('image',new Blob([fs.readFileSync('.local/e2e-results/upload.png')],{type:'image/png'}),'probe.png');
  result = await request('/action', upload); assert.equal(result.status,303);
  page = await request('/admin');
  const url = page.html.match(/\/uploads\/[a-f0-9-]+\.webp/);
  assert.ok(url,'Uploaded WebP path');
  const image = await request(url[0]); assert.equal(image.status,200); assert.ok(image.html.startsWith('RIFF'));
  console.log('CGI HTTP: registration, sessions, login, cart, checkout, retry, ownership, admin denial, Secure cookies PASSED');
  console.log('CGI HTTP: admin login, PNG upload, WebP encoding and file access PASSED');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
