# dotfiles

Hyprland with a 3x3 workspace grid, Waybar, Waypaper and wallpapers.

- Workspaces 1-9 form a 3x3 grid; three-finger swipes move between neighbours (GridGestures plugin), and Waybar shows your position as an arrow.
- Hyprland uses the Lua config (0.55+). Monitors run at their native resolution with automatic scaling; laptop panels drop to about 60 Hz on battery.
- Nothing is tied to one machine. Put per-machine tweaks (extra monitors, mice, one-off binds) in `~/.config/hypr/local.lua`, which is loaded if it exists and is not part of the repo.

## Install

Fedora (including Fedora Asahi Remix on Apple Silicon) or Arch:

```sh
git clone https://github.com/La5u/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Then log in on TTY1; Hyprland starts automatically.

On Fedora the installer enables the `lionheartp/Hyprland` and `scottames/ghostty` COPRs. On Arch it uses pacman, plus `paru` or `yay` for waypaper from the AUR. On other distros, install the packages yourself and run `./install.sh --links`.

The installer installs packages, builds the grid plugin into `~/.local/share/hypr`, and symlinks everything into place. Files it replaces are moved to `~/.dotfiles-backup/<date>/`.

## Notes

- The Waybar webcam and gaming-mode toggles use `sudo -n`, so they need matching sudoers rules; without them they show a notification instead.
- The grid plugin must be rebuilt after every Hyprland update: `./install.sh --links`.
