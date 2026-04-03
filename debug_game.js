const puppeteer = require('puppeteer');

(async () => {
    try {
        const browser = await puppeteer.launch({ headless: 'new' });
        const page = await browser.newPage();
        
        page.on('console', msg => {
            console.log(`[CONSOLE] ${msg.type()}: ${msg.text()}`);
        });
        
        page.on('pageerror', err => {
            console.error(`[PAGE ERROR]: ${err.message}`);
        });
        
        await page.goto('http://127.0.0.1:8080/games_level_1.html', { waitUntil: 'networkidle2', timeout: 10000 });
        
        setTimeout(async () => {
            await browser.close();
        }, 5000);
    } catch (e) {
        console.error("Script error:", e);
    }
})();
