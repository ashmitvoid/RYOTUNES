<script lang="ts">
	import { thumb } from '$lib/thumb';
	import { artworkReady, rememberArtwork } from '$lib/artwork-cache';

	let {
		source,
		size = 640,
		previewSize = 120,
		alt = '',
		className = '',
		eager = true
	}: {
		source?: string | null;
		size?: number;
		previewSize?: number;
		alt?: string;
		className?: string;
		eager?: boolean;
	} = $props();

	const preview = $derived(source ? thumb(source, previewSize) : '');
	const full = $derived(source ? thumb(source, size) : '');
	let fullDecoded = $state(false);

	// High-resolution decoding happens off-DOM. A track change tears down the local Image request
	// before a stale decode may swap into the current surface; the small preview is immediately
	// usable and usually reuses the exact thumbnail already fetched by PlayerBar/TrackRow.
	$effect(() => {
		const url = full;
		fullDecoded = false;
		if (!url) return;
		if (artworkReady(url)) {
			fullDecoded = true;
			return;
		}

		let cancelled = false;
		const image = new Image();
		image.decoding = 'async';
		image.src = url;
		const complete = async () => {
			try {
				if (typeof image.decode === 'function') await image.decode();
			} catch {
				// Some WebKit builds reject decode() even after onload. onload still proves the pixels are
				// usable, so the handler below gets a second chance.
			}
			if (cancelled || !image.naturalWidth) return;
			rememberArtwork(url);
			fullDecoded = true;
		};
		if (image.complete) void complete();
		else image.onload = () => void complete();
		image.onerror = () => {};
		return () => {
			cancelled = true;
			image.onload = null;
			image.onerror = null;
			// Best-effort cancellation for a superseded track. Ready items never reach this branch.
			if (!image.complete) image.src = '';
		};
	});
</script>

<div class="ryo-artwork-image {className}" class:ready={fullDecoded} aria-label={alt || undefined} role={alt ? 'img' : undefined}>
	{#if preview}
		<img
			src={preview}
			alt=""
			class="preview"
			loading={eager ? 'eager' : 'lazy'}
			decoding="async"
			draggable="false"
		/>
		{#if fullDecoded && full && full !== preview}
			<img src={full} alt="" class="full" decoding="async" draggable="false" />
		{/if}
	{:else}
		<span class="placeholder" aria-hidden="true">音</span>
	{/if}
</div>

<style>
	.ryo-artwork-image { position:relative; width:100%; height:100%; overflow:hidden; background:var(--ryo-paper-lift); isolation:isolate; }
	.ryo-artwork-image img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
	.preview { transform:scale(1.025); filter:saturate(.9) blur(5px); opacity:.96; }
	.full { animation:ryo-art-resolve 150ms ease-out both; }
	.placeholder { position:absolute; inset:0; display:grid; place-items:center; color:var(--ryo-ink-faint); font:500 22px/1 "SpaceMono Nerd Font",monospace; }
	@keyframes ryo-art-resolve { from { opacity:0; } to { opacity:1; } }
	@media (prefers-reduced-motion: reduce) { .full { animation:none; } }
</style>
