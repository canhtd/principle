/* proto-comments.js — a review-comment layer for throwaway HTML prototypes.
 *
 * Drop one line at the end of any prototype's <body>:
 *     <script src="./proto-comments.js"></script>
 * Nothing else in the prototype changes.
 *
 * C toggles comment mode, Shift+C toggles the side panel, Esc cancels.
 * Comments persist in localStorage under location.pathname, so each prototype
 * file keeps its own set. "Copy as Markdown" is what gets pasted back.
 *
 * Vanilla JS, no dependencies, no external fonts or CDNs.
 */
(function () {
  'use strict';
  if (window.ProtoComments) return;                       // never install twice

  var TEST = /[?&]selftest\b/.test(location.search);      // ?selftest = in-memory demo run
  var KEY = 'proto-comments:' + location.pathname;

  // ---------------------------------------------------------------- state
  var data = load();
  var mode = false;          // comment mode on/off
  var panelOpen = false;
  var showResolved = false;
  var pop = null;            // {kind:'new'|'view', draft?, id?}
  var replying = false;
  var flash = '';            // transient message in the panel footer

  function load() {
    if (TEST) return {v: 1, seq: 0, items: []};
    try {
      var raw = localStorage.getItem(KEY);
      if (raw) {
        var d = JSON.parse(raw);
        if (d && Array.isArray(d.items)) {
          d.items.forEach(function (i) {
            if (!Array.isArray(i.replies)) i.replies = [];
            if (!i.label) i.label = i.snip || '';         // exports written before labels existed
          });
          return d;
        }
      }
    } catch (e) { /* corrupt or blocked storage - start clean */ }
    return {v: 1, seq: 0, items: []};
  }
  function save() {
    if (TEST) return;                                     // self-test must not pollute storage
    try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (e) {}
  }
  function byId(id) {
    for (var i = 0; i < data.items.length; i++) if (data.items[i].id === id) return data.items[i];
    return null;
  }
  function shown() {
    return data.items.filter(function (i) { return showResolved || !i.resolved; });
  }

  // ---------------------------------------------------------------- helpers
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c];
    });
  }
  function p2(n) { return n < 10 ? '0' + n : '' + n; }
  var MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function stamp(ts) {
    var d = new Date(ts);
    return d.getDate() + ' ' + MON[d.getMonth()] + ', ' + p2(d.getHours()) + ':' + p2(d.getMinutes());
  }
  function today() {
    var d = new Date();
    return d.getFullYear() + '-' + p2(d.getMonth() + 1) + '-' + p2(d.getDate());
  }

  // A short, stable-ish CSS path. Stops at the first id; prefers data-id, then
  // classes, then :nth-of-type. Good enough to survive the prototypes' full
  // innerHTML re-renders, which is the whole point.
  function cssPath(el) {
    if (!el || el.nodeType !== 1) return '';
    var parts = [], cur = el, guard = 0;
    while (cur && cur.nodeType === 1 && cur !== document.body && guard++ < 8) {
      if (cur.id) { parts.unshift('#' + cssEsc(cur.id)); return parts.join(' > '); }
      var seg = cur.tagName.toLowerCase();
      var did = cur.getAttribute('data-id');
      if (did) {
        seg += '[data-id="' + did + '"]';
      } else {
        var cls = [].slice.call(cur.classList).filter(function (c) { return c.indexOf('cmt-') !== 0; });
        if (cls.length) seg += '.' + cls.map(cssEsc).join('.');
        var par = cur.parentElement;
        if (par) {
          var sibs = [].slice.call(par.children).filter(function (s) { return s.tagName === cur.tagName; });
          if (sibs.length > 1) seg += ':nth-of-type(' + (sibs.indexOf(cur) + 1) + ')';
        }
      }
      parts.unshift(seg);
      cur = cur.parentElement;
    }
    parts.unshift('body');
    return parts.join(' > ');
  }
  function cssEsc(s) {
    return (window.CSS && CSS.escape) ? CSS.escape(s) : String(s).replace(/([^\w-])/g, '\\$1');
  }
  // --- what is this element, in words? -------------------------------------
  // A comment is only useful if the reviewer can see what it is attached to, so
  // the same label drives the popover header, the pin tooltip, the list and the
  // Markdown export.
  var SEMANTIC = {BUTTON: 'button', A: 'link', INPUT: 'field', TEXTAREA: 'field',
                  SELECT: 'select', LABEL: 'label', IMG: 'image',
                  H1: 'heading', H2: 'heading', H3: 'heading', H4: 'heading'};
  // class name -> human word. A prototype can extend this: ProtoComments.kinds.foo = 'widget'
  var KINDS = {
    blk: 'block', sugrow: 'suggestion', adit: 'all-day item', dotrow: 'dot', catrow: 'category',
    habit: 'habit', railrow: 'rail item', cb: 'checkbox', pod: 'card', pcard: 'principle card',
    card: 'card', band: 'folded hours', warn: 'note', sec: 'section', axis: 'view switch',
    mgrid: 'month grid', d: 'day', logbar: 'log bar', allday: 'all-day strip',
    gridwrap: 'hour grid', dayhead: 'day header', col1: 'sidebar', col3: 'side panel',
    seg: 'segmented control', fld: 'field', chat: 'chat pane', nowline: 'now line'
  };
  function kindOf(el) {
    if (SEMANTIC[el.tagName]) return SEMANTIC[el.tagName];
    for (var i = 0; i < el.classList.length; i++) if (KINDS[el.classList[i]]) return KINDS[el.classList[i]];
    return el.tagName.toLowerCase();
  }
  function known(el) {
    if (SEMANTIC[el.tagName]) return true;
    for (var i = 0; i < el.classList.length; i++) if (KINDS[el.classList[i]]) return true;
    return false;
  }
  // elementFromPoint lands on the deepest node - usually a bare <span> of text.
  // Climb to the thing a human would name ("block", not "span").
  function meaningful(el) {
    var cur = el, hops = 0;
    while (cur && cur !== document.body && hops++ < 5) {
      if (known(cur)) return cur;
      cur = cur.parentElement;
    }
    if (el.parentElement && el.parentElement !== document.body &&
        /inline/.test(getComputedStyle(el).display)) return el.parentElement;
    return el;
  }
  function labelOf(el) {
    var t = el.getAttribute && (el.getAttribute('aria-label') || el.getAttribute('title'));
    if (!t) {                                             // first visible line of text
      var lines = ((el.innerText || el.textContent || '') + '').split('\n');
      for (var i = 0; i < lines.length; i++) {
        var s = lines[i].replace(/\s+/g, ' ').trim();
        if (s) { t = s; break; }
      }
    }
    t = (t || '').replace(/\s+/g, ' ').trim();
    if (!t) {                                             // no text at all: tag + class
      return el.tagName.toLowerCase() + (el.classList.length ? '.' + el.classList[0] : '');
    }
    if (t.length > 40) t = t.slice(0, 39).replace(/\s+\S*$/, '') + '…';
    return kindOf(el) + ' · ' + t;
  }

  // ---------------------------------------------------------------- chrome
  var style = document.createElement('style');
  style.id = 'cmt-style';
  style.textContent = [
    '#cmt-root{position:fixed;inset:0;z-index:2147483000;pointer-events:none;',
    '  font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;font-size:13px;line-height:1.5;color:#272523}',
    // NOTE: box-sizing is the ONLY id-scoped descendant rule here, because it is
    // the only property no component overrides. An id-scoped `#cmt-root button`
    // or `#cmt-root *` rule outranks every .cmt-* class rule and silently wins:
    // it already cancelled .cmt-pin's negative margin (pins landed 10px off the
    // click) and its background/colour (pins rendered hollow). So each component
    // below carries its own reset instead.
    '#cmt-root *{box-sizing:border-box}',
    '.cmt-hi{position:fixed;pointer-events:none;border:1.5px solid #224735;background:rgba(34,71,53,.06);',
    '  border-radius:5px;display:none}',
    // the element a comment is attached to, held while its popover is open
    '.cmt-sel{position:fixed;pointer-events:none;border:2px solid #224735;background:rgba(34,71,53,.08);',
    // white inner hairline so the outline still reads on dark, filled elements
    '  border-radius:6px;display:none;',
    '  box-shadow:inset 0 0 0 1px rgba(255,255,255,.8),0 0 0 3px rgba(34,71,53,.14)}',
    '.cmt-pins{position:absolute;inset:0}',
    '.cmt-pin{position:absolute;left:0;top:0;width:21px;height:21px;margin:-10px 0 0 -10px;padding:0;',
    '  border:none;border-radius:50%;font-family:inherit;font-size:11px;font-weight:600;cursor:pointer;',
    '  background:#224735;color:#fff;display:flex;align-items:center;',
    '  justify-content:center;pointer-events:auto;box-shadow:0 0 0 2px #fff,0 2px 6px rgba(15,23,42,.22)}',
    '.cmt-pin:hover{background:#09321f}',
    '.cmt-pin-res{background:#fff;color:#77746f;box-shadow:0 0 0 1.5px rgba(39,37,35,.30),0 2px 6px rgba(15,23,42,.12)}',
    // bottom-CENTRE: the corners belong to whatever the prototype puts there
    // (Principle has the Ask Ray bubble bottom-right and a mini month bottom-left)
    '.cmt-pill{position:fixed;left:50%;bottom:16px;transform:translateX(-50%);',
    '  display:flex;align-items:center;gap:2px;padding:4px;',
    '  transition:opacity .12s ease;opacity:.62;',
    '  background:#fff;border:1px solid rgba(39,37,35,.10);border-radius:999px;pointer-events:auto;',
    '  box-shadow:0 10px 26px rgba(15,23,42,.16),0 2px 6px rgba(15,23,42,.08)}',
    '.cmt-pill:hover,.cmt-pill.on{opacity:1}',
    '.cmt-pill button{padding:5px 12px;border:none;border-radius:999px;background:none;font:inherit;',
    '  font-size:13px;cursor:pointer;color:#55524e;white-space:nowrap}',
    '.cmt-pill button:hover{background:#f2f1ec}',
    '.cmt-pill.shift{opacity:1}',                      // stay solid while the panel is open
    '.cmt-pill .cmt-live{background:#224735;color:#eff2ee;font-weight:500}',
    '.cmt-pill .cmt-live:hover{background:#09321f}',
    '.cmt-n{min-width:20px;height:20px;padding:0 6px;border-radius:999px;background:#eff2ee;color:#09321f;',
    '  font-size:11px;font-weight:600;display:flex;align-items:center;justify-content:center}',
    '.cmt-pop{position:fixed;width:284px;background:#fff;border:1px solid rgba(39,37,35,.10);border-radius:12px;',
    '  box-shadow:0 14px 32px rgba(15,23,42,.16);pointer-events:auto;overflow:hidden}',
    '.cmt-h{display:flex;align-items:baseline;gap:6px;padding:9px 12px 6px}',
    '.cmt-h b{font-size:12px;font-weight:600}',
    // the label gets its own line and wraps - truncating it defeats its purpose
    '.cmt-sn{padding:0 12px 7px;font-size:11px;color:#77746f;line-height:1.4;overflow-wrap:anywhere}',
    '.cmt-ts{font-size:11px;color:#a1a1a1}',
    '.cmt-pop textarea{display:block;width:calc(100% - 24px);margin:0 12px;padding:7px 9px;min-height:64px;',
    '  resize:vertical;border:1px solid rgba(39,37,35,.14);border-radius:8px;background:#faf9f6;',
    '  font:inherit;color:inherit;outline:none}',
    '.cmt-pop textarea:focus{border-color:#39624d}',
    '.cmt-note{padding:0 12px 8px;white-space:pre-wrap;overflow-wrap:anywhere}',
    '.cmt-rep{padding:6px 12px 6px 22px;border-top:1px solid rgba(39,37,35,.07);font-size:12px;color:#55524e;',
    '  white-space:pre-wrap;overflow-wrap:anywhere}',
    '.cmt-rep .cmt-ts{display:block;margin-top:2px}',
    '.cmt-a{display:flex;align-items:center;gap:4px;padding:8px 10px 10px;flex-wrap:wrap}',
    '.cmt-a .sp{flex:1}',
    '.cmt-b{padding:4px 10px;border-radius:8px;background:none;font-family:inherit;font-size:12px;',
    '  cursor:pointer;color:#55524e;border:1px solid rgba(39,37,35,.10)}',
    '.cmt-b:hover{background:#f2f1ec}',
    '.cmt-b.pri{background:#224735;color:#eff2ee;border-color:transparent;font-weight:500}',
    '.cmt-b.pri:hover{background:#09321f}',
    '.cmt-b.warn:hover{background:#fdeceb;color:#c0272e}',
    '.cmt-hint{flex:1;font-size:11px;color:#a1a1a1}',
    '.cmt-panel{position:fixed;top:0;right:0;bottom:0;width:312px;background:#fff;pointer-events:auto;',
    '  border-left:1px solid rgba(39,37,35,.10);box-shadow:-8px 0 24px rgba(15,23,42,.08);',
    '  display:flex;flex-direction:column}',
    '.cmt-ph{display:flex;align-items:center;gap:8px;padding:12px 12px 10px;border-bottom:1px solid rgba(39,37,35,.10)}',
    '.cmt-ph b{font-size:13px;font-weight:600}',
    '.cmt-pb{flex:1;overflow:auto;padding:6px 0}',
    '.cmt-row{display:flex;gap:8px;padding:8px 12px;cursor:pointer;border-bottom:1px solid rgba(39,37,35,.06)}',
    '.cmt-row:hover{background:#faf9f6}',
    '.cmt-row .cmt-i{flex:0 0 20px;height:20px;border-radius:50%;background:#224735;color:#fff;font-size:11px;',
    '  font-weight:600;display:flex;align-items:center;justify-content:center}',
    '.cmt-row.res .cmt-i{background:#fff;color:#77746f;box-shadow:inset 0 0 0 1.5px rgba(39,37,35,.30)}',
    '.cmt-row.res .cmt-bd{opacity:.55}',
    '.cmt-bd{flex:1;min-width:0}',
    '.cmt-bd .s{font-size:11px;color:#a1a1a1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.cmt-bd .n{overflow-wrap:anywhere}',
    '.cmt-bd .r{font-size:12px;color:#55524e;padding-left:12px}',
    '.cmt-empty{padding:18px 14px;font-size:12px;color:#a1a1a1}',
    '.cmt-pf{border-top:1px solid rgba(39,37,35,.10);padding:10px 12px;display:flex;flex-wrap:wrap;gap:6px;align-items:center}',
    '.cmt-pf label{display:flex;align-items:center;gap:5px;font-size:12px;color:#55524e;width:100%;cursor:pointer}',
    '.cmt-flash{width:100%;font-size:11px;color:#39624d;min-height:14px}',
    'html.cmt-on,html.cmt-on *{cursor:crosshair !important}',
    'html.cmt-on #cmt-root,html.cmt-on #cmt-root *{cursor:default !important}',
    'html.cmt-on #cmt-root button{cursor:pointer !important}',
    'html.cmt-on #cmt-root textarea{cursor:text !important}'
  ].join('\n');
  document.head.appendChild(style);

  var root = document.createElement('div');
  root.id = 'cmt-root';
  root.innerHTML = '<div class="cmt-sel"></div><div class="cmt-hi"></div><div class="cmt-pins"></div>' +
                   '<div class="cmt-pophost"></div><div class="cmt-panelhost"></div>' +
                   '<div class="cmt-pillhost"></div>';
  document.body.appendChild(root);
  var hi = root.querySelector('.cmt-hi');
  var selBox = root.querySelector('.cmt-sel');
  var pinHost = root.querySelector('.cmt-pins');
  var popHost = root.querySelector('.cmt-pophost');
  var panelHost = root.querySelector('.cmt-panelhost');
  var pillHost = root.querySelector('.cmt-pillhost');

  // ---------------------------------------------------------------- anchoring
  function resolveEl(it) {
    if (!it.sel) return null;
    try {
      var e = document.querySelector(it.sel);
      if (e && !root.contains(e)) return e;
    } catch (err) {}
    return null;
  }
  // Intersection of every scrollable ancestor, so a pin on a block inside the
  // hour grid disappears when that block is scrolled out of the grid.
  function clipOf(el) {
    var r = null, cur = el.parentElement;
    while (cur && cur !== document.body) {
      var cs = getComputedStyle(cur);
      if (/(auto|scroll|hidden)/.test(cs.overflowY + ' ' + cs.overflowX)) {
        var b = cur.getBoundingClientRect();
        r = r ? {top: Math.max(r.top, b.top), left: Math.max(r.left, b.left),
                 right: Math.min(r.right, b.right), bottom: Math.min(r.bottom, b.bottom)}
              : {top: b.top, left: b.left, right: b.right, bottom: b.bottom};
      }
      cur = cur.parentElement;
    }
    return r;
  }
  function positionOf(it) {
    var e = resolveEl(it);
    if (e) {
      var r = e.getBoundingClientRect();
      if (r.width || r.height) {
        var x = r.left + (it.rx == null ? 0.5 : it.rx) * r.width;
        var y = r.top + (it.ry == null ? 0.5 : it.ry) * r.height;
        var c = clipOf(e);
        var vis = true;
        if (c) {
          // Hide only when the element is fully outside its scroll container, so
          // the pin and the selection outline always agree. While the element is
          // partly visible, keep the pin on the visible sliver instead of losing it.
          var l = Math.max(c.left, r.left), t = Math.max(c.top, r.top);
          var rt = Math.min(c.right, r.right), b = Math.min(c.bottom, r.bottom);
          if (rt <= l || b <= t) vis = false;
          else { x = Math.min(Math.max(x, l + 2), rt - 2); y = Math.min(Math.max(y, t + 2), b - 2); }
        }
        return {x: x, y: y, vis: vis, anchored: true};
      }
    }
    // anchor is gone: fall back to where the click landed on the page
    return {x: it.px - window.scrollX, y: it.py - window.scrollY, vis: true, anchored: false};
  }

  // --- selection outline ----------------------------------------------------
  var selPath = null;                                     // CSS path, so it survives re-renders
  function setSelection(path) { selPath = path || null; drawBox(selBox, selPath); }
  function drawBox(box, path) {
    var e = null;
    if (path) { try { e = document.querySelector(path); } catch (err) {} }
    if (!e || root.contains(e)) { box.style.display = 'none'; return; }
    var r = e.getBoundingClientRect();
    var c = clipOf(e);                                    // same rule as the pin: fully outside = gone
    if (c && (Math.min(c.right, r.right) <= Math.max(c.left, r.left) ||
              Math.min(c.bottom, r.bottom) <= Math.max(c.top, r.top))) {
      box.style.display = 'none'; return;
    }
    // must be an explicit value: these boxes are display:none in the stylesheet,
    // so clearing the inline style would hide them instead of showing them
    box.style.display = 'block';
    box.style.left = r.left + 'px'; box.style.top = r.top + 'px';
    box.style.width = r.width + 'px'; box.style.height = r.height + 'px';
  }

  // ---------------------------------------------------------------- rendering
  function renderPins() {
    var html = '';
    shown().forEach(function (it) {
      html += '<button class="cmt-pin' + (it.resolved ? ' cmt-pin-res' : '') + '" data-cid="' + it.id +
              '" title="' + esc(it.label + '\n' + it.note.slice(0, 90)) + '">' + it.n + '</button>';
    });
    pinHost.innerHTML = html;
    reposition();
  }
  function reposition() {
    var kids = pinHost.children;
    for (var i = 0; i < kids.length; i++) {
      var b = kids[i], it = byId(b.getAttribute('data-cid'));
      if (!it) continue;
      var p = positionOf(it);
      b.style.transform = 'translate(' + Math.round(p.x) + 'px,' + Math.round(p.y) + 'px)';
      b.style.display = p.vis ? '' : 'none';
    }
    if (pop && pop.kind === 'view') {
      var v = byId(pop.id);
      if (v) { var q = positionOf(v); placePop(q.x, q.y); }
    }
    drawBox(selBox, selPath);                             // the outline follows its element too
  }
  function renderPill() {
    pillHost.innerHTML =
      '<div class="cmt-pill' + (panelOpen ? ' shift' : '') + '">' +
        '<button class="cmt-t' + (mode ? ' cmt-live' : '') + '" title="Comment mode (C)">' +
          (mode ? 'Commenting' : 'Comment') + '</button>' +
        '<span class="cmt-n">' + data.items.length + '</span>' +
        '<button class="cmt-l" title="Comment list (Shift+C)">List</button>' +
      '</div>';
  }
  function renderPanel() {
    if (!panelOpen) { panelHost.innerHTML = ''; return; }
    var rows = shown().map(function (it) {
      return '<div class="cmt-row' + (it.resolved ? ' res' : '') + '" data-cid="' + it.id + '">' +
        '<span class="cmt-i">' + it.n + '</span>' +
        '<span class="cmt-bd"><span class="s">' + esc(it.label) + (it.resolved ? ' · resolved' : '') + '</span>' +
        '<div class="n">' + esc(it.note) + '</div>' +
        it.replies.map(function (r) { return '<div class="r">↳ ' + esc(r.text) + '</div>'; }).join('') +
        '</span></div>';
    }).join('');
    panelHost.innerHTML =
      '<div class="cmt-panel">' +
        '<div class="cmt-ph"><b>Comments</b><span class="cmt-n">' + data.items.length + '</span>' +
          '<span style="flex:1"></span><button class="cmt-b cmt-x">Close</button></div>' +
        '<div class="cmt-pb">' + (rows || '<div class="cmt-empty">No comments yet. Press C, then click anything on the page.</div>') + '</div>' +
        '<div class="cmt-pf">' +
          '<label><input type="checkbox" class="cmt-sr"' + (showResolved ? ' checked' : '') + '> Show resolved</label>' +
          '<button class="cmt-b pri cmt-md">Copy as Markdown</button>' +
          '<button class="cmt-b cmt-ex">Export JSON</button>' +
          '<button class="cmt-b cmt-im">Import JSON</button>' +
          '<div class="cmt-flash">' + esc(flash) + '</div>' +
        '</div>' +
      '</div>';
  }
  function placePop(x, y) {
    var el = popHost.firstElementChild;
    if (!el) return;
    var w = el.offsetWidth || 284, h = el.offsetHeight || 160;
    var left = x + 16, top = y + 12;
    if (left + w > innerWidth - 8) left = Math.max(8, x - w - 16);
    if (top + h > innerHeight - 8) top = Math.max(8, innerHeight - h - 8);
    el.style.left = Math.round(left) + 'px';
    el.style.top = Math.round(top) + 'px';
  }
  function renderPop() {
    if (!pop) { popHost.innerHTML = ''; replying = false; setSelection(null); return; }
    if (pop.kind === 'new') {
      var d = pop.draft;
      setSelection(d.sel);                                // hold the element the comment will land on
      popHost.innerHTML =
        '<div class="cmt-pop">' +
          '<div class="cmt-h"><b>New comment</b></div>' +
          '<div class="cmt-sn">' + esc(d.label) + '</div>' +
          '<textarea class="cmt-ta" placeholder="What is wrong here?"></textarea>' +
          '<div class="cmt-a"><span class="cmt-hint">Enter saves · Esc cancels</span>' +
            '<button class="cmt-b cmt-cancel">Cancel</button>' +
            '<button class="cmt-b pri cmt-save">Save</button></div>' +
        '</div>';
      placePop(pop.x, pop.y);
      var ta = popHost.querySelector('textarea');
      ta.focus();
    } else {
      var it = byId(pop.id);
      if (!it) { pop = null; popHost.innerHTML = ''; setSelection(null); return; }
      setSelection(it.sel);                               // re-highlight what this pin is attached to
      popHost.innerHTML =
        '<div class="cmt-pop">' +
          '<div class="cmt-h"><b>#' + it.n + '</b><span style="flex:1"></span>' +
            '<span class="cmt-ts">' + stamp(it.ts) + '</span></div>' +
          '<div class="cmt-sn">' + esc(it.label) + '</div>' +
          '<div class="cmt-note">' + esc(it.note) + '</div>' +
          it.replies.map(function (r) {
            return '<div class="cmt-rep">' + esc(r.text) + '<span class="cmt-ts">' + stamp(r.ts) + '</span></div>';
          }).join('') +
          (replying ? '<div style="padding-top:8px"><textarea class="cmt-ta" placeholder="Reply…"></textarea></div>' : '') +
          '<div class="cmt-a">' +
            (replying
              ? '<span class="cmt-hint">Enter sends</span><button class="cmt-b cmt-norep">Cancel</button>' +
                '<button class="cmt-b pri cmt-sendrep">Reply</button>'
              : '<button class="cmt-b cmt-reply">Reply</button>' +
                '<button class="cmt-b cmt-res">' + (it.resolved ? 'Unresolve' : 'Resolve') + '</button>' +
                '<button class="cmt-b warn cmt-del">Delete</button><span class="sp"></span>' +
                '<button class="cmt-b cmt-close">Close</button>') +
          '</div>' +
        '</div>';
      var p = positionOf(it);
      placePop(p.x, p.y);
      if (replying) popHost.querySelector('textarea').focus();
    }
  }
  function renderAll() { renderPins(); renderPill(); renderPanel(); renderPop(); }

  // ---------------------------------------------------------------- actions
  function setMode(on) {
    mode = !!on;
    document.documentElement.classList.toggle('cmt-on', mode);
    if (!mode) { hi.style.display = 'none'; if (pop && pop.kind === 'new') pop = null; }
    renderPill(); renderPop();
  }
  function togglePanel(on) {
    panelOpen = on == null ? !panelOpen : !!on;
    flash = '';
    renderPanel(); renderPill();
  }
  function pick(x, y) {
    var e = document.elementFromPoint(x, y);
    if (!e || root.contains(e) || e === document.documentElement) return null;
    return meaningful(e);                                 // outline, label and anchor agree
  }
  function draftAt(x, y) {
    var el = pick(x, y) || document.body;
    var r = el.getBoundingClientRect();
    return {
      note: '', ts: Date.now(),
      px: x + window.scrollX, py: y + window.scrollY,
      rx: r.width ? (x - r.left) / r.width : 0.5,
      ry: r.height ? (y - r.top) / r.height : 0.5,
      sel: cssPath(el), label: labelOf(el),
      resolved: false, replies: []
    };
  }
  function commit(draft, note) {
    note = (note || '').trim();
    if (!note) return null;                               // empty comment = cancel
    draft.note = note;
    draft.ts = Date.now();
    draft.id = 'c' + (++data.seq);
    draft.n = data.seq;
    data.items.push(draft);
    save();
    return draft;
  }
  function addReply(id, text) {
    var it = byId(id); text = (text || '').trim();
    if (!it || !text) return;
    it.replies.push({text: text, ts: Date.now()});
    save();
  }
  function toggleResolved(id) {
    var it = byId(id);
    if (!it) return;
    it.resolved = !it.resolved;
    save();
  }
  function del(id) {
    data.items = data.items.filter(function (i) { return i.id !== id; });
    save();
  }

  // ---------------------------------------------------------------- export
  function markdown() {
    var out = '## Comments — ' + document.title + ' (' + today() + ')\n\n';
    if (!data.items.length) return out + '_No comments._\n';
    data.items.forEach(function (it) {
      out += it.n + '. [' + it.label + '] ' + it.note + (it.resolved ? ' (resolved)' : '') + '\n';
      it.replies.forEach(function (r) { out += '   - ' + r.text + '\n'; });
    });
    return out;
  }
  function copyMarkdown() {
    var text = markdown();
    var done = function () { flash = 'Markdown copied to the clipboard.'; renderPanel(); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback);
    } else fallback();
    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.cssText = 'position:fixed;left:-9999px;top:0';
      document.body.appendChild(ta); ta.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
      flash = ok ? 'Markdown copied to the clipboard.' : 'Copy blocked — use Export JSON instead.';
      renderPanel();
    }
  }
  function baseName() {
    var p = location.pathname.split('/').pop() || 'prototype';
    return p.replace(/\.html?$/i, '');
  }
  function exportJSON() {
    var blob = new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'});
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'comments-' + baseName() + '-' + today() + '.json';
    document.body.appendChild(a); a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 0);
    flash = 'Exported ' + a.download;
    renderPanel();
  }
  function importJSON() {
    var inp = document.createElement('input');
    inp.type = 'file'; inp.accept = 'application/json,.json';
    inp.onchange = function () {
      var f = inp.files && inp.files[0];
      if (!f) return;
      var fr = new FileReader();
      fr.onload = function () {
        try {
          var d = JSON.parse(fr.result);
          if (!d || !Array.isArray(d.items)) throw new Error('shape');
          d.items.forEach(function (i) { if (!Array.isArray(i.replies)) i.replies = []; });
          var max = 0;
          d.items.forEach(function (i) { max = Math.max(max, i.n || 0); });
          data = {v: 1, seq: Math.max(d.seq || 0, max), items: d.items};
          save();
          flash = 'Imported ' + data.items.length + ' comments.';
          renderAll();
        } catch (e) {
          flash = 'That file is not a comment export.';
          renderPanel();
        }
      };
      fr.readAsText(f);
    };
    inp.click();
  }

  // ---------------------------------------------------------------- events
  function swallow(e) {
    if (root.contains(e.target)) return false;
    e.preventDefault(); e.stopPropagation();
    return true;
  }
  // Capture phase on document runs before the prototype's own document-level
  // handlers, so its drag/create machinery never sees these while commenting.
  ['mousedown', 'mouseup', 'dblclick', 'dragstart'].forEach(function (t) {
    document.addEventListener(t, function (e) { if (mode) swallow(e); }, true);
  });
  document.addEventListener('click', function (e) {
    if (!mode || root.contains(e.target)) return;
    e.preventDefault(); e.stopPropagation();
    pop = {kind: 'new', draft: draftAt(e.clientX, e.clientY), x: e.clientX, y: e.clientY};
    replying = false;
    renderPop();
  }, true);
  document.addEventListener('mousemove', function (e) {
    // once something is selected, the hover outline stops chasing other elements
    if (!mode || pop) { if (pop) hi.style.display = 'none'; return; }
    var el = pick(e.clientX, e.clientY);
    if (!el) { hi.style.display = 'none'; return; }
    var r = el.getBoundingClientRect();
    hi.style.display = 'block';                           // not '' - the stylesheet says none
    hi.style.left = r.left + 'px'; hi.style.top = r.top + 'px';
    hi.style.width = r.width + 'px'; hi.style.height = r.height + 'px';
  }, true);

  root.addEventListener('mousedown', function (e) { e.stopPropagation(); });
  // hovering a row in the list flashes the element that row is attached to
  panelHost.addEventListener('mouseover', function (e) {
    var row = e.target.closest && e.target.closest('.cmt-row');
    if (!row) return;
    var it = byId(row.getAttribute('data-cid'));
    if (it) drawBox(hi, it.sel);
  });
  panelHost.addEventListener('mouseout', function (e) {
    if (e.target.closest && e.target.closest('.cmt-row')) hi.style.display = 'none';
  });
  // with comment mode off, clicking anywhere outside closes the popover and drops the outline
  document.addEventListener('click', function (e) {
    if (mode || !pop || root.contains(e.target)) return;
    pop = null; replying = false; renderPop();
  });
  root.addEventListener('click', function (e) {
    e.stopPropagation();
    var t = e.target;
    var pin = t.closest('.cmt-pin');
    if (pin) { pop = {kind: 'view', id: pin.getAttribute('data-cid')}; replying = false; renderPop(); return; }
    if (t.closest('.cmt-t')) { setMode(!mode); return; }
    if (t.closest('.cmt-l')) { togglePanel(); return; }
    if (t.closest('.cmt-x')) { togglePanel(false); return; }
    if (t.closest('.cmt-save')) { saveDraft(); return; }
    if (t.closest('.cmt-cancel') || t.closest('.cmt-close')) { pop = null; renderPop(); return; }
    if (t.closest('.cmt-reply')) { replying = true; renderPop(); return; }
    if (t.closest('.cmt-norep')) { replying = false; renderPop(); return; }
    if (t.closest('.cmt-sendrep')) { sendReply(); return; }
    if (t.closest('.cmt-res')) { toggleResolved(pop.id); renderAll(); return; }
    if (t.closest('.cmt-del')) { del(pop.id); pop = null; renderAll(); return; }
    if (t.closest('.cmt-md')) { copyMarkdown(); return; }
    if (t.closest('.cmt-ex')) { exportJSON(); return; }
    if (t.closest('.cmt-im')) { importJSON(); return; }
    if (t.closest('.cmt-sr')) { showResolved = t.checked; renderPins(); renderPanel(); return; }
    var row = t.closest('.cmt-row');
    if (row) {
      var it = byId(row.getAttribute('data-cid'));
      if (it) {
        var e2 = resolveEl(it);
        if (e2 && e2.scrollIntoView) e2.scrollIntoView({block: 'center', inline: 'nearest'});
        pop = {kind: 'view', id: it.id}; replying = false;
        setTimeout(function () { reposition(); renderPop(); }, 0);
      }
    }
  });
  function saveDraft() {
    var ta = popHost.querySelector('textarea');
    if (!ta || !pop || pop.kind !== 'new') return;
    var made = commit(pop.draft, ta.value);
    pop = made ? {kind: 'view', id: made.id} : null;
    renderAll();
  }
  function sendReply() {
    var ta = popHost.querySelector('textarea');
    if (!ta || !pop) return;
    addReply(pop.id, ta.value);
    replying = false;
    renderAll();
  }
  // Enter saves, Shift+Enter is a newline, Cmd/Ctrl+Enter always saves.
  root.addEventListener('keydown', function (e) {
    if (e.target.tagName !== 'TEXTAREA') return;
    if (e.key !== 'Enter') return;
    if (e.shiftKey && !(e.metaKey || e.ctrlKey)) return;
    e.preventDefault();
    if (pop && pop.kind === 'new') saveDraft(); else sendReply();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      if (pop) { pop = null; replying = false; renderPop(); e.preventDefault(); e.stopPropagation(); return; }
      if (mode) { setMode(false); e.preventDefault(); e.stopPropagation(); }
      return;
    }
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT' || t.isContentEditable)) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key === 'C') { togglePanel(); e.preventDefault(); }
    else if (e.key === 'c') { setMode(!mode); e.preventDefault(); }
  }, true);

  // keep pins glued to their elements through scrolling, resizing and re-renders
  var queued = false;
  function schedule() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(function () { queued = false; reposition(); });
  }
  addEventListener('scroll', schedule, true);
  addEventListener('resize', schedule);
  new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) if (!root.contains(muts[i].target)) { schedule(); return; }
  }).observe(document.body, {childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class']});

  renderAll();

  // ---------------------------------------------------------------- API
  window.ProtoComments = {
    get data() { return data; },
    markdown: markdown,
    setMode: setMode,
    togglePanel: togglePanel,
    // place a comment on an element, used by the self-test and by tooling
    addOn: function (sel, note, rx, ry) {
      var el = document.querySelector(sel);
      if (!el) return null;
      var r = el.getBoundingClientRect();
      rx = rx == null ? 0.5 : rx; ry = ry == null ? 0.5 : ry;
      var x = r.left + rx * r.width, y = r.top + ry * r.height;
      var draft = draftAt(x, y);
      draft.sel = cssPath(el); draft.label = labelOf(el); draft.rx = rx; draft.ry = ry;
      var made = commit(draft, note);
      renderAll();
      return made;
    },
    reply: function (n, text) {
      var it = data.items.filter(function (i) { return i.n === n; })[0];
      if (it) { addReply(it.id, text); renderAll(); }
    },
    resolve: function (n) {
      var it = data.items.filter(function (i) { return i.n === n; })[0];
      if (it) { toggleResolved(it.id); renderAll(); }
    },
    clear: function () { data = {v: 1, seq: 0, items: []}; save(); pop = null; renderAll(); }
  };

  // ---------------------------------------------------------------- self-test
  // ?selftest seeds two pins in memory (never written to localStorage), prints
  // the Markdown export to the console, and mirrors it into #cmt-selftest so a
  // headless --dump-dom run can read it.
  if (TEST) setTimeout(function () {
    var log = [];
    var pick2 = function (list) {
      for (var i = 0; i < list.length; i++) if (document.querySelector(list[i])) return list[i];
      return 'body';
    };
    var s1 = pick2(['.blk[data-id="t2"]', '.blk', '.card', 'main']);
    var s2 = pick2(['.sugrow', '.railrow', '.pod', 'aside']);
    var a = window.ProtoComments.addOn(s1, 'This block reads as a bar, not an event — it runs the full width.', 0.32, 0.5);
    var b = window.ProtoComments.addOn(s2, 'A suggestion needs its category in words, the colour dot alone is not enough.', 0.5, 0.5);
    window.ProtoComments.reply(b.n, 'Or show the category name on hover.');

    log.push('pins=' + data.items.length);
    log.push('anchored=' + data.items.filter(function (i) { return positionOf(i).anchored; }).length + '/' + data.items.length);
    log.push('labels=' + data.items.map(function (i) { return '"' + i.label + '"'; }).join(' | '));
    log.push('selectors=' + data.items.map(function (i) { return i.sel; }).join(' | '));
    log.push('persisted=' + (localStorage.getItem(KEY) === null ? 'no (self-test is in-memory)' : 'YES - BUG'));

    // prove the (resolved) marker without leaving the pin resolved
    window.ProtoComments.resolve(a.n);
    var resolvedLine = markdown().split('\n').filter(function (l) { return /\(resolved\)/.test(l); })[0] || '(none)';
    window.ProtoComments.resolve(a.n);

    var report = '[proto-comments selftest] ' + log.join('  ') +
                 '\nresolved-line: ' + resolvedLine + '\n\n' + markdown();
    console.log(report);
    var pre = document.createElement('pre');
    pre.id = 'cmt-selftest';
    pre.style.cssText = 'position:fixed;left:-9999px;top:0';
    pre.textContent = report;
    document.body.appendChild(pre);

    // leave pin 1 open so the demo shows the selection outline + popover
    pop = {kind: 'view', id: a.id};
    replying = false;
    renderPop();
  }, 60);
})();
