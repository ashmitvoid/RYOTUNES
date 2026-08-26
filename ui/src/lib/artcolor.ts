const SAMPLE = 24;
const accentCache = new Map<string, string | null>();
const MAX_ACCENTS = 32;

type Bucket = { n: number; r: number; g: number; b: number; score: number };

function saturation(r: number, g: number, b: number) {
	const max = Math.max(r, g, b) / 255;
	const min = Math.min(r, g, b) / 255;
	return max === 0 ? 0 : (max - min) / max;
}

export function pickArtworkAccent(data: Uint8ClampedArray): string | null {
	const buckets = new Map<number, Bucket>();
	for (let i = 0; i < data.length; i += 4) {
		if (data[i + 3] < 128) continue;
		const r = data[i];
		const g = data[i + 1];
		const b = data[i + 2];
		const max = Math.max(r, g, b) / 255;
		const sat = saturation(r, g, b);
		if (sat < 0.12) continue;
		const score = sat * (1 - Math.abs(max - 0.65));
		const key = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5);
		const cur = buckets.get(key) ?? { n: 0, r: 0, g: 0, b: 0, score: 0 };
		cur.n += 1;
		cur.r += r;
		cur.g += g;
		cur.b += b;
		cur.score += score;
		buckets.set(key, cur);
	}
	let best: Bucket | undefined;
	for (const bucket of buckets.values()) {
		if (!best || bucket.score > best.score) best = bucket;
	}
	if (!best || best.score <= 0) return null;
	const rgb = [best.r, best.g, best.b].map((c) => Math.round(c / best!.n));
	return `rgb(${rgb[0]} ${rgb[1]} ${rgb[2]})`;
}

export async function artworkAccent(url: string): Promise<string | null> {
	const hit = accentCache.get(url);
	if (hit !== undefined) {
		accentCache.delete(url);
		accentCache.set(url, hit);
		return hit;
	}
	let accent: string | null = null;
	try {
		const img = new Image();
		img.crossOrigin = 'anonymous';
		img.src = url;
		await img.decode();
		const canvas = document.createElement('canvas');
		canvas.width = SAMPLE;
		canvas.height = SAMPLE;
		const ctx = canvas.getContext('2d', { willReadFrequently: true });
		if (ctx) {
			ctx.drawImage(img, 0, 0, SAMPLE, SAMPLE);
			accent = pickArtworkAccent(ctx.getImageData(0, 0, SAMPLE, SAMPLE).data);
		}
	} catch {
		accent = null;
	}
	accentCache.delete(url);
	accentCache.set(url, accent);
	while (accentCache.size > MAX_ACCENTS) {
		const oldest = accentCache.keys().next().value;
		if (oldest === undefined) break;
		accentCache.delete(oldest);
	}
	return accent;
}
