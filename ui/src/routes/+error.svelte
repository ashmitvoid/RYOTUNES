<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import { AlertCircleIcon, RefreshIcon, Home01Icon } from '@hugeicons/core-free-icons';
	import { Button } from '$lib/components/ui/button';
</script>

<div class="ryo-route-failure" role="alert">
	<div class="ryo-route-failure-mark"><HugeiconsIcon icon={AlertCircleIcon} class="h-6 w-6" /></div>
	<p class="ryo-route-failure-kicker">RYOTUNES / RECOVERY</p>
	<h1>This view could not be opened.</h1>
	<p>{page.error?.message ?? 'An unexpected interface error occurred. Playback can continue while the view recovers.'}</p>
	<div class="ryo-route-failure-actions">
		<Button variant="outline" onclick={() => location.reload()}><HugeiconsIcon icon={RefreshIcon} class="h-4 w-4" />Reload view</Button>
		<Button onclick={() => goto('/')}><HugeiconsIcon icon={Home01Icon} class="h-4 w-4" />Home</Button>
	</div>
</div>
