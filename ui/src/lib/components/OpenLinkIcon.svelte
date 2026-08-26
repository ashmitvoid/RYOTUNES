<script lang="ts">
	let { class: className = '' }: { class?: string } = $props();
</script>

<!-- One unmistakable north-east arrow. No box, chain loops, badge, pseudo-element or alternate
     state: at 16px/fractional Wayland scaling there is nothing that can read as a second icon. -->
<svg
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.8"
	stroke-linecap="round"
	stroke-linejoin="round"
	class={className}
	aria-hidden="true"
>
	<path d="M7 17 17 7" />
	<path d="M10 7h7v7" />
</svg>
