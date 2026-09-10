# Pywal16 + rmpc Integration Guide

## Overview

This guide explains how to configure **rmpc** (Rust MPD client) to sync its theme colors with wallpaper changes via pywal16.

### What This Achieves
- **rmpc UI colors** automatically match wallpaper (via generated theme)
- **Cava visualizer** (embedded in rmpc) gradient automatically updated with wallpaper colors
- All updates happen automatically when you run `wal -i image.png`
- Note: Terminal colors are a separate pywal16 feature; refer to [DEVELOPMENT.md](DEVELOPMENT.md) for the full pywal workflow
- Note: Want the standalone `cava` binary (outside rmpc) to match too? See [CAVA_SETUP.md](CAVA_SETUP.md)

---

## Quick Start

### 1. Ensure pywal16 is Installed
```bash
which wal
wal --version  # Should show 3.8.x or higher
```

### 2. Locate rmpc Config
```bash
# Default location
~/.config/rmpc/config.ron
```

### Load Terminal Colors in New Shells
The `colors-rmpc-theme.ron` template only overrides `default_album_art_path`
and the Cava gradient (both explicit RGB values baked into the file). Every
other rmpc UI color (background, text, borders, highlighted item, etc.) is
**not** set in the theme, so rmpc inherits whatever ANSI colors the terminal
currently has — the same colors your shell prompt and `ls` output use.

`wal` updates those ANSI colors by writing escape sequences to the terminal
it was run from. A brand-new terminal window/tab never saw those sequences,
so it starts with the terminal emulator's default palette until something
re-sends them. This is why Cava's gradient always looks right (it's hardcoded
RGB) while the rest of the rmpc UI looks stale in a fresh terminal.

Fix it by sourcing the sequences file on shell startup, e.g. in `~/.zshrc` or
`~/.bashrc`:
```bash
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences
```

### 3. Symlink a Stable Theme Path
pywal16 regenerates `~/.cache/wal/colors-rmpc-theme.ron` on every `wal` run,
but that raw cache path can be inconvenient to reference directly (and gets
wiped if `~/.cache/wal` is ever cleared). Instead, point rmpc at a themes
directory and symlink the generated file into it:

```bash
mkdir -p ~/.config/rmpc/themes
ln -sf ~/.cache/wal/colors-rmpc-theme.ron ~/.config/rmpc/themes/colors.ron
```

Then edit `~/.config/rmpc/config.ron` (RON format):

```ron
(
    # ... existing settings ...

    # Point theme to the stable symlink (not the raw cache path)
    theme: "~/.config/rmpc/themes/colors.ron",

    # Ensure hot reload is enabled (should be default)
    enable_config_hot_reload: true,

    # ... rest of config ...
)
```

### 4. Generate Initial Theme
```bash
# Option A: Generate from image directly
wal -i ~/Images/Wallpaper/your-image.png

# Option B: Use symlink workflow (recommended)
# Update symlink to point to new image
ln -sf ~/Images/Wallpaper/your-image.png ~/Images/background.png
# Then generate colors
wal -i ~/Images/background.png
```

### 5. Done!
rmpc will automatically hot-reload the theme thanks to `enable_config_hot_reload: true`. No restart needed.

Now whenever you run `wal`, rmpc will automatically update its colors.

---

## Workflow: Using Symlink for Wallpaper

Since you manage wallpapers via symlink, here's the typical workflow:

```bash
# 1. Change wallpaper by updating symlink
ln -sf ~/Images/Wallpaper/my-new-wallpaper.png ~/Images/background.png

# 2. Generate pywal colors from symlink target
wal -i ~/Images/background.png

# Result: Terminal colors + rmpc theme + cava gradient all update automatically
```

**Why this works:**
- Symlink always points to current wallpaper
- Running `wal -i ~/Images/background.png` picks up the current target
- rmpc's `enable_config_hot_reload: true` auto-reloads when theme file changes
- No need to restart anything

---

## How It Works

### Generated Theme File
After running `wal`, pywal16 generates: `~/.cache/wal/colors-rmpc-theme.ron`

