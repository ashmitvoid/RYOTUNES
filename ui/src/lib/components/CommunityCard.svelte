<script lang="ts">
	// A "From the community" playlist card: cover, title, a peek at the first three tracks, and
	// play / add-to-playlist. Wider than a MediaCard, so the shelf stretches these instead of
	// packing more of them per row (see Shelf's `community` prop).
	import { goto } from '$app/navigation';
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import { PlayIcon, PlayListAddIcon, MusicNote01Icon } from '@hugeicons/core-free-icons';
	import { Skeleton } from '$lib/components/ui/skeleton';
	import * as api from '$lib/api';
	import type { BrowseItem, PlaylistPage } from '$lib/api';
	import { thumb } from '$lib/thumb';
	import { getCached, putCached } from '$lib/pagecache';
	import { openAddManyToPlaylist, playFrom, toast, touchPick } from '$lib/player.svelte';
	import ItemMenu from './ItemMenu.svelte';

	let { item }: { item: BrowseItem } = $props();

	// A community playlist's "cover" is usually just the creator's channel avatar — often the
	// generated first-letter tile. Those are served from yt3.*; a real playlist cover is an
	// i.ytimg video thumb or lh3 playlist art. When it's an avatar, build the cover from the
	// tracks' own artwork instead (2×2, like every other multi-track cover in the app).
	const avatar = $derived(/\/\/yt3\./.test(item.thumbnail ?? ''));

	let pl = $state<PlaylistPage | null>(null);
	let root = $state<HTMLElement | null>(null);
	let busy = $state(false); // in-flight guard for the fetch-then-act buttons

	// Same key the playlist page uses — a card that loaded makes opening it instant, and vice versa.
	const key = $derived(`playlist:${item.id}`);

	async function load(): Promise<PlaylistPage> {
		if (pl) return pl;
		const hit = getCached<PlaylistPage>(key);
		if (hit) return (pl = hit);
		const fresh = await api.getPlaylist(item.id);
		putCached(key, fresh);
		return (pl = fresh);
	}

	// Every card is one browse call, and a shelf holds 20 — only spend it once the card is on screen.
	$effect(() => {
		if (!root) return;
		const io = new IntersectionObserver((entries) => {
			if (!entries.some((e) => e.isIntersecting)) return;
			io.disconnect();
			load().catch(() => {}); // best-effort: a card without its tracks still opens and plays
		});
		io.observe(root);
		return () => io.disconnect();
	});

	const tracks = $derived(pl?.items.slice(0, 3) ?? []);
	// Distinct covers only: playlists of art tracks repeat one album's artwork, and a mosaic of four
	// identical tiles looks broken. Under four, a single track cover still beats a letter avatar.
	const covers = $derived([
		...new Set((pl?.items ?? []).map((s) => s.thumbnail).filter((t): t is string => !!t))
	]);
	const mosaic = $derived(avatar && covers.length >= 4 ? covers.slice(0, 4) : []);
	const cover = $derived(avatar ? covers[0] ?? item.thumbnail : item.thumbnail);
	// The playlist header's own subtitle is "31K views • 46 tracks • 3 hours, 11 minutes"; the card's
	// subtitle already says "Creator • 31K views", so drop the duplicated views run.
	const stats = $derived(pl?.subtitle?.replace(/^[^•]*views\s*•\s*/i, '') ?? '');

	function open() {
		touchPick(item.id);
		goto(`/playlist/${encodeURIComponent(item.id)}`);
	}

	async function act(run: (p: PlaylistPage) => void) {
		if (busy) return;
		busy = true;
		try {
			run(await load());
		} catch {
			toast.error('Could not load that playlist — try opening it instead');
		} finally {
			busy = false;
		}
	}
</script>

<div
	bind:this={root}
	class="ryo-community-card group relative flex h-full min-w-0 flex-col"
	data-ctx
