<script lang="ts">
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import { ListRestartIcon, HistoryIcon, RefreshIcon, MusicNote01Icon } from '@hugeicons/core-free-icons';
	import { ON_REPEAT_ID, RECENTLY_PLAYED_ID, REDISCOVER_ID } from '$lib/api';

	let { id, class: klass = '' }: { id: string; class?: string } = $props();
	const mode = $derived(id === ON_REPEAT_ID ? 'repeat' : id === RECENTLY_PLAYED_ID ? 'recent' : id === REDISCOVER_ID ? 'rediscover' : 'generic');
	const icon = $derived(mode === 'repeat' ? ListRestartIcon : mode === 'recent' ? HistoryIcon : mode === 'rediscover' ? RefreshIcon : MusicNote01Icon);
</script>

<span class="ryo-smart-playlist-art {mode} {klass}" aria-hidden="true">
	<HugeiconsIcon {icon} class="h-[44%] w-[44%]" />
	<i>///</i>
</span>
