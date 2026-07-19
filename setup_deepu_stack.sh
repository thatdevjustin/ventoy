#!/bin/bash
###############################################################################
# Arch Linux Post-Install Setup Script for ASUS ROG Flow Z13 GZ302EA
# Replicates Deepu K Sasidharan's fully offline AI-assisted dev machine
# Run this after completing the base Arch install and first boot
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# User running the script
USER_NAME=$(whoami)

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running on Arch
if ! grep -q "Arch Linux" /etc/os-release 2>/dev/null; then
    print_error "This script is designed for Arch Linux only!"
    exit 1
fi

# Check if running as regular user (not root)
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user with sudo privileges, not as root!"
    exit 1
fi

# Check sudo access
if ! sudo -n true 2>/dev/null; then
    print_warning "You may be prompted for your sudo password during setup."
fi

###############################################################################
# STEP 1: Update System & Install Core Packages
###############################################################################
print_header "STEP 1: Updating System & Installing Core Packages"

sudo pacman -Syu --noconfirm

CORE_PACKAGES=(
    # Base utilities
    base-devel git vim nano curl wget

    # System
    amd-ucode fstrim.timer

    # Audio
    pipewire pipewire-pulse pipewire-jack wireplumber

    # Network
    networkmanager network-manager-applet

    # Filesystem
    btrfs-progs timeshift

    # Display/Graphics
    mesa vulkan-radeon libva-mesa-driver mesa-vdpau

    # Fonts
    inter-font noto-fonts noto-fonts-emoji

    # Terminal
    kitty

    # Monitoring
    btop fastfetch htop

    # Update manager
    topgrade

    # Login manager
    sddm

    # Window manager
    niri niri-session

    # Container tools
    docker docker-compose

    # K8s
    kubectl helm

    # Languages
    rustup nodejs npm jdk-openjdk go python python-pip

    # ROCm for AMD GPU ML acceleration
    rocm-hip-sdk rocm-opencl-sdk

    # ASUS-specific
    asusctl supergfxctl

    # Tablet/sensor support
    iio-sensor-proxy

    # Screenshot tools
    grim slurp wl-clipboard

    # File manager
    dolphin

    # Browser
    firefox
)

sudo pacman -S --needed --noconfirm "${CORE_PACKAGES[@]}"
print_success "Core packages installed"

###############################################################################
# STEP 2: Enable Services
###############################################################################
print_header "STEP 2: Enabling System Services"

sudo systemctl enable sddm
sudo systemctl enable NetworkManager
sudo systemctl enable docker
sudo systemctl enable fstrim.timer
sudo systemctl enable asusctl
sudo systemctl enable iio-sensor-proxy

# Add user to docker group
sudo usermod -aG docker "$USER_NAME"

print_success "Services enabled"

###############################################################################
# STEP 3: Install paru (AUR Helper)
###############################################################################
print_header "STEP 3: Installing paru (AUR Helper)"

if ! command -v paru &> /dev/null; then
    cd /tmp
    rm -rf paru
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
    print_success "paru installed"
else
    print_success "paru already installed"
fi

###############################################################################
# STEP 4: Install AUR Packages
###############################################################################
print_header "STEP 4: Installing AUR Packages"

AUR_PACKAGES=(
    # Fonts
    ttf-jetbrains-mono-nerd

    # Theme
    catppuccin-gtk-theme-macchiato
    catppuccin-cursors-macchiato

    # DMS (DankMaterialShell)
    dms-shell

    # VS Code (open source build)
    vscodium-bin

    # Terraform
    terraform

    # LlamaStash
    llamastash
)

for pkg in "${AUR_PACKAGES[@]}"; do
    if ! paru -Q "$pkg" &>/dev/null; then
        print_warning "Installing $pkg..."
        paru -S --noconfirm "$pkg" || print_warning "Failed to install $pkg (may need manual intervention)"
    else
        print_success "$pkg already installed"
    fi
done

###############################################################################
# STEP 5: Configure Rust
###############################################################################
print_header "STEP 5: Configuring Rust"

rustup default stable
rustup component add rust-src
print_success "Rust configured"

###############################################################################
# STEP 6: Configure Kitty Terminal
###############################################################################
print_header "STEP 6: Configuring Kitty Terminal"

mkdir -p ~/.config/kitty

cat > ~/.config/kitty/kitty.conf << 'KITTYEOF'
font_family JetBrainsMono Nerd Font
font_size 11.0

# Catppuccin Macchiato colors
foreground #cad3f5
background #24273a
cursor #f4dbd6
cursor_text_color #24273a
selection_foreground #24273a
selection_background #f4dbd6

