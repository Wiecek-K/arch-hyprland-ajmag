// Pure logic of Extras.qml (Theme Center 1.0.next ticket tc05): the extras switched on in the live file
// ~/.local/state/ajmashell/extras.json, read leniently, as extras_settings.load() reads it for Theme Center. The list of
// extras comes from extras-options.json; every extra is off unless the file says true.
// Tests: ~/Projects/hyprland-lua-migration/tools/test-extras.mjs
// SPDX-License-Identifier: AGPL-3.0-or-later

const isObject = v => v !== null && typeof v === "object" && !Array.isArray(v);

// text: the live file's text, null when there is no file. → {extras: {name: bool}, warnings: [text]}; never throws.
export function resolve(options, text) {
    const extras = {};
    for (const e of options.extras)
        extras[e.name] = false;
    if (text === null)
        return { extras, warnings: [] };
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return { extras, warnings: [`not valid JSON (${e.message}); every extra off`] };
    }
    if (!isObject(data))
        return { extras, warnings: ["not a JSON object; every extra off"] };
    const warnings = [];
    for (const k of Object.keys(data))
        if (!(k in extras))
            warnings.push(`unknown field '${k}' ignored`);
    for (const name of Object.keys(extras)) {
        if (!(name in data))
            continue;
        if (typeof data[name] === "boolean")
            extras[name] = data[name];
        else
            warnings.push(`${name} = ${JSON.stringify(data[name])} is not true or false; off`);
    }
    return { extras, warnings };
}