>
	<ItemMenu
		{item}
		triggerClass="absolute right-2 top-2 z-20 flex h-8 w-8 items-center justify-center rounded-full bg-background/90 text-foreground shadow-md transition hover:bg-background cursor-pointer"
	/>
	<div
		class="block w-full min-w-0 cursor-pointer"
		role="button"
		tabindex="0"
		onclick={open}
		onkeydown={(e) => {
			if (e.target !== e.currentTarget) return;
			if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
		}}
		title={item.title}
	>
		
		<div
			class="ryo-community-cover relative aspect-square w-full overflow-hidden bg-muted"
		>
			{#if mosaic.length === 4}
				<div class="grid h-full w-full grid-cols-2 grid-rows-2">
					{#each mosaic as m (m)}
						<img src={thumb(m, 160)} alt="" class="h-full w-full object-cover" loading="lazy" decoding="async" />
					{/each}
				</div>
			{:else if cover}
				<img
					src={thumb(cover, 256)}
					alt=""
					class="h-full w-full object-cover transition-transform duration-[210ms] ease-out group-hover:scale-105"
					loading="lazy"
					decoding="async"
				/>
			{:else}
				<div class="flex h-full w-full items-center justify-center text-muted-foreground/50">
					<HugeiconsIcon icon={MusicNote01Icon} class="h-6 w-6" />
				</div>
			{/if}
		</div>
		<div class="ryo-community-title truncate">{item.title}</div>
		{#if item.subtitle}
			<div class="ryo-community-subtitle truncate">{item.subtitle}</div>
		{/if}
		{#if stats}
			<div class="ryo-community-stats truncate">{stats}</div>
		{/if}
	</div>

	<div class="flex min-w-0 flex-col gap-0.5">
		{#if tracks.length}
			{#each tracks as t, i (t.video_id + ':' + i)}
				<button
					class="ryo-community-track flex w-full min-w-0 cursor-pointer items-center gap-2 text-left"
					onclick={() => playFrom(item, pl!.items, i, item.id, undefined, pl!.continuation)}
					title={t.artists ? `${t.title} — ${t.artists}` : t.title}
				>
					{#if t.thumbnail}
						<img
							src={thumb(t.thumbnail, 100)}
							alt=""
							class="h-8 w-8 shrink-0 rounded-md bg-muted object-cover"
							loading="lazy"
							decoding="async"
						/>
					{:else}
						<div class="h-8 w-8 shrink-0 rounded-md bg-muted"></div>
					{/if}
					
					<span class="min-w-0 flex-1">
						<span class="block truncate text-xs font-medium">{t.title}</span>
						<span class="block truncate text-[0.6875rem] text-muted-foreground">{t.artists}</span>
					</span>
				</button>
			{/each}
		{:else}
			
			{#each Array(3) as _, i (i)}
				<div class="flex items-center gap-2 p-1">
					<Skeleton class="h-8 w-8 shrink-0 rounded-md" />
					<div class="min-w-0 flex-1">
						<Skeleton class="mb-1 h-3 w-3/5 rounded" />
						<Skeleton class="h-2.5 w-2/5 rounded" />
					</div>
				</div>
			{/each}
		{/if}
	</div>

	<div class="ryo-community-footer mt-auto flex items-center gap-2">
		<button
			aria-label="Play"
			disabled={busy}
			class:animate-pulse={busy}
			class="ryo-community-action primary flex cursor-pointer items-center justify-center gap-1.5"
			onclick={() => act((p) => playFrom(item, p.items, null, item.id, undefined, p.continuation))}
		>
			<HugeiconsIcon icon={PlayIcon} class="h-3.5 w-3.5" /><span>Play</span>
		</button>
		<button
			aria-label="Add to playlist"
			disabled={busy}
			class="ryo-community-action flex cursor-pointer items-center justify-center gap-1.5"
			onclick={() => act((p) => openAddManyToPlaylist(p.items))}
		>
			<HugeiconsIcon icon={PlayListAddIcon} class="h-3.5 w-3.5" /><span>Add</span>
		</button>
	</div>
</div>
