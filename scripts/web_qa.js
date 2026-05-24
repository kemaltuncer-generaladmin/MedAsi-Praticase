/**
 * PratiCase Web QA Script
 * Gerçek kullanıcı gibi uygulamayı gezir, screenshot alır, hataları raporlar.
 */

const { chromium } = require('/Users/kemaltuncer/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:8080';
const ARTIFACTS_DIR = '/Users/kemaltuncer/Desktop/praticase/artifacts';
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// Mobil viewport - iPhone 13 boyutu
const MOBILE_VIEWPORT = { width: 390, height: 844 };

const issues = [];
const screenshots = [];

function log(msg) {
  console.log(`[QA] ${msg}`);
}

function issue(severity, title, detail) {
  issues.push({ severity, title, detail });
  console.log(`[${severity.toUpperCase()}] ${title}: ${detail}`);
}

async function screenshot(page, name, description) {
  const filepath = path.join(ARTIFACTS_DIR, `qa_${name}.png`);
  await page.screenshot({ path: filepath, fullPage: false });
  screenshots.push({ name, filepath, description });
  log(`Screenshot: ${name} - ${description}`);
  return filepath;
}

async function waitForFlutter(page) {
  // Flutter web uygulamasının yüklenmesini bekle
  try {
    await page.waitForFunction(() => {
      return document.querySelector('flt-glass-pane') !== null ||
             document.querySelector('flutter-view') !== null ||
             document.querySelector('canvas') !== null;
    }, { timeout: 15000 });
    // Biraz daha bekle rendering için
    await page.waitForTimeout(2000);
  } catch (e) {
    log('Flutter render wait timeout - devam ediliyor');
    await page.waitForTimeout(3000);
  }
}

async function getConsoleErrors(page) {
  // Console errors page nesnesine bağlanarak dinlenir - başlangıçta set up edilmeli
  return [];
}

async function runQA() {
  log('PratiCase Web QA başlatılıyor...');
  log(`URL: ${BASE_URL}`);
  log(`Viewport: ${MOBILE_VIEWPORT.width}x${MOBILE_VIEWPORT.height}`);

  const browser = await chromium.launch({
    headless: true,
    executablePath: CHROME_PATH,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  });

  const consoleMessages = [];
  const networkErrors = [];

  const context = await browser.newContext({
    viewport: MOBILE_VIEWPORT,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    locale: 'tr-TR',
  });

  const page = await context.newPage();

  // Console mesajlarını yakala
  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warn') {
      consoleMessages.push({ type: msg.type(), text: msg.text() });
    }
  });

  // Network hatalarını yakala
  page.on('requestfailed', req => {
    networkErrors.push({ url: req.url(), failure: req.failure()?.errorText });
  });

  try {
    // ─── EKRAN 1: ONBOARDING / İLK AÇILIŞ ───
    log('\n=== EKRAN 1: İlk açılış ===');
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await waitForFlutter(page);
    await screenshot(page, 'web_01_initial', 'İlk yüklenme ekranı');

    // Flutter canvas'ın yüklü olup olmadığını kontrol et
    const hasCanvas = await page.evaluate(() => document.querySelector('canvas') !== null);
    const hasFltPane = await page.evaluate(() => document.querySelector('flt-glass-pane') !== null);
    log(`Canvas: ${hasCanvas}, Flutter glass pane: ${hasFltPane}`);

    if (!hasCanvas && !hasFltPane) {
      issue('BLOCKER', 'Flutter render yok', 'Sayfa yüklendi ama Flutter widget tree render edilmedi. Canvas veya flt-glass-pane bulunamadı.');
    }

    // Sayfa title kontrolü
    const title = await page.title();
    log(`Sayfa başlığı: "${title}"`);
    if (!title || title === 'PratiCase' || title.trim() === '') {
      // Kabul edilebilir
    }

    // 3 saniye daha bekle tam render için
    await page.waitForTimeout(3000);
    await screenshot(page, 'web_02_loaded', 'Uygulama tam yüklenmiş hali');

    // Semantic tree'yi kontrol et (Flutter web accessibility)
    const semanticsTree = await page.evaluate(() => {
      const root = document.querySelector('flt-semantics');
      if (!root) return null;
      return root.innerHTML.substring(0, 2000);
    });

    if (semanticsTree) {
      log('Flutter semantics tree mevcut (accessibility OK)');
    } else {
      issue('MINOR', 'Flutter semantics yok', 'Semantics tree render edilmemiş, accessibility testi kısıtlı');
    }

    // ─── VIEWPORT TESTLERİ ───
    log('\n=== VIEWPORT TESTLERİ ===');

    // Tablet boyutu
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.waitForTimeout(1500);
    await screenshot(page, 'web_03_tablet', 'Tablet viewport (768x1024)');

    // Desktop boyutu
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.waitForTimeout(1500);
    await screenshot(page, 'web_04_desktop', 'Desktop viewport (1280x800)');

    // Dar ekran (küçük Android)
    await page.setViewportSize({ width: 360, height: 640 });
    await page.waitForTimeout(1500);
    await screenshot(page, 'web_05_small_mobile', 'Küçük mobil (360x640)');

    // Geri mobil boyuta dön
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.waitForTimeout(1000);

    // ─── RELOAD DAVRANIŞI ───
    log('\n=== RELOAD DAVRANIŞI ===');
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
    await screenshot(page, 'web_06_after_reload', 'Sayfayı yeniledikten sonra');

    // ─── DEEP LINK TESTİ ───
    log('\n=== DEEP LINK / ROUTE TESTİ ===');
    await page.goto(`${BASE_URL}/#/login`, { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
    await screenshot(page, 'web_07_route_login', 'Hash route /login');

    await page.goto(`${BASE_URL}/#/register`, { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(2000);
    await screenshot(page, 'web_08_route_register', 'Hash route /register');

    // Geri main'e dön
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(3000);
    await screenshot(page, 'web_09_back_home', 'Ana sayfaya dönüş');

    // ─── KEYBOARD / SCROLL TESTİ ───
    log('\n=== KEYBOARD & SCROLL TESTİ ===');
    // Tab tuşuyla focus gezintisi
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    await screenshot(page, 'web_10_keyboard_tab', 'Keyboard tab focus');

    // Scroll test
    await page.evaluate(() => window.scrollTo(0, 300));
    await page.waitForTimeout(500);
    await screenshot(page, 'web_11_scrolled', 'Sayfa kaydırıldıktan sonra');
    await page.evaluate(() => window.scrollTo(0, 0));

    // ─── PERFORMANCE / LOAD TIME ───
    log('\n=== PERFORMANCE ===');
    const perfData = await page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0];
      if (!nav) return null;
      return {
        domContentLoaded: Math.round(nav.domContentLoadedEventEnd),
        loadComplete: Math.round(nav.loadEventEnd),
        firstByte: Math.round(nav.responseStart),
        domInteractive: Math.round(nav.domInteractive),
      };
    });

    if (perfData) {
      log(`DOM Content Loaded: ${perfData.domContentLoaded}ms`);
      log(`Load Complete: ${perfData.loadComplete}ms`);
      log(`First Byte: ${perfData.firstByte}ms`);
      if (perfData.loadComplete > 10000) {
        issue('MAJOR', 'Yavaş yükleme', `Sayfa yüklenme süresi ${perfData.loadComplete}ms (>10sn). Mobil kullanıcılar için kritik.`);
      } else if (perfData.loadComplete > 5000) {
        issue('MINOR', 'Orta yükleme süresi', `Sayfa yüklenme süresi ${perfData.loadComplete}ms (>5sn).`);
      }
    }

    // ─── KAYNAK BOYUTU ───
    log('\n=== KAYNAK BOYUTU ===');
    const resources = await page.evaluate(() => {
      return performance.getEntriesByType('resource').map(r => ({
        name: r.name.split('/').pop(),
        size: Math.round(r.transferSize / 1024),
        duration: Math.round(r.duration),
      })).filter(r => r.size > 100);
    });

    let totalKB = 0;
    resources.forEach(r => {
      totalKB += r.size;
      if (r.size > 2000) {
        issue('MINOR', `Büyük kaynak: ${r.name}`, `${r.size}KB - yavaş bağlantılarda sorun yaratabilir`);
      }
    });
    log(`Toplam transfer boyutu: ~${totalKB}KB`);

    // ─── MANIFEST / PWA KONTROLÜ ───
    log('\n=== PWA / MANIFEST ===');
    try {
      const manifestResp = await page.request.get(`${BASE_URL}/manifest.json`);
      if (manifestResp.ok()) {
        const manifest = await manifestResp.json();
        log(`Manifest: ${manifest.name || 'adsız'}, display: ${manifest.display}`);
        if (!manifest.name) issue('MINOR', 'Manifest name eksik', 'manifest.json içinde name alanı yok');
        if (!manifest.icons || manifest.icons.length === 0) issue('MINOR', 'Manifest icons eksik', 'PWA ikonları tanımlanmamış');
      }
    } catch (e) {
      issue('MINOR', 'Manifest yüklenemedi', e.message);
    }

    // ─── SERVICE WORKER ───
    log('\n=== SERVICE WORKER ===');
    const swRegistered = await page.evaluate(async () => {
      if (!navigator.serviceWorker) return false;
      const regs = await navigator.serviceWorker.getRegistrations();
      return regs.length > 0;
    });
    log(`Service Worker kayıtlı: ${swRegistered}`);
    if (!swRegistered) {
      issue('INFO', 'Service Worker yok', 'Offline desteği için service worker kayıtlı değil');
    }

    // ─── META TAGS / SEO ───
    log('\n=== META TAGS ===');
    const metaTags = await page.evaluate(() => {
      const tags = {};
      tags.description = document.querySelector('meta[name="description"]')?.content;
      tags.viewport = document.querySelector('meta[name="viewport"]')?.content;
      tags.themeColor = document.querySelector('meta[name="theme-color"]')?.content;
      tags.ogTitle = document.querySelector('meta[property="og:title"]')?.content;
      return tags;
    });
    log(`Viewport meta: ${metaTags.viewport}`);
    if (!metaTags.viewport) {
      issue('MAJOR', 'Viewport meta tag yok', 'Mobil ölçeklendirme çalışmayabilir');
    }
    if (!metaTags.themeColor) {
      issue('INFO', 'Theme-color meta tag yok', 'Tarayıcı toolbar rengi ayarlanmamış');
    }

    // ─── SON EKRAN ───
    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.waitForTimeout(1000);
    await screenshot(page, 'web_12_final_mobile', 'Final mobil görünüm');

    // ─── RAPOR OLUŞTUR ───
    log('\n=== CONSOLE HATALARI ===');
    const errorMessages = consoleMessages.filter(m => m.type === 'error');
    const warnMessages = consoleMessages.filter(m => m.type === 'warn');
    log(`Console error sayısı: ${errorMessages.length}`);
    log(`Console warn sayısı: ${warnMessages.length}`);
    errorMessages.slice(0, 10).forEach(m => {
      issue('MAJOR', 'Console Error', m.text.substring(0, 200));
    });

    log('\n=== NETWORK HATALARI ===');
    log(`Network hata sayısı: ${networkErrors.length}`);
    networkErrors.slice(0, 10).forEach(e => {
      if (!e.url.includes('localhost') || !e.url.includes('supabase')) {
        issue('MINOR', 'Network hatası', `${e.url}: ${e.failure}`);
      }
    });

  } catch (err) {
    issue('BLOCKER', 'Script hatası', err.message);
    log(`HATA: ${err.stack}`);
  } finally {
    await browser.close();
  }

  return {
    issues,
    screenshots,
    consoleMessages,
    networkErrors,
    perfData: null
  };
}

