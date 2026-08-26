-- Ryotunes v2.2 — Ryoku-native main-window policy.
--
-- Ryoku Settings, Ryowalls and Ryovm are ordinary toplevel windows; Ryoku floats them with an
-- `hl.window_rule` before map. Ryotunes follows that same compositor-owned pattern. Match the exact
-- main title so the separate "Ryotunes Mini" surface is never caught by this rule.
hl.window_rule({
    name   = "float-ryotunes-custom",
    match  = { title = "^(Ryotunes)$" },
    float  = true,
    center = true,
})
