// The ONLY place that contains claude.ai / chatgpt.com selectors. If a site changes, fix only this file.
// Every function below works on both sites; GPT is true on chatgpt.com (the account's provider).
window.__mc = {
  isGpt() { return /(^|\.)(chatgpt\.com|openai\.com)$/.test(location.hostname); },
  assistantSel() { return this.isGpt() ? '[data-message-author-role="assistant"]' : '[data-transcript-engine-root]'; },
  userSel() { return this.isGpt() ? '[data-message-author-role="user"]' : '[data-testid="user-message"]'; },
  composer() {
    if (this.isGpt()) return document.querySelector('#prompt-textarea[contenteditable="true"]') || document.querySelector('div.ProseMirror[contenteditable="true"]') || document.querySelector('div[contenteditable="true"]');
    return document.querySelector('div[contenteditable="true"]');
  },
  insert(text) {
    const el = this.composer();
    if (!el) return 'NO_COMPOSER';
    el.focus();
    const ok = document.execCommand('insertText', false, text);
    if (!ok) {
      const dt = new DataTransfer();
      dt.setData('text/plain', text);
      el.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
    }
    return 'OK';
  },
  insertIfEmpty(text) {
    const el = this.composer();
    if (!el) return 'NO_COMPOSER';
    if ((el.innerText || '').trim().length > 0) return 'NOT_EMPTY';
    return this.insert(text);
  },
  thoughtLines() {
    // BEST EFFORT (selectors are guesses): short labels of the buttons/toggles inside the chat area, e.g. "Thinking", "Searched the web".
    // Verta always runs in a fresh chat, so everything in <main> belongs to this run.
    const out = [];
    const seen = new Set();
    const scope = document.querySelector('main') || document.body;
    const skip = /^(copy|retry|share|edit|new chat|stop|send|regenerate|try again|show more|show less|good response|bad response|scroll to bottom)\b/i;
    scope.querySelectorAll('button,summary,[aria-expanded]').forEach(el => {
      if (el.closest('nav,header,form,fieldset,[role="menu"],[role="listbox"],[role="dialog"]')) return;
      if (!this.visibleEl(el)) return;
      const t = (el.innerText || '').replace(/\s+/g, ' ').trim();
      if (t.length < 4 || t.length > 140 || seen.has(t) || skip.test(t)) return;
      if (t.length < 40 && /(mythos|fable|opus|sonnet|haiku)/i.test(t)) return;
      seen.add(t);
      out.push(t);
    });
    return out.slice(-30);
  },
  lastReplyText() {
    // Text of the newest assistant message + its code blocks. streaming=true while Claude is still writing.
    const thoughts = this.thoughtLines();
    const roots = document.querySelectorAll(this.assistantSel());
    if (!roots.length) return JSON.stringify({ found: false, streaming: false, text: '', blocks: [], thoughts });
    const root = roots[roots.length - 1];
    const streaming = this.isGpt()
      ? !!document.querySelector('button[data-testid="stop-button"],button[aria-label*="Stop"]')
      : (!!root.closest('[data-transcript-live]') || !!root.querySelector('code[data-highlight="pending"]'));
    const blocks = [];
    root.querySelectorAll('pre').forEach(pre => blocks.push((pre.innerText || pre.textContent || '').replace(/\n$/, '')));
    return JSON.stringify({ found: true, streaming, text: root.innerText || root.textContent || '', blocks, thoughts });
  },
  // ---- max effort (Verta option). Selectors are guesses: the report goes back as "EFFORT:<ok|fail>:<details>" ----
  visibleEl(e) { return !!(e && (e.offsetParent !== null || e.getClientRects().length)); },
  menuRoot() {
    return Array.from(document.querySelectorAll('[role="menu"],[role="listbox"],[data-radix-popper-content-wrapper]'))
      .filter(e => this.visibleEl(e)).pop() || null;
  },
  modelButton() {
    const bs = Array.from(document.querySelectorAll('button'))
      .filter(b => this.visibleEl(b) && /(mythos|fable|opus|sonnet|haiku)/i.test(b.innerText || ''));
    return bs.find(b => b.getAttribute('aria-haspopup')) || bs[bs.length - 1] || null;
  },
  async setEffortGpt() {
    // BEST EFFORT on chatgpt.com: open the model picker and choose the "Thinking" / most capable entry.
    const post = (s) => { if (window.AiHiveBridge) window.AiHiveBridge.postMessage(s); };
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    try {
      let btn = null;
      for (let i = 0; i < 20 && !btn; i++) {
        btn = document.querySelector('[data-testid="model-switcher-dropdown-button"]');
        if (!btn) await sleep(300);
      }
      if (!btn) { post('EFFORT:fail:model picker not found'); return 'STARTED'; }
      btn.click();
      await sleep(600);
      const root = this.menuRoot();
      if (!root) { post('EFFORT:fail:menu did not open'); return 'STARTED'; }
      const els = Array.from(root.querySelectorAll('[role="menuitem"],[role="option"],[role="menuitemradio"],button'))
        .filter(e => this.visibleEl(e));
      const pick = els.find(e => /(thinking|pro)\b/i.test((e.innerText || '').split('\n')[0]));
      if (pick) pick.click();
      await sleep(400);
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      post('EFFORT:' + (pick ? 'ok' : 'fail') + ':chatgpt picker, ' + (pick ? 'chose ' + (pick.innerText || '').split('\n')[0].slice(0, 30) : 'no thinking entry'));
    } catch (e) { post('EFFORT:fail:' + e); }
    return 'STARTED';
  },
  async setEffort() {
    if (this.isGpt()) return this.setEffortGpt();
    const post = (s) => { if (window.AiHiveBridge) window.AiHiveBridge.postMessage(s); };
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    const log = [];
    try {
      let btn = null;
      for (let i = 0; i < 20 && !btn; i++) { btn = this.modelButton(); if (!btn) await sleep(300); }
      if (!btn) { post('EFFORT:fail:model/effort button not found'); return 'STARTED'; }
      log.push('model=' + (btn.innerText || '').trim().split('\n')[0].slice(0, 40));
      btn.click();
      await sleep(600);
      const root = this.menuRoot();
      if (!root) { post('EFFORT:fail:menu did not open|' + log.join(' ; ')); return 'STARTED'; }
      const els = Array.from(root.querySelectorAll('[role="menuitem"],[role="option"],[role="menuitemradio"],[role="radio"],button,[role="switch"]'))
        .filter(e => this.visibleEl(e));
      log.push('controls=' + els.map(e => (e.innerText || '').trim().split('\n')[0].slice(0, 20)).filter(Boolean).slice(0, 14).join(' | '));
      let done = false;
      const mx = els.find(e => /^\s*(max|maximum|extra high|xhigh)\s*$/i.test((e.innerText || '').split('\n')[0]));
      if (mx) { mx.click(); done = true; log.push('effort=max'); }
      else {
        const th = els.find(e => /(extended|adaptive) thinking/i.test(e.innerText || '') || /thinking/i.test(e.getAttribute('aria-label') || ''));
        if (th) {
          const on = th.getAttribute('aria-checked') === 'true' || th.getAttribute('data-state') === 'checked';
          if (!on) th.click();
          done = true;
          log.push('thinking=on (no max option)');
        }
      }
      if (!done) log.push('effort control not found');
      await sleep(400);
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      post('EFFORT:' + (done ? 'ok' : 'fail') + ':' + log.join(' ; '));
    } catch (e) { post('EFFORT:fail:' + e); }
    return 'STARTED';
  },
  isNewChat() {
    if (this.isGpt()) return location.pathname === '/' || location.pathname === '';
    return /^\/new/.test(location.pathname);
  },
  send() {
    let b = null;
    if (this.isGpt()) b = document.querySelector('button[data-testid="send-button"]:not([disabled])');
    if (!b) b = Array.from(document.querySelectorAll('button'))
      .find(x => /send/i.test(x.getAttribute('aria-label') || '') && !x.disabled);
    if (!b) return 'NO_SEND_BUTTON';
    b.click();
    return 'SENT';
  },
  checkLimit() {
    // Best effort. The answer comes back through the AiHiveBridge channel as "LIMIT:<ok|limited|unknown>:<note>".
    const post = (s) => { if (window.AiHiveBridge) window.AiHiveBridge.postMessage(s); };
    try {
      const txt = (document.body && document.body.innerText) || '';
      const m = /(usage limit|limit reached|reached (your|the)[^.\n]{0,30}limit|hit (your|the)[^.\n]{0,30}limit|out of (free )?messages|limit will reset)[^\n]{0,80}/i.exec(txt.slice(0, 60000));
      if (m) { post('LIMIT:limited:' + m[0].replace(/\s+/g, ' ').slice(0, 100)); return 'STARTED'; }
      if (this.isGpt()) {
        fetch('/api/auth/session', { credentials: 'include' }).then(r => r.ok ? r.json() : null).then(j => {
          if (j && j.user) post('LIMIT:ok:no limit message on the page');
          else post('LIMIT:unknown:not signed in');
        }).catch(e => post('LIMIT:unknown:' + e));
        return 'STARTED';
      }
      fetch('/api/account', { credentials: 'include' }).then(r => {
        if (r.ok) post('LIMIT:ok:no limit message on the page');
        else post('LIMIT:unknown:not signed in (' + r.status + ')');
      }).catch(e => post('LIMIT:unknown:' + e));
      return 'STARTED';
    } catch (e) { post('LIMIT:unknown:' + e); return 'ERR'; }
  },
  limitHit() {
    // Cheap check used by the auto hand-off. Looks for the "limit reached" banner OUTSIDE the chat messages,
    // so a chat that only talks about limits does not count. Returns "LIMITED:<text>" or "OK".
    try {
      const c = document.body.cloneNode(true);
      c.querySelectorAll('[data-testid="user-message"],[data-transcript-engine-root],[data-message-author-role],script,style,nav,pre,code').forEach(e => e.remove());
      const txt = (c.textContent || '').replace(/\s+/g, ' ').slice(0, 60000);
      const m = /(usage limit|limit reached|reached (your|the)[^.]{0,30}limit|hit (your|the)[^.]{0,30}limit|out of (free )?messages|limit will reset)[^.]{0,80}/i.exec(txt);
      return m ? 'LIMITED:' + m[0].slice(0, 100) : 'OK';
    } catch (e) { return 'OK'; }
  },
  transcript() {
    // The conversation as [{role:"user"|"assistant", text}] in page order. BEST EFFORT: user messages use
    // [data-testid="user-message"], assistant messages the same [data-transcript-engine-root] as lastReplyText().
    const out = [];
    const uSel = this.userSel();
    document.querySelectorAll(uSel + ',' + this.assistantSel()).forEach(el => {
      const isUser = el.matches(uSel);
      if (!isUser && el.closest(uSel)) return;
      const text = (el.innerText || el.textContent || '').trim();
      if (text) out.push({ role: isUser ? 'user' : 'assistant', text });
    });
    return JSON.stringify(out);
  },
  info() {
    return JSON.stringify({
      url: location.href,
      title: document.title,
      userAgent: navigator.userAgent,
      hasComposer: !!this.composer()
    });
  },
  lastCodeBlocks() {
    // Selectors found with "Dump last reply": every assistant message has its own [data-transcript-engine-root];
    // while it is being written its wrapper has [data-transcript-live] and the code has data-highlight="pending".
    const roots = document.querySelectorAll(this.assistantSel());
    const out = { streaming: false, blocks: [] };
    if (!roots.length) return JSON.stringify(out);
    const root = roots[roots.length - 1];
    out.streaming = this.isGpt()
      ? !!document.querySelector('button[data-testid="stop-button"],button[aria-label*="Stop"]')
      : (!!root.closest('[data-transcript-live]') || !!root.querySelector('code[data-highlight="pending"]'));
    root.querySelectorAll('pre').forEach(pre => {
      const code = pre.querySelector('code');
      const m = code && /language-([^\s]+)/.exec(code.className || '');
      out.blocks.push({ lang: m ? m[1] : '', code: (pre.innerText || '').replace(/\n$/, '') });
    });
    return JSON.stringify(out);
  },
  dumpLastReply() {
    // Structure dump only (no selectors guessed): helps find the reply, code blocks and the Stop button.
    const sig = (el) => {
      let a = el.tagName.toLowerCase();
      if (el.id) a += '#' + el.id;
      const c = (typeof el.className === 'string' ? el.className : '').trim().split(/\s+/).filter(Boolean).slice(0, 5).join('.');
      if (c) a += '.' + c;
      for (const at of Array.from(el.attributes)) {
        if (/^(data-|role$|aria-)/.test(at.name)) a += '[' + at.name + '=' + String(at.value).slice(0, 40) + ']';
      }
      return a;
    };
    const chain = (el, n) => {
      const out = [];
      while (el && el !== document.body && out.length < n) { out.push(sig(el)); el = el.parentElement; }
      return out;
    };
    const skel = (el, d) => {
      const o = { s: sig(el) };
      const t = Array.from(el.childNodes).filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join(' ').slice(0, 24);
      if (t) o.t = t;
      if (d > 0 && el.children.length) o.c = Array.from(el.children).slice(0, 6).map(k => skel(k, d - 1));
      return o;
    };
    const pres = Array.from(document.querySelectorAll('pre'));
    const out = { url: location.href, preCount: pres.length, codeCount: document.querySelectorAll('code').length };
    out.lastPres = pres.slice(-2).map(p => ({
      chain: chain(p, 10),
      textStart: (p.innerText || '').slice(0, 120),
      textLen: (p.innerText || '').length,
      block: p.parentElement ? skel(p.parentElement, 3) : null
    }));
    const names = {};
    document.querySelectorAll('*').forEach(e => {
      for (const at of Array.from(e.attributes)) if (at.name.startsWith('data-')) names[at.name] = (names[at.name] || 0) + 1;
    });
    out.dataAttrs = names;
    out.buttons = Array.from(document.querySelectorAll('button[aria-label]'))
      .map(b => b.getAttribute('aria-label')).filter(l => /stop|send|copy|retry|edit/i.test(l)).slice(-12);
    return JSON.stringify(out, null, 1);
  },
  dumpComposer() {
    const el = this.composer();
    if (!el) return 'NO_COMPOSER';
    const p = (el.parentElement && el.parentElement.parentElement) || el.parentElement || el;
    return p.outerHTML.slice(0, 3000);
  }
};
