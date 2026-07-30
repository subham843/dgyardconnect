// Firebase Cloud Messaging service worker for web (dgyard-connect)
// Must be at web/firebase-messaging-sw.js so it is served from app root.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAW74gkDR9D9AkRrITK1yWuOy7X5sq1Yyg',
  authDomain: 'dgyard-connect.firebaseapp.com',
  projectId: 'dgyard-connect',
  storageBucket: 'dgyard-connect.firebasestorage.app',
  messagingSenderId: '541039650342',
  appId: '1:541039650342:web:f5e5baffa57512174968e7',
  measurementId: 'G-8JKPZHKDWY',
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage(function (payload) {
  const data = payload.data || {};
  const jobId = data.jobId;
  if (!jobId) return;
  const title = data.title || 'Job update';
  const body = data.body || 'You have a job update. Tap to view.';
  const target = data.target || 'dealer';
  const type = data.type || 'job_request';
  let path = '/dealer/jobs/' + jobId;
  if (target === 'technician') {
    path = type === 'job_request' ? '/technician/incoming?jobId=' + jobId : '/technician/jobs/' + jobId;
  } else if (target === 'dealer' && (type === 'technician_accepted' || type === 'technician_bid')) {
    path = '/dealer/jobs/' + jobId + '/bidding';
  }
  const options = {
    body,
    icon: '/icons/Icon-192.png',
    tag: 'job-' + jobId,
    requireInteraction: true,
    data: { url: path, jobId, type, target },
  };
  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const data = event.notification.data || {};
  const url = data.url || '/';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
    for (let i = 0; i < clientList.length; i++) {
      const client = clientList[i];
      if (client.url && 'focus' in client) {
        client.navigate(url);
        return client.focus();
      }
    }
    if (clients.openWindow) {
      return clients.openWindow(self.location.origin + url);
    }
  }));
});
