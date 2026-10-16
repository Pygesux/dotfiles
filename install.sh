#!/usr/bin/env bash
# Usage: ./install.sh [profile ...]
#   ./install.sh                 base only
#   ./install.sh laptop          base + laptop
#   ./install.sh laptop nvidia   base + laptop + nvidia
#
# For each profile, looks in packages/ for:
#   <profile>.pacman     official repo packages
#   <profile>.aur        AUR packages (built with yay)
#   <profile>.services   systemd units to enable
# Missing files are skipped. Lines starting with # and blank lines are ignored.

set -euo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$DOTS/packages"
PROFILES=(base "$@")

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# Prints a list file's entries, minus comments and blanks.
read_list() { grep -vE '^\s*(#|$)' "$1" || true; }

ensure_yay() {
  command -v yay >/dev/null && return
  log "Building yay"
  sudo pacman -S --needed --noconfirm git base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

install_profile() {
  local profile="$1" file pkgs=()

  file="$PKG/$profile.pacman"
  if [[ -f "$file" ]]; then
    mapfile -t pkgs < <(read_list "$file")
    if ((${#pkgs[@]})); then
      log "[$profile] pacman packages"
      sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    fi
  fi

  file="$PKG/$profile.aur"
  if [[ -f "$file" ]]; then
    mapfile -t pkgs < <(read_list "$file")
    if ((${#pkgs[@]})); then
      ensure_yay
      log "[$profile] AUR packages"
      yay -S --needed --noconfirm "${pkgs[@]}"
    fi
  fi
}

enable_services() {
  local profile="$1" file="$PKG/$1.services" unit
  [[ -f "$file" ]] || return 0
  log "[$profile] enabling services"
  while read -r unit; do
    sudo systemctl enable "$unit"
  done < <(read_list "$file")
}

link_dotfiles() {
  log "Stowing home"
  stow -d "$DOTS" -t "$HOME" --no-folding -R home

  if [[ -d "$DOTS/system" ]]; then
    log "Copying system config into /"
    sudo cp -rv "$DOTS/system/." /
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  fi
}

apply_gsettings() {
  log "Applying gsettings"
  dbus-run-session -- bash -c "
        gsettings set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
        gsettings set org.gnome.desktop.interface icon-theme 'breeze-dark'
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    " || warn "gsettings failed; rerun from inside Hyprland"
}

main() {
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm stow

  local profile
  for profile in "${PROFILES[@]}"; do
    install_profile "$profile"
  done

  link_dotfiles

  for profile in "${PROFILES[@]}"; do
    enable_services "$profile"
  done

  apply_gsettings

  log "Done. Bootloader and nvidia_drm.modeset=1 (if applicable) are still yours to handle."
}

main
