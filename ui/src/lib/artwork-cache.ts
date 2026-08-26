/**
 * Tiny readiness cache for the handful of *large* artwork surfaces (Now Playing, Queue/Lyrics,
 * mini player). It deliberately stores URLs, not decoded Image objects or blobs: WebKit's normal
 * HTTP/image cache owns the pixels, while this map only remembers which high-resolution variant
 * has already decoded cleanly. That keeps the application-side cache bounded and cheap.
 */
const MAX_READY_ARTWORK = 36;
const ready = new Map<string, true>();

export function artworkReady(url: string): boolean {
	if (!url || !ready.has(url)) return false;
	// Map insertion order doubles as LRU order. Refresh a hit without allocating another object.
	ready.delete(url);
	ready.set(url, true);
	return true;
}

export function rememberArtwork(url: string): void {
	if (!url) return;
	ready.delete(url);
	ready.set(url, true);
	while (ready.size > MAX_READY_ARTWORK) {
		const oldest = ready.keys().next().value as string | undefined;
		if (!oldest) break;
		ready.delete(oldest);
	}
}

/** Exposed only for diagnostics/invariants; callers should not size UI behavior from it. */
export const artworkCacheEntries = () => ready.size;
