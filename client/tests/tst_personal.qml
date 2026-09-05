import QtQuick
import QtTest
import "../lib/personal.js" as P

// The personal store's pure reducers, run without Quickshell (Personal.qml imports Daemon). These
// are ports of ui/src/lib/personal.check.ts: the rules that are easy to get wrong — recency that
// refreshes but never reorders, a removal that permanently blocks the suggestion, the Home
// arrangement's stable unranked sort and one-time '@familiar' slotting, and hydrate degrading junk
// to empty instead of throwing.
TestCase {
    name: "Personal"

    function item(id) { return { kind: "playlist", id: id, title: id }; }
    function ids(list) { return list.map(function (x) { return x.id; }).join(","); }
    function keys(list) { return list.map(function (x) { return x.key; }).join(","); }
    function secs() { return Array.prototype.slice.call(arguments).map(function (k) { return { key: k }; }); }

    // addPick appends and refreshes recency; touchPick refreshes without reordering.
    function test_addpick_and_touchpick() {
        var p = P.empty();
        P.addPick(p, item("a"), 100);
        P.addPick(p, item("b"), 200);
        compare(P.addPick(p, item("a"), 300), false);   // a repeat add reports "already there"
        compare(p.picks.length, 2);                      // and does not duplicate
        compare(p.picks.filter(function (x) { return x.id === "a"; })[0].lastUsedAt, 300); // but refreshes
        P.addPick(p, item("c"), 250);
        compare(ids(p.picks), "a,b,c");                  // display order is add order
        compare(P.touchPick(p, "b", 99999), true);
        compare(ids(p.picks), "a,b,c");                  // playing a tile does not move it
        compare(P.touchPick(p, "nope", 1), false);       // a tile not on the grid reports no change
    }

    // A seeded suggestion is refusable, and a removal permanently blocks re-suggestion while still
    // letting the user add it back by hand.
    function test_seed_and_remove_are_permanent() {
        var p = P.empty();
        verify(P.seedPick(p, item("onrepeat")));
        verify(!P.seedPick(p, item("onrepeat")));        // already on the grid
        P.removePick(p, "onrepeat");
        compare(p.picks.length, 0);
        verify(!P.seedPick(p, item("onrepeat")));        // a removed suggestion never comes back
        verify(!P.seedPick(p, item("onrepeat"), 9999));  // not on a later visit either
        compare(P.addPick(p, item("onrepeat"), 1), true); // the user can still add it manually
        compare(ids(p.picks), "onrepeat");
        P.removePick(p, "onrepeat");
        verify(!P.seedPick(p, item("onrepeat")));        // removing again re-arms the dismissal
    }

    // recentItems: newest played-from first, capped by n, empty when nothing played.
    function test_recent_items() {
        var p = P.empty();
        compare(P.recentItems(p).length, 0);
        P.noteRecent(p, item("a"), 100);
        P.noteRecent(p, item("b"), 300);
        P.noteRecent(p, item("c"), 200);
        compare(ids(P.recentItems(p)), "b,c,a");
        compare(ids(P.recentItems(p, 2)), "b,c");
    }

    // noteArtist accumulates play counts and updates the name; topArtistIds keeps only channel-keyed
    // (UC…) entries, ordered by plays.
    function test_note_artist_and_top_ids() {
        var p = P.empty();
        P.noteArtist(p, "UCb", "B");
        P.noteArtist(p, "UCb", "B");
        P.noteArtist(p, "UCa", "A");
        P.noteArtist(p, "Some Band", "Some Band"); // name-keyed: no channel to open
        compare(p.artists["UCb"].count, 2);
        compare(p.artists["UCa"].count, 1);
        compare(P.topArtistIds(p).join(","), "UCb,UCa"); // plays desc, name-keyed dropped
        compare(P.topArtistIds(p, 1).join(","), "UCb");
        compare(P.topArtistIds(P.empty()).length, 0);
        // A later note updates the display name even when it started blank.
        P.noteArtist(p, "UCc", "");
        P.noteArtist(p, "UCc", "C");
        compare(p.artists["UCc"].name, "C");
        compare(p.artists["UCc"].count, 2);
    }

    // firstArtist takes the lead credit out of a joined artist string.
    function test_first_artist() {
        compare(P.firstArtist("Daft Punk"), "Daft Punk");
        compare(P.firstArtist("Daft Punk, Pharrell Williams"), "Daft Punk");
        compare(P.firstArtist("The Weeknd & Ariana Grande"), "The Weeknd");
        compare(P.firstArtist("Drake feat. Rihanna"), "Drake");
    }

    // arrangeSections: saved order wins, hidden ones still return, unranked hold their feed order
    // (they must not compare as NaN), an empty feed is fine.
    function test_arrange_sections() {
        var p = P.empty();
        compare(keys(P.arrangeSections(secs("a", "b", "c"), p)), "a,b,c");
        p.home = { order: ["c", "a"], hidden: ["a"], seen: [] };
        compare(keys(P.arrangeSections(secs("a", "b", "c"), p)), "c,a,b");
        compare(keys(P.arrangeSections(secs("z", "y", "c"), p)), "c,z,y");
        compare(keys(P.arrangeSections([], p)), "");
    }

    // hydrate degrades junk to empty rather than throwing, caps pins, drops malformed tiles and
    // auto-seeded ones from the old build, and filters junk dismissals.
    function test_hydrate_tolerates_junk() {
        compare(P.hydrate(null).picks.length, 0);
        compare(P.hydrate("nonsense").pins.length, 0);
        compare(P.hydrate({ pins: ["a", "b", "c", "d", "e"] }).pins.length, 3);
        compare(P.hydrate({ picks: [{ id: "a" }, {}] }).picks.length, 1);
        var migrated = P.hydrate({ picks: [{ id: "kept", manual: true }, { id: "seeded", manual: false }, { id: "new" }] });
        compare(migrated.picks.map(function (x) { return x.id; }).join(","), "kept,new");
        compare(P.hydrate({ dismissedSeeds: ["a", 7] }).dismissedSeeds.join(","), "a");
    }

    // The Home arrangement survives a round trip, slots '@familiar' into an order saved before it
    // existed exactly once, and degrades a corrupt one instead of throwing.
    function test_hydrate_home_arrangement() {
        var p = P.empty();
        p.home = { order: ["@recent", "Listen again"], hidden: ["@forgotten"], seen: ["Listen again"] };
        var back = P.hydrate(JSON.parse(JSON.stringify(p)));
        compare(back.home.order.join(","), "@recent,@familiar,Listen again");
        compare(back.home.hidden.join(","), "@forgotten");
        compare(back.home.seen.join(","), "Listen again");
        compare(P.hydrate({ home: { order: ["Listen again"], hidden: [] } }).home.order.join(","), "Listen again,@familiar");
        // Slotting happens once, not on every load.
        compare(P.hydrate(JSON.parse(JSON.stringify(back))).home.order.join(","), back.home.order.join(","));
        compare(P.hydrate({}).home.order.length, 0);
        compare(P.hydrate({ home: { order: [1, "a"], hidden: "nope" } }).home.order.join(","), "a,@familiar");
    }
}
