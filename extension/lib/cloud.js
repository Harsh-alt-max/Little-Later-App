// Reads and writes the same Firestore documents as the phone app:
//   /users/{email}          { email, name, backupPayload (JSON string), lastSeenAt }
//   /collab_folders/{cf_…}  { version, payload (JSON string) }
import { PROJECT } from './config.js';
import { token } from './auth.js';

const DOCS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const DEFAULT_FOLDERS = [
  { name: 'Work', kind: 'work', icon: 'folder', collab: false },
  { name: 'Love', kind: 'love', icon: 'folder', collab: false },
  { name: 'Hobby', kind: 'hobby', icon: 'folder', collab: false },
];

export class CloudError extends Error {}

const enc = (v) => (typeof v === 'number' ? { integerValue: String(Math.round(v)) } : { stringValue: String(v) });
const dec = (f) => (f == null ? undefined : f.stringValue ?? (f.integerValue != null ? Number(f.integerValue) : f.doubleValue ?? f.booleanValue));

async function call(path, { method = 'GET', body, query = '' } = {}) {
  const s = await token();
  if (!s) throw new CloudError('Signed out');
  let r;
  try {
    r = await fetch(`${DOCS}/${path}${query}`, {
      method,
      headers: { Authorization: `Bearer ${s.idToken}`, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new CloudError('No internet connection.');
  }
  if (r.status === 404) return null;
  const j = await r.json().catch(() => ({}));
  if (!r.ok) {
    const e = new CloudError(r.status === 403 ? 'Little Later can’t reach your account. Sign out and in again.' : 'Couldn’t save. Try again.');
    e.status = j?.error?.status || r.status;
    throw e;
  }
  return j;
}

async function getDoc(path) {
  const j = await call(path);
  if (!j) return null;
  const data = {};
  for (const [k, v] of Object.entries(j.fields || {})) data[k] = dec(v);
  return { data, updateTime: j.updateTime };
}

async function writeDoc(path, fields, updateTime) {
  const q = new URLSearchParams();
  for (const k of Object.keys(fields)) q.append('updateMask.fieldPaths', k);
  if (updateTime) q.append('currentDocument.updateTime', updateTime);
  else q.append('currentDocument.exists', 'false');
  const body = { fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, enc(v)])) };
  return call(path, { method: 'PATCH', body, query: `?${q}` });
}

/// Read → change → write, retried if the phone wrote at the same moment.
async function update(path, change) {
  for (let i = 0; i < 4; i++) {
    const doc = await getDoc(path);
    const fields = change(doc?.data || null);
    if (!fields) return;
    try {
      await writeDoc(path, fields, doc?.updateTime);
      return;
    } catch (e) {
      if (e.status !== 'FAILED_PRECONDITION' && e.status !== 'ALREADY_EXISTS' && e.status !== 409) throw e;
    }
  }
  throw new CloudError('Busy right now. Try again.');
}

const userPath = (email) => `users/${encodeURIComponent(email.toLowerCase())}`;
const parse = (s) => {
  try {
    return s ? JSON.parse(s) : {};
  } catch {
    return {};
  }
};

/// Folders and recent saves from your account.
export async function load() {
  const s = await token();
  const doc = await getDoc(userPath(s.email));
  const p = parse(doc?.data?.backupPayload);
  const folders = Array.isArray(p.folders) && p.folders.length ? p.folders : DEFAULT_FOLDERS;
  const deleted = new Set((p.deletedIds || []).map(String));
  const items = (p.items || []).filter((i) => !deleted.has(String(i.id)) && !i.msg);
  const name = doc?.data?.name || s.name || s.email.split('@')[0];
  return { folders, items, name, email: s.email };
}

/// Links in a shared folder, straight from the folder everyone shares.
export async function loadShared(folder) {
  const cid = folder?.collabId;
  if (!cid || !/^cf_[a-z0-9_]+$/.test(cid)) return [];
  const doc = await getDoc(`collab_folders/${cid}`);
  const p = parse(doc?.data?.payload);
  const deleted = new Set((p.deletedIds || []).map(String));
  return (p.items || []).filter((i) => i.url && !i.msg && !deleted.has(String(i.id)));
}

export const newId = () => `${Date.now()}${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`;

/// Save a link. [folder] is a folder object from load(). [reminder] is epoch ms or 0.
export async function saveLink({ url, title, thumbnail = '', note = '', folder, reminder = 0 }) {
  const s = await token();
  const now = Date.now();
  const item = {
    id: newId(),
    kind: 'link',
    title: title || url,
    folder: folder?.name || '',
    url,
    note,
    thumbnail: thumbnail && !thumbnail.startsWith('data:') ? thumbnail : '',
    reminder,
    dueAt: 0,
    tasks: [],
    savedAt: now,
    updatedAt: now,
    completedAt: 0,
    senderEmail: s.email,
    senderName: s.name || '',
    via: 'chrome',
  };

  await update(userPath(s.email), (data) => {
    const p = parse(data?.backupPayload);
    p.items = Array.isArray(p.items) ? p.items : [];
    p.folders = Array.isArray(p.folders) && p.folders.length ? p.folders : DEFAULT_FOLDERS;
    p.deletedIds = Array.isArray(p.deletedIds) ? p.deletedIds : [];
    if (folder && !p.folders.some((f) => String(f.name).toLowerCase() === folder.name.toLowerCase())) p.folders.push(folder);
    p.items.unshift(item);
    const body = JSON.stringify(p);
    if (body.length > 880000) throw new CloudError('Your account is full. Delete some old saves in the app.');
    const fields = { email: s.email, backupPayload: body, lastSeenAt: now };
    if (!data) fields.name = s.name || s.email.split('@')[0];
    return fields;
  });

  // Shared folder: friends get it too.
  const cid = folder?.collab && folder.collabId;
  if (cid && /^cf_[a-z0-9_]+$/.test(cid)) {
    await update(`collab_folders/${cid}`, (data) => {
      const p = parse(data?.payload);
      if (p.folder?.closed) return null; // folder moved; the app sorts it out
      p.folder = p.folder || { name: folder.name, kind: 'folder', icon: folder.icon || 'folder', collab: true, collabId: cid, ownerEmail: folder.ownerEmail || s.email, ownerName: folder.ownerName || '', collaborators: folder.collaborators || [] };
      p.items = Array.isArray(p.items) ? p.items : [];
      p.deletedIds = Array.isArray(p.deletedIds) ? p.deletedIds : [];
      p.items.push({ ...item, folder: p.folder.name || folder.name });
      p.updatedAt = now;
      const payload = JSON.stringify(p);
      if (payload.length > 880000) return null;
      return { version: now, payload };
    });
  }
  return item;
}
