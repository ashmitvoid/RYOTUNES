<script lang="ts">
	import { fade } from 'svelte/transition';
		import { HugeiconsIcon } from '@hugeicons/svelte';
	import { Maximize01Icon, Minimize01Icon } from '@hugeicons/core-free-icons';
	import LyricsView from './LyricsView.svelte';
	import { np, ui } from '$lib/player.svelte';

	let { onClose, queueOpen = false }: { onClose: () => void; queueOpen?: boolean } = $props();

	function focusLyrics() {
		np.tab = 'lyrics';
		np.lyricsFocus = true;
		np.open = true;
		onClose();
	}
</script>


<button
	class="absolute inset-0 z-20 cursor-default bg-black/40 lg:hidden"
	onclick={onClose}
	aria-label="Close lyrics"
	transition:fade={{ duration: 90 }}
></button>
<aside
	transition:fade={{ duration: 210 }}
	class={`ryo-float-panel absolute inset-y-0 right-0 z-30 flex h-full w-80 max-w-[80vw] flex-col border-l bg-card ${queueOpen ? 'lg:right-80' : ''}`}
>
	<div class="flex items-center justify-between border-b px-4 py-3">
		<h2 class="ryo-panel-title">// LYRICS</h2>
		<button
			onclick={focusLyrics}
			class="cursor-pointer text-muted-foreground transition-colors hover:text-foreground"
			aria-label="Open lyrics focus"
		>
			
			<HugeiconsIcon
				icon={Maximize01Icon}
				altIcon={Minimize01Icon}
				showAlt={false}
				class="h-4 w-4"
			/>
		</button>
	</div>
	<LyricsView expanded={false} />
</aside>
