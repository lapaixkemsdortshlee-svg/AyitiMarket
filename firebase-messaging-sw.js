// Firebase Cloud Messaging : Service Worker pou background push.
//
// Fichye sa a dwe SOU RACINE site la (egz. https://ekomat/firebase-
// messaging-sw.js) paske se sa Firebase ap chèche pa defo. Yo ka kowegzite
// ak sw.js (PWA cache) san pwoblèm, yo nan scope diferan.
//
// VLE FIREBASE_CONFIG yo DWE menm valè ak index.html. Lè li vid, service
// worker la ap aktif men li pa fè anyen.

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyAF_byJDhzM6sPMPbexfofWI-9TJbFuw5k',
  authDomain: 'ayitimarket-19c78.firebaseapp.com',
  projectId: 'ayitimarket-19c78',
  storageBucket: 'ayitimarket-19c78.firebasestorage.app',
  messagingSenderId: '372041211822',
  appId: '1:372041211822:web:68bfbf9ed33b9adbf5f23f',
  measurementId: 'G-QJG6ZGJR70',
};

if (FIREBASE_CONFIG.apiKey && FIREBASE_CONFIG.projectId) {
  try {
    firebase.initializeApp(FIREBASE_CONFIG);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage(payload => {
      const n = (payload && payload.notification) || {};
      const data = (payload && payload.data) || {};
      const title = n.title || data.title || 'Ekomat';
      const body = n.body || data.body || '';
      self.registration.showNotification(title, {
        body,
        icon: '/icon-192.png',
        badge: '/icon-192.png',
        tag: data.tag || 'aym-push',
        data,
      });
    });
  } catch (e) {
    console.warn('[FCM SW] init failed:', e && e.message);
  }
}

// Klike sou notifikasyon → fokis sou onglè aplikasyon an oswa louvri yon
// nouvèl. Itilize `data.url` lè li disponib pou direksyon entèn.
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const data = event.notification.data || {};
  const targetUrl = (data && data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const client of list) {
        if ('focus' in client) {
          if (targetUrl && 'navigate' in client) {
            try { client.navigate(targetUrl); } catch (_) { }
          }
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })
  );
});
