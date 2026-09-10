# Pywal16 + mako Integration Guide

## Overview

This guide explains how to configure **mako** (Wayland notification daemon) to sync its theme colors with wallpaper changes via pywal16.

### What This Achieves

- **mako notification colors** (background, text, border) automatically match wallpaper
- **Per-urgency and per-app color overrides** stay themed too (e.g. critical alerts, weather popups)
- All updates happen automatically when you run `wal -i image.png`
- Note: Terminal colors are a separate pywal16 feature; refer to [DEVELOPMENT.md](DEVELOPMENT.md) for the full pywal workflow
- Note: Want sway itself themed too? See the `colors-sway` template already in this repo

---

## Quick Start

### 1. Ensure pywal16 is Installed

```bash
which wal
wal --version  # Should show 3.8.x or higher
```

### 2. Ensure mako is Installed

```bash
which mako
mako --version
```

### 3. Symlink a Stable Config Path

pywal16 regenerates `~/.cache/wal/colors-mako-theme` on every `wal` run, but mako expects its config at a fixed path. Point mako's config at the generated file via a symlink:

```bash
mkdir -p ~/.config/mako
ln -sf ~/.cache/wal/colors-mako-theme ~/.config/mako/config
```

### 4. Generate Initial Theme

```bash
# Option A: Generate from image directly
wal -i ~/Images/Wallpaper/your-image.png

# Option B: Use symlink workflow (recommended)
ln -sf ~/Images/Wallpaper/your-image.png ~/Images/background.png
wal -i ~/Images/background.png
```

### 5. Reload mako

Unlike rmpc, mako does **not** hot-reload its config automatically — you must tell it to reload:

```bash
makoctl reload
```

