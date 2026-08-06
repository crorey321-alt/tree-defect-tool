/* 교목 하자조사 도구 v20 — 서비스워커
   앱 껍데기와 라이브러리를 기기에 캐시해 두어, 현장에서 신호가 없어도 즉시 실행된다.
   앱을 고칠 때마다 아래 CACHE 이름의 숫자를 하나 올려 주세요. (예: v20-3) */
var CACHE = 'tds-v20-3';

var SHELL = [
  './',
  './index.html',
  './config.js',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './lib/pdf.min.js',
  './lib/pdf.worker.min.js',
  './lib/jspdf.umd.min.js',
  './lib/supabase.js'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE).then(function (c) {
      /* 하나가 실패해도 나머지는 캐시되도록 개별 처리 */
      return Promise.all(SHELL.map(function (u) {
        return c.add(new Request(u, { cache: 'reload' })).catch(function () {});
      }));
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (ks) {
      return Promise.all(ks.map(function (k) { return k === CACHE ? null : caches.delete(k); }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;

  var url;
  try { url = new URL(req.url); } catch (err) { return; }

  /* Supabase(로그인·동기화) 요청은 절대 캐시하지 않는다 — 항상 네트워크로 */
  if (url.origin !== self.location.origin) return;

  /* 화면 문서: 네트워크 우선, 실패하면 캐시 (배포 직후 새 버전이 바로 보이도록) */
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).then(function (res) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put('./index.html', copy); });
        return res;
      }).catch(function () {
        return caches.match('./index.html').then(function (r) { return r || caches.match('./'); });
      })
    );
    return;
  }

  /* 나머지 정적 파일: 캐시 우선 (라이브러리는 변하지 않음) */
  e.respondWith(
    caches.match(req).then(function (hit) {
      if (hit) return hit;
      return fetch(req).then(function (res) {
        if (res && res.status === 200 && res.type === 'basic') {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(req, copy); });
        }
        return res;
      });
    })
  );
});