color0 #494d64
color1 #ed8796
color2 #a6da95
color3 #eed49f
color4 #8aadf4
color5 #f5bde6
color6 #8bd5ca
color7 #b8c0e0
color8 #5b6078
color9 #ed8796
color10 #a6da95
color11 #eed49f
color12 #8aadf4
color13 #f5bde6
color14 #8bd5ca
color15 #a5adcb

enable_audio_bell no
scrollback_lines 10000
window_padding_width 4
background_opacity 0.95

# Tab bar style
tab_bar_style powerline
active_tab_foreground   #24273a
active_tab_background   #8aadf4
inactive_tab_foreground #cad3f5
inactive_tab_background #363a4f
KITTYEOF

print_success "Kitty configured with Catppuccin Macchiato"

###############################################################################
# STEP 7: Configure niri
###############################################################################
print_header "STEP 7: Configuring niri"

mkdir -p ~/.config/niri

cat > ~/.config/niri/config.kdl << 'NIRIEOF'
// Niri config for ASUS ROG Flow Z13
// Scrolling tiling Wayland compositor

input {
    touchpad {
        tap
        natural-scroll
        accel-speed 0.2
    }

    keyboard {
        xkb {
            layout "us"
        }
    }

    mouse accel-speed 0.0
}

// Built-in display: 13" 2560x1600 @ 180Hz
output "eDP-1" {
    mode "2560x1600@180.000"
    scale 1.5
}

// Auto-configure external displays
// Niri handles hotplug automatically

// Environment variables for applications
environment {
    QT_QPA_PLATFORMTHEME "gtk2"
    SDL_VIDEODRIVER "wayland"
    _JAVA_AWT_WM_NONREPARENTING "1"
    MOZ_ENABLE_WAYLAND "1"
}

// Spawn DMS on login
spawn-at-startup "dms" "run"

// Spawn a terminal
spawn-at-startup "kitty"

// Window rules
window-rule {
    app-id "firefox"
    open-on-workspace 2
}

window-rule {
    app-id "codium"
    open-on-workspace 3
}

window-rule {
    app-id "vscodium"
    open-on-workspace 3
}

window-rule {
    app-id "kitty"
    open-on-workspace 1
}

// Keybindings
binds {
    // Apps
    Mod+Return { spawn "kitty"; }
    Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }

    // Window management
    Mod+Q { close-window; }
    Mod+M { maximize-column; }
    Mod+F { fullscreen-window; }

    // Lock screen
    Mod+L { spawn "dms" "ipc" "call" "lock" "lock"; }

    // Quit niri
    Mod+Shift+E { quit; }

    // Focus
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }

    // Move
    Mod+Shift+Left { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up { move-window-up; }
    Mod+Shift+Down { move-window-down; }

    // Workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }

    // Move to workspace
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }

    // Screenshot
    Mod+Shift+S { spawn "grim" "-g" "$(slurp)" "-$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; }
    Print { spawn "grim" "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; }

    // Volume (handled by DMS, but backup binds)
    XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+"; }
    XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"; }
    XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

    // Brightness
    XF86MonBrightnessUp { spawn "brightnessctl" "set" "+10%"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }
}

// Layout settings
layout {
    gaps 8
    center-focused-column "never"

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5; }

    focus-ring {
        width 2
        active-color "#8aadf4"
        inactive-color "#6e738d"
    }

    border {
        off
    }

    shadow {
        on
        softness 30
        spread 5
        offset x=0 y=5
        color "#00000070"
        draw-behind-window true
    }

    tab-indicator {
        hide-when-single-tab true
        place-within-column true
        gap 5
        width 2
        length total-proportion=0.3
        position "top"
        segments "all"
        active-color "#8aadf4"
        inactive-color "#6e738d"
    }
}

// Animations
animations {
    slowdown 1.0
    workspace-switch {
        spring damping-ratio=0.8 stiffness=800 epsilon=0.0001
    }
}
NIRIEOF

print_success "niri configured"

###############################################################################
# STEP 8: Configure DMS (DankMaterialShell)
###############################################################################
print_header "STEP 8: Configuring DMS"

mkdir -p ~/.config/dms

cat > ~/.config/dms/config.toml << 'DMSEOF'
[appearance]
theme = "catppuccin-macchiato"
accent_color = "#8aadf4"
font_family = "Inter"
monospace_font = "JetBrainsMono Nerd Font"

[bar]
position = "top"
height = 32
center_widgets = ["workspaces", "window_title"]
right_widgets = ["system_tray", "network", "bluetooth", "battery", "clock"]