Add this to your `wal` post-hook (see [Extending with Hooks](#extending-with-hooks)) so it happens automatically on every wallpaper change.

---

## Workflow: Using Symlink for Wallpaper

Since you manage wallpapers via symlink, here's the typical workflow:

```bash
# 1. Change wallpaper by updating symlink
ln -sf ~/Images/Wallpaper/my-new-wallpaper.png ~/Images/background.png

# 2. Generate pywal colors from symlink target
wal -i ~/Images/background.png

# 3. Reload mako (if not already hooked in)
makoctl reload

# Result: Terminal colors + sway colors + mako theme all update
```

**Why this works:**

- Symlink always points to current wallpaper
- Running `wal -i ~/Images/background.png` picks up the current target
- `makoctl reload` re-reads the config at `~/.config/mako/config`, which is the symlink to the freshly generated theme

---

## How It Works

### Generated Theme File

After running `wal`, pywal16 generates: `~/.cache/wal/colors-mako-theme`

mako reads it via the stable symlink at `~/.config/mako/config` (see [Quick Start](#3-symlink-a-stable-config-path)).

**Contents** (example):

```ini
background-color=#1e1e2eee
text-color=#cdd6f4
border-color=#89b4fa
progress-color=over #313244

[urgency=low]
border-color=#a6adc8

[urgency=normal]
border-color=#89b4fa

[urgency=critical]
border-color=#f38ba8
default-timeout=0

[app-name="weather"]
border-color=#f9e2af
```

**What's Updated:**

- **Background/foreground/border colors** — pulled straight from pywal's 16-color palette
- **Per-urgency overrides** — low/normal/critical each get a palette color, with critical pinned to `default-timeout=0` so it never auto-dismisses
- **Per-app overrides** — e.g. `[app-name="weather"]` gets its own accent color
- **Hex format** — pywal substitutes `{colorN}` directly as `#RRGGBB`; alpha (e.g. `ee`) is appended manually in the template where needed

### No Auto-Reload (Unlike rmpc)

mako does not watch its config file for changes. You must run `makoctl reload` after every `wal` run — see [Extending with Hooks](#extending-with-hooks) to automate this.

---

## Customization

### Adjust Which Palette Colors Map Where

Edit `pywal/templates/colors-mako-theme` in this repo. mako has no fixed "N colors" expectation like rmpc's gradient — assign any `{colorN}` to any role:

```ini
border-color={color4}      # change to {color2}, {color6}, etc.
text-color={foreground}
background-color={background}ee
```

### Adjust Background Opacity

The `ee` suffix on `background-color={background}ee` is a hex alpha channel (0–255, or `00`–`ff`). Lower it for more transparency:

```ini
background-color={background}cc   # more transparent
background-color={background}ff   # fully opaque
```

Regenerate after editing: `wal -i image.png`

### Add More Per-App Overrides

Add additional `[app-name="..."]` blocks to the template for any app whose `notify-send -a <name>` you want styled distinctly:

```ini
[app-name="Spotify"]
border-color={color5}
default-timeout=5000
```

### Merge with a Custom mako Config

If you have existing mako settings you don't want pywal to touch (e.g. custom bindings), keep them in a second file and `include` it in the template:

```ini
# pywal/templates/colors-mako-theme
background-color={background}ee
text-color={foreground}
border-color={color4}

include=~/.config/mako/custom.conf
```

Then put static settings (keybinds, grouping rules, etc.) in `~/.config/mako/custom.conf`, which pywal never regenerates.

---

## Troubleshooting

### mako Reports Config Errors / Won't Start

**Cause**: Theme file doesn't exist yet, or the symlink is missing/broken

**Solution**:

```bash
# Generate theme (if not already done)
wal -i ~/Images/Wallpaper/image.png

# Verify the generated file exists
ls -la ~/.cache/wal/colors-mako-theme

# Verify the symlink exists and points to it
ls -la ~/.config/mako/config

# Try mako directly to see the error
mako
```

### Colors Not Updating When I Run `wal`

**Cause**: `makoctl reload` isn't being called — mako has no hot-reload

**Solution**:

```bash
# Manually confirm reload works
makoctl reload

# Verify the config actually changed
cat ~/.config/mako/config | grep border-color
```

If the file itself has new values but the popup still looks stale, mako just hasn't been told to reload — add `makoctl reload` to your `wal` post-hook (see below).

### Notifications Look Right After Reload, But Old Ones On Screen Don't Change

**Cause**: mako only applies new styling to *new* notifications; already-visible popups keep their original styling until dismissed.

**Solution**: This is expected — no fix needed. It'll be correct on the next notification.

### Per-App Override Not Applying

**Cause**: `app-name` in mako's config must match what the app reports via D-Bus, which isn't always the binary name.

**Solution**:

```bash
# Send a test notification with an explicit app-name
notify-send -a "weather" "Test" "Checking app-name match"

# Check mako's actual notification history for the app-name it saw
makoctl history
```

Adjust the `[app-name="..."]` block in the template to match exactly, then regenerate and reload.

### Critical Notifications Look Muddy / Low Contrast

**Cause**: Some generated palettes don't have a strong "red" or high-contrast color at `{color1}`, depending on the wallpaper.

**Solutions**:

1. Try a different image: `wal -i different-image.png`
2. Use the contrast flag: `wal -i image.png --contrast 2.0`
3. Try a different backend: `wal --backend colorz -i image.png`
4. Hardcode just that line in the template instead of using a palette variable:
   ```ini
   [urgency=critical]
   border-color=#f38ba8
   ```

---

## Testing

### Verify Theme Generation

```bash
# Run wal
wal -i ~/test.png

# Check generated theme (via the stable symlink)
cat ~/.config/mako/config

# Should show hex values, not template variables
# Good: border-color=#89b4fa
# Bad:  border-color={color4}
```

### Test Color Updates

```bash
# Update symlink to different image (recommended workflow)
ln -sf ~/Images/Wallpaper/different-image.png ~/Images/background.png

# Generate colors
wal -i ~/Images/background.png

# Reload mako
makoctl reload

# Check theme was updated
stat ~/.config/mako/config          # Should show recent timestamp
cat ~/.config/mako/config | grep '#'  # Should show new hex values

# Fire a test notification to see it live
notify-send "Test" "Does this match the new palette?"
```

### Compare with Terminal / sway

```bash
# After running wal, terminal, sway, and mako should all match
# Terminal colors: cat ~/.cache/wal/sequences
# sway colors:     cat ~/.cache/wal/colors-sway
# mako theme:      cat ~/.config/mako/config
```

---

## Extending with Hooks

### Run Custom Script After `wal`

You can run additional commands when wal generates colors:

```bash
wal -i image.png -o ~/.local/bin/wal-post-hook.sh
```

**Example hook** (`~/.local/bin/wal-post-hook.sh`):

```bash
#!/bin/bash
# Run after wal generates colors

# Reload mako (required — no hot-reload)
makoctl reload

# Reload rmpc / other apps (if applicable)
pkill -HUP rmpc

# Reload sway config to pick up new colors-sway values
swaymsg reload

# Custom integration
# ... your logic here ...

echo "Pywal update complete!"
```

Make it executable:

```bash
chmod +x ~/.local/bin/wal-post-hook.sh
```

### Alternative: Systemd User Timer

For periodic wallpaper changes, reuse the same timer/service pattern as [RMPC_SETUP.md](RMPC_SETUP.md#alternative-systemd-user-timer) — `wal-post-hook.sh` above already covers mako's reload, so no mako-specific timer is needed.

---

## Files

### Generated Files

- `~/.cache/wal/colors-mako-theme` — Theme for mako
- `~/.cache/wal/colors.json` — Full palette
- `~/.cache/wal/sequences` — Terminal escape sequences

### Modified Files

- `~/.config/mako/config` — Symlink to the generated theme

### Template (in pywal16 repo)

- `pywal/templates/colors-mako-theme` — Template file for mako's config

---

## Further Reading

- [RMPC_SETUP.md](RMPC_SETUP.md) — Matching colors for rmpc + embedded Cava
- [CAVA_SETUP.md](CAVA_SETUP.md) — Matching colors for the standalone `cava` binary
- [Pywal16 Architecture](DEVELOPMENT.md) — How pywal16 works
- [mako Documentation](https://github.com/emersion/mako) — Full mako config options (`man 5 mako`)

---

## Troubleshooting Checklist

- [ ] `wal` command available: `which wal`
- [ ] `mako` command available: `which mako`
- [ ] Symlink exists: `ls -la ~/.config/mako/config`
- [ ] Theme has hex values (not variables): `cat ~/.config/mako/config | grep '#'`
- [ ] `makoctl reload` runs without error
- [ ] Reload hooked into `wal` post-hook script: `grep makoctl ~/.local/bin/wal-post-hook.sh`
- [ ] Different wallpaper tested: `wal -i different-image.png`
- [ ] Test notification fired and matches palette: `notify-send "Test" "Check colors"`
