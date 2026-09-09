# Arch Linux Packaging Guide for pywal16

## Overview

pywal16 is available on the Arch User Repository (AUR). This guide covers building, testing, and maintaining the package.

**Official AUR Package**: https://aur.archlinux.org/packages/pywal16

---

## Quick Start: Local Build & Test

### Prerequisites
```bash
sudo pacman -S --needed base-devel git
```

### Build from Source
```bash
git clone https://github.com/eylles/pywal16.git
cd pywal16
makepkg --syncdeps
```

### Install Locally
```bash
sudo pacman -U pywal16-*.pkg.tar.zst
```

### Verify Installation
```bash
wal --version
wal --backend
wal -i ~/test-image.png
```

---

## Creating Your Own PKGBUILD

### Step 1: Create Working Directory
```bash
mkdir -p ~/aur/pywal16
cd ~/aur/pywal16
```

### Step 2: Write PKGBUILD

Create `PKGBUILD`:

```bash
# Maintainer: Your Name <your.email@example.com>

pkgname=pywal16
pkgver=3.8.15
pkgrel=1
pkgdesc="Generate colorschemes on the fly (16-color palette improvement fork)"
arch=('any')
url="https://github.com/eylles/pywal16"
license=('MIT')

depends=('python>=3.6')
optdepends=(
    'imagemagick: for image processing'
    'python-pillow: for faster image processing'
    'feh: for setting wallpaper on X11'
    'swaybg: for setting wallpaper on Wayland'
)
makedepends=('python-build' 'python-installer' 'python-setuptools')

source=("${pkgname}-${pkgver}.tar.gz::https://github.com/eylles/pywal16/archive/refs/tags/${pkgver}.tar.gz")
sha256sums=('PUT_ACTUAL_SHA256_HERE')

build() {
    cd "pywal16-${pkgver}"
    python -m build --wheel --no-isolation
}

package() {
    cd "pywal16-${pkgver}"
    python -m installer --destdir="$pkgdir" dist/*.whl
    install -Dm644 LICENSE.md "$pkgdir/usr/share/licenses/${pkgname}/LICENSE"
}
```

### Step 3: Generate SHA256

```bash
# Option A: Download and hash
wget "https://github.com/eylles/pywal16/archive/refs/tags/3.8.15.tar.gz"
sha256sum 3.8.15.tar.gz

# Option B: Let makepkg generate it
makepkg --geninteg
```

Replace `PUT_ACTUAL_SHA256_HERE` in PKGBUILD with the hash.

### Step 4: Test Build
```bash
makepkg --syncdeps
```

### Step 5: Install & Test
```bash
sudo pacman -U pywal16-*.pkg.tar.zst

# Verify
wal --version
wal -i ~/image.png
```

---

## Submitting to AUR

