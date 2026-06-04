globalThis.manifest = {
  id: "jiosaavn",
  name: "JioSaavn",
  version: "1.0.0",
  description: "Dynamic search and streaming for JioSaavn",
  icon: "https://www.jiosaavn.com/favicon.ico"
};

globalThis.search = async function(query) {
  try {
    const cleanQuery = query.trim();
    if (!cleanQuery) return [];

    console.log('[JS Plugin JioSaavn] Searching for: ' + cleanQuery);
    
    const url = 'https://saavn.sumit.co/api/search/songs?query=' + encodeURIComponent(cleanQuery);
    const response = await globalThis.fetch(url);
    if (!response.ok) {
      console.log('[JS Plugin JioSaavn] Fetch failed: ' + response.status);
      return [];
    }

    const data = await response.json();
    if (!data) return [];

    const isVercelFormat = (data.success === true || data.status === 'SUCCESS') && data.data;
    const results = isVercelFormat ? (data.data.results || []) : (data.results || []);

    const out = [];
    for (const item of results) {
      try {
        const title = item.name || 'Unknown';
        
        let artist = 'Unknown Artist';
        if (typeof item.primaryArtists === 'string') {
          artist = item.primaryArtists;
        } else if (item.artists && Array.isArray(item.artists.primary)) {
          artist = item.artists.primary.map(a => a.name || 'Unknown').join(', ');
        }

        const albumData = item.album;
        const albumName = (albumData && typeof albumData === 'object') ? (albumData.name || '') : (albumData || '');

        // Images
        const images = item.image || [];
        let thumbnail = images.length > 0 ? (images[images.length - 1].link || images[images.length - 1].url) : null;
        for (const img of images) {
          if (img.quality === '500x500') {
            thumbnail = img.link || img.url;
            break;
          }
        }

        // Download URLs
        const downloadUrls = item.downloadUrl || [];
        let downloadUrl = null;
        let qualityStr = '160kbps';

        for (const d of downloadUrls) {
          if (d.quality === '320kbps') {
            downloadUrl = d.link || d.url;
            qualityStr = '320kbps';
            break;
          }
        }

        if (!downloadUrl) {
          for (const d of downloadUrls) {
            if (d.quality === '160kbps') {
              downloadUrl = d.link || d.url;
              qualityStr = '160kbps';
              break;
            }
          }
          if (downloadUrls.length > 0) {
            downloadUrl = downloadUrl || downloadUrls[downloadUrls.length - 1].link || downloadUrls[downloadUrls.length - 1].url;
          }
        }

        if (!downloadUrl) continue;

        const durationSecs = parseInt(item.duration || '0', 10);
        const mins = Math.floor(durationSecs / 60);
        const secs = durationSecs % 60;
        const duration = mins + ':' + (secs < 10 ? '0' + secs : secs);

        out.push({
          title: title,
          artist: artist,
          url: downloadUrl,
          trackId: item.id || downloadUrl,
          isLazy: false, // directly playable
          size: 0,
          format: 'AAC:' + qualityStr,
          source: 'JioSaavn (JS)',
          album: albumName,
          thumbnail: thumbnail,
          duration: duration,
          extras: {
            id: item.id,
            year: item.year
          }
        });
      } catch (e) {
        console.error('[JS Plugin JioSaavn] Parse error: ' + e);
      }
    }
    return out;
  } catch (e) {
    console.error('[JS Plugin JioSaavn] Error: ' + e);
    return [];
  }
};

globalThis.getStream = async function(trackId) {
  return trackId;
};
