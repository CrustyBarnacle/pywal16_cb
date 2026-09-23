#!/usr/bin/env bash
# Reloads sway/waybar/mako/kitty/ghostty/rmpc after a `wal` run.
#
# Per-app behavior (researched 2026-09-20, see RMPC_SETUP.md/CAVA_SETUP.md
# for background):
#   sway     - swaymsg reload, always safe
#   waybar   - SIGUSR2 (on-sigusr2 defaults to "reload"); known upstream gaps:
#              tooltip styles and idle-inhibitor state don't always survive
#   mako     - makoctl reload, no known issues
#   kitty    - SIGUSR1 per instance; only affects already-running windows
#   ghostty  - SIGUSR2 ONLY - any other signal crashes it (ghostty >= 1.2)
#   rmpc UI  - hot-reloads on its own via file watch, no signal needed
#   rmpc Cava pane - passive file-watch hot-reload doesn't reliably pick up
#              cava options (github.com/mierak/rmpc/issues/621), but
#              `rmpc remote set theme <path>` is an explicit push that's
#              confirmed working (tested 2026-09-20). Used below instead of
#              relying on the file watcher.
#   standalone cava - no reload signal, restart-only, not handled here.

set -uo pipefail

reload_sway() {
    command -v swaymsg >/dev/null || return 0
    swaymsg reload
}

reload_waybar() {
    pgrep -x waybar >/dev/null || return 0
    killall -SIGUSR2 waybar
}

reload_mako() {
    command -v makoctl >/dev/null || return 0
    makoctl reload
}

reload_kitty() {
    # Reloads every running kitty instance's OS window that has the
    # remote-control socket enabled (allow_remote_control in kitty.conf).
    pgrep -x kitty >/dev/null || return 0
    for pid in $(pgrep -x kitty); do
        kill -SIGUSR1 "$pid" 2>/dev/null
    done
}

reload_ghostty() {
    pgrep -x ghostty >/dev/null || return 0
    for pid in $(pgrep -x ghostty); do
        kill -SIGUSR2 "$pid" 2>/dev/null
    done
}

reload_rmpc() {
    command -v rmpc >/dev/null || return 0
    pgrep -x rmpc >/dev/null || return 0
    rmpc remote set theme ~/.config/rmpc/themes/colors.ron
}

reload_sway
reload_waybar
reload_mako
reload_kitty
reload_ghostty
reload_rmpc

echo "wal-reload: sway/waybar/mako/kitty/ghostty/rmpc reloaded."
