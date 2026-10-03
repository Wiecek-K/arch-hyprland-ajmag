// Pure logic of the tray menu (ticket 09): entry label and check mark.
// A JS module (not QML) so tools/test-bar-tray.mjs can test it with node.
// Own implementation; enum values as DankMaterialShell Modules/DankBar/Widgets/SystemTrayBar.qml reads them:
// https://github.com/AvengeMedia/DankMaterialShell@9dc5b2c5af7d18b7231f425fe0d8fa7243233109

const CHECK_BOX = 1; // QsMenuButtonType.CheckBox
const RADIO_BUTTON = 2; // QsMenuButtonType.RadioButton
const UNCHECKED = 0; // Qt.Unchecked; partially checked shows as checked

export const SUBMENU_ICON = "\u{f0142}"; // chevron right
export const BACK_ICON = "\u{f0141}"; // chevron left

// DBusMenu labels mark the access key with "_" ("_Quit"); "__" is a literal underscore.
export function menuLabel(text) {
    return (text ?? "").replace(/__|_/g, match => match === "__" ? "_" : "");
}

export function checkMark(buttonType, checkState) {
    const on = checkState !== UNCHECKED;
    if (buttonType === CHECK_BOX)
        return on ? "\u{f0132}" : "\u{f0131}";
    if (buttonType === RADIO_BUTTON)
        return on ? "\u{f043e}" : "\u{f043d}";
    return "";
}

// Applets whose job a Bar island does (Wi-Fi, BT): they keep running (nm-applet asks for Wi-Fi
// passwords, blueman-applet is the pairing agent), only their tray icon is hidden (user, 2026-10-01).
const HIDDEN_IDS = ["nm-applet", "blueman"]; // StatusNotifierItem Id

export function shownInTray(id) {
    return !HIDDEN_IDS.includes(id);
}
