<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import {
		UserLove02Icon,
		UserIcon,
		UserStar01Icon,
		ArrowRight01Icon,
		PlayIcon
	} from '@hugeicons/core-free-icons';
	import SectionHeading from './SectionHeading.svelte';
	import TrackMenu from './TrackMenu.svelte';
	import * as api from '$lib/api';
	import type { ArtistPage, SongItem } from '$lib/api';
	import { thumb } from '$lib/thumb';
	import { getCached, putCached } from '$lib/pagecache';
	import { topArtistIds } from '$lib/personal';
	import { personal, toast, playFrom, playSong, openAddToPlaylist } from '$lib/player.svelte';
	import { appearance } from '$lib/theme.svelte';

	const VISIBLE = 6;
	const COUNT = VISIBLE;
	const MIN = 3;

	let artists = $state<ArtistPage[]>([]);
	let loading = $state(true);
	let activeId = $state('');
	let subs = $state<Record<string, boolean>>({});
	let subBusy = $state<string | null>(null);
	let failed = $state<Record<string, boolean>>({});
	let playing = $state(false);
	let sectionEl: HTMLElement | undefined = $state();

	const ids = topArtistIds(personal, COUNT);
	const active = $derived(artists.find((a) => a.channelId === activeId) ?? artists[0] ?? null);
	const previewSongs = $derived(active?.topSongs.slice(0, 4) ?? []);

	type HeroImage = { channelId: string; src: string };
	let heroImage = $state<HeroImage | null>(null);
	let heroRequest = 0;

	// Keep the current hero painted until the next artist image has decoded. WebKitGTK otherwise
	// exposes a blank frame when a keyed <img> is replaced while its new source is still decoding.
	$effect(() => {
		const artist = active;
		const src = artist?.thumbnail ? thumb(artist.thumbnail, 512) : '';
		const request = ++heroRequest;
		if (!artist || !src) {
			heroImage = null;
			return;
		}
		if (heroImage?.channelId === artist.channelId && heroImage.src === src) return;

		const image = new Image();
		image.decoding = 'async';
		image.src = src;
		image.decode()
			.then(() => {
				if (request !== heroRequest) return;
				heroImage = { channelId: artist.channelId, src };
			})
			.catch(() => {
				if (request !== heroRequest) return;
				failed = { ...failed, [`hero:${artist.channelId}`]: true };
				heroImage = null;
			});
	});

	async function fetchArtist(id: string): Promise<ArtistPage | null> {
		const key = `artist:${id}`;
		const hit = getCached<ArtistPage>(key);
		if (hit) return hit;
		try {
			const page = await api.getArtist(id);
			putCached(key, page);
			return page;
		} catch {
			return null;
		}
	}

	onMount(() => {
		if (ids.length < MIN) {
			loading = false;
			return;
		}

		let alive = true;
		let started = false;
		const loadArtists = async () => {
			if (started) return;
			started = true;
			const pages: ArtistPage[] = [];
			const batchSize = appearance.lowResourceMode ? 1 : 2;
			// Low Resource serializes enrichment; normal mode keeps the bounded two-request lane.
			for (let i = 0; i < ids.length && alive; i += batchSize) {
				const batch = await Promise.all(ids.slice(i, i + batchSize).map(fetchArtist));
				pages.push(...batch.filter((page): page is ArtistPage => !!page));
			}
			if (!alive) return;
			artists = pages;
			activeId = pages[0]?.channelId ?? '';
			subs = Object.fromEntries(pages.map((page) => [page.channelId, page.subscribed]));
			loading = false;
		};

		let observer: IntersectionObserver | undefined;
		if ('IntersectionObserver' in window && sectionEl) {
			observer = new IntersectionObserver(
				([entry]) => {
					if (!entry.isIntersecting) return;
					observer?.disconnect();
					void loadArtists();
				},
				{ rootMargin: appearance.lowResourceMode ? '180px 0px' : '700px 0px' }
			);
			observer.observe(sectionEl);
		} else {
			void loadArtists();
		}

		return () => {
			alive = false;
			observer?.disconnect();
		};
	});

	function open(a: ArtistPage) {
		goto(`/artist/${encodeURIComponent(a.channelId)}`);
	}

	function moveArtist(delta: number) {
		const visible = artists.slice(0, VISIBLE);
		if (!visible.length) return;
		const at = Math.max(0, visible.findIndex((a) => a.channelId === active?.channelId));
		const next = Math.max(0, Math.min(visible.length - 1, at + delta));
		activeId = visible[next].channelId;
		requestAnimationFrame(() => {
			document.querySelector<HTMLElement>(`[data-artist-id="${CSS.escape(visible[next].channelId)}"]`)?.focus();
		});
	}

	async function playArtist(a: ArtistPage) {
		if (playing || !a.topSongs.length) return;
		playing = true;
		try {
			await playFrom(
				{ kind: 'artist', id: a.channelId, title: a.name ?? 'Artist', subtitle: a.subscribers, thumbnail: a.thumbnail },
				a.topSongs,
				null
			);
		} finally {
			playing = false;
		}
	}

	async function playPreview(song: SongItem) {
		await playSong(song);
	}

	async function toggleSub(a: ArtistPage) {
		if (subBusy) return;
		const next = !subs[a.channelId];
		subBusy = a.channelId;
		subs = { ...subs, [a.channelId]: next };
		try {
			await api.subscribe(a.channelId, next);
			putCached(`artist:${a.channelId}`, { ...a, subscribed: next });
			toast.success(next ? `Subscribed to ${a.name ?? 'artist'}` : 'Unsubscribed');
		} catch (e) {
			subs = { ...subs, [a.channelId]: !next };
			toast.error(String(e));
		} finally {
			subBusy = null;
		}
	}
