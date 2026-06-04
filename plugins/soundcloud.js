globalThis.manifest = {
  id: "soundcloud",
  name: "SoundCloud",
  version: "1.0.0",
  description: "Dynamic search and streaming for SoundCloud",
  icon: "https://soundcloud.com/favicon.ico"
};

const clientId = 'iuspDvaXDbD3AnFwLWK56Fk69q56xsKu';
const apiBase = 'https://api-v2.soundcloud.com';

globalThis.search = async function(query) {
  try {
    const cleanQuery = query.trim();
    if (!cleanQuery) return [];

    console.log('[JS Plugin SoundCloud] Searching for: ' + cleanQuery);

    const url = apiBase + '/search?q=' + encodeURIComponent(cleanQuery) + '&client_id=' + clientId + '&limit=15';
    const response = await globalThis.fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    });

    if (!response.ok) {
      console.log('[JS Plugin SoundCloud] Search failed: ' + response.status);
      return [];
    }

    const data = await response.json();
    const collection = data.collection || [];
    const out = [];

    for (const item of collection) {
      if (item.kind !== 'track') continue;

      try {
        const id = item.id;
        const title = item.title || 'Unknown';
        const artist = (item.user && item.user.username) || 'Unknown Artist';

        let thumbnail = item.artwork_url || (item.user && item.user.avatar_url);
        if (thumbnail) {
          thumbnail = thumbnail.replace('-large.', '-t500x500.');
        }

        const durationMs = parseInt(item.duration || '0', 10);
        const mins = Math.floor(durationMs / 60000);
        const secs = Math.floor((durationMs % 60000) / 1000);
        const duration = mins + ':' + (secs < 10 ? '0' + secs : secs);

        out.push({
          title: title,
          artist: artist,
          url: id.toString(),
          trackId: id.toString(),
          isLazy: true, // Needs lazy resolution
          size: 0,
          format: 'SoundCloud',
          source: 'SoundCloud (JS)',
          thumbnail: thumbnail,
          duration: duration,
          extras: {
            track_id: id,
            full_duration_ms: durationMs,
            permalink: item.permalink_url,
            track_authorization: item.track_authorization
          }
        });
      } catch (e) {
        console.error('[JS Plugin SoundCloud] Parse error: ' + e);
      }
    }
    return out;
  } catch (e) {
    console.error('[JS Plugin SoundCloud] Error: ' + e);
    return [];
  }
};

globalThis.getStream = async function(trackId) {
  try {
    console.log('[JS Plugin SoundCloud] Resolving stream for track: ' + trackId);

    const url = apiBase + '/tracks/' + trackId + '?client_id=' + clientId;
    const response = await globalThis.fetch(url);
    if (!response.ok) {
      console.log('[JS Plugin SoundCloud] Track fetch failed: ' + response.status);
      return null;
    }

    const trackData = await response.json();
    const transcodings = (trackData.media && trackData.media.transcodings) || [];
    if (transcodings.length === 0) return null;

    let transcoding = transcodings.find(t => t.format && t.format.protocol === 'progressive');
    if (!transcoding) {
      transcoding = transcodings[0];
    }

    const streamUrl = transcoding.url;
    if (!streamUrl) return null;

    const mediaResponse = await globalThis.fetch(streamUrl + '?client_id=' + clientId);
    if (!mediaResponse.ok) return null;

    const mediaData = await mediaResponse.json();
    return mediaData.url || null;
  } catch (e) {
    console.error('[JS Plugin SoundCloud] Resolution error: ' + e);
    return null;
  }
};
