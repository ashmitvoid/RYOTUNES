// Small LRU for browse responses. The visible route already owns a reactive copy, so this cache is
// only for fast revisits; keeping a browser-sized history here just duplicates arrays and artwork
// metadata that WebKit also has to trace.
const TTL_MS = 3 * 60_000;
const MAX_ENTRIES = 8;

const store = new Map<string, { data: unknown; at: number }>();

export function getCached<T>(key: string): T | null {
	const e = store.get(key);
	if (!e) return null;
	if (Date.now() - e.at > TTL_MS) {
		store.delete(key);
		return null;
	}
	// True LRU: a route the user actually revisits earns its place; stale speculative entries do not.
	store.delete(key);
	store.set(key, e);
	return e.data as T;
}

export function putCached(key: string, data: unknown): void {
	store.delete(key);
	store.set(key, { data, at: Date.now() });
	while (store.size > MAX_ENTRIES) {
		const oldest = store.keys().next().value;
		if (oldest === undefined) break;
		store.delete(oldest);
	}
}

export function invalidateCached(key: string): void {
	store.delete(key);
}

/** Drop everything — browse data is per-account, so sign-in/out makes all of it stale. */
export function clearCached(): void {
	store.clear();
}
