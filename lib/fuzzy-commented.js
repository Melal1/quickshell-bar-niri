/*
 * Build the searchable text fields for one desktop entry.
 *
 * A launcher app can have a visible name, a generic name, and keywords.
 * All of those fields are treated as searchable text.
 */
function haystacks(e) {
    var parts = [];

    // Main visible app name, for example "Firefox" or "Kitty".
    if (e.name) parts.push(String(e.name));

    // Generic app type, for example "Web Browser" or "Terminal Emulator".
    if (e.genericName) parts.push(String(e.genericName));

    // Extra keywords from the desktop file, if the app provides them.
    if (e.keywords) for (var i = 0; i < e.keywords.length; i++) parts.push(String(e.keywords[i]));

    return parts;
}

/*
 * Check whether every character in `needle` appears in `hay` in the same order.
 *
 * This is the loose fuzzy part:
 *   "ffx" matches "firefox" because f -> f -> x appear in order.
 *   "fxf" does not match "firefox" because the order is wrong.
 */
function subsequence(needle, hay) {
    // `j` is the current position inside the search query.
    var j = 0;

    // Walk through the app text and advance `j` whenever the next query char matches.
    for (var i = 0; i < hay.length && j < needle.length; i++)
        if (hay[i] === needle[j]) j++;

    // If `j` reached the query length, every query character was found in order.
    return j === needle.length;
}

/*
 * Score one app against the current search query.
 *
 * Lower score is better:
 *   0  = app name starts with the query
 *   1  = query appears anywhere in name/genericName/keywords
 *   2  = query characters appear in order with gaps allowed
 *   99 = no match
 */
function score(e, q) {
    // Prefix matches on the app name are the strongest matches.
    var name = (e.name || "").toLowerCase();
    if (name.indexOf(q) === 0) return 0;

    // Search every text field and keep the best score seen.
    var fields = haystacks(e);
    var best = 99;

    for (var i = 0; i < fields.length; i++) {
        var f = fields[i].toLowerCase();

        // Direct substring match is good, but weaker than name-prefix match.
        if (f.indexOf(q) !== -1) { best = Math.min(best, 1); continue; }

        // Subsequence match is looser, so it gets the weaker fuzzy score.
        if (subsequence(q, f)) best = Math.min(best, 2);
    }

    return best;
}

/*
 * Return how many times this app has been launched before.
 *
 * `usage` is loaded from the launcher usage JSON file and keyed by app id:
 *   { "firefox.desktop": 12, "kitty.desktop": 5 }
 */
function uses(usage, e) {
    // Missing usage data, missing app, or missing id all count as zero launches.
    if (!usage || !e || !e.id) return 0;

    var c = usage[e.id];

    // Only real numbers are trusted. Any bad value falls back to zero.
    return typeof c === "number" ? c : 0;
}

/*
 * Main function used from QML:
 *   Fuzzy.rank(allEntries, query, usage)
 *
 * It returns a new app list sorted for display in the launcher.
 */
function rank(entries, query, usage) {
    // Usage is optional. If the usage file is missing or invalid, use an empty map.
    usage = usage || {};

    // Remove hidden desktop entries so they do not appear in launcher results.
    var visible = [];
    for (var i = 0; i < entries.length; i++)
        if (!entries[i].noDisplay) visible.push(entries[i]);

    // Normalize the query once so matching is trimmed and case-insensitive.
    var q = (query || "").trim().toLowerCase();

    /*
     * Empty search mode:
     * show all visible apps, with most-used apps first.
     * Apps with the same usage count are sorted alphabetically.
     */
    if (q.length === 0)
        return visible.slice().sort(function (a, b) {
            var ua = uses(usage, a);
            var ub = uses(usage, b);

            // Higher launch count appears earlier.
            if (ua !== ub) return ub - ua;

            // Alphabetical fallback keeps the list stable.
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
        });

    /*
     * Search mode:
     * score every visible app against the query and keep only matched apps.
     */
    var scored = [];
    for (var k = 0; k < visible.length; k++) {
        var s = score(visible[k], q);

        // Score 99 means no match, so that app is hidden from this result set.
        if (s < 99) scored.push({ e: visible[k], s: s });
    }

    /*
     * Sort matched apps:
     *   1. better fuzzy score first
     *   2. higher usage count first
     *   3. alphabetical fallback
     */
    scored.sort(function (a, b) {
        // Lower fuzzy score is better.
        if (a.s !== b.s) return a.s - b.s;

        // More frequently launched apps win score ties.
        var ua = uses(usage, a.e);
        var ub = uses(usage, b.e);
        if (ua !== ub) return ub - ua;

        // Final fallback keeps ordering deterministic.
        return (a.e.name || "").toLowerCase().localeCompare((b.e.name || "").toLowerCase());
    });

    // Convert [{ e: app, s: score }, ...] back into [app, ...] for QML ListView.
    return scored.map(function (x) { return x.e; });
}
