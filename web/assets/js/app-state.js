// app-state.js
// Global Utility for App State Persistence (Scroll & Input Data)

(function() {
    const PATH = window.location.pathname || 'app';
    const SCROLL_KEY = `${PATH}_scroll`;
    const INPUT_PREFIX = `${PATH}_input_`;

    let scrollTimeout;
    let inputTimeout;

    // --- SCROLL PERSISTENCE ---
    function saveScrollPosition() {
        localStorage.setItem(SCROLL_KEY, window.scrollY);
    }

    function restoreScrollPosition() {
        const savedScroll = localStorage.getItem(SCROLL_KEY);
        if (savedScroll !== null) {
            window.scrollTo(0, parseInt(savedScroll, 10));
        }
    }

    // Debounced scroll listener
    window.addEventListener('scroll', () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(saveScrollPosition, 200);
    });

    // --- FORM DATA PERSISTENCE ---
    function isEligibleInput(el) {
        if (!el.id && !el.name) return false; // Needs an identifier
        if (el.hasAttribute('data-no-restore')) return false;
        if (el.type === 'password' || el.type === 'hidden' || el.type === 'file' || el.type === 'submit' || el.type === 'button') return false;
        // Exclude login-related inputs from persistence
        const eid = (el.id || el.name || '').toLowerCase();
        if (el.type === 'email' || eid.includes('login') || eid.includes('pass') || eid.includes('email')) return false;
        return true;
    }

    function getElementIdentifier(el) {
        return el.id || el.name;
    }

    function saveInputValue(el) {
        if (!isEligibleInput(el)) return;
        const key = INPUT_PREFIX + getElementIdentifier(el);
        if (el.type === 'checkbox' || el.type === 'radio') {
            localStorage.setItem(key, el.checked);
        } else {
            localStorage.setItem(key, el.value);
        }
    }

    function restoreInputValues() {
        const inputs = document.querySelectorAll('input, textarea, select');
        inputs.forEach(el => {
            if (!isEligibleInput(el)) return;
            const key = INPUT_PREFIX + getElementIdentifier(el);
            const savedValue = localStorage.getItem(key);
            
            if (savedValue !== null) {
                if (el.type === 'checkbox' || el.type === 'radio') {
                    el.checked = (savedValue === 'true');
                } else {
                    el.value = savedValue;
                }
                // Trigger change/input event in case other scripts rely on it
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });
    }

    function clearFormData(formEl) {
        const inputs = formEl.querySelectorAll('input, textarea, select');
        inputs.forEach(el => {
            if (isEligibleInput(el)) {
                localStorage.removeItem(INPUT_PREFIX + getElementIdentifier(el));
            }
        });
    }

    // Debounced input listener
    document.addEventListener('input', (e) => {
        const el = e.target;
        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') {
            clearTimeout(inputTimeout);
            inputTimeout = setTimeout(() => saveInputValue(el), 300);
        }
    });

    document.addEventListener('change', (e) => {
        const el = e.target;
        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') {
            saveInputValue(el);
        }
    });

    // Clear form data on successful submit
    document.addEventListener('submit', (e) => {
        clearFormData(e.target);
    });

    // --- SERVICE WORKER REGISTRATION ---
    function registerServiceWorker() {
        if ('serviceWorker' in navigator) {
            window.addEventListener('load', () => {
                navigator.serviceWorker.register('../sw.js', { scope: '/' }).then(registration => {
                    console.log('ServiceWorker registration successful with scope: ', registration.scope);
                    // Force check for updates immediately
                    registration.update();
                }).catch(err => {
                    console.log('ServiceWorker registration failed: ', err);
                });
            });
        }
    }

    // --- WEBVIEW LIFECYCLE HOOKS ---
    // In mobile WebViews (Android/iOS), JS is paused immediately when the app goes to the background.
    // We must force save on visibilitychange to ensure no data is lost.
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden') {
            saveScrollPosition();
            // Force save active element if it's an input
            const activeEl = document.activeElement;
            if (activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA' || activeEl.tagName === 'SELECT')) {
                saveInputValue(activeEl);
            }
        }
    });

    // --- INITIALIZATION ---
    document.addEventListener('DOMContentLoaded', () => {
        restoreInputValues();
        // Give the DOM a tiny bit of time to layout before restoring scroll
        setTimeout(restoreScrollPosition, 50);
    });

    registerServiceWorker();

    // --- IN-APP BROWSER OVERLAY ---
    window.openInAppBrowser = function(url, titleText = 'Document') {
        const overlay = document.createElement('div');
        overlay.style.position = 'fixed';
        overlay.style.top = '0';
        overlay.style.left = '0';
        overlay.style.width = '100vw';
        overlay.style.height = '100vh';
        overlay.style.backgroundColor = '#fff';
        overlay.style.zIndex = '999999';
        overlay.style.display = 'flex';
        overlay.style.flexDirection = 'column';

        const header = document.createElement('div');
        header.style.display = 'flex';
        header.style.justifyContent = 'space-between';
        header.style.alignItems = 'center';
        header.style.padding = '12px 16px';
        header.style.backgroundColor = '#f8fafc';
        header.style.borderBottom = '1px solid #e2e8f0';
        header.style.boxShadow = '0 1px 2px 0 rgba(0, 0, 0, 0.05)';

        const titleEl = document.createElement('h3');
        titleEl.textContent = titleText;
        titleEl.style.margin = '0';
        titleEl.style.fontSize = '1.1rem';
        titleEl.style.color = '#0f172a';
        titleEl.style.fontWeight = '600';
        titleEl.style.fontFamily = 'system-ui, -apple-system, sans-serif';

        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';
        closeBtn.style.background = 'none';
        closeBtn.style.border = 'none';
        closeBtn.style.cursor = 'pointer';
        closeBtn.style.color = '#64748b';
        closeBtn.style.padding = '4px';
        closeBtn.style.display = 'flex';
        closeBtn.style.alignItems = 'center';
        closeBtn.style.justifyContent = 'center';
        closeBtn.onclick = () => document.body.removeChild(overlay);

        const iframe = document.createElement('iframe');
        iframe.src = url;
        iframe.style.flexGrow = '1';
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.backgroundColor = '#fff';

        header.appendChild(titleEl);
        header.appendChild(closeBtn);
        overlay.appendChild(header);
        overlay.appendChild(iframe);

        document.body.appendChild(overlay);
    };

})();