[launcher]
show_icons = true
show_descriptions = true

[notifications]
enabled = true
max_visible = 5

[lock]
enabled = true
background_blur = true

[wallpaper]
mode = "fill"
DMSEOF

print_success "DMS configured"

###############################################################################
# STEP 9: Configure ZSH
###############################################################################
print_header "STEP 9: Configuring ZSH"

# Install zsh
sudo pacman -S --needed --noconfirm zsh zsh-completions

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true

# Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions 2>/dev/null || true

# Configure .zshrc
cat > ~/.zshrc << 'ZSHRC'
# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    sudo
    history
    colored-man-pages
    command-not-found
)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
export VISUAL='vim'

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias l='ls -l'
alias ..='cd ..'
alias ...='cd ../..'
alias update='topgrade'
alias ff='fastfetch'

# Local AI endpoint
export LOCAL_ENDPOINT="http://127.0.0.1:11435/v1"

# Rust
source $HOME/.cargo/env 2>/dev/null || true

# Go
export PATH=$PATH:$(go env GOPATH)/bin 2>/dev/null || true

# Java
export JAVA_HOME=/usr/lib/jvm/default

# Niri specific
export MOZ_ENABLE_WAYLAND=1
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC

# Set default shell to zsh
chsh -s /bin/zsh

print_success "ZSH configured"

###############################################################################
# STEP 10: Configure Git
###############################################################################
print_header "STEP 10: Configuring Git"

read -p "Enter your Git username: " GIT_USER
read -p "Enter your Git email: " GIT_EMAIL

git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global core.editor vim

print_success "Git configured"

###############################################################################
# STEP 11: Create Directories
###############################################################################
print_header "STEP 11: Creating Directory Structure"

mkdir -p ~/{Documents,Downloads,Pictures,Music,Videos,Projects,.local/bin}
mkdir -p ~/Pictures/{screenshots,wallpapers}

print_success "Directories created"

###############################################################################
# STEP 12: First Timeshift Snapshot
###############################################################################
print_header "STEP 12: Creating First Timeshift Snapshot"

sudo timeshift --create --comments "Fresh install after Deepu stack setup" || print_warning "Timeshift snapshot failed (may need GUI setup first)"

###############################################################################
# STEP 13: Install OpenCode
###############################################################################
print_header "STEP 13: Installing OpenCode"

# Try to install from latest GitHub release
cd /tmp
rm -rf opencode-install

# Download latest release
LATEST_URL=$(curl -s https://api.github.com/repos/opencode-ai/opencode/releases/latest | grep "browser_download_url.*linux_amd64" | cut -d '"' -f 4)

if [ -n "$LATEST_URL" ]; then
    curl -LO "$LATEST_URL"
    tar -xzf opencode_*_linux_amd64.tar.gz 2>/dev/null || true
    sudo mv opencode /usr/local/bin/ 2>/dev/null || print_warning "OpenCode binary move failed"
else
    print_warning "Could not auto-download OpenCode. Please install manually from https://github.com/opencode-ai/opencode"
fi

cd ~

###############################################################################
# STEP 14: Setup Complete
###############################################################################
print_header "SETUP COMPLETE!"

cat << 'FINAL'

╔══════════════════════════════════════════════════════════════════════════════╗
║                    ARCH LINUX + DEEPU STACK INSTALLED                          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  Next steps:                                                                 ║
║                                                                              ║
║  1. REBOOT to start niri + DMS:                                            ║
║       sudo reboot                                                            ║
║                                                                              ║
║  2. After login, initialize LlamaStash:                                      ║
║       llamastash init                                                        ║
║                                                                              ║
║  3. Start local AI coding:                                                   ║
║       llamastash                                                             ║
║       # In another terminal:                                                 ║
║       opencode                                                               ║
║                                                                              ║
║  4. Keybindings (niri):                                                      ║
║       Mod+Return  → Open Kitty                                             ║
║       Mod+D       → Open DMS Spotlight                                     ║
║       Mod+Q       → Close window                                           ║
║       Mod+L       → Lock screen                                            ║
║       Mod+Left/Right → Scroll columns                                      ║
║       Mod+1-5     → Switch workspace                                       ║
║                                                                              ║
║  5. DMS Controls:                                                            ║
║       Super       → Spotlight launcher                                     ║
║       Click bar   → Control center                                         ║
║                                                                              ║
║  6. Update everything:                                                     ║
║       topgrade                                                               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

FINAL

echo -e "${GREEN}Enjoy your fully offline AI-assisted Arch Linux dev machine!${NC}\n"
