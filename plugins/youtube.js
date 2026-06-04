globalThis.manifest = {
  id: "youtube",
  name: "YouTube",
  version: "2.0.0",
  description: "Dynamic search and stream resolution for YouTube using native YoutubeExplode bridge",
  icon: "https://youtube.com/favicon.ico"
};

globalThis.search = async function(query) {
  try {
    const cleanQuery = query.trim();
    if (!cleanQuery) return [];
    console.log('[JS Plugin YouTube] Searching natively for: ' + cleanQuery);
    return await globalThis.youtubeExplode.search(cleanQuery);
  } catch (e) {
    console.error('[JS Plugin YouTube] Search error: ' + e);
    return [];
  }
};

globalThis.getStream = async function(trackId) {
  try {
    console.log('[JS Plugin YouTube] Resolving stream natively for video ID: ' + trackId);
    return await globalThis.youtubeExplode.getStream(trackId);
  } catch (e) {
    console.error('[JS Plugin YouTube] Stream resolution error: ' + e);
    return null;
  }
};
