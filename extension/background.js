// Right-click "Save to Little Later", and the Google sign-in hand-off from the website.
import { signInWithRefreshToken, session } from './lib/auth.js';
import { saveLink, load } from './lib/cloud.js';
import { describeTab, cleanTitle, youtubeId } from './lib/page.js';
import { SITE } from './lib/config.js';

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({ id: 'll-page', title: 'Save page to Little Later', contexts: ['page', 'frame', 'selection', 'image', 'video'] });
    chrome.contextMenus.create({ id: 'll-link', title: 'Save link to Little Later', contexts: ['link'] });
  });
});

function badge(text, color) {
  chrome.action.setBadgeBackgroundColor({ color });
  chrome.action.setBadgeText({ text });
  setTimeout(() => chrome.action.setBadgeText({ text: '' }), 2500);
}

async function lastFolder() {
  const { lastFolder: name } = await chrome.storage.local.get('lastFolder');
  if (!name) return null;
  try {
    const { folders } = await load();
    return folders.find((f) => String(f.name).toLowerCase() === String(name).toLowerCase()) || null;
  } catch {
    return null;
  }
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!(await session())) {
    chrome.tabs.create({ url: chrome.runtime.getURL('popup.html?signin=1') });
    return;
  }
  try {
    let link;
    if (info.menuItemId === 'll-link' && info.linkUrl) {
      const yt = youtubeId(info.linkUrl);
      link = { url: info.linkUrl, title: cleanTitle(info.selectionText || '', info.linkUrl), image: yt ? `https://i.ytimg.com/vi/${yt}/hqdefault.jpg` : '' };
      if (!info.selectionText) link.title = info.linkUrl; // the phone fills in the real title
    } else {
      link = await describeTab(tab);
      if (!link.savable) throw new Error('page');
    }
    await saveLink({ url: link.url, title: link.title, thumbnail: link.image, folder: await lastFolder() });
    badge('✓', '#3D7BFF');
  } catch {
    badge('!', '#E5484D');
  }
});

// The website signs you in with Google, then passes the session here.
chrome.runtime.onMessageExternal.addListener((msg, sender, reply) => {
  if (!sender.url || !sender.url.startsWith(SITE)) return false;
  if (msg?.type === 'll-auth' && msg.refreshToken) {
    signInWithRefreshToken(msg.refreshToken)
      .then((s) => reply({ ok: true, email: s.email }))
      .catch((e) => reply({ ok: false, error: e.message }));
    return true;
  }
  if (msg?.type === 'll-ping') {
    reply({ ok: true, version: chrome.runtime.getManifest().version });
    return false;
  }
  return false;
});
