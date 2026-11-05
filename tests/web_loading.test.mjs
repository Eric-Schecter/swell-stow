import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const html = readFileSync(new URL('../tools/web_shell.html', import.meta.url), 'utf8');
const code = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1]
  .replace('$GODOT_CONFIG', JSON.stringify({ executable: 'index', args: [] }));
const flush = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function page() {
  const runtime = deferred(), pack = deferred(), calls = [];
  const elements = Object.fromEntries(['canvas', 'play', 'progress', 'status', 'error', 'launch'].map(id => [id, {
    hidden: id === 'play', disabled: true, style: {}, textContent: '',
    addEventListener(event, handler) { this[event] = handler; },
    removeAttribute() {}, remove() { this.removed = true; }, focus() { this.focused = true; }
  }]));
  class Engine {
    init(name) { calls.push(['init', name]); return runtime.promise; }
    preloadFile(...args) { calls.push(['preload', ...args]); return pack.promise; }
    async start(options) { calls.push(['start', ...options.args]); }
  }
  class Audio { constructor(src) { this.src = src; } play() { calls.push(['sound', this.src]); return Promise.resolve(); } }
  runInNewContext(code, { Engine, Audio, performance: { now: () => 1000 }, document: { getElementById: id => elements[id] } });
  return { elements, runtime, pack, calls };
}

test('preloads on page load; Play appears only after runtime and pack are ready', async () => {
  const p = page();
  assert.deepEqual(p.calls, [['init', 'index'], ['preload', 'index.pck', 'index.pck']]);
  assert.equal(p.elements.play.hidden, true);
  p.runtime.resolve(); await flush();
  assert.equal(p.elements.play.hidden, true);
  p.pack.resolve(); await flush();
  assert.equal(p.elements.play.hidden, false);
  assert.equal(p.elements.play.disabled, false);
  assert.equal(p.calls.length, 2); // No game timer starts while waiting for a click.
  await p.elements.play.click();
  assert.deepEqual(p.calls.at(-1), ['start', '--main-pack', 'index.pck', '--', '--web-launch']);
  assert.deepEqual(p.calls.at(-2), ['sound', 'press.wav']);
  assert.equal(p.calls.length, 4); // Runtime and pack were not downloaded again.
  assert.equal(p.elements.launch.removed, true);
});

test('loading failure keeps Play hidden and displays an error', async () => {
  const p = page();
  p.runtime.reject(new Error('Download failed')); p.pack.resolve();
  await flush();
  assert.equal(p.elements.play.hidden, true);
  assert.match(p.elements.error.textContent, /Download failed/);
});
