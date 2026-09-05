/**
 * Seek-thumb release safety net for the range inputs in the player bar and the mini player.
 *
 * Both hold the dragged value locally (`seekDrag`) so mpv's position ticks cannot yank the thumb
 * while the pointer is down, and commit on the input's `change` event. WebKitGTK only fires
 * `change` for a release it actually receives: let go of the thumb outside the window (the bar
 * sits on the window's bottom edge, so dragging past it is one flick away) and neither `change`
 * nor `pointerup` arrives. The local value then shadows every later tick and the timeline
 * freezes for the rest of the session while playback carries on.
 *
 * This attachment commits the pending drag on every signal that the button is no longer down:
 * `pointerup`/`pointercancel`/`lostpointercapture` on the input, the window losing focus, and,
 * for the release nobody delivered, the first pointer movement anywhere with no button held.
 */
export function seekReleaseGuard(pending: () => boolean, commit: () => void) {
	return (input: HTMLInputElement) => {
		const release = () => {
			if (pending()) commit();
		};
		const onWindowMove = (e: PointerEvent) => {
			if (e.buttons === 0) release();
		};
		input.addEventListener('pointerup', release);
		input.addEventListener('pointercancel', release);
		input.addEventListener('lostpointercapture', release);
		window.addEventListener('pointermove', onWindowMove, { passive: true });
		window.addEventListener('blur', release);
		return () => {
			input.removeEventListener('pointerup', release);
			input.removeEventListener('pointercancel', release);
			input.removeEventListener('lostpointercapture', release);
			window.removeEventListener('pointermove', onWindowMove);
			window.removeEventListener('blur', release);
		};
	};
}
