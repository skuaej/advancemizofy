import { initializeApp } from 'firebase/app';
import { getDatabase } from 'firebase/database';

// Placeholders for Firebase config
const firebaseConfig = {
  apiKey: "PLACEHOLDER_API_KEY",
  authDomain: "PLACEHOLDER_AUTH_DOMAIN",
  databaseURL: "https://ummo-tv-be82a-default-rtdb.firebaseio.com", // Found from console
  projectId: "ummo-tv-be82a",
  storageBucket: "PLACEHOLDER_STORAGE_BUCKET",
  messagingSenderId: "PLACEHOLDER_MESSAGING_SENDER_ID",
  appId: "PLACEHOLDER_APP_ID"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const database = getDatabase(app);

export { app, database };
