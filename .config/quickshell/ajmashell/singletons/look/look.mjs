// Pure logic of Look.qml (faza E ticket 13, ADR 0021): the look in the live file read leniently, as
// look_settings.load() reads it for Theme Center. Lists, ranges and defaults come from look-options.json.
// Tests: ~/Projects/hyprland-lua-migration/tools/test-look.mjs

// {field: [check(value) → bool, what the field wants]} in file order
function fields(options) {
    const a = options.alpha;
    const out = {
        background: [v => typeof v === "string" && options.roles.includes(v), "a role of look-options.json"],
        alpha: [v => typeof v === "number" && Number.isFinite(v) && v >= a.min && v <= a.max, `a number from ${a.min} to ${a.max}`]
    };
    for (const f of options.flags)
        out[f] = [v => typeof v === "boolean", "true or false"];
    return out;
}

// text: the live file's text, null when there is no file. → {look, warnings: [text]}; never throws.
export function resolve(options, text) {
    const look = Object.assign({}, options.defaults);
    if (text === null)
        return { look, warnings: [] };
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return { look, warnings: [`not valid JSON (${e.message}); using the defaults`] };
    }
    if (data === null || typeof data !== "object" || Array.isArray(data))
        return { look, warnings: ["not a JSON object; using the defaults"] };
    const want = fields(options);
    const warnings = Object.keys(data).filter(k => !(k in want)).map(k => `unknown field '${k}' ignored`);
    for (const [key, [check, what]] of Object.entries(want)) {
        if (!(key in data))
            continue;
        if (check(data[key]))
            look[key] = data[key];
        else
            warnings.push(`${key} = ${JSON.stringify(data[key])} is not ${what}; using the default`);
    }
    return { look, warnings };
}

// The look of a preset, null for an unknown name (IPC `look set`)
export function preset(options, name) {
    return Object.prototype.hasOwnProperty.call(options.presets, name) ? Object.assign({}, options.presets[name]) : null;
}
