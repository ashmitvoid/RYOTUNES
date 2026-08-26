export type ShortcutEventLike = {
	code: string;
	ctrlKey: boolean;
	metaKey: boolean;
	altKey: boolean;
	shiftKey: boolean;
};

export type ShortcutChord = {
	codes: string[];
	primary?: boolean;
	alt?: boolean;
	shift?: boolean | 'any';
	ctrl?: boolean;
	meta?: boolean;
};

/**
 * Match physical keys rather than printable characters. This makes shortcuts stable across
 * keyboard layouts and prevents Shift/IME state from silently changing what an action means.
 */
export function matchesShortcutChord(
	e: ShortcutEventLike,
	chord: ShortcutChord,
	isMacOS: boolean
): boolean {
	if (!chord.codes.includes(e.code)) return false;
	const primaryPressed = isMacOS ? e.metaKey : e.ctrlKey;
	const explicitCtrl = isMacOS ? e.ctrlKey : false;
	const explicitMeta = isMacOS ? false : e.metaKey;
	if (primaryPressed !== Boolean(chord.primary)) return false;
	if (explicitCtrl !== Boolean(chord.ctrl)) return false;
	if (explicitMeta !== Boolean(chord.meta)) return false;
	if (e.altKey !== Boolean(chord.alt)) return false;
	if (chord.shift !== 'any' && e.shiftKey !== Boolean(chord.shift)) return false;
	return true;
}

export function chordSignature(chord: ShortcutChord): string {
	return [
		[...chord.codes].sort().join(','),
		chord.primary ? 'P' : '-',
		chord.ctrl ? 'C' : '-',
		chord.meta ? 'M' : '-',
		chord.alt ? 'A' : '-',
		chord.shift === 'any' ? '*' : chord.shift ? 'S' : '-'
	].join('|');
}
