// Pure logic of the clock's calendar popup (ticket 42): month grid from Monday with ISO week numbers,
// month scrolling, Polish names, Polish statutory days off.
// A JS module (not QML) so tools/test-calendar.mjs can test it with node.
// Own implementation, no donor. Computed locally, no network (user decision 2026-10-14); the test compares the
// current year and 5 years ahead with the Nager.Date and OpenHolidays APIs.
// Source of the rules: ustawa z 18 stycznia 1951 r. o dniach wolnych od pracy (Dz.U. 1951 nr 4 poz. 28),
// art. 1, as amended: Epiphany from 2011, Christmas Eve from 2025. A change of the law = edit FIXED below + the test.

const DAY = 86400000; // ms

// Days off with a fixed date: [month, day, name, first year]
const FIXED = [
    [1, 1, "Nowy Rok", 0],
    [1, 6, "Święto Trzech Króli", 2011],
    [5, 1, "Święto Pracy", 0],
    [5, 3, "Święto Konstytucji 3 Maja", 0],
    [8, 15, "Wniebowzięcie Najświętszej Maryi Panny", 0],
    [11, 1, "Wszystkich Świętych", 0],
    [11, 11, "Narodowe Święto Niepodległości", 0],
    [12, 24, "Wigilia Bożego Narodzenia", 2025],
    [12, 25, "Boże Narodzenie", 0],
    [12, 26, "Drugi Dzień Bożego Narodzenia", 0],
];

// Movable days off: [days after Easter Sunday, name]
const MOVABLE = [
    [0, "Wielkanoc"],
    [1, "Poniedziałek Wielkanocny"],
    [49, "Zielone Świątki"],
    [60, "Boże Ciało"],
];

function pad(n) {
    return String(n).padStart(2, "0");
}

function iso(date) {
    return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

function easterDate(year) {
    // Anonymous Gregorian algorithm (Meeus/Jones/Butcher)
    const a = year % 19, b = Math.floor(year / 100), c = year % 100;
    const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
    const g = Math.floor((b - f + 1) / 3);
    const h = (19 * a + b - d - g + 15) % 30;
    const i = Math.floor(c / 4), k = c % 4;
    const l = (32 + 2 * e + 2 * i - h - k) % 7;
    const m = Math.floor((a + 11 * h + 22 * l) / 451);
    const month = Math.floor((h + l - 7 * m + 114) / 31);
    const day = ((h + l - 7 * m + 114) % 31) + 1;
    return new Date(Date.UTC(year, month - 1, day));
}

export function easter(year) {
    return iso(easterDate(year));
}

// { "YYYY-MM-DD": name } sorted by date
export function holidaysPL(year) {
    const out = [];
    for (const [month, day, name, from] of FIXED)
        if (year >= from)
            out.push([`${year}-${pad(month)}-${pad(day)}`, name]);
    const e = easterDate(year);
    for (const [offset, name] of MOVABLE)
        out.push([iso(new Date(e.getTime() + offset * DAY)), name]);
    out.sort((x, y) => (x[0] < y[0] ? -1 : 1));
    const result = {}; // no Object.fromEntries: Qt's JS engine (V4) lacks it
    for (const [date, name] of out)
        result[date] = name;
    return result;
}

const cache = {};

// month 1–12. off: Sunday or a statutory holiday; name: the holiday's name ("" for a plain Sunday)
export function dayOff(year, month, day) {
    const h = cache[year] || (cache[year] = holidaysPL(year));
    const name = h[`${year}-${pad(month)}-${pad(day)}`] || "";
    const sunday = new Date(Date.UTC(year, month - 1, day)).getUTCDay() === 0;
    return { off: sunday || name !== "", name };
}

export const WEEKDAYS = ["Pn", "Wt", "Śr", "Cz", "Pt", "So", "Nd"];
const MONTHS = ["Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
    "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień"];

export function title(year, month) {
    return `${MONTHS[month - 1]} ${year}`;
}

// ISO 8601 week number: weeks start on Monday, week 1 holds the year's first Thursday
export function isoWeek(year, month, day) {
    const d = new Date(Date.UTC(year, month - 1, day));
    d.setUTCDate(d.getUTCDate() + 3 - (d.getUTCDay() + 6) % 7); // Thursday of this week
    const jan1 = Date.UTC(d.getUTCFullYear(), 0, 1);
    return Math.floor((d.getTime() - jan1) / DAY / 7) + 1;
}

// 6 weeks × 7 days from the Monday on or before the 1st, so the popup never changes height:
// [{ week, days: [{ year, month, day, inMonth }] }]
export function monthGrid(year, month) {
    const first = new Date(Date.UTC(year, month - 1, 1));
    const start = first.getTime() - ((first.getUTCDay() + 6) % 7) * DAY;
    const weeks = [];
    for (let w = 0; w < 6; w++) {
        const days = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(start + (w * 7 + i) * DAY);
            const m = d.getUTCMonth() + 1;
            days.push({ year: d.getUTCFullYear(), month: m, day: d.getUTCDate(), inMonth: m === month });
        }
        weeks.push({ week: isoWeek(days[0].year, days[0].month, days[0].day), days });
    }
    return weeks;
}

