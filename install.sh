#!/usr/bin/env bash
# Set up the Hyprland 3x3 grid desktop from this repo.
#   ./install.sh          packages (Fedora or Arch), grid plugin, links
#   ./install.sh --links  grid plugin and links only
set -euo pipefail

DOT="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# repo path -> target path
LINKS=(
    "hypr/hyprland.lua           .config/hypr/hyprland.lua"
    "hypr/hypridle.conf          .config/hypr/hypridle.conf"
    "hypr/scripts/redlight.sh    .config/hypr/scripts/redlight.sh"
    "waybar/config               .config/waybar/config"
    "waybar/style.css            .config/waybar/style.css"
    "waypaper/config.ini         .config/waypaper/config.ini"
    "waypaper/style.css          .config/waypaper/style.css"
    "ghostty/config.ghostty      .config/ghostty/config.ghostty"
    "rofi/config.rasi            .config/rofi/config.rasi"
    "thunar/uca.xml              .config/Thunar/uca.xml"
    "hyprland-mimeapps.list      .config/hyprland-mimeapps.list"
    "systemd/online-notifier.service .config/systemd/user/online-notifier.service"
    "systemd/hyprland-session.target .config/systemd/user/hyprland-session.target"
    "wallpapers                  Pictures/Wallpapers"
    "shell/bash_profile          .bash_profile"
    "shell/bashrc                .bashrc"
    "shell/bash_logout           .bash_logout"
    "shell/profile               .profile"
    "shell/prompt.sh             .bashrc.d/prompt.sh"
)
for f in "$DOT"/waybar/*.sh; do LINKS+=("waybar/${f##*/} .config/waybar/${f##*/}"); done
for f in "$DOT"/bin/*; do LINKS+=("bin/${f##*/} .local/bin/${f##*/}"); done
# Betterfox user.js into the profile Firefox launches by default, if one exists yet.
# Newer Firefox keeps profiles under ~/.config/mozilla, older under ~/.mozilla.
for ff in .config/mozilla/firefox .mozilla/firefox; do
    ff_profile=$(awk -F= '/^\[Install/{i=1} i&&/^Default=/{print $2; exit}' "$HOME/$ff/profiles.ini" 2>/dev/null || true)
    [[ -n "$ff_profile" ]] && { LINKS+=("firefox/user.js $ff/$ff_profile/user.js"); break; }
done

COPRS=(lionheartp/Hyprland scottames/ghostty)
# swaybg is never run (hyprmosaic draws the wallpapers), but Waypaper refuses to start without a backend installed.
FEDORA_PACKAGES=(
    hyprland hyprland-devel hyprgraphics-devel hyprland-guiutils hypridle hyprsunset
    xdg-desktop-portal-hyprland hyprpolkitagent
    waybar waypaper swaybg rofi dunst ghostty thunar firefox unzip mpv obs-studio
    brightnessctl playerctl wireplumber pavucontrol blueman bluez
    NetworkManager-wifi nm-connection-editor iw
    grim slurp wl-clipboard swappy ImageMagick jq imv libnotify
    git gcc-c++ make pkgconf-pkg-config pixman-devel libdrm-devel pango-devel
    libinput-devel systemd-devel wayland-devel libxkbcommon-devel
    curl fontconfig terminus-fonts-console
)
# Arch ships headers with the libraries, so no -devel packages are needed.
ARCH_PACKAGES=(
    hyprland hyprland-guiutils hypridle hyprsunset
    xdg-desktop-portal-hyprland hyprpolkitagent
    waybar swaybg rofi dunst ghostty thunar firefox unzip mpv obs-studio hyprshot
    brightnessctl playerctl wireplumber pavucontrol blueman bluez bluez-utils
    networkmanager nm-connection-editor iw
    grim slurp wl-clipboard swappy imagemagick jq imv libnotify
    git base-devel pkgconf pixman libdrm pango libinput systemd wayland libxkbcommon
    curl fontconfig terminus-font
)
AUR_PACKAGES=(waypaper)
CONSOLE_FONT=ter-132b
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DejaVuSansMono.tar.xz"
HYPRSHOT_URL="https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot"
HYPRMOSAIC_URL="https://github.com/La5u/hyprmosaic"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

install_fedora() {
    say "Enabling COPRs: ${COPRS[*]}"
    sudo dnf install -y dnf-plugins-core
    for c in "${COPRS[@]}"; do sudo dnf copr enable -y "$c" || warn "COPR $c unavailable"; done

    say "Installing packages"
    sudo dnf install -y --skip-unavailable "${FEDORA_PACKAGES[@]}"

    # Fedora ships an empty OpenH264 stub; OBS needs Cisco's real build to record H.264.
    if rpm -q noopenh264 >/dev/null 2>&1; then
        say "Installing Cisco OpenH264"
        sudo dnf swap -y noopenh264 openh264 || warn "Could not install OpenH264"
    fi
}

install_arch() {
    say "Installing packages"
    sudo pacman -S --needed --noconfirm "${ARCH_PACKAGES[@]}"

    local aur
    aur=$(command -v paru || command -v yay || true)
    if [[ -n "$aur" ]]; then
        "$aur" -S --needed --noconfirm "${AUR_PACKAGES[@]}" || warn "Could not install ${AUR_PACKAGES[*]} from the AUR"
    else
        warn "No AUR helper (paru or yay); install ${AUR_PACKAGES[*]} yourself"
    fi
}

install_packages() {
    if command -v dnf >/dev/null; then
        install_fedora
    elif command -v pacman >/dev/null; then
        install_arch
    else
        warn "Neither dnf nor pacman found; install the packages yourself"
        return
    fi

    command -v waypaper >/dev/null || warn "waypaper is not installed"

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
        if command -v dracut >/dev/null; then
            sudo dracut -f
        elif command -v mkinitcpio >/dev/null; then
            sudo mkinitcpio -P
        fi
    fi

    # Only on laptops whose battery driver supports a charge limit.
    if compgen -G "/sys/class/power_supply/*/charge_control_end_threshold" >/dev/null &&
        ! cmp -s "$DOT/udev/99-charge-limit.rules" /etc/udev/rules.d/99-charge-limit.rules; then
        say "Limiting battery charge to 80%"
        sudo install -Dm 644 "$DOT/udev/99-charge-limit.rules" /etc/udev/rules.d/99-charge-limit.rules
        sudo udevadm control --reload
        sudo udevadm trigger --action=add --subsystem-match=power_supply
    fi

    # Only on machines with macOS partitions (Apple Silicon dual boot).
    if lsblk -no FSTYPE | grep -qx apfs &&
        ! cmp -s "$DOT/udev/99-hide-apfs.rules" /etc/udev/rules.d/99-hide-apfs.rules; then
        say "Hiding macOS partitions from file managers"
        sudo install -Dm 644 "$DOT/udev/99-hide-apfs.rules" /etc/udev/rules.d/99-hide-apfs.rules
        sudo udevadm control --reload
        sudo udevadm trigger --subsystem-match=block
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
    local src="$HOME/.local/src/hyprmosaic"
    say "Building hyprmosaic plugin"
    if [[ -d "$src/.git" ]]; then
        git -C "$src" pull -q --ff-only || warn "Could not update $src; building the current checkout"
    else
        git clone -q "$HYPRMOSAIC_URL" "$src" || return 1
    fi
    make -C "$src" -s &&
        install -Dm 755 "$src/hyprmosaic.so" "$HOME/.local/share/hypr/hyprmosaic.so"
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

# The plugin is optional: without it everything works except grid swipes and per-workspace wallpapers.
if ! { check_hyprland && build_plugin; }; then
    warn "hyprmosaic not built; fix the error above, then rerun ./install.sh --links"
fi

systemctl --user daemon-reload
# Disabled 2026-10-05 (reliable Wi-Fi now): systemctl --user enable --now online-notifier.service >/dev/null 2>&1 || warn "Could not enable online-notifier"

[[ -d "$BACKUP" ]] && say "Replaced files are in $BACKUP"
say "Done. Log in on TTY1 and Hyprland starts automatically."
