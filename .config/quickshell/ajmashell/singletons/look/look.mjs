// Pure logic of Look.qml (faza E tickets 13 and 14, ADR 0021): the look in the live file read leniently, as
// look_settings.load() reads it for Theme Center. Lists, ranges and defaults come from look-options.json.
// Tests: ~/Projects/hyprland-lua-migration/tools/test-look.mjs

const number = (v, r) => typeof v === "number" && Number.isFinite(v) && v >= r.min && v <= r.max;

// {field: [check(value) → bool, what the field wants]} of the gradient, in file order
function gradientFields(options) {
    const g = options.gradient;
    const role = [v => typeof v === "string" && options.roles.includes(v), "a role of look-options.json"];
    const range = r => [v => number(v, r), `a number from ${r.min} to ${r.max}`];
    return {
        style: [v => g.styles.some(s => s.name === v), "a style of look-options.json"],
        a: role,
        b: role,
        strength: range(g.strength),
        angle: [v => Number.isInteger(v) && number(v, g.angle), `a whole number from ${g.angle.min} to ${g.angle.max}`],
        reachA: range(g.reach),
        reachB: range(g.reach)
    };
}

// {field: [check(value) → bool, what the field wants]} in file order, without the gradient
function fields(options) {
    const a = options.alpha;
    const out = {
        background: [v => typeof v === "string" && options.roles.includes(v), "a role of look-options.json"],
        alpha: [v => number(v, a), `a number from ${a.min} to ${a.max}`]
    };
    for (const f of options.flags)
        out[f] = [v => typeof v === "boolean", "true or false"];
    return out;
}

const isObject = v => v !== null && typeof v === "object" && !Array.isArray(v);

// the valid fields of data over the defaults; prefix names the field in a warning
function merge(defaults, want, data, prefix, warnings) {
    const out = Object.assign({}, defaults);
    for (const k of Object.keys(data))
        if (!(k in want))
            warnings.push(`unknown field '${prefix}${k}' ignored`);
    for (const [key, [check, what]] of Object.entries(want)) {
        if (!(key in data))
            continue;
        if (check(data[key]))
            out[key] = data[key];
        else
            warnings.push(`${prefix}${key} = ${JSON.stringify(data[key])} is not ${what}; using the default`);
    }
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
    if (!isObject(data))
        return { look, warnings: ["not a JSON object; using the defaults"] };
    const warnings = [];
    const rest = Object.assign({}, data);
    delete rest.gradient; // read below, part by part
    const out = merge(options.defaults, fields(options), rest, "", warnings);
    if ("gradient" in data) {
        if (isObject(data.gradient))
            out.gradient = merge(options.defaults.gradient, gradientFields(options), data.gradient, "gradient.", warnings);
        else
            warnings.push(`gradient = ${JSON.stringify(data.gradient)} is not an object; using the default`);
    }
    return { look: out, warnings };
}

// IPC `look set`: the preset over the look (a preset has no gradient, so the look's own stays); null for an unknown name
export function preset(options, name, look) {
    return Object.prototype.hasOwnProperty.call(options.presets, name) ? Object.assign({}, look, options.presets[name]) : null;
}
