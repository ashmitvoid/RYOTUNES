-- Ryotunes v2.2.1 — Ryoku-native main-window policy.
--
-- Ryoku Settings, Ryowalls and Ryovm are ordinary toplevel windows; Ryoku floats and sizes them
-- with an `hl.window_rule` before map. Ryotunes follows that same compositor-owned pattern.
-- Match the exact main title so the separate "Ryotunes Mini" surface is never caught by this rule.
hl.window_rule({
    name   = "float-ryotunes-custom",
    match  = { title = "^(Ryotunes)$" },
    float  = true,
    size   = { 1760, 1000 },
    center = true,
})
