// Import Firebase scripts
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Firebase configuration (from firebase_options.dart)
const firebaseConfig = {
  apiKey: "AIzaSyCMP5RbBSnBr23Jix2ixKvNPhhCn18QQh8",
  authDomain: "executivesystem.firebaseapp.com",
  projectId: "executivesystem",
  storageBucket: "executivesystem.appspot.com",
  messagingSenderId: "616328184468",
  appId: "1:616328184468:web:e3b5eca7d669c7c85d6a81"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png' // Optional: add an icon
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});