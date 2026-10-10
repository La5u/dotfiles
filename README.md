# dotfiles

Hyprland with a 3x3 workspace grid, Waybar, Waypaper and wallpapers.

- Workspaces 1-9 form a 3x3 grid; three-finger swipes move between neighbours, and Waybar shows your position as an arrow. Each workspace has its own wallpaper that slides with it, picked with Waypaper (Super+Shift+W). Both come from [hyprmosaic](https://github.com/La5u/hyprmosaic).
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

The installer installs packages, clones and builds hyprmosaic into `~/.local/share/hypr`, and symlinks everything into place. Files it replaces are moved to `~/.dotfiles-backup/<date>/`.

## Notes

- App preferences now include Neovim, MPV, yt-dlp, Zed, qt6ct, GTK, htop, Fcitx5, autostart suppressions and Thunar. Close Thunar and stop `xfconfd` before installing to prevent cached preferences overwriting the restored XML. Generated window geometry and inactive Thunar shortcut dumps are excluded.
- Laptop-specific PipeWire latency and batsignal overrides are tracked but only linked with `./install.sh --links --machine-settings`. Install/enable batsignal separately if needed; other machines keep their own audio/battery settings.
- `bin/agent-window` and `agent-windows/shell.bash` track and restore agent terminals. See [agent-windows/README.md](agent-windows/README.md); runtime records and conversations stay outside Git. `codex-sub` requires Codex; `mg.sh` requires FFmpeg, gifski and MPV.
- Pi extension sources and agent definitions are in `pi/`; the installer links them under `~/.pi/agent/`. Install Pi and authenticate its providers separately. Codex/Claude/Pi/Zed/gifski are not installed by this script.
- Git preferences are included from `~/.config/git/dotfiles.conf`, preserving local identity/authentication. The tracked commit-message guard is installed in `~/.config/git/hooks`; existing custom hook locations are preserved.
- Ghostty's normal `config` and `config.ghostty` paths both link to the tracked config. Per-machine DPI, credentials, OBS stream settings, caches and application state are intentionally excluded.
- Bash aliases, prompt, login profile, logout file and `.profile` are tracked in `shell/` and symlinked by the installer. Keep credentials and local shell overrides in `~/.bashrc.local` (loaded by `.bashrc`, never tracked); `~/.free-coding-models.env` also stays local.

- The Waybar webcam and gaming-mode toggles use `sudo -n`, so they need matching sudoers rules; without them they show a notification instead.
- hyprmosaic must be rebuilt after every Hyprland update: `./install.sh --links` (it also pulls the latest version).