rmpc reads it via the stable symlink at `~/.config/rmpc/themes/colors.ron`
(see [Quick Start](#3-symlink-a-stable-theme-path)).

**Contents** (example):
```ron
#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    default_album_art_path: "/home/togusa/Images/default-album-art.png",

    cava: (
        bar_color: Gradient({
            0: "rgb(14,21,32)",
            12: "rgb(41,87,105)",
            25: "rgb(73,79,86)",
            37: "rgb(162,107,127)",
            50: "rgb(26,104,141)",
            62: "rgb(80,115,145)",
            75: "rgb(95,143,168)",
            87: "rgb(194,196,199)",
            100: "rgb(93,100,114)",
        })
    ),
)
```

**What's Updated:**
- **9-point color gradient** — Built from pywal's 16-color palette
- **Album art fallback** — Your default album art image
- **RGB format** — Converted from hex via pywal's `.rgb` property

### Auto-Reload
With `enable_config_hot_reload: true`, rmpc detects when the theme file changes and reloads automatically. No need to restart rmpc.

---

## Customization

### Customize Album Art Path
The template uses a hardcoded path. To change it:

1. Edit `pywal/templates/colors-rmpc-theme.ron`
2. Change the `default_album_art_path` line:
```ron
default_album_art_path: "/your/path/to/default.png",
```

3. Regenerate theme:
```bash
wal -i image.png
```

### Customize Cava Gradient
The gradient uses 9 points (0%, 12%, 25%, 37%, 50%, 62%, 75%, 87%, 100%) and colors 0-8.

To adjust:
1. Edit `pywal/templates/colors-rmpc-theme.ron`
2. Modify gradient percentages or color indices:
```ron
bar_color: Gradient({
    0: "rgb({color0.rgb})",
    20: "rgb({color2.rgb})",  # Changed from 25
    40: "rgb({color4.rgb})",  # Changed from 37/50
    60: "rgb({color6.rgb})",
    80: "rgb({color8.rgb})",
    100: "rgb({color15.rgb})",
})
```

3. Regenerate: `wal -i image.png`

### Merge with Existing rmpc Theme

If you have a custom rmpc theme, you can include the pywal colors instead of replacing:

**Option 1: Use RON includes**
```ron
#[include = "~/.cache/wal/colors-rmpc-theme.ron"]

(
    // Your custom rmpc settings
    default_album_art_path: "/path/to/art.png",
    // ...
)
```

**Option 2: Keep separate theme, layer colors**
```bash
# Use a base theme for layout
theme: "~/.config/rmpc/themes/my-theme.ron",

# Then override cava colors in a hook script
# (See "Extending with Hooks" below)
```

---

## Troubleshooting

### rmpc Reports "Failed to read config"
**Cause**: Theme file doesn't exist yet, or the symlink is missing/broken

**Solution**:
```bash
# Generate theme (if not already done)
wal -i ~/Images/Wallpaper/image.png

# Verify the generated file exists
ls -la ~/.cache/wal/colors-rmpc-theme.ron

# Verify the symlink exists and points to it
ls -la ~/.config/rmpc/themes/colors.ron

# Check config path is correct
grep theme ~/.config/rmpc/config.ron
```

### Colors Not Updating When I Run `wal`
**Cause**: `enable_config_hot_reload` is disabled

**Solution**:
```bash
# Check config
grep enable_config_hot_reload ~/.config/rmpc/config.ron

# Should show: enable_config_hot_reload: true

# If false, update to true and restart rmpc
pkill rmpc
rmpc
```

**Alternative**: If colors still don't update after `wal`, verify the theme file changed:
```bash
stat ~/.config/rmpc/themes/colors.ron  # Check timestamp (follows the symlink)
cat ~/.config/rmpc/themes/colors.ron   # Verify RGB values updated
```

### rmpc Looks Right in Old Terminals but Not New Ones (Cava Gradient Updates, Rest of UI Doesn't)
**Cause**: The theme file only sets explicit RGB for `default_album_art_path`
and the Cava gradient — everything else in rmpc's UI uses terminal-inherited
ANSI colors. New terminals haven't received the latest `wal` escape sequences
yet, so they still show the old/default palette.

**Solution**: Make sure `~/.cache/wal/sequences` is sourced on shell startup
(see [Load Terminal Colors in New Shells](#load-terminal-colors-in-new-shells)):
```bash
grep -n "wal/sequences" ~/.zshrc ~/.bashrc 2>/dev/null
```
If nothing is found, add it to your shell rc file and open a new terminal.

### Cava Gradient Looks Off
**Cause**: Palette generated might not have good contrast

**Solutions**:
1. Try different image: `wal -i different-image.png`
2. Use contrast flag: `wal -i image.png --contrast 2.0`
3. Try different backend: `wal --backend colorz -i image.png`
4. Manually adjust gradient in template (see Customization above)

### rmpc Not Starting After Update
**Debugging**:
```bash
# Check for config errors
rmpc 2>&1 | head -20

# Validate RON syntax (if you edited config)
# Look for mismatched braces, missing commas

# Try with default config
mv ~/.config/rmpc/config.ron ~/.config/rmpc/config.ron.bak
rmpc
# If it works, your config has a syntax error
```

---

## Testing

### Verify Theme Generation
```bash
# Run wal with verbose output
wal -i ~/test.png

# Check generated theme (via the stable symlink)
cat ~/.config/rmpc/themes/colors.ron

# Should show RGB values, not template variables
# Good: rgb(14,21,32)
# Bad: rgb({color0.rgb})
```

### Test Color Updates
```bash
# Update symlink to different image (recommended workflow)
ln -sf ~/Images/Wallpaper/different-image.png ~/Images/background.png

# Generate colors
wal -i ~/Images/background.png

# Check theme was updated
stat ~/.config/rmpc/themes/colors.ron  # Should show recent timestamp

# If rmpc is running, colors should update automatically via hot-reload
# Verify by checking the generated theme file
cat ~/.config/rmpc/themes/colors.ron | grep rgb  # Should show new RGB values
```

### Compare with Terminal
```bash
# After running wal, terminal AND rmpc should match
# Terminal colors: cat ~/.cache/wal/sequences
# rmpc theme: cat ~/.config/rmpc/themes/colors.ron

# The RGB values in rmpc theme should correspond to terminal colors
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

# Force rmpc to reload (usually automatic, but just in case)
pkill -HUP rmpc

# Update other apps
polybar-msg cmd reload  # If using polybar

# Custom integration
# ... your logic here ...

echo "Pywal update complete!"
```

Make it executable:
```bash
chmod +x ~/.local/bin/wal-post-hook.sh
```

### Alternative: Systemd User Timer
For periodic wallpaper changes:

```ini
# ~/.config/systemd/user/wal-update.timer
[Unit]
Description=Update wallpaper colors every hour

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
```

```ini
# ~/.config/systemd/user/wal-update.service
[Unit]
Description=Generate pywal colors from wallpaper

[Service]
Type=oneshot
ExecStart=%h/.local/bin/wal-random-wallpaper.sh
```

Script that picks random wallpaper:
```bash
#!/bin/bash
# ~/.local/bin/wal-random-wallpaper.sh
WALLPAPERS=~/Images/Wallpapers
IMAGE=$(find "$WALLPAPERS" -type f -name "*.png" -o -name "*.jpg" | shuf -n 1)
wal -i "$IMAGE"
```

Enable:
```bash
systemctl --user enable wal-update.timer
systemctl --user start wal-update.timer
systemctl --user status wal-update.timer
```

---

## Files

### Generated Files
- `~/.cache/wal/colors-rmpc-theme.ron` — Theme for rmpc
- `~/.cache/wal/colors.json` — Full palette
- `~/.cache/wal/sequences` — Terminal escape sequences

### Modified Files
- `~/.config/rmpc/themes/colors.ron` — Symlink to the generated theme
- `~/.config/rmpc/config.ron` — Updated to point `theme:` at the symlink

### Template (in pywal16 repo)
- `pywal/templates/colors-rmpc-theme.ron` — Template file for rmpc's embedded Cava pane

---

## Further Reading

- [CAVA_SETUP.md](CAVA_SETUP.md) — Matching colors for the standalone `cava` binary (outside rmpc)
- [Pywal16 Architecture](DEVELOPMENT.md) — How pywal16 works
- [rmpc Documentation](https://github.com/mierak/rmpc) — Full rmpc config options
- [MPD Documentation](https://www.musicpd.org/) — Music Player Daemon reference

---

## Troubleshooting Checklist

- [ ] `wal` command available: `which wal`
- [ ] Symlink exists: `ls -la ~/.config/rmpc/themes/colors.ron`
- [ ] Theme path correct in rmpc config: `grep theme ~/.config/rmpc/config.ron`
- [ ] Hot reload enabled: `grep enable_config_hot_reload ~/.config/rmpc/config.ron`
- [ ] Theme has RGB values (not variables): `cat ~/.config/rmpc/themes/colors.ron | grep rgb`
- [ ] rmpc restarted after config change: `pkill rmpc && rmpc`
- [ ] Different wallpaper tested: `wal -i different-image.png`
