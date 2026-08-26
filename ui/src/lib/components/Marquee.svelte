<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		text,
		children,
		class: cls = ''
	}: {
		text: string;
		children?: Snippet;
		class?: string;
	} = $props();
</script>

<div class="min-w-0 overflow-hidden {cls}" title={text}>
	<span class="block truncate">
		{#if children}{@render children()}{:else}{text}{/if}
	</span>
</div>
