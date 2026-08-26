import { getCurrentWebview } from '@tauri-apps/api/webview';
import * as api from '$lib/api';

const MIN = 0.8;
const MAX = 1.4;
const STEP = 0.1;
const DEFAULT = 1.1;

let level = DEFAULT;

function clamp(next: number) {
	return Math.min(Math.max(next, MIN), MAX);
}

function apply(next: number) {
	level = clamp(next);
	getCurrentWebview()
		.setZoom(level)
		.catch(() => {});
}

export function interfaceScalePercent() {
	return Math.round(level * 100);
}

export async function setInterfaceScale(percent: number, persist = true) {
	const next = clamp(percent / 100);
	apply(next);
	if (persist) await api.setSetting('ui_scale', String(Math.round(next * 100)));
}

export function zoomIn() {
	void setInterfaceScale((level + STEP) * 100);
}

export function zoomOut() {
	void setInterfaceScale((level - STEP) * 100);
}

export function zoomReset() {
	void setInterfaceScale(DEFAULT * 100);
}

export function initZoom() {
	apply(DEFAULT);
	api.getSettings()
		.then((settings) => {
			const saved = Number(settings.ui_scale);
			if (Number.isFinite(saved) && saved >= MIN * 100 && saved <= MAX * 100) apply(saved / 100);
		})
		.catch(() => {});

	const onWheel = (e: WheelEvent) => {
		if (!e.ctrlKey) return;
		e.preventDefault();
		void setInterfaceScale((level + (e.deltaY < 0 ? STEP : -STEP)) * 100);
	};
	window.addEventListener('wheel', onWheel, { passive: false });
	return () => {
		window.removeEventListener('wheel', onWheel);
	};
}
