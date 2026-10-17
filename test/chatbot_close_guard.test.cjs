const assert = require('node:assert/strict');
const { readFileSync, existsSync } = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const guardPath = path.join(__dirname, '../web/chatbot-close-guard.js');
const source = existsSync(guardPath) ? readFileSync(guardPath, 'utf8') : '';

function fixture() {
  const listeners = [];
  const frameWindow = {};
  const root = {
    querySelectorAll: () => [{ contentWindow: frameWindow }],
  };
  const window = {
    addEventListener(type, listener, capture) {
      listeners.push({ type, listener, capture });
    },
  };
  const document = {
    getElementById(id) {
      return id === 'JotformAgent-01a1485505b070008c24740628322f437e85'
        ? root : null;
    },
  };
  const context = vm.createContext({ window, document });
  const install = () => vm.runInContext(source, context);
  let opened = true;
  install();
  return {
    frameWindow,
    install,
    listeners,
    get opened() { return opened; },
    clickLauncher() { opened = !opened; },
    message(data, origin = 'https://www.noupe.com', sender = frameWindow) {
      const event = { data, origin, source: sender };
      for (const { type, listener } of listeners) {
        if (type === 'message') listener(event);
      }
      // Noupe's inspected host handler flips for toggle and sets for close/open.
      if (data.action === 'toggle-embed-agent') opened = !opened;
      if (data.action === 'close-embed-agent') opened = false;
      if (data.action === 'open-embed-agent') opened = true;
      return event.data;
    },
  };
}

test('two iframe close signals cannot close then reopen the chat', () => {
  const f = fixture();
  f.message({ action: 'toggle-embed-agent' });
  assert.equal(f.opened, false);
  f.message({ action: 'toggle-embed-agent' });
  assert.equal(f.opened, false);
});

test('late iframe close after a launcher close stays closed', () => {
  const f = fixture();
  f.clickLauncher();
  f.message({ action: 'toggle-embed-agent' });
  assert.equal(f.opened, false);
});

test('launcher can still reopen immediately after closing', () => {
  const f = fixture();
  f.message({ action: 'toggle-embed-agent' });
  f.clickLauncher();
  assert.equal(f.opened, true);
});

test('only this agent iframe and the exact Noupe origin are normalized', () => {
  const f = fixture();
  for (const [origin, sender] of [
    ['https://example.com', f.frameWindow],
    ['https://www.noupe.com.evil.example', f.frameWindow],
    ['https://www.noupe.com', {}],
    ['https://www.noupe.com', null],
  ]) {
    const data = { action: 'toggle-embed-agent' };
    f.message(data, origin, sender);
    assert.equal(data.action, 'toggle-embed-agent');
  }
});

test('explicit open/close, chat content, and other payloads are untouched', () => {
  const f = fixture();
  for (const data of [
    { action: 'open-embed-agent' },
    { action: 'close-embed-agent' },
    { action: 'agent-response-received', payload: { text: 'example' } },
    { messageType: 'noupe-post-message', payload: { selectedColor: '#176b45' } },
  ]) {
    const before = JSON.stringify(data);
    f.message(data);
    assert.equal(JSON.stringify(data), before);
  }
});

test('install is idempotent and runs before vendor bubble listeners', () => {
  const f = fixture();
  f.install();
  assert.equal(f.listeners.length, 1);
  assert.equal(f.listeners[0].type, 'message');
  assert.equal(f.listeners[0].capture, true);
});

test('unrelated or absent message data is ignored safely', () => {
  const f = fixture();
  const listener = f.listeners[0]?.listener;
  assert.equal(typeof listener, 'function');
  for (const data of [null, undefined, 'message', 42]) {
    assert.doesNotThrow(() => listener({
      data, origin: 'https://www.noupe.com', source: f.frameWindow,
    }));
  }
});