// month 1–12, delta in months
export function shiftMonth(year, month, delta) {
    const n = year * 12 + month - 1 + delta;
    return { year: Math.floor(n / 12), month: (n % 12 + 12) % 12 + 1 };
}

// --- Left panel: today or the clicked day (user, 2026-10-14) ---

const WEEKDAY_NAMES = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"];
const MONTHS_GENITIVE = ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca",
    "lipca", "sierpnia", "września", "października", "listopada", "grudnia"];

function utc(d) {
    return Date.UTC(d.year, d.month - 1, d.day);
}

function weekday(d) {
    return new Date(utc(d)).getUTCDay();
}

// first named holiday on or after d (the day itself counts): { year, month, day, name, days }
export function nextHoliday(year, month, day) {
    for (let i = 0; i < 400; i++) {
        const d = new Date(Date.UTC(year, month - 1, day + i));
        const date = { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
        const name = dayOff(date.year, date.month, date.day).name;
        if (name !== "")
            return { year: date.year, month: date.month, day: date.day, name: name, days: i }; // no object spread in V4
    }
    return null;
}

// "dziś", "jutro", "wczoraj", "za N dni", "N dni temu"; today and d: { year, month, day }
export function relative(today, d) {
    const n = Math.round((utc(d) - utc(today)) / DAY);
    if (n === 0)
        return "dziś";
    if (n === 1)
        return "jutro";
    if (n === -1)
        return "wczoraj";
    return n > 0 ? `za ${n} dni` : `${-n} dni temu`;
}

// Texts of the left panel for the day d. when: distance from today ("" for today). holiday: its name, "" if none.
// next: the next holiday after d (user, 2026-10-14: counted from the clicked day, not from today), only while d is
// not a holiday itself; null otherwise. when: from today; next.when: from d (user, 2026-10-14).
export function describe(d, today) {
    const info = dayOff(d.year, d.month, d.day);
    const h = info.name === "" ? nextHoliday(d.year, d.month, d.day) : null;
    return {
        day: d.day,
        weekday: WEEKDAY_NAMES[weekday(d)],
        date: `${d.day} ${MONTHS_GENITIVE[d.month - 1]} ${d.year} · tydzień ${isoWeek(d.year, d.month, d.day)}`,
        when: utc(d) === utc(today) ? "" : relative(today, d),
        off: info.off,
        holiday: info.name,
        next: h && {
            name: h.name,
            date: `${WEEKDAY_NAMES[weekday(h)].toLowerCase()}, ${h.day} ${MONTHS_GENITIVE[h.month - 1]}`,
            when: relative(d, h),
        },
    };
}
