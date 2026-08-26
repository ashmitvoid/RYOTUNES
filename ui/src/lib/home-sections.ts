import type { HomeSection } from '$lib/api';

/** App-owned Home blocks. This is the only list the renderer/editor may invent locally. */
export const HOME_LOCAL_SECTIONS = [
	{ key: '@recent', title: 'Jump back in' },
	{ key: '@familiar', title: 'Familiar Artists' },
	{ key: '@forgotten', title: 'Forgotten favourites' }
] as const;

export type HomeRegistryEntry = {
	key: string;
	title: string;
	available: boolean;
	local?: boolean;
};

export const unsupportedHomeSection = (title: string) =>
	/music\s*videos?|video\s+for\s+you/i.test(title);

const tidy = (value: string | undefined | null) => (value ?? '').trim().replace(/^\/{2}\s*/, '');
const fold = (value: string) => tidy(value).toLocaleLowerCase();

/**
 * YouTube occasionally labels a mixed recommendation shelf with only the seed artist name. That
 * reads as if the row contains that artist, which it does not. Detect seed-name labels from the
 * actual cards/known listening artists and normalize the *display title* centrally. The raw title
 * remains the persistence key so existing Edit Home order/visibility survives an upgrade.
 */
export function homeSectionTitle(section: HomeSection, knownArtistNames: Iterable<string> = []): string {
	const raw = tidy(section.title);
	if (!raw || section.titleIsArtist) return 'You might also like';
	const candidate = fold(raw);
	const artists = new Set<string>();
	for (const name of knownArtistNames) if (tidy(name)) artists.add(fold(name));
	for (const item of section.items) {
		if (item.kind === 'artist') artists.add(fold(item.title));
		for (const run of item.artistRuns ?? []) if (tidy(run.text)) artists.add(fold(run.text));
		if (item.kind === 'song' && item.subtitle) {
			// Card subtitles are normally "Artist" or "Artist • Album". The first field is enough to
			// recognize a seed label without treating generic editorial headings as artists.
			const first = item.subtitle.split(' • ')[0];
			if (tidy(first)) artists.add(fold(first));
		}
	}
	return artists.has(candidate) ? 'You might also like' : raw;
}

/** Raw title is the compatibility key; unsupported/video shelves never enter renderer or editor. */
export function homeSectionKey(section: Pick<HomeSection, 'title'>): string {
	return tidy(section.title);
}

/**
 * One authoritative registry for Home + Edit Home. Loaded entries are available; remembered
 * entries that are not in this session are retained as unavailable (rather than pretending they
 * are renderable), and unsupported video entries are dropped in both paths.
 */
export function buildHomeRegistry(
	loaded: HomeSection[],
	remembered: string[],
	knownArtistNames: Iterable<string> = []
): HomeRegistryEntry[] {
	const out: HomeRegistryEntry[] = HOME_LOCAL_SECTIONS.map((entry) => ({ ...entry, available: true, local: true }));
	const seen = new Set(out.map((entry) => entry.key));
	for (const section of loaded) {
		if (unsupportedHomeSection(section.title)) continue;
		const key = homeSectionKey(section);
		if (!key || seen.has(key)) continue;
		seen.add(key);
		out.push({ key, title: homeSectionTitle(section, knownArtistNames), available: true });
	}
	for (const title of remembered) {
		if (unsupportedHomeSection(title)) continue;
		const key = tidy(title);
		if (!key || seen.has(key)) continue;
		seen.add(key);
		out.push({ key, title: tidy(title), available: false });
	}
	return out;
}
