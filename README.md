<div align="center">

# Quickshell

**A modern, feature-rich desktop shell for Wayland compositors.**

[Niri](https://github.com/YaLTeR/niri) · [Hyprland](https://github.com/hyprwm/Hyprland) · [MangoWC](https://github.com/DreamMaoMao/mango)

[![CI](https://github.com/ekremx25/quickshell/actions/workflows/ci.yml/badge.svg)](https://github.com/ekremx25/quickshell/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: Wayland](https://img.shields.io/badge/platform-Wayland-green.svg)]()
[![Built with: Quickshell](https://img.shields.io/badge/built%20with-Quickshell-7F60F6.svg)](https://github.com/outfoxxed/quickshell)

https://github.com/user-attachments/assets/c32273fd-03a5-41d9-ab4e-100727b9591d

</div>

## Quick Install — Hyprland

Run in your Hyprland session to open the interactive setup wizard:

```bash
bash <(curl -qfsSL https://raw.githubusercontent.com/ekremx25/quickshell/main/install.sh)
```

Automatically detects monitors, asks for screen preferences, and backs up an
existing installation. **No GitHub account or password is required.**

**Preview without making changes:** append `--dry-run` to the command above.
Read the [full installation guide](#installation) for dependencies and safety details.

---

Built on top of [outfoxxed's Quickshell framework](https://github.com/outfoxxed/quickshell), this configuration turns it into a complete desktop shell: a top bar, dock, settings dashboard, on-screen display, notification centre, blue-light filter, Material You theming, and more — all drag-and-drop customisable and compositor-agnostic.

## Table of Contents

- [Features](#features)
- [Supported Compositors](#supported-compositors)
- [MangoWC 0.16+](#mangowc-016)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Configuration](#configuration)
- [Workspace Overview](#workspace-overview)
- [Activity Monitor](#activity-monitor)
- [Night Light](#night-light)
- [Power Profiles](#power-profiles)
- [Network & Wi-Fi](#network--wi-fi)
- [Audio Equaliser](#audio-equaliser)
- [Regression Checks](#regression-checks)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Links](#links)
- [License](#license)

## Features

### Top Bar
- **Workspaces** — Per-monitor role ranges, occupied/global modes, app grouping, scrolling and Roman / Chinese / Urartian cuneiform / Göktürk / Arabic-Indic / decimal labels
- **System Info** — CPU, RAM, temperature, disk usage, groupable
- **Activity Monitor** — On-demand CPU, memory, GPU, network, storage and process details; tested on Hyprland and MangoWC
- **Audio** — Volume control, mute, 10-band parametric equaliser
- **Weather & World Clocks** — Current conditions plus a configurable multi-city desktop clock; search any city/country, reorder up to eight locations, and get DST-aware local time with live weather
- **Markets** — Official TCMB USD/TRY buying/selling rates plus live Bitcoin and Ethereum prices with 24-hour change and offline cache
- **Draggable desktop widgets** — Move World Clocks and Markets freely with the mouse; positions persist independently for each monitor role
- **Quick currency converter** — Place the converter on the bar or dock and open the complete currency selector with one click
- **Clock & Calendar** — With agenda and event countdown
- **Notification Centre** — Grouped history, DND, per-app filters, customisable popup position
- **System Tray** — Standard StatusNotifierItem protocol
- **Clipboard Manager** — History with copy-on-click
- **Power Profiles** — Performance, Balanced and Power Saver with automatic Arch/Fedora backend detection

### Dock
- Animated zoom effect on hover
- Drag-and-drop pinning and reordering
- Live running indicators (dot or line, configurable)
- Per-monitor visibility
- Four positions: top, bottom, left and right, with direction-aware separators and drag targets
- Intelligent auto-hide based on occupied active workspaces on the dock's own monitor (not geometric window-overlap detection)
- Edge reveal with hover tracking that keeps application icons clickable
- Direction-aware tooltip and context-menu popup surfaces with screen-boundary adjustment
- Left/right module slots (Weather, Volume, Tray, Power, Media, Notepad, …)

### Workspace Overview
- Hyprland workspace overview with live window previews and icon/title fallback
- All connected monitors, their workspace assignments and per-monitor application counts in one view
- Click to focus/switch; drag windows between regular or special workspaces and across monitors
- Transactional cross-monitor moves with hot-plug verification and rollback

### Settings Dashboard
- Drag-and-drop bar module arrangement
- Bar position toggle (top / bottom / left / right)
- Per-screen module assignment (OSD on one monitor, notifications on another)
- Workspace ranges by monitor role (primary 1–5, secondary 6–10, …), independent of HDMI/DP port names
- Seven built-in layout presets (macOS, Windows 11, GNOME, KDE, Unity, ZorinOS, Custom)
- Material You theme editor with live wallpaper colour extraction

### Visual Effects
Every effect is optional and configured in **Settings → Effects**; one **Animation Speed** slider (0.25×–3×, with Relaxed / Normal / Snappy / Instant presets) scales them all.

- **Liquid Glass** — Frosted glass for the dock, bar module groups, dock menus, notifications, the weather popup and the volume OSD, built from the current wallpaper with edge refraction, a chromatic rim, a specular highlight and an optional light sweep. Wayland clients cannot read the windows behind them, so the glass shows the wallpaper (set with `awww`), not the window underneath
- **Popup opening styles** — Liquid Ring (a rippling circle from the module you clicked), Genie, 3D Flip, Jelly, Spring, Fade or Off, applied to every module popup including the EQ, calendar and Activity Monitor
- **Open on Hover** — Small module popups open when the pointer rests on the module and close when it leaves, like the calendar; the notepad stays open once you start typing
- **Dock** — App launch animation (Bounce, Pulse, Wiggle or Off), a smoke-puff "poof" when an icon is removed, and a compact music visualizer next to the track title. **The visualizer requires `cava`**, which the installer sets up (manual installs: `sudo pacman -S cava`); without it the visualizer simply stays hidden
- **Bar** — Flowing active-workspace indicator that stretches towards the new workspace
- **Notifications** — Spring, Elastic or Classic entrance
- **Volume OSD** — Rippling liquid fill
- Shader layers run only while an animation plays, and `cava` only while music is playing

#### Window open/close animations (Hyprland, optional)
Springy window opening and shrink-and-fade closing are set in **Hyprland's own configuration**, not in Quickshell: Quickshell cannot animate other applications' windows. The installer only adds a Quickshell autostart entry and does **not** add these animation lines, so add them yourself if you want this feel.

Lua config (Hyprland 0.56+, e.g. `~/.config/hypr/hyprland.lua`):

```lua
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("closeEase", { type = "bezier", points = { { 0.4, 0 }, { 0.6, 1 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "closeEase", style = "popin 70%" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "closeEase" })
```

Classic `hyprland.conf`:

```ini
animations {
    enabled = true
    bezier = overshot, 0.05, 0.9, 0.1, 1.05
    bezier = closeEase, 0.4, 0, 0.6, 1
    animation = windowsIn, 1, 4, overshot, popin 80%
    animation = windowsOut, 1, 3, closeEase, popin 70%
    animation = fadeOut, 1, 3, closeEase
}
```

Reload Hyprland afterwards (`hyprctl reload`). Settings → Effects → Animation Speed does not affect these; adjust the `speed` values above instead.

### Fonts
- System-wide font picker for general and monospace families (writes to `kdeglobals` and `qt6ct.conf`)
- Live preview tiles with the current selection rendered in situ
- Searchable catalogue of every installed family, sourced via `fc-list` (includes user fonts in `~/.local/share/fonts`)
- Applies without a shell restart: the Theme singleton re-reads the system font and every bar / dock / popup / settings module updates on the fly
- Nerd Font glyphs stay pinned to `JetBrainsMono Nerd Font` so icons keep rendering after the switch

### Monitor Management
- Resolution, refresh rate, and independent scale per output
- HDR, VRR, 10-bit colour, wide-gamut colour management (sRGB / DCI-P3 / Adobe RGB / Rec.2020)
- Drag-to-arrange multi-monitor layout canvas with edge snapping
- 10-second **Keep / Revert** safety prompt after display changes
- SDR brightness, saturation, and reference luminance for HDR outputs
- Applied with a single `hyprctl --batch` call on Hyprland (no flicker)

### Night Light
- Blue-light filter with 1000–6500 K slider and five presets
- **Fixed-time schedule** with midnight-wrap support (e.g. 19:00 → 07:00)
- Cross-compositor backend: `hyprsunset` on Hyprland, `gammastep` on wlroots
- Persists through shell restart; auto-applies on startup

### Extras
- **OSD** for volume
- **App Drawer** launcher with fuzzy search
- **Wallpaper Picker** with Material You palette extraction ([matugen](https://github.com/InioX/matugen))
- **Lock Screen** — wallpaper, dim/lock/suspend timeouts, media inhibit
- **Mouse & Keyboard** — sensitivity, scroll factor, cursor theme
- **Network & Bluetooth** connection managers
- **VPN** connection manager (NetworkManager + WireGuard)
- **API Keys** — configure [SmartComplete](https://github.com/ekremx25/smartcomplete) AI providers (OpenAI, Claude, Groq, Ollama, …)
- **Notepad** and **Event Countdown**

## Screenshots

<table>
  <tr>
    <td align="center" valign="middle" colspan="2">
      <img src="docs/screenshots/workspace-overview.png" alt="Workspace Overview with live windows grouped by monitor" />
      <br>
      <sub><b>Workspace Overview</b> — live window previews, per-monitor workspace groups and cross-monitor drag-and-drop</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="middle" width="50%">
      <img src="docs/screenshots/settings-bar.png" alt="Bar Settings (drag-drop layout)" />
      <sub><b>Bar Settings</b> — drag-drop module layout, four positions, per-screen visibility</sub>
    </td>
    <td align="center" valign="middle" width="50%">
      <img src="docs/screenshots/settings-monitors.png" alt="Monitor settings with HDR/VRR/colour management" />
      <sub><b>Monitors</b> — resolution, scale, HDR, VRR, colour management, drag-to-arrange canvas</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-nightlight.png" alt="Night Light blue-light filter with schedule" />
      <sub><b>Night Light</b> — temperature slider, presets, fixed-time schedule (hyprsunset / gammastep)</sub>
    </td>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-materialyou.png" alt="Material You theme settings" />
      <sub><b>Material You</b> — wallpaper-derived palette, light/dark, multiple scheme types</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-dock.png" alt="Dock settings (auto-hide, indicators, scale)" />
      <sub><b>Dock Settings</b> — auto-hide, indicator style, icon scale, alignment</sub>
    </td>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-apikeys.png" alt="API Keys for SmartComplete AI providers" />
      <sub><b>API Keys</b> — local-only or any of 7 cloud providers for SmartComplete</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="middle" colspan="2">
      <img src="docs/screenshots/settings-effects.png" alt="Effects settings: animation speed, popup styles, liquid glass, dock and notification effects" />
      <br>
      <sub><b>Effects</b> — animation speed, popup opening styles, open on hover, Liquid Glass, dock, notification and OSD effects</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-systeminfo.png" alt="System Info dashboard" />
      <sub><b>System Info</b> — CPU, RAM, GPU, storage, environment</sub>
    </td>
    <td align="center" valign="middle">
      <img src="docs/screenshots/settings-fonts.png" alt="Fonts picker" />
      <sub><b>Fonts</b> — system-wide Qt/KDE font picker with live preview, searchable <code>fc-list</code> catalogue</sub>
    </td>
  </tr>
</table>

### Bar popovers

Click any of these on the bar to reveal an inline popover.

<table>
  <tr>
    <td align="center">
      <img src="docs/screenshots/popover-eq.png" alt="Equalizer popover" />
      <sub><b>Equalizer</b> — 10-band parametric EQ with sound theming</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/popover-notepad.png" alt="Notepad popover" />
      <sub><b>Notepad</b> — quick scratchpad, autosaved</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/popover-calendar.png" alt="Calendar popover" />
      <sub><b>Calendar</b> — month view with today highlighted</sub>
    </td>
  </tr>
</table>

<details>
<summary><b>More Settings pages</b> (click to expand)</summary>

<table>
  <tr>
    <td align="center">
      <img src="docs/screenshots/settings-workspaces.png" alt="Workspaces settings" />
      <sub><b>Workspaces</b> — numeral style (Roman / Japan / Decimal), grouping, scroll behaviour</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/settings-layout-presets.png" alt="Layout presets" />
      <sub><b>Layout Presets</b> — macOS, Windows 11, GNOME, KDE, Unity, ZorinOS, Custom</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/screenshots/settings-notifications.png" alt="Notification settings" />
      <sub><b>Notifications</b> — DND, popup position, animation speed, filters</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/settings-weather.png" alt="Weather settings" />
      <sub><b>Weather</b> — location and provider configuration</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/screenshots/settings-lockscreen.png" alt="Lock screen settings" />
      <sub><b>Lock Screen</b> — wallpaper, dim/lock/suspend timeouts, media inhibit</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/settings-mouse.png" alt="Mouse settings" />
      <sub><b>Mouse</b> — sensitivity, scroll factor, accel profile, cursor theme</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/screenshots/settings-network.png" alt="Network settings (Ethernet / Wi-Fi)" />
      <sub><b>Network</b> — Ethernet, Wi-Fi, DNS, proxy, advanced</sub>
    </td>
    <td align="center">
      <img src="docs/screenshots/settings-disks.png" alt="Disk management" />
      <sub><b>Disks</b> — mount points, removable drives, fstab helper</sub>
    </td>
  </tr>
  <tr>
    <td align="center" colspan="2">
      <img src="docs/screenshots/settings-screen-prefs.png" alt="Per-screen module preferences" width="49%" />
      <br>
      <sub><b>Screen Prefs</b> — assign each component (bar, dock, OSD, notif) to specific monitors</sub>
    </td>
  </tr>
</table>

</details>

## Workspace Overview

The Workspace Overview is currently **Hyprland-only**. It displays configured
regular workspaces from every connected monitor, special workspaces, live
window contents and the monitor that owns each workspace. If Wayland window
capture is unavailable, the card falls back to the application icon and title.

Open or close it through Quickshell IPC:

```bash
qs ipc call workspace-overview toggle
```

`SUPER+TAB` is **not installed automatically** when this repository is cloned:
the repository owns the Quickshell configuration, not the user's Hyprland
keybindings. Quickshell must be running, and the user must add one of the
following bindings to their own Hyprland configuration.

Standard `hyprland.conf` syntax:

```ini
bind = SUPER, TAB, exec, qs ipc call workspace-overview toggle
```

Hyprland Lua configuration-provider syntax:

```lua
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc call workspace-overview toggle"))
```

Reload the Hyprland configuration after adding the binding. If `SUPER+TAB` is
already assigned, remove/replace the conflicting binding or choose another key.
The overview does not replace the compositor's normal `ALT+TAB` window cycle.

Click a workspace to switch, click a window to focus it, or drag a window to a
regular/special workspace. Cross-monitor drops snapshot the source state,
validate that the destination is connected, enabled and not mirrored, then
verify the final window/workspace placement. A failed or interrupted hot-plug
move attempts to restore the source workspace and monitor. Exact restoration
cannot be guaranteed after process termination (`SIGKILL`) or if the source
monitor also disappears; incomplete rollback is reported as an error.

Runtime state can be inspected without opening the overlay:

```bash
qs ipc call workspace-overview status
```

The status includes the focused output, connected monitor count, and per-monitor
workspace/application counts. `jq` is required for transactional cross-monitor
moves and is included in the core dependency list below.

## Supported Compositors

| Compositor | Status | Notes |
|------------|:------:|-------|
| [Niri](https://github.com/YaLTeR/niri) | Full | Event-driven IPC, auto-reconnect |
| [Hyprland](https://github.com/hyprwm/Hyprland) | Full | Socket2 event stream; Night Light requires `hyprsunset` |
| [MangoWC](https://github.com/DreamMaoMao/mango) | Full | Mango 0.16+ JSON IPC; live tags, clients and per-output display controls |

## MangoWC 0.16+

MangoWC is supported through its native `mmsg` JSON IPC. Quickshell verifies a
live Mango socket instead of assuming that Mango is active merely because the
`mmsg` executable is installed. The integration does not call Niri IPC while a
Mango session is running.

The integration covers live tags and windows, dock actions, per-output scale,
placement, HDR/VRR, mouse settings and session actions. Display changes use a
10-second **Keep / Revert** preview. Monitor discovery uses `mmsg` directly;
`wlr-randr` is not required.

> **Current-mode note:** Mango 0.16's monitor IPC reports the active mode and
> logical geometry, but not the complete list of modes advertised by the
> display. The monitor page therefore shows the current resolution and refresh
> rate on Mango while still allowing independent scale, placement, HDR and VRR
> control.

Monitor and mouse settings are written only inside the
`QUICKSHELL MANAGED MONITORS` and `QUICKSHELL MANAGED MOUSE` blocks of
`~/.config/mango/config.conf`; other settings are preserved.

Required versions:

- MangoWC **0.16 or newer**
- Quickshell **0.3.1 or newer**
- `jq` for JSON-based helper actions

## Dependencies

### Core

| Package | Purpose |
|---------|---------|
| `quickshell` | Shell framework ([outfoxxed/quickshell](https://github.com/outfoxxed/quickshell)) |
| `niri`, `hyprland`, or `mango` | A Wayland compositor |
| `networkmanager` | Network management (`nmcli`) |
| `bluez` + `bluez-utils` | Bluetooth |
| `pipewire` + `pipewire-pulse` + `wireplumber` + `libpulse` | Audio control and EQ filter-chain |
| `jq` | JSON processing in helper scripts |
| `util-linux` | `flock` serialises EQ operations |
| `glib2` | `gdbus` monitors NetworkManager VPN changes |
| `python` 3.10+ | Port-independent monitor role manager and helper scripts |
| `socat` or `ncat` | Hyprland event stream, monitor hot-plug and live dock updates |

### Fonts

| Font | Package (Arch) |
|------|----------------|
| JetBrainsMono Nerd Font | `ttf-jetbrains-mono-nerd` |
| Inter | `ttf-inter` |
| Font Awesome 6 Free | `ttf-font-awesome` |

### Theming

- **[matugen](https://github.com/InioX/matugen)** — Material You palette from wallpapers
  - Arch: `sudo pacman -S matugen` (or AUR: `paru -S matugen-bin`)
  - Fedora: `sudo dnf install matugen`
  - Any supported distribution via Cargo: `cargo install matugen`

### Optional (feature-specific)

| Package | Feature |
|---------|---------|
| `hypridle` + `hyprlock` | Lock, dim, monitor-off and suspend timers on Hyprland and Niri |
| `hyprsunset` | Night Light on Hyprland (required) |
| `gammastep` | Night Light on Niri / MangoWC (required) |
| `kconfig` | Fonts picker (`kreadconfig6` / `kwriteconfig6` write to `kdeglobals`) |
| `qt6ct-kde` (AUR) | Fonts picker also writes to `qt6ct.conf` when `QT_QPA_PLATFORMTHEME=qt6ct` |
| `fontconfig` | Fonts picker catalogue via `fc-list` (pre-installed on most distros) |
| `inotify-tools` | Event-driven config file watching (otherwise falls back to polling) |
| `grim` + `slurp` | Screenshot helpers |
| `imagemagick` | Wallpaper Spectrum image sampling and the module colour eyedropper (`magick`) |
| `wl-clipboard` | Copy captured screenshots to the clipboard |
| `power-profiles-daemon` (Arch) or `tuned-ppd` + `python3-gobject` (Fedora) | Power Profile module; supported profiles are detected from the active service |
| `awww` | Liquid Glass effect (reads the current wallpaper and its crop mode) |
| `cava` | Music visualizer in the dock media widget |
| `hyprmoncfg` + `xdg-terminal-exec` | Optional Hyprland display-profile management in Display Studio; not required by the built-in monitor settings |

### One-liner install (Arch)

```bash
sudo pacman -S quickshell networkmanager bluez bluez-utils pipewire \
  pipewire-pulse wireplumber libpulse jq python socat inotify-tools util-linux glib2 \
  kconfig fontconfig power-profiles-daemon \
  ttf-jetbrains-mono-nerd ttf-inter ttf-font-awesome awww cava

# qt6ct (AUR fork with KDE integration)
yay -S qt6ct-kde
```

## Installation

### Interactive Hyprland setup (recommended)

Use a separate checkout, **not** your running `~/.config/quickshell` directory:

```bash
git clone https://github.com/ekremx25/quickshell.git quickshell-source
cd quickshell-source
bash install.sh --dry-run
bash install.sh
```

The wizard reads `hyprctl monitors -j`, confirms the detected count, asks which
outputs are Main/Secondary/Third, and asks where each component should appear.
It preserves current resolution, refresh rate, scale and coordinates; it does
not invoke monitor-setting commands or start the shell. Hyprland Lua autostart
is offered separately after installation and requires explicit consent. Newly installed monitor profiles use observation-only mode so the
existing startup/hotplug hooks do not rearrange your displays later.

- **Dry-run:** interactive plan only; no destination writes, backups or package installs.
- **Packages:** on Arch/CachyOS, `pacman -Q` checks each required package. Only
  missing packages are offered for installation, behind a separate confirmation,
  using `pacman -S --needed`. No full system upgrade is performed. Other distros
  use the dependency list above; no guessed package-manager commands are run.
- **Backups:** an existing installation is renamed to a unique sibling
  `quickshell.backup-DATE-TIME-ID` only after the replacement has been staged.
  Failed activation restores the old directory. Existing unrelated settings are
  retained; selected monitor roles and screen preferences are updated.
- **Safety:** a running destination, overlapping source/destination or symlinked
  configuration is rejected. No shell is killed; no autostart entry is added without explicit consent.
- **Privacy:** root-level author JSON and the profile avatar are not copied into
  a fresh installation. Existing user JSON is retained, except generated monitor
  files and the selected screen preferences. Legacy unknown preference keys survive.
- **Hyprland autostart:** after installation, the wizard optionally backs up an
  existing `hyprland.lua` and adds the current Lua startup event below. Legacy
  `.conf` files are refused, not migrated. Declining or reaching EOF leaves
  Hyprland untouched. Existing Quickshell Lua launch entries are left unchanged.
  This does not start Quickshell immediately or reload the compositor.

  ```lua
  hl.on("hyprland.start", function()
      hl.exec_cmd("quickshell")
  end)
  ```

  Reference: [official Hyprland autostart documentation](https://wiki.hypr.land/configuring/core/autostart/), checked 2026-10-14.

- **Offline metadata:** `bash install.sh --monitors-json /path/to/monitors.json --dry-run`
  accepts a saved `hyprctl monitors -j` snapshot. It still requires valid monitor
  data and interactive answers; EOF cancels instead of accepting an install.

Python 3.10+ and Bash are required for the wizard; Git is also required for its
remote bootstrap. Run without `sudo`; the optional package step requests it
when necessary. The target is `$XDG_CONFIG_HOME/quickshell` (default
`~/.config/quickshell`). Start manually with the printed guarded launcher after
checking dependencies. To restore a backup, stop the shell, move the current
configuration aside, and rename the printed backup directory to `quickshell`.
Backups are never pruned automatically.

For a published version containing this installer, the process-substitution
entrypoint is also supported (review downloaded code before executing it):

```bash
bash <(curl -qfsSL https://raw.githubusercontent.com/ekremx25/quickshell/main/install.sh) --dry-run
```

This downloads a temporary checkout and removes that checkout afterward.
The bootstrap uses public HTTPS with Git terminal/askpass prompts and credential
helpers disabled. User Git URL rewrites are ignored for this download only.
It never asks for a GitHub username, password or token: if the public download
fails, it exits with an error instead of prompting for authentication. Optional
package installation may still request your **local sudo password**, not a GitHub
password. Existing Git settings are not modified.
`QUICKSHELL_INSTALL_REF` selects a published branch/tag for that checkout;
local checkout invocation is preferable when reproducibility or offline use matters.
The first three screen selections use stable roles; additional outputs use
connector names in component preferences. Duplicate/absent display identities
fall back to connector/capability matching rather than overwriting one identity.

### Manual installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/ekremx25/quickshell ~/.config/quickshell
   ```

2. **Install dependencies** (see the section above).

3. **Spawn quickshell at compositor startup**

   <details>
   <summary><b>Niri</b> — <code>~/.config/niri/config.kdl</code></summary>

   ```kdl
   spawn-at-startup "quickshell"
   ```
   </details>

   <details>
   <summary><b>Hyprland</b> — <code>~/.config/hypr/hyprland.conf</code></summary>

   ```ini
   exec-once = quickshell
   ```
   </details>

   <details>
   <summary><b>MangoWC</b> — <code>~/.config/mango/autostart.sh</code></summary>

   ```bash
   pgrep -x quickshell >/dev/null || quickshell &
   ```
   </details>

   Or launch manually: `quickshell`.

4. **Enable the lock and idle timer service** (Hyprland and Niri)

   ```bash
   systemctl --user enable --now hypridle.service
   ```

   Start `hypridle` through this user service only. Running it a second time
   from the compositor startup file would leave two independent timeout sets
   active.

## Configuration

All settings live in `~/.config/quickshell/` and are edited through the in-app **Settings** dashboard (launcher logo on the bar → settings icon).

| File | Contents |
|------|----------|
| `bar_config.json` | Bar modules, layout, position |
| `dock_config.json` | Pinned apps, scale, alignment |
| `monitor_config.json` | Resolution, scale, HDR, VRR, colour mode per output |
| `monitor_identities.json` | Local EDID identity → stable monitor role mapping (generated locally) |
| `monitor_role_profiles.json` | Port-independent settings for Main / Secondary / Third (generated locally) |
| `monitor_runtime.json` | Current role → connector mapping (generated locally) |
| `theme_config.json` | Material You settings, wallpaper path |
| `lock_config.json` | Lock screen wallpaper and timeouts |
| `notification_config.json` | DND, popup position, animation speed, filters |
| `mouse_config.json` | Sensitivity, scroll factor, cursor theme |
| `screen_config.json` | Per-component monitor filtering |
| `nightlight_config.json` | Blue-light filter state + schedule |
| `weather_config.json` | Main weather location and configurable world-clock cities (generated locally) |
| `desktop_widgets.json` | Per-monitor-role desktop widget positions (generated locally) |

## Power Profiles

The **Power Profile** module uses the available system backend:

- **Arch Linux:** uses `powerprofilesctl` from `power-profiles-daemon`.
- **Fedora:** uses the standard Power Profiles D-Bus API exposed by `tuned-ppd`.

Install and start the matching backend once:

```bash
# Arch Linux
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service

# Fedora
sudo dnf install tuned-ppd python3-gobject
sudo systemctl enable --now tuned.service
```

The popup only displays profiles reported by the active backend, so systems
without hardware support for Performance mode will not show an unusable
option. Do not run `power-profiles-daemon` and `tuned-ppd` at the same time;
both provide the same D-Bus service.

### Multi-monitor roles and notifications

On Hyprland, displays are remembered by their physical EDID identity
(manufacturer, model and serial), not by connector names such as `DP-1` or
`HDMI-A-1`. The first launch assigns `Main`, `Secondary` and `Third` roles,
stores them locally, and updates the live role map after every monitor hot-plug.
Moving a display to another HDMI/DisplayPort connector therefore keeps its
role, workspace range and per-screen component selections.

Open **Settings → Hardware → Screen Prefs** to choose where each component is
shown:

- **Main / Secondary / Third** follows the selected physical display even when
  its port changes.
- If a role mapping is missing or stale, every unmatched connected display remains selectable by its current connector name (for example, `DP-1`). Connector selections do not automatically migrate to a different port.
- **All** creates one component instance on every connected display.
- **Disable** prevents that component from being created.
- **Toast** controls transient notification cards that appear on screen.
- **Notifications** controls the notification-centre/bar module; it is separate
  from Toast.

For notification cards on two monitors, set **Toast → All**. To show cards on
only one physical monitor, select its role instead.

`monitor_config.json`, `monitor_identities.json`, `monitor_role_profiles.json`,
`monitor_runtime.json`, `screen_config.json` and `desktop_widgets.json` are
runtime files excluded by `.gitignore`. A clone never inherits the repository
owner's monitor ports, serial numbers, layout or screen preferences; every user
gets a local mapping generated from their own hardware.

Displays without a usable EDID serial fall back to capability matching. Two
identical displays that both report the same or no serial cannot be physically
distinguished by any Wayland shell; in that rare case reconnect both displays,
choose the desired roles once, and keep the generated identity file local.

### Wallpaper Spectrum theming

Open **Settings → Appearance → Material You**, enable Material You and select
**Wallpaper Spectrum**. With ImageMagick installed, this Quickshell-specific
scheme samples colours from the image and derives distinct, contrast-adjusted
module accents and tinted surfaces. Without ImageMagick, it falls back to
matugen's generated palette.

The responsive editor includes a live bar preview, wallpaper thumbnail,
descriptive scheme cards, and light/dark controls. **Follow desktop** tracks
the current wallpaper through `awww`, `swww`, `swaybg`, or Waypaper's saved
selection. A selected image can also be used independently of the desktop.

Use the module colour editor to search modules, show only custom colours,
choose presets, enter a six-digit hex colour, or sample a screen pixel
(`grim`, `slurp`, and `magick` required). Individual colours can be returned
to automatic mode, and the editor provides undo and reset actions. Custom
module accents are saved in `theme_config.json`; they are local preferences,
not a requirement for other users.

- **Live Update** watches both the wallpaper backend and the selected image.
  Changing paths or overwriting the same image file regenerates the palette.
- Module foregrounds use WCAG relative-luminance contrast and automatically
  choose a light or dark glyph colour.
- Rapid wallpaper or scheme changes are coalesced; the last requested palette
  is applied after any running matugen process completes.
- Catppuccin, Kanagawa and Tokyo Night are authored static palettes and do not
  react to wallpaper changes.

### Workspace appearance

Workspace shape and transparency are independent settings, including a true
outline style. Reset uses the same defaults as a fresh bar configuration.
Application icons keep their desktop-file colours, with a fallback while icon
metadata loads. The appearance layer is shared by Niri, MangoWC and Hyprland;
workspace discovery still uses each compositor's own adapter.

### Display Studio and screenshot helper

**Display Studio** is available in Bar Settings and opens a movable, resizable
monitor-settings panel. Its separate `hyprmoncfg` profile and automatic
switching controls require Hyprland and an installed `hyprmoncfg` tool. They
are not a replacement for the Niri/MangoWC monitor backend. When
`hyprmoncfgd.service` is active, the monitor-apply helper defers to that daemon
to avoid competing layout writers.

`bash scripts/screenshot_capture.sh full` captures the desktop; use `region`
for an interactive selection. Images are saved under `Pictures/screen` by
default, with optional clipboard copying and a desktop notification. Set
`SCREENSHOT_DIR` to override the destination. Bind the helper in your own
compositor configuration; installing this repository does not add a keybind.

### Regression checks

Run from the repository root:

```bash
# CI runner fails on test failures and skipped tests.
PYTHONDONTWRITEBYTECODE=1 python3 tests/run_ci.py

# Separate JavaScript checks; preserve failures instead of hiding them with break.
bash -c 'for test_file in tests/test_*.js; do node "$test_file" || exit "$?"; done'
```

QML tests use isolated temporary configuration and an offscreen renderer;
they require Quickshell. Pointer-event tests also require the Qt 6
`qmltestrunner` (Qt Quick Test). JavaScript checks require Node.js.

Tests cover network reconnects and password transport, dock layout and pointer
interaction, monitor selection, theming, and EQ live updates and rollback.
Fake system commands keep network/audio tests isolated from the real session.
Live compositor and hardware checks are still necessary.

### World clocks

Open **Settings → Features → World Clocks**. Select any of the bundled 249 ISO countries/territories, search for a city inside that country, then choose **Add clock**. Up to eight DST-aware clocks can be reordered or removed. Weather is fetched in one batched Open-Meteo request and the last successful response is cached for offline display. Use **Screen Prefs → World Clocks** to choose the target monitor(s).

### Markets

Open **Settings → Features → Markets** for the official TCMB USD/TRY buying and selling rates plus CoinGecko Bitcoin and Ethereum spot prices in USD/TRY. Crypto cards include the 24-hour percentage change. The built-in converter supports the current currencies published by Frankfurter, including USD, TRY, EUR and Philippine Peso (PHP), with reversible pairs and offline rate caching. Data refreshes every five minutes and the last successful response remains available offline.

The World Clocks and Markets desktop panels can be dragged from anywhere on their surface. Their positions are saved per monitor role in `desktop_widgets.json`, so the layout survives restarts and connector changes.

## Activity Monitor

Add **Activity Monitor** from **Settings → Appearance → Bar Settings** and click
its bar chip to open the live panel. The compact view shows CPU, memory, network
and disk activity; the expanded view adds GPU, storage and a searchable process
table. Sampling starts only while the panel is open, so the module stays idle in
the background.

The reader uses Linux `/proc` and `/sys` interfaces rather than compositor IPC,
so the same module works on Hyprland, MangoWC and Niri. A prebuilt x86-64 reader
is included. Other architectures can rebuild it locally:

```bash
make -C Modules/bar/ActivityMonitor clean all
```

Building requires a C++17 compiler. The bundled source and reader are adapted
from [stappmus/omarchy-activity-monitor](https://github.com/stappmus/omarchy-activity-monitor)
2.1.1 and retain its MIT licence in
[`Modules/bar/ActivityMonitor/LICENSE`](Modules/bar/ActivityMonitor/LICENSE).

## Night Light

Warm-tint the display in the evening to reduce eye strain. Manual control, fixed-time scheduling, cross-compositor.

### Setup

Install the backend for your compositor:

```bash
# Hyprland
sudo pacman -S hyprsunset

# Niri / MangoWC
sudo pacman -S gammastep
```

> **Why two backends?** Modern Hyprland removed the `wlr-gamma-control` protocol that gammastep relies on, so it now ships its own daemon (`hyprsunset`). Quickshell detects the active compositor and uses the appropriate backend automatically.

### Usage

**Settings → Appearance → Night Light**:

- Toggle the filter on or off
- Adjust temperature with the 1000–6500 K slider
- Pick a preset (Candle, Warm, Reading, Neutral, Daylight)
- Enable the **Schedule** card and set on/off times — e.g. `19:00 → 07:00` (midnight-wrap supported)
- Enable **Apply on startup** to restore the saved temperature at shell boot

## Network & Wi-Fi

Open **Settings → Hardware → Network** to manage Ethernet and Wi-Fi.
Available networks show a percentage and a four-level signal indicator.
Expand a secured network to enter a masked password, then use **Connect** or
Enter. Leave the password blank to try saved credentials; open networks do
not require a password field. Connection failures and timeouts appear in the
expanded network row.

Passwords are passed to the connection helper and `nmcli --ask` through
stdin, not command-line arguments or Quickshell configuration files. The
field clears after submission or when the row closes. Raw `nmcli` error
output is not returned to the UI, because it may contain sensitive data.
NetworkManager's own credential-storage policy is unchanged.

Network and VPN services share an escape-aware `nmcli` parser. Active
Ethernet/Wi-Fi detection scans past VPN and other unsupported connection
types. Monitor processes reconnect with bounded backoff, take a fresh
snapshot even after a silent reconnect, and coalesce refresh requests that
arrive while a query is running. VPN details and elapsed connection times
are tracked by UUID.

## Audio Equaliser

Native 10-band parametric EQ built on a PipeWire filter-chain. The UI invokes a helper that persists `eq/parametric-eq.txt` and creates:

- `effect_input.eq` — virtual EQ sink (applications play into this)
- `effect_output.eq` — processed stream, manually linked to the selected physical sink

### Quick start

```bash
# Apply a flat curve to the current default sink
~/.config/quickshell/scripts/eq_filter_chain.sh apply 0 0 0 0 0 0 0 0 0 0 auto

# Check status
~/.config/quickshell/scripts/eq_filter_chain.sh status

# Disable
~/.config/quickshell/scripts/eq_filter_chain.sh disable
```

Expected healthy output: `conf_exists=yes`, plus `effect_input.eq` and `filter-chain` visible in `wpctl status`.

### Live updates and recovery

On an existing compatible EQ filter with the same output target, preset and
band changes update the running filter's controls without restarting
PipeWire, relinking channels or moving application streams. The helper
reports `applied live`. Initial setup, migration from an older filter, or
other changes requiring filter reconstruction can still restart the audio
services and briefly interrupt playback.

EQ state is read as data and written atomically with private permissions.
Operations share a lock; recovery skips busy operations. Channel retries and
closed-stream handling avoid unnecessary failures.

Failed apply operations attempt to restore the previous configuration and
audio state. If rollback is incomplete, the backup and
`${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/eq_filter_chain.pending`
are retained. The marker blocks further apply, switch, disable and recovery
commands until the configuration is repaired.

**Recovery limits:** there is no automatic crash-recovery command. Do not
blindly delete the pending marker: inspect the reported backup, restore the
intended configuration and verify the audio state before clearing it.
Rollback is not a guarantee against power loss or `SIGKILL`, and it does not
preserve every application's custom per-stream output assignment.

### Device switching

When you change output devices in `pavucontrol` or another mixer, the Equalizer module refreshes sink state in the background and **auto-reapplies** the active EQ curve — the same preset follows you from speakers → USB headphones → Bluetooth without rebuilding the curve.

The last known physical sink is stored in `~/.local/state/quickshell/eq_filter_chain.state` as `BASE_SINK`.

## Architecture

- [`Services/`](Services/) — shared state, compositor adapters and system integrations.
- [`Modules/`](Modules/) — bar, dock, settings and the Hyprland Workspace Overview.
- [`Widgets/`](Widgets/) — shared visual components and theme.
- [`Services/core/`](Services/core/) — persistence, parsing and file watching.
- [`shell.qml`](shell.qml) — staged startup to keep the initial frame responsive.

Bar and dock modules share a registry and visual catalog. See the
[module registry guide](docs/MODULE_REGISTRY.md) and
[contribution guide](CONTRIBUTING.md) before adding a module.

## Troubleshooting

<details>
<summary><b>Icons are missing or show as empty squares</b></summary>

Install JetBrainsMono Nerd Font and refresh the font cache:

```bash
sudo pacman -S ttf-jetbrains-mono-nerd
fc-cache -fv
```
</details>

<details>
<summary><b>Dock application icons do not match the selected theme</b></summary>

Application icons use the Qt icon theme, separately from Nerd Font glyphs.
If your session uses qt6ct, install its Qt 6 platform-theme plugin, choose an
icon theme in qt6ct, and make sure Quickshell starts with
`QT_QPA_PLATFORMTHEME=qt6ct`.

When using a custom systemd user service, compositor environment settings
are not automatically inherited. Import the variables from the compositor
session **before** starting your service, including the theme selection:

```bash
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE NIRI_SOCKET QT_QPA_PLATFORMTHEME
```

The Niri socket variable is only relevant to Niri. Set the theme variable in
your session first; importing an unset variable does not configure Qt.
An already running Quickshell must be restarted to pick up the new process
environment. This repository does not install a `quickshell.service` unit;
use either the direct startup examples above or your own service, not both.

</details>

<details>
<summary><b>Network or Bluetooth toggles do nothing</b></summary>

Make sure the services are running:

```bash
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
```
</details>

<details>
<summary><b>Night Light does not tint the screen</b></summary>

- **Hyprland**: confirm `hyprsunset` is installed (`which hyprsunset`). Modern Hyprland no longer exposes `wlr-gamma-control`, so `gammastep` will report _"Zero outputs support gamma adjustment"_ and silently do nothing.
- **Niri / MangoWC**: test `gammastep -O 4000` directly — it should tint the screen. If it doesn't, the wlroots gamma-control protocol may not be advertised by your compositor build.
- Look for an error banner at the top of **Settings → Night Light** for diagnostic info.
</details>

<details>
<summary><b>The equaliser has no effect</b></summary>

Inspect the current state without changing the EQ curve:

```bash
~/.config/quickshell/scripts/eq_filter_chain.sh status
wpctl status
```

Check for `conf_exists=yes` and the EQ nodes. See [Audio Equaliser](#audio-equaliser)
for setup and incomplete-transaction recovery precautions.
</details>

<details>
<summary><b>Dock shows no running indicators on Hyprland</b></summary>

The dock uses Hyprland's socket2 stream via `socat` or `ncat`. Install one of them:

```bash
sudo pacman -S socat
# or
sudo pacman -S openbsd-netcat
```

Without either, the dock falls back to 2.5 s polling — indicators still work but update slower.
</details>

<details>
<summary><b>MangoWC shows no monitors, tags or running applications</b></summary>

Confirm that Mango 0.16+ and its IPC client are active in the same session:

```bash
mmsg get version
mmsg get all-monitors
mmsg get all-tags
mmsg get all-clients
```

Each command should return JSON. If they cannot connect, verify that Quickshell
was launched from Mango's session environment and that
`MANGO_INSTANCE_SIGNATURE` is available. Restart Quickshell after correcting
the session startup command.
</details>

<details>
<summary><b>A component appears on the wrong monitor after reconnecting cables</b></summary>

First check **Settings → Hardware → Screen Prefs**. Remember that **Toast**
controls popup notification cards while **Notifications** controls the
notification-centre module.

Inspect the current role map:

```bash
cat ~/.config/quickshell/monitor_runtime.json
```

An unmatched connected output remains selectable by its current connector
name. Physical-role remapping is described under
[multi-monitor roles](#multi-monitor-roles-and-notifications). Back up local
identity files before changing mappings; restarting alone does not guarantee
that every compositor will rebuild them.
</details>

## Links

- Demos & tutorials: [YouTube: @linuxlifex](https://www.youtube.com/@linuxlifex)
- Built on: [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell)
- Theming: [InioX/matugen](https://github.com/InioX/matugen)
- Companion project: [ekremx25/smartcomplete](https://github.com/ekremx25/smartcomplete)

## License

[MIT](LICENSE)
