globalThis.manifest = {
  id: "masstamilan",
  name: "MassTamilan",
  version: "1.0.0",
  description: "Scrapes High-Quality 320kbps Tamil music from MassTamilan",
  icon: "https://www.masstamilan.dev/favicon.ico"
};

const baseUrl = 'https://www.masstamilan.dev';

globalThis.search = async function(query) {
  try {
    const rawQuery = query.trim();
    if (!rawQuery) return [];

    console.log('[JS Plugin MassTamilan] Searching for: ' + rawQuery);

    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    // 1. Direct URL handling
    if (rawQuery.startsWith('http') && rawQuery.indexOf('masstamilan') !== -1) {
      console.log('[JS Plugin MassTamilan] Direct Album Link detected');
      return await scrapeAlbum(rawQuery, '', headers);
    }

    // 2. Normal keyword search
    let cleanQuery = rawQuery.replace(/[&()"[\]]/g, ' ').replace(/\s+/g, ' ').trim();
    if (!cleanQuery) return [];

    const words = cleanQuery.split(' ');
    let searchKeyword = cleanQuery;
    if (words.length > 6) {
      searchKeyword = words.slice(0, 6).join(' ');
    }

    const searchUrl = baseUrl + '/search?keyword=' + encodeURIComponent(searchKeyword);
    const response = await globalThis.fetch(searchUrl, { headers: headers });
    if (!response.ok) {
      console.log('[JS Plugin MassTamilan] Search fetch failed: ' + response.status);
      return [];
    }

    const html = await response.text();

    const albumLinks = [];
    const albumRegex = /<a\s+[^>]*href="([^"]+-songs[^"]*)"[^>]*>([\s\S]*?)<\/a>/gi;
    let match;
    const seenUrls = new Set();

    while ((match = albumRegex.exec(html)) !== null) {
      let url = match[1];
      if (!url.startsWith('http')) {
        url = baseUrl + url;
      }
      if (!seenUrls.has(url)) {
        seenUrls.add(url);
        
        let title = 'Unknown Album';
        const titleAttrMatch = match[0].match(/title="([^"]+)"/i);
        if (titleAttrMatch) {
          title = titleAttrMatch[1].replace(' tamil songs download', '');
        } else {
          title = match[2].replace(/<[^>]*>/g, '').trim();
        }
        
        albumLinks.push({ url: url, title: title });
      }
    }

    console.log('[JS Plugin MassTamilan] Found ' + albumLinks.length + ' albums');
    const targetAlbums = albumLinks.slice(0, 3);
    const out = [];

    for (const album of targetAlbums) {
      try {
        const songs = await scrapeAlbum(album.url, cleanQuery, headers);
        out.push(...songs);
      } catch (e) {
        console.error('[JS Plugin MassTamilan] Album scrape error: ' + e);
      }
    }

    return out;
  } catch (e) {
    console.error('[JS Plugin MassTamilan] Error: ' + e);
    return [];
  }
};

async function scrapeAlbum(albumUrl, cleanQuery, headers) {
  console.log('[JS Plugin MassTamilan] Scraping album: ' + albumUrl);
  const response = await globalThis.fetch(albumUrl, { headers: headers });
  if (!response.ok) return [];

  const html = await response.text();

  // Parse album title
  const h1Match = html.match(/<h1 class="page-title">([\s\S]*?)<\/h1>/i) || html.match(/<h1>([\s\S]*?)<\/h1>/i);
  let albumTitle = h1Match ? h1Match[1].replace(/<[^>]*>/g, '').trim() : 'Unknown Album';
  albumTitle = albumTitle.replace(' Tamil Songs', '').replace(' Songs Download', '');

  // Parse thumbnail (using updated figure.ib or alt="*poster" checks)
  const imgMatch = html.match(/<figure class="ib">[\s\S]*?<img[^>]+src="([^"]+)"/i) || 
                   html.match(/<img[^>]+src="([^"]+)"[^>]+alt="[^"]*poster/i) || 
                   html.match(/<div class="info-wrapper">[\s\S]*?<img[^>]+src="([^"]+)"/i) || 
                   html.match(/<img[^>]+src="([^"]+)"[^>]*class="[^"]*img-responsive[^"]*"/i);
  let thumbnail = imgMatch ? imgMatch[1] : null;
  if (thumbnail && !thumbnail.startsWith('http')) {
    thumbnail = baseUrl + thumbnail;
  }

  const rows = html.split(/<tr[^>]*itemprop="itemListElement"[^>]*>/i);
  rows.shift();

  const results = [];
  const queryWords = cleanQuery.toLowerCase().split(' ').filter(w => w.length > 2);

  for (const rowHtml of rows) {
    const songNameMatch = rowHtml.match(/<span\s+itemprop="name">([\s\S]*?)<\/span>/i);
    let songName = songNameMatch ? songNameMatch[1].replace(/<[^>]*>/g, '').trim() : null;

    const artistMatch = rowHtml.match(/<span\s+itemprop="byArtist">([\s\S]*?)<\/span>/i);
    const singers = artistMatch ? artistMatch[1].replace(/<[^>]*>/g, '').trim() : 'Unknown Artist';

    const dlinksRegex = /<a\s+[^>]*class="dlink"[^>]*href="([^"]+)"[^>]*title="([^"]*)"/gi;
    let dlinkMatch;
    let downloadUrl = null;

    while ((dlinkMatch = dlinksRegex.exec(rowHtml)) !== null) {
      const url = dlinkMatch[1];
      const title = dlinkMatch[2];
      if (url.indexOf('d320_cdn') !== -1 || url.indexOf('320') !== -1 || title.indexOf('320kbps') !== -1) {
        downloadUrl = url;
        if (!songName && title.indexOf('Download ') !== -1) {
          songName = title.replace('Download ', '').replace(' 320kbps', '').trim();
        }
        break;
      }
    }

    if (!songName) continue;

    const songLower = songName.toLowerCase();
    const albumLower = albumTitle.toLowerCase();
    let matched = queryWords.length === 0;

    if (queryWords.length > 0) {
      for (const word of queryWords) {
        if (songLower.indexOf(word) !== -1 || albumLower.indexOf(word) !== -1) {
          matched = true;
          break;
        }
      }
    }

    if (!matched) continue;

    if (downloadUrl) {
      if (!downloadUrl.startsWith('http')) {
        downloadUrl = baseUrl + downloadUrl;
      }
      results.push({
        title: songName,
        artist: singers,
        url: downloadUrl,
        trackId: downloadUrl,
        isLazy: false, // Directly playable link
        size: 0,
        format: 'MP3 (320kbps)',
        source: 'MassTamilan (JS)',
        album: albumTitle,
        thumbnail: thumbnail,
        extras: {}
      });
    }
  }

  return results;
}

globalThis.getStream = async function(trackId) {
  return trackId;
};
