# Screenshots

Images used by the project README. Each one is downscaled to **1280 px wide**
(~650 KB) so the README loads quickly.

## Current set

| File | Subject |
|------|---------|
| `settings-bar.png` | Bar Settings — drag-drop module layout |
| `settings-dock.png` | Dock Settings — auto-hide, indicators, scale |
| `settings-monitors.png` | Monitor management — HDR / VRR / scale / colour |
| `settings-nightlight.png` | Night Light — temperature slider + schedule |
| `settings-materialyou.png` | Material You — wallpaper-derived palette |
| `settings-workspaces.png` | Workspaces — numerals, grouping, scroll |
| `settings-layout-presets.png` | Built-in layout presets (macOS, Win11, GNOME, …) |
| `settings-notifications.png` | Notification Center configuration |
| `settings-weather.png` | Weather provider / location |
| `settings-lockscreen.png` | Lock screen wallpaper + timeouts |
| `settings-mouse.png` | Mouse sensitivity / cursor theme |
| `settings-network.png` | Ethernet / Wi-Fi / DNS / proxy |
| `settings-disks.png` | Disk management |
| `settings-screen-prefs.png` | Per-component monitor assignment |
| `settings-systeminfo.png` | System Info dashboard |
| `settings-apikeys.png` | SmartComplete API Keys page |

## Adding more

### 1. Capture (popup-friendly)

For modules with popovers that close on focus loss (EQ, Notepad, Calendar,
right-click menus), use the bundled delayed-capture helper instead of
`hyprshot`:

```bash
~/.config/quickshell/scripts/screenshot_popover.sh eq.png 4 DP-3
#                                                  └──┘ └┘ └──┘
#                                                   |   |   |
#                                                   |   |   output (optional)
#                                                   |   delay seconds
#                                                   filename
```

You then have 4 seconds to open the popover before `grim` fires silently.

For static views you can still use `hyprshot`:

```bash
hyprshot -m output -o ~/Pictures/screen
hyprshot -m region -o ~/Pictures/screen
```

### 2. Resize to 1280 px wide

The repo standard is 1280 px wide (preserves aspect ratio). Use ffmpeg —
ImageMagick is not in this dotfile set:

```bash
ffmpeg -i ~/Pictures/screen/raw.png -vf "scale=1280:-2" docs/screenshots/<name>.png
```

### 3. Reference in the README

Add a `<td>` cell to the existing `<table>` block under `## Screenshots`:

```html
<td align="center">
  <img src="docs/screenshots/<name>.png" alt="..." />
  <sub><b>Title</b> — short description</sub>
</td>
```

## Tips

- Take all screenshots with the **same wallpaper** — Material You will derive
  consistent colours so the gallery looks unified.
- Keep notifications closed and the clock at a sensible time; throwaway
  details distract from the feature you're highlighting.
- For consistent multi-monitor shots use `-o DP-2` (or whichever output) —
  full-screen captures of dual-monitor setups make the gallery feel cluttered.
