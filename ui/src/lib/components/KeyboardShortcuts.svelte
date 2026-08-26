<script lang="ts">
	import * as Dialog from '$lib/components/ui/dialog';
	import { KEYBIND_GROUPS, MOD } from '$lib/shortcuts';
	import { ui } from '$lib/player.svelte';
</script>

<Dialog.Root bind:open={ui.shortcutsOpen}>
	<Dialog.Content class="ryo-overlay-sheet sm:max-w-md">
		<Dialog.Header>
			<Dialog.Title>Keyboard shortcuts</Dialog.Title>
			<Dialog.Description>{MOD}H brings this back at any time.</Dialog.Description>
		</Dialog.Header>
		<div class="flex flex-col gap-5">
			{#each KEYBIND_GROUPS as group (group.title)}
				<section>
					<h3 class="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">{group.title}</h3>
					<dl class="flex flex-col gap-1.5">
						{#each group.rows as row (row.id)}
							<div class="flex items-center justify-between gap-4"><dt class="min-w-0 truncate text-sm">{row.label}</dt><dd><kbd class="rounded border bg-muted px-1.5 py-0.5 font-mono text-[0.6875rem] font-medium tracking-wide text-muted-foreground">{row.display}</kbd></dd></div>
						{/each}
					</dl>
				</section>
			{/each}
		</div>
	</Dialog.Content>
</Dialog.Root>
