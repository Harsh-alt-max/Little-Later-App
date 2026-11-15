// Title, cover image and URL of a tab.
export function youtubeId(url) {
  try {
    const u = new URL(url);
    if (u.hostname.includes('youtu.be')) return u.pathname.slice(1).split('/')[0] || null;
    if (!u.hostname.includes('youtube')) return null;
    if (u.searchParams.get('v')) return u.searchParams.get('v');
    const m = u.pathname.match(/\/(shorts|embed|live)\/([^/?]+)/);
    return m ? m[2] : null;
  } catch {
    return null;
  }
}

/// Runs inside the page (via chrome.scripting).
function readPage() {
  const meta = (p) => document.querySelector(`meta[property="${p}"],meta[name="${p}"]`)?.content || '';
  const abs = (u) => {
    try {
      return u ? new URL(u, location.href).href : '';
    } catch {
      return '';
    }
  };
  return {
    title: meta('og:title') || document.title || '',
    image: abs(meta('og:image') || meta('og:image:url') || meta('twitter:image') || meta('twitter:image:src')),
    canonical: abs(document.querySelector('link[rel=canonical]')?.href || ''),
  };
}

export function cleanTitle(t, url) {
  let s = String(t || '').replace(/\s+/g, ' ').trim();
  s = s.replace(/\s+[-|–·]\s+(YouTube|Instagram|Facebook|X|Twitter|TikTok|Reddit|Medium|Pinterest)$/i, '');
  s = s.replace(/^\(\d+\)\s+/, ''); // "(3) Video title" notification counts
  if (!s) {
    try {
      s = new URL(url).hostname.replace(/^www\./, '');
    } catch {
      s = url;
    }
  }
  return s.length > 90 ? `${s.slice(0, 89)}…` : s;
}

export async function describeTab(tab) {
  const url = tab.url || '';
  let info = { title: tab.title || '', image: '' };
  if (/^https?:/.test(url)) {
    try {
      const [r] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: readPage });
      if (r?.result) info = r.result;
    } catch {
      /* chrome:// pages, the web store etc. can't be read */
    }
  }
  const yt = youtubeId(url);
  // YouTube changes pages without reloading, so its meta tags can be stale: use the tab.
  const title = yt ? tab.title : info.title || tab.title;
  return {
    url,
    title: cleanTitle(title, url),
    image: yt ? `https://i.ytimg.com/vi/${yt}/hqdefault.jpg` : info.image,
    savable: /^https?:/.test(url),
  };
}
