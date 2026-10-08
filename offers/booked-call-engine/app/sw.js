var C = 'bce-v1';
var FILES = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];
self.addEventListener('install', function(e){
  self.skipWaiting();
  e.waitUntil(caches.open(C).then(function(c){ return c.addAll(FILES); }).catch(function(){}));
});
self.addEventListener('activate', function(e){
  e.waitUntil(caches.keys().then(function(k){
    return Promise.all(k.filter(function(n){ return n !== C; }).map(function(n){ return caches.delete(n); }));
  }));
  self.clients.claim();
});
self.addEventListener('fetch', function(e){
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(function(hit){
      return hit || fetch(e.request).then(function(r){
        var copy = r.clone();
        caches.open(C).then(function(c){ c.put(e.request, copy); }).catch(function(){});
        return r;
      }).catch(function(){ return caches.match('./index.html'); });
    })
  );
});