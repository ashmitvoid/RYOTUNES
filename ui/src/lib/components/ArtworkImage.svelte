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
	const needsSwap = $derived(!!full && full !== preview);
	let fullDecoded = $state(false);
	let fullFailed = $state(false);

	// Keep the tiny preview visible while the larger DOM image downloads and decodes. The old
	// off-DOM path had one nasty edge case: sources thumb() cannot resize have full === preview,
	// so no "full" element was ever rendered and the preview's intentional 5px loading blur became
	// permanent. A same-URL source is now sharp immediately; a failed large request also falls back
	// to the usable preview instead of leaving the artwork blurred forever.
	$effect(() => {
		const url = full;
		fullFailed = false;
		fullDecoded = !!url && artworkReady(url);
	});

	async function revealFull(image: HTMLImageElement, url: string) {
		try {
			if (typeof image.decode === 'function') await image.decode();
		} catch {
			// WebKitGTK can reject decode() after onload for some image types. naturalWidth below is
			// the authoritative "pixels are usable" check in that case.
		}
		if (full !== url || !image.naturalWidth) return;
		rememberArtwork(url);
		fullDecoded = true;
	}

	function failFull(url: string) {
		if (full !== url) return;
		fullFailed = true;
		fullDecoded = false;
	}
</script>

<div
	class="ryo-artwork-image {className}"
	class:ready={fullDecoded || !needsSwap}
	aria-label={alt || undefined}
	role={alt ? 'img' : undefined}
>
	{#if preview}
		<img
			src={preview}
			alt=""
			class="preview"
			class:sharp={!needsSwap || fullFailed}
			loading={eager ? 'eager' : 'lazy'}
			decoding="async"
			draggable="false"
		/>
		{#if needsSwap && !fullFailed}
			{#key full}
				<img
					src={full}
					alt=""
					class="full"
					class:resolved={fullDecoded}
					loading={eager ? 'eager' : 'lazy'}
					decoding="async"
					draggable="false"
					onload={(event) => void revealFull(event.currentTarget, full)}
					onerror={() => failFull(full)}
				/>
			{/key}
		{/if}
	{:else}
		<span class="placeholder" aria-hidden="true">音</span>
	{/if}
</div>

<style>
	.ryo-artwork-image { position:relative; width:100%; height:100%; overflow:hidden; background:var(--ryo-paper-lift); isolation:isolate; }
	.ryo-artwork-image img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
	.preview { transform:scale(1.025); filter:saturate(.9) blur(5px); opacity:.96; transition:filter 120ms ease-out,transform 120ms ease-out; }
	.preview.sharp { transform:none; filter:none; opacity:1; }
	.full { opacity:0; }
	.full.resolved { animation:ryo-art-resolve 150ms ease-out both; }
	.placeholder { position:absolute; inset:0; display:grid; place-items:center; color:var(--ryo-ink-faint); font:500 22px/1 "SpaceMono Nerd Font",monospace; }
	@keyframes ryo-art-resolve { from { opacity:0; } to { opacity:1; } }
	@media (prefers-reduced-motion: reduce) {
		.preview { transition:none; }
		.full.resolved { animation:none; opacity:1; }
	}
</style>
