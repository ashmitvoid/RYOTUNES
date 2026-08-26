<script lang="ts">
	import { Dialog as DialogPrimitive } from "bits-ui";
	import DialogPortal from "./dialog-portal.svelte";
	import type { Snippet } from "svelte";
	import * as Dialog from "./index.js";
	import { cn, type WithoutChildrenOrChild } from "$lib/utils.js";
	import type { ComponentProps } from "svelte";
	import { Button } from "$lib/components/ui/button/index.js";
	import { HugeiconsIcon } from "@hugeicons/svelte"
	import { Cancel01Icon } from '@hugeicons/core-free-icons';

	let {
		ref = $bindable(null),
		class: className,
		portalProps,
		children,
		showCloseButton = true,
		...restProps
	}: WithoutChildrenOrChild<DialogPrimitive.ContentProps> & {
		portalProps?: WithoutChildrenOrChild<ComponentProps<typeof DialogPortal>>;
		children: Snippet;
		showCloseButton?: boolean;
	} = $props();
</script>

<DialogPortal {...portalProps}>
	<Dialog.Overlay />
	<div class="ryo-overlay-stage pointer-events-none fixed z-50 flex items-center justify-center">
		<DialogPrimitive.Content
			bind:ref
			data-slot="dialog-content"
			class={cn(
				"ryo-dialog-base pointer-events-auto relative grid w-full max-w-[calc(100%-2rem)] gap-5 rounded-[6px] border bg-popover p-5 text-sm text-popover-foreground shadow-none outline-none duration-[90ms] data-open:animate-in data-closed:animate-out data-open:fade-in-0 data-closed:fade-out-0 sm:max-w-md",
				className
			)}
			{...restProps}
		>
			{@render children?.()}
			{#if showCloseButton}
				<DialogPrimitive.Close data-slot="dialog-close">
					{#snippet child({ props })}
						<Button variant="ghost" class="ryo-dialog-close absolute top-3 right-3" size="icon-sm" {...props}>
							<HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
							<span class="sr-only">Close</span>
						</Button>
					{/snippet}
				</DialogPrimitive.Close>
			{/if}
		</DialogPrimitive.Content>
	</div>
</DialogPortal>
