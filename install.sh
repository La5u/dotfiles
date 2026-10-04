#!/usr/bin/env bash
# Set up the Hyprland 3x3 grid desktop from this repo.
#   ./install.sh          packages (Fedora only), grid plugin, links
#   ./install.sh --links  grid plugin and links only
set -euo pipefail

DOT="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# repo path -> target path
LINKS=(
    "hypr/hyprland.lua           .config/hypr/hyprland.lua"
    "hypr/hypridle.conf          .config/hypr/hypridle.conf"
    "hypr/hosts                  .config/hypr/hosts"
    "hypr/scripts/redlight.sh    .config/hypr/scripts/redlight.sh"
    "waybar/config               .config/waybar/config"
    "waybar/style.css            .config/waybar/style.css"
    "waypaper/config.ini         .config/waypaper/config.ini"
    "ghostty/config.ghostty      .config/ghostty/config.ghostty"
    "rofi/config.rasi            .config/rofi/config.rasi"
    "systemd/online-notifier.service .config/systemd/user/online-notifier.service"
    "wallpapers                  Pictures/Wallpapers"
    "shell/bash_profile          .bash_profile"
)
for f in "$DOT"/waybar/*.sh; do LINKS+=("waybar/${f##*/} .config/waybar/${f##*/}"); done
for f in "$DOT"/bin/*; do LINKS+=("bin/${f##*/} .local/bin/${f##*/}"); done

COPRS=(lionheartp/Hyprland scottames/ghostty)
PACKAGES=(
    hyprland hyprland-devel hyprland-guiutils hypridle hyprsunset awww
    waybar waypaper rofi dunst ghostty thunar firefox
    brightnessctl playerctl wireplumber pavucontrol blueman bluez
    NetworkManager-wifi nm-connection-editor iw
    grim slurp wl-clipboard swappy ImageMagick jq imv libnotify
    gcc-c++ make pkgconf-pkg-config pixman-devel libdrm-devel pango-devel
    libinput-devel systemd-devel wayland-devel libxkbcommon-devel
    curl fontconfig terminus-fonts-console
)
CONSOLE_FONT=ter-132b
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DejaVuSansMono.tar.xz"
HYPRSHOT_URL="https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

install_packages() {
    if ! command -v dnf >/dev/null; then
        warn "dnf not found; skipping packages (use --links on non-Fedora systems)"
        return
    fi
    say "Enabling COPRs: ${COPRS[*]}"
    sudo dnf install -y dnf-plugins-core
    for c in "${COPRS[@]}"; do sudo dnf copr enable -y "$c" || warn "COPR $c unavailable"; done

    say "Installing packages"
    sudo dnf install -y --skip-unavailable "${PACKAGES[@]}"

    command -v waypaper >/dev/null || warn "waypaper not installed (missing from COPR?)"

    if ! command -v hyprshot >/dev/null; then
        say "Installing hyprshot"
        mkdir -p "$HOME/.local/bin"
        curl -fsSL "$HYPRSHOT_URL" -o "$HOME/.local/bin/hyprshot" &&
            chmod +x "$HOME/.local/bin/hyprshot" || warn "Could not install hyprshot"
    fi

    # Large TTY font for the login prompt, also baked into the initramfs for early boot.
    if ! grep -q "^FONT=$CONSOLE_FONT$" /etc/vconsole.conf 2>/dev/null; then
        say "Setting console font $CONSOLE_FONT"
        sudo sed -i '/^FONT=/d' /etc/vconsole.conf 2>/dev/null || true
        echo "FONT=$CONSOLE_FONT" | sudo tee -a /etc/vconsole.conf >/dev/null
        sudo systemctl restart systemd-vconsole-setup
        sudo dracut -f
    fi

    if [[ -d /sys/class/power_supply/macsmc-battery ]] &&
        ! cmp -s "$DOT/udev/99-charge-limit.rules" /etc/udev/rules.d/99-charge-limit.rules; then
        say "Limiting battery charge to 80%"
        sudo install -Dm 644 "$DOT/udev/99-charge-limit.rules" /etc/udev/rules.d/99-charge-limit.rules
        sudo udevadm control --reload
        sudo udevadm trigger --subsystem-match=power_supply --sysname-match=macsmc-battery
    fi

    if ! fc-list | grep -q "DejaVuSansM Nerd Font"; then
        say "Installing DejaVuSansM Nerd Font"
        mkdir -p "$HOME/.local/share/fonts/DejaVuSansMNerd"
        curl -fsSL "$FONT_URL" | tar -xJ -C "$HOME/.local/share/fonts/DejaVuSansMNerd" &&
            fc-cache -f >/dev/null || warn "Could not install DejaVuSansM Nerd Font"
    fi
}

check_hyprland() {
    command -v Hyprland >/dev/null || { warn "Hyprland is not installed"; return 1; }
    local v
    v=$(Hyprland --version | awk '/^Hyprland/{print $2; exit}')
    # Lua configs need Hyprland 0.55 or newer.
    if [[ "$(printf '%s\n0.55.0\n' "$v" | sort -V | head -1)" != "0.55.0" ]]; then
        warn "Hyprland $v is too old for hyprland.lua (needs 0.55+)"
        return 1
    fi
}

build_plugin() {
    say "Building GridGestures plugin"
    make -C "$DOT/gridgestures" -s &&
        install -Dm 755 "$DOT/gridgestures/gridgestures.so" "$HOME/.local/share/hypr/gridgestures.so"
}

link() {
    local src="$DOT/$1" dst="$HOME/$2"
    [[ "$(readlink "$dst" 2>/dev/null)" == "$src" ]] && return
    if [[ -e "$dst" || -L "$dst" ]]; then
        mkdir -p "$BACKUP/$(dirname "$2")"
        mv "$dst" "$BACKUP/$2"
        echo "  backed up ~/$2"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  linked ~/$2"
}

say "Linking configs"
for entry in "${LINKS[@]}"; do
    read -r src dst <<<"$entry"
    link "$src" "$dst"
done

[[ "${1:-}" == "--links" ]] || install_packages

# The grid plugin is optional: without it everything works except swipe gestures.
if ! { check_hyprland && build_plugin; }; then
    warn "Grid plugin not built; fix the error above, then rerun ./install.sh --links"
fi

systemctl --user daemon-reload
systemctl --user enable --now online-notifier.service >/dev/null 2>&1 || warn "Could not enable online-notifier"

[[ -d "$BACKUP" ]] && say "Replaced files are in $BACKUP"
say "Done. Log in on a TTY and run: Hyprland"
