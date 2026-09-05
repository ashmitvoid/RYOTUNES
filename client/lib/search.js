.pragma library

// The small ranked result set the typeahead surfaces (SearchSuggest, the Ctrl+K palette), ported
// from browse.ts previewMix: the top hit first, then a round-robin across songs / artists / albums
// / playlists rather than six songs, deduped by kind:id. Kept pure so both surfaces show the same
// rows for the same query.
function previewMix(res, limit) {
    limit = limit || 16;
    var out = [];
    var seen = {};
    function push(item) {
        if (!item)
            return;
        var key = item.kind + ":" + item.id;
        if (seen[key])
            return;
        seen[key] = true;
        out.push(item);
    }
    var top = res.top || [];
    for (var i = 0; i < top.length; i++)
        push(top[i]);
    var groups = [res.songs || [], res.artists || [], res.albums || [], res.playlists || []];
    for (var row = 0; out.length < limit; row++) {
        var added = false;
        for (var g = 0; g < groups.length; g++) {
            if (groups[g][row]) { push(groups[g][row]); added = true; }
            if (out.length >= limit)
                break;
        }
        if (!added)
            break;
    }
    return out.slice(0, limit);
}
