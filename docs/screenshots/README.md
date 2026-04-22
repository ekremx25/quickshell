# Screenshots

Screenshots that the README references. Sizes are recommendations — if a screenshot is taller or wider that's fine, but please keep them under ~2 MB each so the README loads quickly on slow connections.

## Checklist

The README expects the following images to exist in this directory:

| Filename | Subject | Recommended size |
|----------|---------|------------------|
| `bar-top.png` | The full top bar (one monitor) | full-width, 80–120 px tall |
| `dock.png` | The dock with a few pinned apps + running indicators | ~600 px wide |
| `settings-bar.png` | Settings → Bar Settings (drag-drop layout view, like the existing screenshot the user has) | 1200×800 |
| `settings-monitors.png` | Settings → Monitors (with the layout canvas showing 2 displays) | 1200×800 |
| `settings-nightlight.png` | Settings → Appearance → Night Light (toggle on, schedule visible) | 1200×800 |
| `settings-materialyou.png` | Settings → Appearance → Material You (with a wallpaper selected) | 1200×800 |
| `osd-volume.png` | Volume OSD popping up in the corner | ~300 px wide |
| `notification-popup.png` | A notification popup with the Material You theme | ~400 px wide |

Optional but nice to have:
- `lockscreen.png` — Lock Screen with custom background
- `dock-context-menu.png` — right-click menu on a dock icon
- `night-light-comparison.png` — split image, off vs. on (3500 K)

## How to take them

```bash
# Whole screen
grim ~/screenshot.png

# Region (drag-select)
grim -g "$(slurp)" ~/screenshot.png

# Specific output (e.g. 1080p monitor)
grim -o DP-2 ~/screenshot.png

# Specific window (Hyprland)
grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" ~/screenshot.png
```

Then move into this directory:

```bash
mv ~/screenshot.png ~/.config/quickshell/docs/screenshots/<name>.png
```

## After adding screenshots

Open [`README.md`](../../README.md) and replace the section under `### Top Bar` (and the other feature sections) with:

```markdown
### Top Bar
![Top bar](docs/screenshots/bar-top.png)
- Workspaces — ...
- ...
```

Or add a dedicated `## Screenshots` section between `## Features` and `## Supported Compositors`:

```markdown
## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/bar-top.png" alt="Top bar"/></td>
    <td><img src="docs/screenshots/dock.png" alt="Dock"/></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/settings-bar.png" alt="Bar settings"/></td>
    <td><img src="docs/screenshots/settings-nightlight.png" alt="Night Light settings"/></td>
  </tr>
</table>
```

GitHub will scale them automatically.

## Tip: consistent look

For a polished feel, take all screenshots with:
- The **same wallpaper** (Material You will derive the same theme)
- The **same time of day** in the clock
- **No private notifications** showing

A throwaway test profile helps:

```bash
HOME=/tmp/qs-screenshot quickshell  # uses /tmp/qs-screenshot/.config/quickshell
```