</script>

{#if loading ? ids.length >= MIN : artists.length >= MIN}
	<section bind:this={sectionEl} class="ryo-artist-index-section">
		<SectionHeading title="Familiar artists" icon={UserStar01Icon} />
		<div class="ryo-artist-index">
			<div class="ryo-artist-list" role="listbox" aria-label="Familiar artists">
				<div class="ryo-artist-list-head"><span>// ARTIST INDEX</span><b>{loading ? 'SYNC' : `${Math.min(VISIBLE, artists.length)} KNOWN`}</b></div>
				{#if loading}
					{#each Array(Math.min(ids.length, VISIBLE)) as _, i (i)}
						<div class="ryo-artist-row is-loading" aria-hidden="true">
							<span class="ryo-artist-number">{String(i + 1).padStart(2, '0')}</span><i></i><div><b></b><small></small></div>
						</div>
					{/each}
				{:else}
					{#each artists.slice(0, VISIBLE) as a, i (a.channelId)}
						<button
							type="button"
							role="option"
							aria-selected={active?.channelId === a.channelId}
							class="ryo-artist-row"
							class:active={active?.channelId === a.channelId}
							data-artist-id={a.channelId}
							onfocus={() => (activeId = a.channelId)}
							onclick={() => (activeId = a.channelId)}
							ondblclick={() => open(a)}
							onkeydown={(e) => {
								if (e.key === 'ArrowDown' || e.key === 'j' || e.key === 'J') { e.preventDefault(); moveArtist(1); }
								else if (e.key === 'ArrowUp' || e.key === 'k' || e.key === 'K') { e.preventDefault(); moveArtist(-1); }
								else if (e.key === 'Enter') { e.preventDefault(); open(a); }
							}}
						>
							<span class="ryo-artist-number">{String(i + 1).padStart(2, '0')}</span>
							<span class="ryo-artist-thumb">
								{#if a.thumbnail && !failed[a.channelId]}
									<img src={thumb(a.thumbnail, 128)} alt="" loading="lazy" decoding="async" draggable="false" onerror={() => (failed = { ...failed, [a.channelId]: true })} />
								{:else}
									<HugeiconsIcon icon={UserIcon} class="h-4 w-4" />
								{/if}
							</span>
							<span class="ryo-artist-row-copy"><strong>{a.name ?? 'Artist'}</strong><small>{a.monthlyListeners ?? a.subscribers ?? 'Artist'}</small></span>
							<span class="ryo-artist-row-mark">{active?.channelId === a.channelId ? '//' : '聴'}</span>
						</button>
					{/each}
				{/if}
			</div>

			<aside class="ryo-artist-inspector" aria-live="polite">
				{#if loading || !active}
					<div class="ryo-artist-hero is-loading"><span></span></div>
					<div class="ryo-artist-inspector-copy is-loading"><span></span><b></b><i></i></div>
				{:else}
					<div class="ryo-artist-hero">
						{#if heroImage}
							<img src={heroImage.src} alt="" decoding="async" draggable="false" />
						{:else if !active.thumbnail || failed[`hero:${active.channelId}`]}
							<div class="ryo-artist-hero-empty"><HugeiconsIcon icon={UserIcon} class="h-10 w-10" /></div>
						{:else}
							<div class="ryo-artist-hero-loading" aria-hidden="true"></div>
						{/if}
						<div class="ryo-artist-hero-label"><span>// PROFILE</span><b>{active.channelId.slice(0, 8).toUpperCase()}</b></div>
					</div>
					<div class="ryo-artist-inspector-copy">
						<div class="ryo-artist-kicker">SELECTED ARTIST · {active.monthlyListeners ?? active.subscribers ?? 'LIBRARY SIGNAL'}</div>
						<h3>{active.name ?? 'Artist'}</h3>
						{#if previewSongs.length}
							<div class="ryo-artist-top">
								<div class="ryo-artist-top-head"><span>TOP TRACKS</span><b>{previewSongs.length}</b></div>
								{#each previewSongs as song, i (song.video_id)}
									<div class="ryo-artist-top-row group/artisttrack" data-ctx="track">
										<button type="button" class="ryo-artist-top-play" onclick={() => playPreview(song)} title={`Play ${song.title}`}>
											<span>{String(i + 1).padStart(2, '0')}</span><strong>{song.title}</strong><HugeiconsIcon icon={PlayIcon} class="h-3 w-3" />
										</button>
										<TrackMenu
											{song}
											onAdd={() => openAddToPlaylist(song)}
											triggerClass="ryo-artist-top-menu transition"
										/>
									</div>
								{/each}
							</div>
						{/if}
						<div class="ryo-artist-actions">
							<button type="button" class="primary" onclick={() => playArtist(active)} disabled={playing || !active.topSongs.length}><HugeiconsIcon icon={PlayIcon} class="h-3.5 w-3.5" /> {playing ? 'STARTING…' : 'PLAY'}</button>
							<button type="button" onclick={() => open(active)}>OPEN ARTIST <HugeiconsIcon icon={ArrowRight01Icon} class="h-3.5 w-3.5" /></button>
							<button type="button" onclick={() => toggleSub(active)} disabled={subBusy === active.channelId}><HugeiconsIcon icon={UserLove02Icon} class="h-3.5 w-3.5" /> {subs[active.channelId] ? 'SUBSCRIBED' : 'SUBSCRIBE'}</button>
						</div>
					</div>
				{/if}
			</aside>
		</div>
	</section>
{/if}
