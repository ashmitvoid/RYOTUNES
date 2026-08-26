<script lang="ts">
	// Arrange home: drag the sections into the order you want them, hide the ones you don't. Nothing
	// is written until Save, so dismissing the modal any other way (Esc, the overlay, the ✕) throws
	// the edit away — which is why the list below is a working copy and not `personal` itself.
	//
	// Note: drag is the only way to reorder, matching the Shortcuts grid. Hiding works from the
	// keyboard; wire arrow-key moves onto the rows if anyone asks.
	import { untrack } from 'svelte';
	import { flip } from 'svelte/animate';
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import {
		Cancel02Icon,
		DragDropHorizontalIcon,
		SaveIcon,
		RefreshIcon,
		ViewIcon,
		ViewOffSlashIcon
	} from '@hugeicons/core-free-icons';
	import { Button } from '$lib/components/ui/button';
	import * as Dialog from '$lib/components/ui/dialog';
	import { personal, saveHomeLayout } from '$lib/player.svelte';
	import { arrangeSections, hiddenSections } from '$lib/personal';

	let {
		open = $bindable(false),
		sections
	}: { open: boolean; sections: { key: string; title: string; available?: boolean }[] } = $props();

	type Row = { key: string; title: string; shown: boolean; available: boolean };
	let rows = $state<Row[]>([]);
	// Keep drag identity separate from insertion position. The list remains stable under the pointer
	// while dragging; a rule shows the exact insertion slot and the reorder commits once on drop.
	let draggingKey = $state<string | null>(null);
	let insertAt = $state<number | null>(null);

	// Snapshotted when the modal opens, not derived: the feed keeps appending shelves as the page
	// behind loads, and a list that grows mid-drag reshuffles under the cursor. Hence `untrack` —
	// `open` is the only thing that may re-run this, or the reset lands in the middle of an edit.
	$effect(() => {
		if (!open) return;
		untrack(() => {
			const hidden = hiddenSections(personal);
			rows = arrangeSections(sections, personal).map((s) => ({
				...s,
				available: s.available !== false,
				shown: !hidden.has(s.key)
			}));
			draggingKey = null;
			insertAt = null;
		});
	});

	/** Commit the working-copy reorder once. `slot` is an insertion index from 0..rows.length. */
	function commitDrop(slot: number) {
		if (!draggingKey) return;
		const from = rows.findIndex((row) => row.key === draggingKey);
		if (from < 0) return;
		const next = rows.slice();
		const [moved] = next.splice(from, 1);
		const adjusted = Math.max(0, Math.min(next.length, slot - (from < slot ? 1 : 0)));
		next.splice(adjusted, 0, moved);
		rows = next;
		draggingKey = null;
		insertAt = null;
	}

	function clearDrag() {
		draggingKey = null;
		insertAt = null;
	}

	function resetDefaults() {
		// Keep the authoritative registry order and reveal all supported entries. Nothing persists until Save.
		rows = sections.map((section) => ({
			...section,
			available: section.available !== false,
			shown: true
		}));
		clearDrag();
	}

	function save() {
		saveHomeLayout(
			rows.map((r) => r.key),
			rows.filter((r) => !r.shown).map((r) => r.key)
		);
		open = false;
	}
</script>

<Dialog.Root bind:open>
	<Dialog.Content class="ryo-overlay-sheet ryo-overlay-sheet-flush gap-0 overflow-hidden p-0 sm:max-w-md">
		<div class="border-b px-5 py-4">
			<Dialog.Title class="text-lg font-semibold">Edit home</Dialog.Title>
			<Dialog.Description class="text-xs text-muted-foreground">
				Drag to reorder. Hidden sections stay off Home; unavailable sections are remembered but not fetched yet.
			</Dialog.Description>
		</div>

		<div role="list" class="max-h-[24rem] min-h-[12rem] overflow-y-auto p-2">
			{#each rows as row, i (row.key)}
				
				<div
					role="listitem"
					draggable="true"
					animate:flip={{ duration: 170 }}
					ondragstart={(e) => {
						draggingKey = row.key;
						insertAt = i;
						e.dataTransfer?.setData('text/plain', row.key);
						if (e.dataTransfer) e.dataTransfer.effectAllowed = 'move';
					}}
					ondragover={(e) => {
						if (!draggingKey) return;
						e.preventDefault();
						const rect = e.currentTarget.getBoundingClientRect();
						insertAt = e.clientY >= rect.top + rect.height / 2 ? i + 1 : i;
					}}
					ondrop={(e) => { e.preventDefault(); commitDrop(insertAt ?? i); }}
					ondragend={clearDrag}
					class="relative flex cursor-grab items-center gap-2 rounded-lg py-2 pl-3 pr-2 transition-colors hover:bg-muted/50 {draggingKey === row.key ? 'bg-muted opacity-55' : ''}"
				>
					{#if draggingKey && insertAt === i}
						<span class="ryo-home-insert-rule pointer-events-none absolute inset-x-2 top-0 h-0.5 rounded-full bg-primary" aria-hidden="true"></span>
					{/if}
					<div class="min-w-0 flex-1">
						<span class="block truncate text-sm {row.shown ? '' : 'text-muted-foreground'}">{row.title}</span>
						<small class="mt-0.5 block text-[9px] uppercase tracking-[.12em] text-muted-foreground/70">
							{row.available ? (row.shown ? 'Visible' : 'Hidden') : (row.shown ? 'Temporarily unavailable' : 'Hidden · unavailable')}
						</small>
					</div>
					<button
						onclick={() => (row.shown = !row.shown)}
						title={row.shown ? 'Hide from home' : 'Show on home'}
						aria-label={row.shown ? `Hide ${row.title}` : `Show ${row.title}`}
						class="flex h-8 w-8 shrink-0 cursor-pointer items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
					>
						
						<HugeiconsIcon
							icon={ViewIcon}
							altIcon={ViewOffSlashIcon}
							showAlt={!row.shown}
							class="h-4 w-4"
						/>
					</button>
					<span
						aria-hidden="true"
						class="flex h-8 w-8 shrink-0 items-center justify-center text-muted-foreground/60"
					>
						<HugeiconsIcon icon={DragDropHorizontalIcon} class="h-4 w-4" />
					</span>
					{#if draggingKey && insertAt === rows.length && i === rows.length - 1}
						<span class="ryo-home-insert-rule pointer-events-none absolute inset-x-2 bottom-0 h-0.5 rounded-full bg-primary" aria-hidden="true"></span>
					{/if}
				</div>
			{/each}
		</div>

		<div class="flex items-center justify-between gap-2 border-t px-5 py-3">
			<Button variant="ghost" size="sm" onclick={resetDefaults}>
				<HugeiconsIcon icon={RefreshIcon} class="h-4 w-4" /> Reset default
			</Button>
			<div class="flex justify-end gap-2">
			<Button variant="outline" size="sm" onclick={() => (open = false)}>
				<HugeiconsIcon icon={Cancel02Icon} class="h-4 w-4" />
				Cancel
			</Button>
				<Button size="sm" onclick={save}>
					<HugeiconsIcon icon={SaveIcon} class="h-4 w-4" />
					Save
				</Button>
			</div>
		</div>
	</Dialog.Content>
</Dialog.Root>
