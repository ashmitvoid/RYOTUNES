import { matchesShortcutChord, type ShortcutChord, type ShortcutEventLike } from './shortcut-match.ts';

function ok(condition: unknown, message: string): asserts condition {
	if (!condition) throw new Error(`shortcut regression: ${message}`);
}
const ev = (code: string, mods: Partial<ShortcutEventLike> = {}): ShortcutEventLike => ({
	code,
	ctrlKey: false,
	metaKey: false,
	altKey: false,
	shiftKey: false,
	...mods
});
const ctrlK: ShortcutChord = { codes: ['KeyK'], primary: true };
const slash: ShortcutChord = { codes: ['Slash'] };
const zoomIn: ShortcutChord = { codes: ['Equal', 'NumpadAdd'], primary: true, shift: 'any' };

ok(matchesShortcutChord(ev('KeyK', { ctrlKey: true }), ctrlK, false), 'Ctrl+K must match on Linux');
ok(!matchesShortcutChord(ev('KeyK'), ctrlK, false), 'bare K must not match Ctrl+K');
ok(matchesShortcutChord(ev('KeyK', { metaKey: true }), ctrlK, true), 'Cmd+K must match on macOS');
ok(!matchesShortcutChord(ev('KeyK', { ctrlKey: true }), ctrlK, true), 'Ctrl+K must not masquerade as Cmd+K on macOS');
ok(matchesShortcutChord(ev('Slash'), slash, false), 'slash page-search must match by physical key');
ok(!matchesShortcutChord(ev('Slash', { ctrlKey: true }), slash, false), 'modified slash must not trigger page-search');
ok(matchesShortcutChord(ev('Equal', { ctrlKey: true }), zoomIn, false), 'Ctrl+= must zoom in');
ok(matchesShortcutChord(ev('Equal', { ctrlKey: true, shiftKey: true }), zoomIn, false), 'Ctrl++ must zoom in');
ok(matchesShortcutChord(ev('NumpadAdd', { ctrlKey: true }), zoomIn, false), 'numpad add must zoom in');
console.log('Shortcut matching: OK');
