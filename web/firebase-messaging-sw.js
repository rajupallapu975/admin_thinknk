importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// 🛡️ High-fidelity Firebase synchronization for Web Background Alerts.
// This allows PC/Website users to receive notifications even when the browser tab is closed.
firebase.initializeApp({
  apiKey: "AIzaSyCG9N9vDUPmWyId1ZgkiPa7O5vXLp-2l1M",
  authDomain: "thinkink-admin.firebaseapp.com",
  projectId: "thinkink-admin",
  storageBucket: "thinkink-admin.firebasestorage.app",
  messagingSenderId: "1071627103248",
  appId: "1:1071627103248:web:a67da5bcbf4d1ad29bae95",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background Message received: ', payload);
  const notificationTitle = payload.notification.title || "ThinkInk Order Update";
  const notificationOptions = {
    body: payload.notification.body || "A new order requires your attention.",
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
