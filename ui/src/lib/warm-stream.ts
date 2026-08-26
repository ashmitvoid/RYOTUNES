import * as api from './api';
import { appearance } from './theme.svelte';

// Speculative stream resolution is a latency optimization, never a requirement. Keep it bounded and
// serial so moving the pointer across a shelf cannot fan out several network/cipher jobs at once.
const MAX_WARMED = 48;
const MIN_GAP_MS = 700;
const warmed = new Set<string>();
let active = false;
let lastWarmAt = 0;

function remember(videoId: string) {
	warmed.delete(videoId);
	warmed.add(videoId);
	while (warmed.size > MAX_WARMED) {
		const oldest = warmed.values().next().value;
		if (!oldest) break;
		warmed.delete(oldest);
	}
}

export function warmStream(videoId: string, isUpload = false) {
	if (appearance.lowResourceMode || !videoId || api.isLocalId(videoId) || warmed.has(videoId)) return;
	const now = performance.now();
	if (active || now - lastWarmAt < MIN_GAP_MS) return;

	remember(videoId);
	lastWarmAt = now;
	active = true;
	api.prefetchStream(videoId, isUpload)
		.catch(() => warmed.delete(videoId))
		.finally(() => (active = false));
}
