import * as api from '$lib/api';
import { appearance, setRyokuSystemTheme } from '$lib/theme.svelte';

const LIVE_KEYS = [
	'--ryo-paper',
	'--ryo-paper-lift',
	'--ryo-panel',
	'--ryo-card',
	'--ryo-sidebar-surface',
	'--ryo-player-surface',
	'--ryo-ink',
	'--ryo-ink-dim',
	'--ryo-ink-muted',
	'--ryo-ink-faint',
	'--ryo-bone',
	'--ryo-ink-on-bone',
	'--ryo-light-sage',
	'--ryo-light-sage-strong',
	'--ryo-light-on-sage',
	'--ryo-light-blue',
	'--ryo-light-blue-strong',
	'--ryo-light-on-blue',
	'--ryo-light-clay',
	'--ryo-light-clay-strong',
	'--ryo-light-on-clay',
	'--ryo-light-gold',
	'--ryo-light-rose'
] as const;

/**
 * Mirror Ryoku.Ui.Singletons.Tokens inside WebKit.
 *
 * Ryoku Settings/Hub, Ryowalls and RyoStore all resolve the same three live files through the
 * shared Tokens singleton. The Rust host mirrors that chain and pushes a complete token payload
 * over a Tauri event whenever theme.json, shell.json or colors.json changes. There is deliberately
 * no frontend polling interval: idle playback stays asleep and theme changes still arrive
 * immediately.
 */
export function initRyokuLiveTokens() {
	let stopped = false;
	let last = '';
	let current: api.RyokuThemeTokens | null = null;
	let unlisten: (() => void) | undefined;
	let generation = 0;
	let resolveReady!: () => void;
	let readySettled = false;
	const ready = new Promise<void>((resolve) => (resolveReady = resolve));

	const settleReady = () => {
		if (!readySettled) {
			readySettled = true;
			resolveReady();
		}
	};

	const clearPalette = () => {
		const root = document.documentElement;
		for (const key of LIVE_KEYS) root.style.removeProperty(key);
		setRyokuSystemTheme(null);
		root.dataset.ryokuPalette = 'local';
	};

	const apply = (t: api.RyokuThemeTokens) => {
		if (stopped) return;
		current = t;
		const root = document.documentElement;

		// Accent + motion always follow Ryoku when available, even if the user deliberately picks
		// a local Light/Dark override for the rest of Ryotunes.
		root.style.setProperty('--ryo-system-accent', t.primary);
		root.style.setProperty('--ryo-sun', t.primary);
		const scale = t.reduceMotion ? 0 : Math.max(0.05, t.motionScale || 1);
		root.style.setProperty('--ryo-snap', `${Math.round(90 * scale)}ms`);
		root.style.setProperty('--ryo-move', `${Math.round(170 * scale)}ms`);
		root.style.setProperty('--ryo-swap', `${Math.round(210 * scale)}ms`);
		root.style.setProperty('--ryo-flap', `${Math.round(110 * scale)}ms`);
		root.dataset.ryokuReducedMotion = t.reduceMotion ? 'true' : 'false';

		// Full palette ownership matches the rest of Ryoku while Follow system is selected. Explicit
		// Light/Dark remains a real Ryotunes override, not a misleading switch.
		if (!t.detected || appearance.themeMode !== 'system') {
			clearPalette();
			return;
		}

		const pairs: Record<string, string> = {
			'--ryo-paper': t.paper,
			'--ryo-paper-lift': t.paperLift,
			'--ryo-panel': t.panel,
			'--ryo-card': t.card,
			'--ryo-sidebar-surface': t.sidebar,
			'--ryo-player-surface': t.player,
			'--ryo-ink': t.ink,
			'--ryo-ink-dim': t.inkDim,
			'--ryo-ink-muted': `color-mix(in srgb, ${t.inkDim} 78%, transparent)`,
			'--ryo-ink-faint': `color-mix(in srgb, ${t.inkDim} 55%, transparent)`,
			'--ryo-bone': t.bone,
			'--ryo-ink-on-bone': t.inkOnBone,

			// The richer v2.3 light treatment keeps its structure, but its colour families now come
			// straight from Material roles instead of fixed sage/blue/clay hex values.
			'--ryo-light-sage': t.secondaryContainer,
			'--ryo-light-sage-strong': t.secondary,
			'--ryo-light-on-sage': t.onSecondary,
			'--ryo-light-blue': t.primaryContainer,
			'--ryo-light-blue-strong': t.primary,
			'--ryo-light-on-blue': t.onPrimary,
			'--ryo-light-clay': t.tertiaryContainer,
			'--ryo-light-clay-strong': t.tertiary,
			'--ryo-light-on-clay': t.onTertiary,
			'--ryo-light-gold': t.secondaryContainer,
			'--ryo-light-rose': t.tertiary
		};
		for (const [key, value] of Object.entries(pairs)) root.style.setProperty(key, value);

		setRyokuSystemTheme(t.light);
		root.dataset.ryokuPalette = t.source;
	};

	const accept = (t: api.RyokuThemeTokens) => {
		generation += 1;
		const sig = JSON.stringify(t);
		if (sig === last) {
			current = t;
			settleReady();
			return;
		}
		last = sig;
		apply(t);
		settleReady();
	};

	const refresh = async () => {
		const mine = ++generation;
		try {
			const t = await api.ryokuThemeTokens();
			if (stopped || mine !== generation) return;
			const sig = JSON.stringify(t);
			if (sig !== last) {
				last = sig;
				apply(t);
			}
		} catch {
			// Outside Ryoku the CSS signature defaults remain authoritative.
		} finally {
			settleReady();
		}
	};

	// Native inotify delivers a fully resolved token payload after the producing file has closed or
	// been atomically moved into place. No debounce timer and no second filesystem read are needed.
	void api.onRyokuThemeChanged(accept).then((fn) => {
		if (stopped) fn();
		else unlisten = fn;
	});

	const wake = () => {
		if (!document.hidden) void refresh();
	};
	const appearanceChanged = () => {
		if (current) apply(current);
		else void refresh();
	};

	void refresh();
	window.addEventListener('focus', wake);
	document.addEventListener('visibilitychange', wake);
	window.addEventListener('ryotunes-appearance-changed', appearanceChanged);

	return {
		ready,
		destroy() {
			stopped = true;
			unlisten?.();
			window.removeEventListener('focus', wake);
			document.removeEventListener('visibilitychange', wake);
			window.removeEventListener('ryotunes-appearance-changed', appearanceChanged);
		}
	};
}
