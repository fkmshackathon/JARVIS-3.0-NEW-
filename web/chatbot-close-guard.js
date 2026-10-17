(() => {
  'use strict';

  if (window.__synchroChatbotCloseGuardInstalled) return;
  window.__synchroChatbotCloseGuardInstalled = true;

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (event.origin !== 'https://www.noupe.com' ||
        !data || typeof data !== 'object' ||
        data.action !== 'toggle-embed-agent' || !event.source) return;

    const root = document.getElementById(
      'JotformAgent-01a1485505b070008c24740628322f437e85',
    );
    if (!root) return;
    const fromChat = Array.from(root.querySelectorAll('iframe')).some(
      (frame) => frame.contentWindow === event.source,
    );
    if (!fromChat) return;

    // Inside the chat, this signal is the close control, not the launcher.
    // Make repeated/late close signals idempotent instead of flipping back open.
    // The parent-page launcher and explicit open requests remain untouched.
    data.action = 'close-embed-agent';
  }, true);
})();
