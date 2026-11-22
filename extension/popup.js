import { signInWithEmail, session, signOut } from './lib/auth.js';
import { load, saveLink, loadShared } from './lib/cloud.js';
import { describeTab } from './lib/page.js';
import { SITE } from './lib/config.js';

const $ = (id) => document.getElementById(id);
const views = ['v-load', 'v-signin', 'v-save', 'v-done'];
function show(v) {
  for (const id of views) $(id).hidden = id !== v;
}

// ---------------------------------------------------------------- time helpers
const pad = (n) => String(n).padStart(2, '0');
const fmtT = (d) => d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).replace(/\s?([AP]M)/i, (_, m) => ` ${m.toLowerCase()}`);
function soon() {
  // About an hour from now on a 5-minute step, never past today.
  const n = new Date();
  const d = new Date(n.getTime() + 3600e3);
  d.setMinutes(Math.ceil(d.getMinutes() / 5) * 5, 0, 0);
  if (d.getDate() !== n.getDate()) return new Date(n.getFullYear(), n.getMonth(), n.getDate(), 23, 55);
  return d;
}
const dayStr = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const timeStr = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
function dayLabel(d) {
  const t = new Date();
  const a = new Date(t.getFullYear(), t.getMonth(), t.getDate());
  const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - a) / 864e5);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Tomorrow';
  return d.toLocaleDateString([], { weekday: 'short', day: 'numeric', month: 'short' });
}

// ---------------------------------------------------------------- state
const state = { page: null, folders: [], folder: null, when: 'none', at: null, items: [], libFolder: null };

// Same colours as the phone app: picked in the app, or a stable one from the name.
const PALETTE = ['#FF9F7E', '#F5C451', '#7ED492', '#5FC8E8', '#7E8CFF', '#C58BFF', '#FF7FB0', '#B9B4AA'];
function folderColor(f) {
  if (typeof f.color === 'number') return `#${(f.color & 0xffffff).toString(16).padStart(6, '0')}`;
  let h = 0;
  for (const c of String(f.name).toLowerCase()) h = (h * 31 + c.charCodeAt(0)) & 0x7fffffff;
  return PALETTE[h % PALETTE.length];
}
function folderChip(f, on) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = `chip${on ? ' on' : ''}`;
  if (f) {
    const d = document.createElement('span');
    d.className = 'dot';
    d.style.background = folderColor(f);
    b.append(d);
    if (f.collab) b.insertAdjacentHTML('beforeend', USERS_ICON);
  }
  b.append(document.createTextNode(f ? f.name : 'All'));
  if (f) b.title = f.collab ? 'Shared folder: friends get it too' : f.name;
  return b;
}

const USERS_ICON = '<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0"/><path d="M15.5 5.6a3.2 3.2 0 0 1 0 5.8M17.5 14.2A5.5 5.5 0 0 1 20.5 19"/></svg>';

function renderFolders() {
  const box = $('folders');
  box.innerHTML = '';
  for (const f of state.folders) {
    const b = folderChip(f, state.folder === f);
    b.onclick = () => {
      state.folder = state.folder === f ? null : f;
      renderFolders();
    };
    box.append(b);
  }
}

function renderWhen() {
  for (const b of $('when').querySelectorAll('button')) b.classList.toggle('on', b.dataset.w === state.when);
  $('w-today').textContent = state.when === 'today' && state.at ? fmtT(state.at) : fmtT(soon());
  $('w-date').textContent = state.when === 'date' && state.at ? `${dayLabel(state.at)}, ${fmtT(state.at)}` : 'Any day';
  const edit = state.when !== 'none';
  $('when-edit').hidden = !edit;
  $('w-day').hidden = state.when !== 'date';
  if (edit && state.at) {
    $('w-day').value = dayStr(state.at);
    $('w-time').value = timeStr(state.at);
  }
  const t = $('when').querySelector('[data-w=tomorrow] small');
  t.textContent = state.when === 'tomorrow' && state.at ? fmtT(state.at) : '9:00 am';
}

function pickWhen(w) {
  state.when = w;
  const n = new Date();
  if (w === 'today') state.at = soon();
  else if (w === 'tomorrow') state.at = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1, 9, 0);
  else if (w === 'date') state.at = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 2, 9, 0);
  else state.at = null;
  renderWhen();
}

