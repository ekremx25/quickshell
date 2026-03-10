
# Quickshell

A modern, feature-rich desktop shell for **Niri**, **Hyprland**, and **MangoWC** using [Quickshell](https://github.com/outfoxxed/quickshell).


https://github.com/user-attachments/assets/c4c67fdb-3545-4575-be4e-232178523691

## Features

- **Top Bar**:
  - Workspaces (Japan numerals, scrollable)
  - System Info (CPU, RAM, Temp, Disk)
  - Controls (Volume, Mic, Brightness)
  - Weather, Clock, Calendar, Event Countdown
  - Notification Center
  - Tray & Clipboard Manager
- **Dock**:
  - Animated icons with zoom effect
  - Drag & Drop pinning/reordering
  - Live running indicators
- **Settings Dashboard**:
  - Drag & Drop module customization
  - Monitor management (Resolution, Scale, HDR, VRR)
  - Network & Bluetooth connection managers
- **OSD**: Volume/Brightness on-screen display
- **App Drawer**: Application launcher
- **Wallpaper Picker**: With color palette extraction

## Supported Compositors

| Compositor | Status |
|------------|--------|
| [Niri](https://github.com/YaLTeR/niri) | ✅ Fully supported |
| [Hyprland](https://github.com/hyprwm/Hyprland) | ✅ Fully supported |
| [MangoWC](https://github.com/DreamMaoMao/mango) | ✅ Fully supported |

## Dependencies

### Core
- **Quickshell**: The shell framework
- **Niri**, **Hyprland**, or **MangoWC**: Wayland compositor

### Fonts
- **JetBrainsMono Nerd Font**: Required for icons and text
  - Arch: `ttf-jetbrains-mono-nerd`
  - Fedora: `jetbrains-mono-nerd-fonts`
- **Inter**: Modern sans-serif font used for UI text
  - Arch: `ttf-inter`
- **Font Awesome 6 Free**: Used for some specific icons
  - Arch: `ttf-font-awesome`

### Theming
- **[matugen](https://github.com/InioX/matugen)**: Material You color generation from wallpapers
  - Arch (AUR): `paru -S matugen-bin` or `yay -S matugen-bin`
  - Cargo: `cargo install matugen`

### System Utilities
- **NetworkManager** (`nmcli`, `nm-connection-editor`): Network management
- **BlueZ** (`bluetoothctl`): Bluetooth devices
- **Pipewire** (`pw-dump`): Audio control
- **Systemd** (`systemctl`, `loginctl`): Power management and session locking

### Audio EQ Module Requirements
The native EQ module (`Modules/bar/Equalizer` + `scripts/eq_filter_chain.sh`) requires:
- `pipewire`
- `pipewire-pulse`
- `wireplumber`
- `libpulse` (`pactl` on Arch)
- `pipewire` tools (`pw-cli`, `pw-link`)
- `wireplumber` tools (`wpctl`)
- `systemd --user` session support

Example (Arch):
```bash
sudo pacman -S pipewire pipewire-pulse wireplumber libpulse
```

This script expects these commands to exist in `PATH`:
- `pactl`
- `wpctl`
- `pw-cli`
- `pw-link`
- `systemctl`

## Installation

1. **Clone the repository**:
    ```bash
    git clone https://github.com/ekremx25/quickshell ~/.config/quickshell
    ```

2. **Install dependencies** (Arch Linux):
    ```bash
    sudo pacman -S ttf-jetbrains-mono-nerd networkmanager bluez pipewire
    ```

3. **Install Quickshell**:
    Follow the instructions at [Quickshell's Repository](https://github.com/outfoxxed/quickshell).

4. **Run**:

    **For Niri** — add to `~/.config/niri/config.kdl`:
    ```kdl
    spawn-at-startup "quickshell"
    ```

    **For Hyprland** — add to `~/.config/hypr/hyprland.conf`:
    ```ini
    exec-once = quickshell
    ```

    **For MangoWC** — add to `~/.config/mango/autostart.sh`:
    ```bash
    pgrep -x quickshell >/dev/null || quickshell &
    ```

    Or run manually:
    ```bash
    quickshell
    ```
    My youtube channel : https://www.youtube.com/@Linux-Windows-LifeX

## Configuration

- **Bar Modules**: Open the Settings menu to drag & drop modules to rearrange the bar.
- **Dock**: Rearrange existing icons. Left-click to open apps. Right-click to pin/unpin.
- **Monitors**: Go to Settings > Monitors to configure resolution, scale, HDR, and VRR.
- **Theme**: Wallpaper-based color palette extraction for automatic theming.

## EQ Quick Start

1. Apply EQ with 10-band gains (`dB`) and auto-target current default sink:
```bash
~/.config/quickshell/scripts/eq_filter_chain.sh apply 0 0 0 0 0 0 0 0 0 0 auto
```

2. Check status:
```bash
~/.config/quickshell/scripts/eq_filter_chain.sh status
wpctl status | grep -E "effect_input.eq|filter-chain"
```

3. Disable EQ:
```bash
~/.config/quickshell/scripts/eq_filter_chain.sh disable
```

Expected healthy output:
- `conf_exists=yes`
- `effect_input.eq` visible
- `filter-chain` visible

## How The EQ Works

- The UI writes a 10-band parametric EQ file to `eq/parametric-eq.txt`.
- `scripts/eq_filter_chain.sh` creates a PipeWire filter-chain with:
  - `effect_input.eq` as the virtual EQ sink
  - `effect_output.eq` as the EQ output stream
- Applications play into `effect_input.eq`, then PipeWire sends the processed signal to the selected physical output device.
- The script disables PipeWire autoconnect for the EQ output and manually links it to the selected sink. This avoids the EQ jumping to the wrong device on multi-output systems.
- The script stores the last physical target in `~/.local/state/quickshell/eq_filter_chain.state` as `BASE_SINK`.
- The Equalizer panel shows the real physical output volume, not just the virtual EQ sink volume.

### Device Switching

- If you change output devices in `pavucontrol` or another mixer, the Equalizer module refreshes sink state in the background.
- When it detects a new physical output, it auto-runs `apply` again with the current EQ values.
- This means the same preset can move from speakers to USB headphones or Bluetooth audio without manually rebuilding the EQ curve.
- Some applications may still need a quick pause/resume if their stream was already active during the device handoff.

## Troubleshooting & Helpful Scripts

- **MangoWC Auto Layout**: If you hotplug monitors under MangoWC, Mango might default the new screens to the `(0,0)` coordinate causing overlapping displays. You can dynamically snap them side-by-side using the provided Python script.
  - **Manual use**: `python3 ~/.config/quickshell/scripts/mango_auto_layout.py`
  - **Auto-start**: Add `python3 ~/.config/quickshell/scripts/mango_auto_layout.py &` to your `~/.config/mango/autostart.sh`
  - **Keybind**: Add `bind=SUPER,p,spawn,python3 ~/.config/quickshell/scripts/mango_auto_layout.py` to your `~/.config/mango/config.conf`
- **Global/portable EQ module (PipeWire native)**:
  - Script: `scripts/eq_filter_chain.sh`
  - Works with `XDG_CONFIG_HOME` automatically (default: `~/.config`)
  - Optional overrides:
    - `QUICKSHELL_CONFIG_DIR=/path/to/quickshell`
    - `PIPEWIRE_CONF_DIR=/path/to/pipewire.conf.d`
  - Required tools: `pactl`, `wpctl`, `pw-cli`, `pw-link`, `systemctl`
  - Quick test:
    - `~/.config/quickshell/scripts/eq_filter_chain.sh apply 0 0 0 0 0 0 0 0 0 0 auto`
    - `~/.config/quickshell/scripts/eq_filter_chain.sh status`
  - The Equalizer UI now auto-reapplies the current preset when the active physical output device changes.
- **Missing Icons**: Ensure `JetBrainsMono Nerd Font` is installed and the cache is updated (`fc-cache -fv`).
- **Network/Bluetooth not working**: Ensure `NetworkManager` and `bluetooth` services are running.

## License

MIT
