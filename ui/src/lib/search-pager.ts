import * as api from '$lib/api';
import type { BrowseItem, SearchResults, SongItem } from '$lib/api';

export type SearchStream = 'mixed' | 'songs' | 'albums' | 'artists' | 'playlists';
const STREAMS: SearchStream[] = ['mixed', 'songs', 'albums', 'artists', 'playlists'];

export interface SearchPagerState {
	index: number;
	tokens: Partial<Record<SearchStream, string | null>>;
	started: Partial<Record<SearchStream, boolean>>;
}

export function createSearchPager(opts: {
	mixedContinuation?: string;
	songContinuation?: string;
	songsStarted?: boolean;
} = {}): SearchPagerState {
	return {
		index: 0,
		tokens: {
			mixed: opts.mixedContinuation ?? null,
			songs: opts.songContinuation ?? null
		},
		started: {
			mixed: true,
			songs: opts.songsStarted ?? false,
			albums: false,
			artists: false,
			playlists: false
		}
	};
}

export function searchPagerDone(state: SearchPagerState): boolean {
	return state.index >= STREAMS.length;
}

export function cloneSearchPager(state: SearchPagerState): SearchPagerState {
	return { index: state.index, tokens: { ...state.tokens }, started: { ...state.started } };
}

export function songToBrowse(song: SongItem): BrowseItem {
	return {
		kind: 'song',
		id: song.video_id,
		title: song.title,
		subtitle: song.artists,
		thumbnail: song.thumbnail,
		duration: song.duration,
		playCount: song.play_count,
		artistRuns: song.artist_runs,
		explicit: song.explicit,
		isUpload: song.is_upload
	};
}

export function flattenSearchResults(res: SearchResults): BrowseItem[] {
	return [...res.top, ...res.songs, ...res.albums, ...res.artists, ...res.playlists];
}

/**
 * Fetch exactly one bounded next search page. The state advances across the mixed stream, then the
 * songs filter, then album/artist/playlist filters. No caller needs to guess a result ceiling and no
 * invocation floods the network: at most one request is made per call.
 */
export async function nextSearchPage(query: string, state: SearchPagerState): Promise<BrowseItem[]> {
	while (!searchPagerDone(state)) {
		const stream = STREAMS[state.index];
		if (stream === 'mixed') {
			const token = state.tokens.mixed;
			if (!token) { state.index++; continue; }
			const page = await api.searchAllMore(token);
			state.tokens.mixed = page.continuation ?? null;
			if (!state.tokens.mixed) state.index++;
			return flattenSearchResults(page);
		}

		if (stream === 'songs') {
			if (!state.started.songs) {
				state.started.songs = true;
				const page = await api.searchPage(query);
				state.tokens.songs = page.continuation ?? null;
				if (!state.tokens.songs) state.index++;
				return page.items.filter((song) => !song.is_video).map(songToBrowse);
			}
			const token = state.tokens.songs;
			if (!token) { state.index++; continue; }
			const page = await api.searchPageMore(token);
			state.tokens.songs = page.continuation ?? null;
			if (!state.tokens.songs) state.index++;
			return page.items.filter((song) => !song.is_video).map(songToBrowse);
		}

		const category = stream as 'albums' | 'artists' | 'playlists';
		if (!state.started[stream]) {
			state.started[stream] = true;
			const page = await api.searchCardsPage(query, category);
			state.tokens[stream] = page.continuation ?? null;
			if (!state.tokens[stream]) state.index++;
			return page.items;
		}
		const token = state.tokens[stream];
		if (!token) { state.index++; continue; }
		const page = await api.searchCardsMore(token);
		state.tokens[stream] = page.continuation ?? null;
		if (!state.tokens[stream]) state.index++;
		return page.items;
	}
	return [];
}
