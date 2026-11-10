// Pure logic of the Dyski section of the Centrum sterowania (faza C ticket 06): removable drives (USB sticks, SD
// cards) from LSBLK_COMMAND, one row per drive. A JS module so tools/test-control-drives.mjs can
// test it with node. Own implementation.

// --tree: without the NAME column lsblk lists the partitions flat, beside their disk, not in its `children`
export const LSBLK_COMMAND = ["lsblk", "-J", "-b", "--tree", "-o", "PATH,TYPE,RM,HOTPLUG,MODEL,VENDOR,LABEL,SIZE,FSSIZE,FSUSED,MOUNTPOINT,FSTYPE"];

const GB = 1e9; // decimal, as printed on sticks
const MB = 1e6;

// "12.3 / 31.0 GB"; both in the unit of the size
function usage(used, size) {
    const unit = size >= GB ? GB : MB;
    const digits = unit === GB ? 1 : 0;
    return `${(used / unit).toFixed(digits)} / ${(size / unit).toFixed(digits)} ${unit === GB ? "GB" : "MB"}`;
}

// lsblk: parsed JSON of LSBLK_COMMAND's output
// → [{ path, title, text, mountpoint, mounted, unmounted, mountable }]: mountpoint "" while nothing is mounted (the
// row opens nothing), mounted = device paths of the mounted filesystems (ejectCommand unmounts them), unmounted =
// those that could be mounted (not swap; mountCommand), mountable = nothing mounted yet and something to mount
export function removableDrives(lsblk) {
    return (lsblk?.blockdevices ?? [])
        .filter(d => d.type === "disk" && (d.rm || d.hotplug))
        .map(d => {
            // filesystems: the partitions, or the disk itself (a stick formatted without a partition table)
            const volumes = [d, ...(d.children ?? [])].filter(v => v.fstype);
            const mounted = volumes.filter(v => v.mountpoint?.startsWith("/")); // not "[SWAP]"
            const unmounted = volumes.filter(v => !v.mountpoint && v.fstype !== "swap");
            const used = mounted.reduce((sum, v) => sum + (v.fsused ?? 0), 0);
            const size = mounted.reduce((sum, v) => sum + (v.fssize ?? 0), 0);
            const name = [d.vendor, d.model].map(s => (s ?? "").trim()).filter(s => s).join(" ");
            return {
                path: d.path,
                title: volumes.find(v => v.label)?.label ?? (name || d.path.replace("/dev/", "")),
                text: mounted.length ? usage(used, size) : "Not mounted",
                mountpoint: mounted[0]?.mountpoint ?? "",
                mounted: mounted.map(v => v.path),
                unmounted: unmounted.map(v => v.path),
                mountable: mounted.length === 0 && unmounted.length > 0
            };
        });
}

// Safe eject of a removableDrives row: unmount every mounted filesystem, then power the drive off (udisks2; the
// stick can be pulled out and leaves the list). Stops at the first error, so a busy stick is not powered off.
// Paths go in as arguments, never into the script's text.
export function ejectCommand(drive) {
    const script = 'disk=$1; shift; for p; do udisksctl unmount -b "$p" || exit; done; udisksctl power-off -b "$disk"';
    return ["sh", "-c", script, "eject", drive.path, ...drive.mounted];
}

// stderr of a failed ejectCommand → the row's text
export function ejectError(stderr) {
    return /busy/i.test(stderr) ? "In use: close its files" : "Eject failed";
}

// Mount of a drive with nothing mounted (a click on its row): every filesystem it has, as udiskie does on plug-in;
// stops at the first error. Paths go in as arguments.
export function mountCommand(drive) {
    const script = 'for p; do udisksctl mount -b "$p" || exit; done';
    return ["sh", "-c", script, "mount", ...drive.unmounted];
}

// the row's text after a failed mountCommand
export const MOUNT_FAILED = "Mount failed";
