#!/usr/bin/env bash
# Reloads sway/waybar/mako/kitty/ghostty/rmpc after a `wal` run.
#
# Per-app behavior (researched 2026-09-20, see RMPC_SETUP.md/CAVA_SETUP.md
# for background):
#   sway     - swaymsg reload, always safe
#   waybar   - NOT signaled here. If launched via sway's `swaybar_command`
#              (bar { swaybar_command waybar }), sway supervises that
#              process directly and already kills+respawns it as part of
#              `swaymsg reload` - sending SIGUSR2 on top of that races/
#              conflicts with sway's own supervision and kills the bar
#              instead of reloading it (confirmed 2026-09-24). If you
#              instead launch waybar via a plain `exec waybar` (not under
#              sway's bar supervision), uncomment reload_waybar below -
#              that's the case SIGUSR2 was originally written for.
#   mako     - makoctl reload, no known issues
#   kitty    - SIGUSR1 per instance; only affects already-running windows
#   ghostty  - SIGUSR2 ONLY - any other signal crashes it (ghostty >= 1.2)
#   rmpc UI  - hot-reloads on its own via file watch, no signal needed
#   rmpc Cava pane - passive file-watch hot-reload doesn't reliably pick up
#              cava options (github.com/mierak/rmpc/issues/621), but
#              `rmpc remote set theme <path>` is an explicit push that's
#              confirmed working (tested 2026-09-20). Used below instead of
#              relying on the file watcher.
#   standalone cava - no reload signal, restart-only. Its INI format has
#              no include=-style merge directive (unlike mako), so the
#              generated colors-cava template is colors-only (just
#              [color]) and sync_cava_config() below splices it into the
#              static ~/.config/cava/config between marker comments on
#              every run, rather than symlinking the whole file. The
#              markers make the splice safe regardless of where [color]
#              sits in the file - no positional convention to rely on.
#              Restart cava manually after this to pick up the change
#              (see CAVA_SETUP.md).

set -uo pipefail

reload_sway() {
    command -v swaymsg >/dev/null || return 0
    swaymsg reload
}

reload_waybar() {
    # Only safe if waybar is launched via a plain `exec waybar`, not via
    # sway's `swaybar_command` (which already respawns it on `swaymsg
    # reload` - see note above). Not called by default; uncomment the
    # call in the run list below if your setup needs it.
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

sync_cava_config() {
    local static_config="$HOME/.config/cava/config"
    local generated="$HOME/.cache/wal/colors-cava"
    local begin_marker="## BEGIN colors (managed - do not edit within markers) ##"
    local end_marker="## END colors ##"
    [ -f "$generated" ] || return 0
    mkdir -p "$(dirname "$static_config")"
    touch "$static_config"

    if grep -qF "$begin_marker" "$static_config"; then
        # Replace the marked block in place, wherever it sits in the file.
        awk -v begin="$begin_marker" -v end="$end_marker" -v genfile="$generated" '
            $0 == begin { print; while ((getline line < genfile) > 0) print line; skip=1; next }
            $0 == end { print; skip=0; next }
            skip { next }
            { print }
        ' "$static_config" >"${static_config}.tmp" && mv "${static_config}.tmp" "$static_config"
    else
        # First run: no markers yet, append a fresh marked block.
        {
            echo ""
            echo "$begin_marker"
            cat "$generated"
            echo "$end_marker"
        } >>"$static_config"
    fi
}

reload_sway
# reload_waybar  # see note above - only if waybar is NOT sway-supervised
reload_mako
reload_kitty
reload_ghostty
reload_rmpc
sync_cava_config

echo "wal-reload: sway/mako/kitty/ghostty/rmpc reloaded (waybar covered by sway reload); cava config synced (restart cava manually to pick it up)."
