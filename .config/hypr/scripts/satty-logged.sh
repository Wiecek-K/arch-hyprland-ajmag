#!/usr/bin/env bash
# Runs satty with its arguments and records what happened, so a random freeze
# ("satty is not responding") leaves data for later debugging without reproducing it.
# Log: ${XDG_STATE_HOME:-~/.local/state}/satty/satty.log (rotated to satty.log.1 above 1 MiB)
# Per run: start line with the arguments, satty's own stdout/stderr (RUST_BACKTRACE=1),
# every 2 s while it runs: process state, what the main thread waits on (wchan), child
# processes (e.g. wl-copy from --copy-command); end line with exit code / signal and run time.
# Called from screenshot.sh. Parked issue: ~/Projects/hyprland-lua-migration/plan/zaparkowane.md

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/satty"
LOG="$LOG_DIR/satty.log"
mkdir -p "$LOG_DIR"
if [[ -f "$LOG" ]] && (($(stat -c %s "$LOG") > 1048576)); then
    mv -f "$LOG" "$LOG.1"
fi

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

log "=== start: satty $* ($(satty --version 2>/dev/null))"
start=$SECONDS

RUST_BACKTRACE=1 satty "$@" >> "$LOG" 2>&1 &
pid=$!

# sample the process while it runs (satty is open for seconds, so only a few lines)
while kill -0 "$pid" 2>/dev/null; do
    sleep 2
    [[ -r /proc/$pid/stat ]] || break
    state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null)
    wchan=$(cat "/proc/$pid/wchan" 2>/dev/null)
    children=$(ps --ppid "$pid" -o comm=,pid=,stat= 2>/dev/null | tr -s ' ' | paste -sd ';')
    log "    +$((SECONDS - start))s state=$state wchan=${wchan:-?} children=[${children}]"
done

wait "$pid"
code=$?
if ((code > 128)); then
    log "=== end: killed by SIG$(kill -l $((code - 128))) after $((SECONDS - start))s"
else
    log "=== end: exit $code after $((SECONDS - start))s"
fi
exit "$code"