function editWhen() {
  const t = $('w-time').value;
  if (!t || !state.at) return;
  const [h, m] = t.split(':').map(Number);
  let d = state.at;
  if (state.when === 'date' && $('w-day').value) {
    const [y, mo, da] = $('w-day').value.split('-').map(Number);
    d = new Date(y, mo - 1, da);
  }
  state.at = new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m);
  renderWhen();
}

function renderRecent(items) {
  const list = items.filter((i) => i.url).slice(0, 3);
  $('recent-wrap').hidden = !list.length;
  const ul = $('recent');
  ul.innerHTML = '';
  for (const it of list) ul.append(linkRow(it, true));
}

// ---------------------------------------------------------------- my links
const host = (u) => {
  try {
    return new URL(u).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
};

function linkRow(it, showFolder) {
  const li = document.createElement('li');
  const th = document.createElement('span');
  th.className = 'th';
  if (it.thumbnail) th.style.backgroundImage = `url("${String(it.thumbnail).replace(/"/g, '%22')}")`;
  else th.textContent = (host(it.url)[0] || '•').toUpperCase();
  const t = document.createElement('div');
  t.className = 't';
  const b = document.createElement('b');
  b.textContent = it.title || it.url;
  const sm = document.createElement('small');
  const who = it.senderName || (it.senderEmail ? String(it.senderEmail).split('@')[0] : '');
  sm.textContent = [showFolder ? it.folder : '', who && state.libFolder?.collab ? who : '', host(it.url)].filter(Boolean).join(' · ');
  t.append(b, sm);
  li.append(th, t);
  li.title = it.url;
  li.onclick = () => chrome.tabs.create({ url: it.url });
  return li;
}

let libGen = 0;
async function renderLib() {
  const gen = ++libGen;
  const box = $('lib-folders');
  box.innerHTML = '';
  const chip = (f) => {
    const b = folderChip(f, state.libFolder === f);
    b.onclick = () => {
      state.libFolder = f;
      renderLib();
    };
    box.append(b);
  };
  chip(null);
  for (const f of state.folders) chip(f);

  const f = state.libFolder;
  const ul = $('lib');
  $('lib-note').textContent = f?.collab ? 'Shared folder: everyone in it sees these links.' : '';
  let list;
  if (f?.collab) {
    ul.innerHTML = '<li class="loading"><div class="dots"><i></i><i></i><i></i></div></li>';
    try {
      list = await loadShared(f);
    } catch {
      list = state.items.filter((i) => String(i.folder).toLowerCase() === f.name.toLowerCase());
    }
    if (gen !== libGen) return;
  } else {
    list = state.items.filter((i) => i.url && (!f || String(i.folder).toLowerCase() === f.name.toLowerCase()));
  }
  list = list.filter((i) => i.url && !i.completedAt).sort((a, b) => (b.savedAt || 0) - (a.savedAt || 0));
  ul.innerHTML = '';
  for (const it of list.slice(0, 100)) ul.append(linkRow(it, !f));
  $('lib-empty').hidden = list.length > 0;
}

function setTab(saved) {
  $('tab-save').classList.toggle('on', !saved);
  $('tab-saved').classList.toggle('on', saved);
  $('pane-save').hidden = saved;
  $('pane-saved').hidden = !saved;
  if (saved) renderLib();
}

// ---------------------------------------------------------------- screens
async function openSave(s) {
  $('me-name').textContent = s.name || s.email.split('@')[0];
  $('me-email').textContent = s.email;
  $('avatar').textContent = (s.name || s.email)[0].toUpperCase();

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  state.page = tab ? await describeTab(tab) : { url: '', title: '', image: '', savable: false };
  $('title').value = state.page.title;
  const h = host(state.page.url);
  $('domain').textContent = h;
  $('cover-letter').textContent = (h[0] || '•').toUpperCase();
  if (state.page.image) {
    const img = $('cover-img');
    img.onload = () => (img.hidden = false);
    img.onerror = () => (img.hidden = true);
    img.src = state.page.image;
  }
  $('unsavable').hidden = state.page.savable;
  $('save').disabled = !state.page.savable;

  const { lastFolder, cache } = await chrome.storage.local.get(['lastFolder', 'cache']);
  const apply = (data) => {
    state.folders = data.folders;
    const keep = state.folder?.name ?? lastFolder;
    state.folder = data.folders.find((f) => String(f.name).toLowerCase() === String(keep || '').toLowerCase()) || null;
    state.items = data.items;
    renderFolders();
    renderRecent(data.items);
    if (!$('pane-saved').hidden) renderLib();
    if (data.name) $('me-name').textContent = data.name;
  };
  if (cache?.email === s.email) apply(cache); // instant, then refresh
  pickWhen('none');
  show('v-save');
  try {
    const data = await load();
    apply(data);
    await chrome.storage.local.set({ cache: { ...data, items: data.items.slice(0, 5) } });
  } catch (e) {
    if (!cache) {
      state.folders = [];
      renderFolders();
    }
    if (/sign in again|Sign out/.test(e.message)) $('save-err').textContent = e.message;
  }
}

async function doSave() {
  const btn = $('save');
  $('save-err').textContent = '';
  btn.disabled = true;
  btn.innerHTML = '<span class="spin"></span>Saving…';
  try {
    const title = $('title').value.replace(/\s+/g, ' ').trim();
    await saveLink({
      url: state.page.url,
      title: title || state.page.title,
      thumbnail: state.page.image,
      note: $('note').value.trim(),
      folder: state.folder,
      reminder: state.at ? state.at.getTime() : 0,
    });
    await chrome.storage.local.set({ lastFolder: state.folder?.name || '' });
    const where = state.folder ? `It’s in ${state.folder.name}` : 'It’s in Saved';
    $('done-title').textContent = 'Saved!';
    const lab = state.at ? dayLabel(state.at) : '';
    const day = lab === 'Today' ? 'today' : lab === 'Tomorrow' ? 'tomorrow' : `on ${lab}`;
    $('done-sub').textContent = state.at ? `${where}. I’ll remind you ${day} at ${fmtT(state.at)}.` : `${where}. It’s on your phone too.`;
    show('v-done');
    setTimeout(() => window.close(), 1600);
  } catch (e) {
    $('save-err').textContent = e.message || 'Couldn’t save. Try again.';
    btn.disabled = false;
    btn.textContent = 'Save for later';
  }
}

async function start() {
  const s = await session();
  if (!s) {
    show('v-signin');
    setTimeout(() => $('email').focus(), 50);
    return;
  }
  await openSave(s);
}

// ---------------------------------------------------------------- events
$('login').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('login-err').textContent = '';
  const btn = $('login-btn');
  btn.disabled = true;
  btn.innerHTML = '<span class="spin"></span>Signing in…';
  try {
    const s = await signInWithEmail($('email').value, $('password').value);
    $('password').value = '';
    if (new URLSearchParams(location.search).get('signin')) {
      show('v-done');
      $('done-title').textContent = 'You’re in!';
      $('done-sub').textContent = 'Right-click any page or link to save it.';
      return;
    }
    await openSave(s);
  } catch (err) {
    $('login-err').textContent = err.message;
  } finally {
    btn.disabled = false;
    btn.textContent = 'Sign in';
  }
});
$('google').onclick = () => chrome.tabs.create({ url: `${SITE}/auth.html?ext=${chrome.runtime.id}` });
$('get-app').onclick = (e) => {
  e.preventDefault();
  chrome.tabs.create({ url: SITE });
};
$('menu').onclick = (e) => {
  e.stopPropagation();
  $('menu-pop').hidden = !$('menu-pop').hidden;
};
document.addEventListener('click', () => ($('menu-pop').hidden = true));
$('open-app').onclick = () => chrome.tabs.create({ url: SITE });
$('signout').onclick = async () => {
  await signOut();
  show('v-signin');
};
for (const b of $('when').querySelectorAll('button')) b.onclick = () => pickWhen(b.dataset.w);
$('w-time').addEventListener('change', editWhen);
$('w-day').addEventListener('change', editWhen);
$('add-note').onclick = () => {
  $('add-note').hidden = true;
  $('note').hidden = false;
  $('note').focus();
};
$('save').onclick = doSave;
$('tab-save').onclick = () => setTab(false);
$('tab-saved').onclick = () => setTab(true);
$('add-remind').onclick = () => {
  $('add-remind').hidden = true;
  $('remind-box').hidden = false;
};
$('title').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    doSave();
  }
});
chrome.storage.onChanged.addListener((c) => {
  // Google sign-in finished on the website while this window was open.
  if (c.session?.newValue && !c.session.oldValue) start();
});

// Min/max for the date picker: today … 3 months.
{
  const n = new Date();
  $('w-day').min = dayStr(n);
  $('w-day').max = dayStr(new Date(n.getFullYear(), n.getMonth() + 3, n.getDate()));
}
start();
