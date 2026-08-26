<script lang="ts">
	import { HugeiconsIcon, type IconSvgElement } from '@hugeicons/svelte';
	import { ArrowRight01Icon } from '@hugeicons/core-free-icons';
	import type { Snippet } from 'svelte';

	let {
		title,
		icon,
		onMore,
		moreLabel = 'See all',
		headingClass = 'ryo-section-heading-text',
		lead,
		children
	}: {
		title: string;
		icon?: IconSvgElement;
		onMore?: () => void;
		moreLabel?: string;
		headingClass?: string;
		lead?: Snippet;
		children?: Snippet;
	} = $props();
</script>

<div class="mb-3 flex items-center gap-3">
	{#if icon}
		{#key icon}
			<HugeiconsIcon {icon} class="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
		{/key}
	{/if}
	{#if onMore}
		<button class="min-w-0 cursor-pointer text-left" onclick={onMore} title="{moreLabel} {title}">
			<h2 class="{headingClass} truncate hover:underline"><span class="ryo-slashes">//</span> {title}</h2>
		</button>
	{:else}
		<h2 class="{headingClass} min-w-0 truncate"><span class="ryo-slashes">//</span> {title}</h2>
	{/if}
	{@render lead?.()}
	<div class="ryo-section-rule"></div>
	{@render children?.()}
	{#if onMore}
		<button
			class="flex shrink-0 cursor-pointer items-center gap-1 text-[10px] font-medium tracking-[0.08em] text-muted-foreground hover:text-foreground"
			onclick={onMore}
		>
			{moreLabel.toUpperCase()}
			<HugeiconsIcon icon={ArrowRight01Icon} class="h-3.5 w-3.5" />
		</button>
	{/if}
</div>