### Prerequisites
1. Create account at https://aur.archlinux.org/
2. Generate SSH key (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/aur -C "aur@archlinux.org"
   ```
3. Add public key to AUR account settings

### Step 1: Clone AUR Repository
```bash
git clone ssh://aur@aur.archlinux.org/pywal16.git
cd pywal16
```

### Step 2: Update Files
```bash
# Update PKGBUILD with new version/hash
# Generate .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Review changes
git diff

# Stage and commit
git add PKGBUILD .SRCINFO
git commit -m "Update to version 3.8.15"

# Push to AUR
git push origin main
```

### Step 3: Wait for CI
AUR runs automated checks. Fix any issues if flagged by `namcap`.

---

## Maintenance

### Check for Updates
```bash
# Clone upstream and check tags
git clone https://github.com/eylles/pywal16.git /tmp/pywal16-check
cd /tmp/pywal16-check
git fetch --tags
git tag | tail -5  # Show latest 5 releases

# Or subscribe to: https://github.com/eylles/pywal16/releases
```

### Update to New Version
```bash
cd ~/aur/pywal16

# Get new source
wget "https://github.com/eylles/pywal16/archive/refs/tags/3.9.0.tar.gz"
sha256sum 3.9.0.tar.gz

# Update PKGBUILD
sed -i 's/pkgver=.*/pkgver=3.9.0/' PKGBUILD

# Update .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Test build
makepkg --syncdeps --clean

# Commit
git add PKGBUILD .SRCINFO
git commit -m "Update to pywal16 3.9.0"
git push origin main
```

---

## Version Numbering

### Upstream Versions
pywal16 uses semantic versioning: `MAJOR.MINOR.PATCH`
- Example: `3.8.15` → `3.8.16` (patch) → `3.9.0` (minor)

### Package Release Number
- `pkgrel=1` — New upstream version
- `pkgrel=2+` — AUR-only fixes to same version (e.g., PKGBUILD fixes)

Example:
```
# New upstream version
pkgver=3.9.0
pkgrel=1        # Reset to 1

# Bug fix in PKGBUILD for same upstream version
pkgver=3.9.0
pkgrel=2        # Increment
```

---

## Debugging Build Issues

### Issue: "No module named 'pywal'"
**Solution**: Ensure build deps installed
```bash
makepkg --clean --syncdeps
```

### Issue: "ImportError: No module named 'PIL'"
**Solution**: Add `python-pillow` to makedepends
```bash
# Then rebuild
makepkg --syncdeps --clean
```

### Issue: "wal command not found"
**Debugging**:
```bash
# Check if installed
python -m pywal --version

# Check PATH
echo $PATH | tr ':' '\n' | grep -E 'bin|local'

# Reinstall
sudo pacman -R pywal16
sudo pacman -U pywal16-*.pkg.tar.zst
```

### Issue: "Tests fail during build"
**Note**: Tests aren't run during build (only in dev). If you want to debug:
```bash
cd extracted-source-dir
python -m pytest tests/ -v
```

---

## Testing Checklist

Before releasing an update:

```bash
# [ ] Version is correct
grep ^pkgver PKGBUILD

# [ ] SHA256 is correct
grep sha256sums PKGBUILD

# [ ] .SRCINFO regenerated
ls -l .SRCINFO
git log -1 --oneline .SRCINFO

# [ ] Build succeeds
makepkg --syncdeps --clean

# [ ] Installation succeeds
sudo pacman -U pywal16-*.pkg.tar.zst

# [ ] Basic commands work
wal --version
wal --backend
wal -i ~/test.png

# [ ] Templates exported
ls ~/.cache/wal/colors-* | wc -l

# [ ] No file conflicts
pacman -Q | grep wal
```

---

## Advanced: Customizations

### Custom Templates in Package

If you want to include custom export templates:

1. Create `customize.patch`
2. Add to PKGBUILD:

```bash
prepare() {
    cd "pywal16-${pkgver}"
    patch -Np1 < "${srcdir}/customize.patch"
}
```

### Custom Environment Configuration

Create `/etc/profile.d/pywal16.sh`:

```bash
# Set default cache location
export PYWAL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wal"
```

Add to PKGBUILD:

```bash
package() {
    # ... existing ...
    install -Dm644 "${srcdir}/pywal16.sh" "$pkgdir/etc/profile.d/pywal16.sh"
}
```

---

## Useful Resources

- **AUR Submission Guidelines**: https://wiki.archlinux.org/title/AUR_submission_guidelines
- **Creating Packages**: https://wiki.archlinux.org/title/Creating_packages
- **PKGBUILD Reference**: https://wiki.archlinux.org/title/PKGBUILD
- **Arch Package Guidelines**: https://wiki.archlinux.org/title/Arch_packaging_standards
- **Upstream Repository**: https://github.com/eylles/pywal16
- **AUR Package Page**: https://aur.archlinux.org/packages/pywal16

---

## Quick Reference

### Build Commands
```bash
makepkg                    # Build only
makepkg --syncdeps         # Build + install deps
makepkg --clean            # Remove build dir after
makepkg --geninteg         # Generate sha256sums
makepkg --printsrcinfo     # Generate .SRCINFO
```

### Installation Commands
```bash
sudo pacman -U *.pkg.tar.zst        # Install package
sudo pacman -R pywal16               # Remove package
sudo pacman -S pywal16               # Install from repos (AUR via yay/paru)
```

### Git Commands
```bash
git add PKGBUILD .SRCINFO   # Stage changes
git commit -m "message"     # Commit
git push origin main        # Push to AUR
```
