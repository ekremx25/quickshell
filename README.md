
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

## Troubleshooting & Helpful Scripts

- **MangoWC Auto Layout**: If you hotplug monitors under MangoWC, Mango might default the new screens to the `(0,0)` coordinate causing overlapping displays. You can dynamically snap them side-by-side using the provided Python script.
  - **Manual use**: `python3 ~/.config/quickshell/scripts/mango_auto_layout.py`
  - **Auto-start**: Add `python3 ~/.config/quickshell/scripts/mango_auto_layout.py &` to your `~/.config/mango/autostart.sh`
  - **Keybind**: Add `bind=SUPER,p,spawn,python3 ~/.config/quickshell/scripts/mango_auto_layout.py` to your `~/.config/mango/config.conf`
- **Missing Icons**: Ensure `JetBrainsMono Nerd Font` is installed and the cache is updated (`fc-cache -fv`).
- **Network/Bluetooth not working**: Ensure `NetworkManager` and `bluetooth` services are running.

## License

MIT
