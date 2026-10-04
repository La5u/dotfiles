# dotfiles

Hyprland with a 3x3 workspace grid, Waybar, Waypaper and wallpapers.

- Workspaces 1-9 form a 3x3 grid; three-finger swipes move between neighbours (GridGestures plugin), and Waybar shows your position as an arrow.
- Hyprland uses the Lua config (0.55+). Monitor, brightness and device settings are per machine in `hypr/hosts/<uname -m>.lua`.

## Install

Fedora (including Fedora Asahi Remix on Apple Silicon):

```sh
sudo dnf install -y git
git clone https://github.com/La5u/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Then log in on a TTY and run `Hyprland`.

On other distros, install the packages yourself and run `./install.sh --links`.

The installer enables the `lionheartp/Hyprland` and `scottames/ghostty` COPRs, installs packages, builds the grid plugin into `~/.local/share/hypr`, and symlinks everything into place. Files it replaces are moved to `~/.dotfiles-backup/<date>/`.

## Notes

- The Waybar webcam and gaming-mode toggles use `sudo -n`, so they need matching sudoers rules; without them they show a notification instead.
- The grid plugin must be rebuilt after every Hyprland update: `./install.sh --links`.