// Ana çalıştırma
runQA().then(results => {
  log('\n\n========================================');
  log('QA RAPORU ÖZETI');
  log('========================================');

  const blockers = results.issues.filter(i => i.severity === 'BLOCKER');
  const critical = results.issues.filter(i => i.severity === 'CRITICAL');
  const major = results.issues.filter(i => i.severity === 'MAJOR');
  const minor = results.issues.filter(i => i.severity === 'MINOR');
  const info = results.issues.filter(i => i.severity === 'INFO');

  log(`BLOCKER: ${blockers.length}`);
  log(`CRITICAL: ${critical.length}`);
  log(`MAJOR: ${major.length}`);
  log(`MINOR: ${minor.length}`);
  log(`INFO: ${info.length}`);
  log(`Toplam sorun: ${results.issues.length}`);

  log('\n--- BLOCKER/CRITICAL/MAJOR SORUNLAR ---');
  [...blockers, ...critical, ...major].forEach(i => {
    log(`[${i.severity}] ${i.title}`);
    log(`  → ${i.detail}`);
  });

  log('\n--- MINOR SORUNLAR ---');
  minor.forEach(i => {
    log(`[MINOR] ${i.title}: ${i.detail}`);
  });

  log('\n--- EKRAN GÖRÜNTÜLERİ ---');
  results.screenshots.forEach(s => {
    log(`  ${s.name}: ${s.filepath}`);
  });

  // JSON raporu kaydet
  const reportPath = '/Users/kemaltuncer/Desktop/praticase/WEB_QA_REPORT.json';
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  log(`\nDetaylı rapor: ${reportPath}`);
}).catch(err => {
  console.error('QA script çöktü:', err);
  process.exit(1);
});
