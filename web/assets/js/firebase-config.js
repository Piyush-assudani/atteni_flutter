// firebase-config.js
// ⚠️ Single source of truth for all Firebase configuration.
// Imported via <script> tag in every HTML page BEFORE any module script.

(function() {
    // Define Config 1 (Default: DPS) & its corresponding access code
    const config1 = {
        apiKey: "AIzaSyBC3tfhCq53pA2kNJtL8GFsC8F-OSCaJ9Q",
        authDomain: "buspro-4767d.firebaseapp.com",
        databaseURL: "https://buspro-4767d-default-rtdb.firebaseio.com",
        projectId: "buspro-4767d",
        storageBucket: "buspro-4767d.firebasestorage.app",
        messagingSenderId: "772721278896",
        appId: "1:772721278896:android:84df6b64cc19d5772c2075"
    };
    
    // Access Code for Config 1 is now stored in Firebase RTDB (/system/accessCode)
    // window.ATTENI_ACCESS_CODE_1 has been removed for security.

    // URL parameter check to override database selection (useful for school links)
    try {
        const urlParams = new URLSearchParams(window.location.search);
        const schoolParam = urlParams.get('school');
        if (schoolParam) {
            const normalizedSchool = schoolParam.trim().toUpperCase();
            if (normalizedSchool === 'DPS' || normalizedSchool === 'DPS_BALOTRA') {
                localStorage.setItem('SELECTED_DB_INDEX', '1');
                localStorage.setItem('SELECTED_SCHOOL', 'DPS');
            } else {
                localStorage.setItem('SELECTED_DB_INDEX', '2');
                localStorage.setItem('SELECTED_SCHOOL', schoolParam.trim());
            }
        }
    } catch (e) {
        console.warn("Failed checking school parameter override:", e);
    }

    const selectedDbIndex = localStorage.getItem('SELECTED_DB_INDEX') || '1';
    const selectedSchool = localStorage.getItem('SELECTED_SCHOOL') || 'DPS';

    window.ATTENI_FIREBASE_CONFIG = config1;

    if (selectedSchool !== 'DPS') {
        window.ATTENI_DB_PATH = `artifacts/student-system-v2/public/data/${selectedSchool}`;
    } else {
        window.ATTENI_DB_PATH = `artifacts/student-system-v2/public/data`;
    }

    // Global app constants
    window.ATTENI_APP_ID = 'student-system-v2';
})();
