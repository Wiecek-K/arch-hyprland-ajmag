// Pure logic of the workspace overview (overview/Overview.qml, faza C ticket cb44): the 2×5 grid, the windows
// scaled into its cells, the swap of two whole workspaces, the Lua dispatch strings.
// A JS module (not QML) so tools/test-overview.mjs can test it with node.
// Grid and window placement after end-4/dots-hyprland OverviewWidget.qml / OverviewWindow.qml:
// https://github.com/end-4/dots-hyprland/blob/2f0c8bf/dots/.config/quickshell/ii/modules/ii/overview/
// Copyright (C) end-4 and contributors — GPL-3.0
// Changes: fixed 2×5 grid (no rows/columns/order options), moved out of QML into a tested module.
// SPDX-License-Identifier: AGPL-3.0-or-later

import { focusRequest, luaString } from "../bar/workspaces.mjs";

export const ROWS = 2;
export const COLUMNS = 5;
export const WORKSPACES = Array.from({ length: ROWS * COLUMNS }, (_, i) => i + 1);

// row and column (0-based) of a workspace, or null outside 1-10
export function cellOf(workspace) {
    if (!Number.isInteger(workspace) || workspace < 1 || workspace > ROWS * COLUMNS)
        return null;
    return { row: Math.floor((workspace - 1) / COLUMNS), col: (workspace - 1) % COLUMNS };
}

// monitor: Hyprland's monitor object (hyprctl monitors -j / lastIpcObject); reserved = [left, top, right, bottom]
// in logical pixels (the Bar's band). Returns the area windows tile in, in logical (layout) coordinates.
export function usableArea(monitor) {
    const rotated = (monitor.transform ?? 0) % 2 === 1;
    const scale = monitor.scale || 1;
    const width = (rotated ? monitor.height : monitor.width) / scale;
    const height = (rotated ? monitor.width : monitor.height) / scale;
    const [left, top, right, bottom] = monitor.reserved ?? [0, 0, 0, 0];
    return { x: monitor.x + left, y: monitor.y + top, width: width - left - right, height: height - top - bottom };
}

// scale of a cell to the usable area, so the whole grid fits maxWidth × maxHeight with `spacing` between cells
export function fitScale(area, maxWidth, maxHeight, spacing) {
    const byWidth = (maxWidth - (COLUMNS - 1) * spacing) / (COLUMNS * area.width);
    const byHeight = (maxHeight - (ROWS - 1) * spacing) / (ROWS * area.height);
    return Math.min(byWidth, byHeight);
}

// a window (at, size, monitor id from lastIpcObject) inside a cell of cellWidth × cellHeight: the same share of the
// cell as of its own monitor's usable area, cut to the cell, in whole pixels; null when its monitor is unknown
export function windowRect(window, monitors, cellWidth, cellHeight) {
    const monitor = monitors.find(m => m.id === window.monitor);
    if (!monitor)
        return null;
    const area = usableArea(monitor);
    const sx = cellWidth / area.width;
    const sy = cellHeight / area.height;
    const left = Math.max(0, (window.at[0] - area.x) * sx);
    const top = Math.max(0, (window.at[1] - area.y) * sy);
    const right = Math.min(cellWidth, (window.at[0] - area.x + window.size[0]) * sx);
    const bottom = Math.min(cellHeight, (window.at[1] - area.y + window.size[1]) * sy);
    const x = Math.round(left);
    const y = Math.round(top);
    return { x, y, width: Math.max(1, Math.round(right) - x), height: Math.max(1, Math.round(bottom) - y) };
}

const windowSelector = address => luaString("address:" + address);

// to another workspace without following it (the overview stays where it is)
export function moveRequest(address, workspace) {
    return `hl.dsp.window.move({ workspace = ${workspace}, follow = false, window = ${windowSelector(address)} })`;
}

// middle click on a thumbnail (user, 2026-11-12)
export function closeRequest(address) {
    return `hl.dsp.window.close({ window = ${windowSelector(address)} })`;
}

export function focusWorkspaceRequest(workspace) {
    return focusRequest(workspace);
}

// tiled windows in reading order (top row first, then left to right), floating ones after them, so the tiling
// is built again in about the same order and the floating windows stay on top
function moveOrder(a, b) {
    if (a.floating !== b.floating)
        return a.floating ? 1 : -1;
    return a.at[1] - b.at[1] || a.at[0] - b.at[0];
}

// the dispatches that swap the contents of workspaces a and b (user's idea, 2026-10-01): Hyprland has no such
// dispatcher, so a's windows go to b, then b's own windows go to a. windows: {address, workspace, floating, at}
export function swapPlan(windows, a, b) {
    if (a === b)
        return [];
    const on = id => windows.filter(w => w.workspace === id).sort(moveOrder);
    const fromA = on(a);
    const fromB = on(b);
    return [...fromA.map(w => moveRequest(w.address, b)), ...fromB.map(w => moveRequest(w.address, a))];
}
