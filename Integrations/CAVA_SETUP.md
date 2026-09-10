# Pywal16 + Standalone Cava Integration Guide

## Overview

This guide covers matching the colors of the standalone **cava** binary
(the actual `cava` program, run on its own — not embedded in another app)
to your wallpaper via pywal16.

If you're looking for rmpc's `Cava` pane instead, see
[RMPC_SETUP.md](RMPC_SETUP.md) — rmpc still shells out to the real `cava`
binary under the hood (it must be installed and on `$PATH`; see
https://rmpc.mierak.dev/configuration/cava/), but rmpc supplies its own
config/theme for that pane rather than using `cava`'s own config file.
That setup is covered in RMPC_SETUP.md, not here.

### What This Achieves
- Standalone `cava`'s color gradient automatically matches your wallpaper
- Updates happen automatically when you run `wal -i image.png`
- Stays visually in sync with rmpc's `Cava` pane, if you use both

---

## Why Two Separate Configs?

Both rmpc's `Cava` pane and this guide's standalone setup ultimately run the
same `cava` binary — but rmpc feeds it settings from its own
`~/.config/rmpc/config.ron` (RON format; see the `cava: (...)` block in
[RMPC_SETUP.md](RMPC_SETUP.md)), while a directly-invoked `cava` reads its
own INI-style config at `~/.config/cava/config`.

Because the two setups source their settings from different config formats,
there's no single file both can read — but pywal16 generates a matching
template for each, so a single `wal -i image.png` run keeps them visually
in sync:

- `pywal/templates/colors-rmpc-theme.ron` — rmpc's `Cava` pane config
- `pywal/templates/colors-cava` — standalone `cava` (this guide)

---

## Quick Start

### 1. Ensure pywal16 is Installed
```bash
which wal
wal --version  # Should show 3.8.x or higher
```

### 2. Back Up Your Existing Cava Config
```bash
mkdir -p ~/.config/cava
mv ~/.config/cava/config ~/.config/cava/config.bak 2>/dev/null
```

### 3. Symlink the Generated Config
```bash
ln -sf ~/.cache/wal/colors-cava ~/.config/cava/config
```

### 4. Generate Initial Colors
```bash
wal -i ~/Images/Wallpaper/your-image.png
```

### 5. Done!
Every time you run `wal`, `~/.config/cava/config` (via the symlink)
picks up the new gradient. Restart `cava` to see the change take effect
(it doesn't hot-reload like rmpc).

---

## Customization

### Transparent Background
By default the template leaves `background`/`foreground` commented out in
`pywal/templates/colors-cava`, so `cava` inherits your terminal's
transparency instead of drawing an opaque background — handy if you want
the gradient bars floating over a transparent terminal that already shows
your wallpaper:

```ini
[color]
#background = '{background}'
#foreground = '{foreground}'
gradient = 1
gradient_color_1 = '{color0}'
...
```

Uncomment either line (and regenerate with `wal -i image.png`) if you'd
rather cava paint a solid background/foreground instead.

### Customize Gradient
The template maps 8 gradient stops to `color0`–`color7`:

```ini
gradient_color_1 = '{color0}'
gradient_color_2 = '{color1}'
...
gradient_color_8 = '{color7}'
```

Edit `pywal/templates/colors-cava` to change which palette colors are
used, then regenerate: `wal -i image.png`.

### Tuning Values
`framerate`, `sensitivity`, `autosens`, cutoff frequencies, input source,
and smoothing settings are all in the `[general]`, `[input]`, and
`[smoothing]` sections of the template — edit directly and regenerate.

**Keep in sync**: if you change these values (or the gradient stops) here,
consider making the equivalent change in
`pywal/templates/colors-rmpc-theme.ron` so rmpc's Cava pane doesn't drift
out of sync with standalone `cava`.

---

## Troubleshooting

### "Error loading config. Unable to open theme file..."
If you see something like:
```
Error loading config. Unable to open theme file '/home/user/.config/cava//themes/name', exiting...
```
this means a `theme = ...` line is set somewhere in your cava config
(possibly left over from a previous config) pointing at a theme file that
doesn't exist. Our generated template doesn't set `theme`, so check for a
stray `theme = ...` line in `~/.config/cava/config` (or `config.bak`) if
you see this.

### Colors Not Updating When I Run `wal`
**Cause**: `~/.config/cava/config` isn't actually the symlink

**Solution**:
```bash
ls -l ~/.config/cava/config
# Should show: config -> /home/user/.cache/wal/colors-cava

# If it's a regular file instead, re-run the symlink step:
ln -sf ~/.cache/wal/colors-cava ~/.config/cava/config
```

Also remember `cava` doesn't hot-reload — restart it after regenerating
colors.

### Gradient Looks Off
Same causes/fixes as rmpc's Cava pane — see
[RMPC_SETUP.md's Troubleshooting](RMPC_SETUP.md#cava-gradient-looks-off).

---

## Files

### Generated Files
- `~/.cache/wal/colors-cava` — Config for standalone `cava`

### Modified Files
- `~/.config/cava/config` — Symlinked to the generated config

### Template (in pywal16 repo)
- `pywal/templates/colors-cava` — Template file for standalone `cava`

---

## Further Reading

- [RMPC_SETUP.md](RMPC_SETUP.md) — rmpc's Cava pane (separate config/format, but shells out to the real cava binary)
- [cava Documentation](https://github.com/karlstav/cava) — Full cava config options
