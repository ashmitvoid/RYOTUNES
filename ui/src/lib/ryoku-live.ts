import * as api from '$lib/api';

/**
 * Mirror Ryoku.Ui Tokens inside WebKit. The Hub and native Ryoku apps watch the
 * same files; Ryotunes polls lightly because Tauri already owns the file access.
 * When the wallpaper/theme or motion preference changes, the application shell
 * follows without a restart. Outside Ryoku, the Rust command returns the
 * signature defaults and this remains harmless.
 */
export function initRyokuLiveTokens() {
	let stopped = false;
	let last = '';

	const apply = (t: api.RyokuThemeTokens) => {
		const root = document.documentElement;
		// Ryoku supplies identity (accent + motion), while Ryotunes owns comfortable light/dark
		// surfaces. Importing wallpaper paper/ink colours directly made light mode flash pure white
		// and could destroy contrast when a wallpaper palette was extreme.
		const pairs: Record<string, string> = {
			'--ryo-system-accent': t.sun,
			'--ryo-sun': t.sun
		};
		for (const [k, v] of Object.entries(pairs)) root.style.setProperty(k, v);

		const scale = t.reduceMotion ? 0 : Math.max(0.05, t.motionScale || 1);
		root.style.setProperty('--ryo-snap', `${Math.round(90 * scale)}ms`);
		root.style.setProperty('--ryo-move', `${Math.round(170 * scale)}ms`);
		root.style.setProperty('--ryo-swap', `${Math.round(210 * scale)}ms`);
		root.style.setProperty('--ryo-flap', `${Math.round(110 * scale)}ms`);
		root.dataset.ryokuPalette = t.source;
		root.dataset.ryokuReducedMotion = t.reduceMotion ? 'true' : 'false';
	};

	let refreshing = false;

	const refresh = async () => {
		if (stopped || refreshing || document.hidden) return;
		refreshing = true;
		try {
			const t = await api.ryokuThemeTokens();
			if (stopped) return;
			const sig = JSON.stringify(t);
			if (sig === last) return;
			last = sig;
			apply(t);
		} catch {
			// Not running inside Ryoku, or the backend is still starting. The CSS
			// signature defaults remain valid; the next cadence can try again.
		} finally {
			refreshing = false;
		}
	};

	// Theme files change rarely. 1.6s polling kept both WebKit and Tauri waking constantly
	// while a music app sat idle. Refresh immediately when the window comes back, otherwise use
	// a deliberately sleepy cadence. Hidden/minimised windows do no theme I/O at all.
	const wake = () => { if (!document.hidden) void refresh(); };
	void refresh();
	const timer = window.setInterval(refresh, 60_000);
	window.addEventListener('focus', wake);
	document.addEventListener('visibilitychange', wake);
	return () => {
		stopped = true;
		window.clearInterval(timer);
		window.removeEventListener('focus', wake);
		document.removeEventListener('visibilitychange', wake);
	};
}
