// Public pages only. Browser uses a fresh profile; no live accounts/orders are created.
const {chromium,expect}=require('@playwright/test');
const fs=require('node:fs');
(async()=>{
  fs.mkdirSync('.local/live-results',{recursive:true});
  const browser=await chromium.launch({channel:'msedge',headless:true});
  try {
    const context=await browser.newContext({baseURL:'https://case-garage.fun'});
    const page=await context.newPage();
    for(const width of [360,390,768,1440]) {
      await page.setViewportSize({width,height:1000});
      for(const route of ['/','/menu']) {
        const response=await page.goto(route,{waitUntil:'networkidle'});
        expect(response.status()).toBe(200);
        await page.evaluate(()=>document.fonts.ready);
        await page.locator('img').evaluateAll(async imgs=>{
          imgs.forEach(img=>{img.loading='eager';});
          await Promise.all(imgs.map(img=>img.decode().catch(()=>{})));
        });
        expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
        expect(await page.locator('img').evaluateAll(imgs=>imgs.filter(i=>!i.complete||i.naturalWidth===0).length)).toBe(0);
        if(width===390||width===1440) await page.screenshot({path:'.local/live-results/'+(route==='/'?'home':'menu')+'-'+width+'.png'});
      }
    }
    await page.goto('/admin');
    await page.waitForURL('**/login?admin=1',{timeout:20000});
    await expect(page.getByRole('heading',{name:'Вход для сотрудников'})).toBeVisible();
    await page.goto('/menu');
    await page.locator('[data-dialog]').first().click();
    await expect(page.locator('dialog[open]')).toBeVisible();
    await page.keyboard.press('Escape');
    expect(await page.locator('dialog[open]').count()).toBe(0);
    console.log('LIVE BROWSER PASSED: home/menu four widths, images, admin login redirect after Beget check, product dialog and Escape');
  } finally {await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
