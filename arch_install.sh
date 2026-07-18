#!/bin/bash
# Arch Linux Auto-Setup for ASUS ROG Flow Z13
# Run from Arch live environment (via Ventoy hook or manually)

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

# ============================================================
# CONFIGURATION - EDIT THESE
# ============================================================
DISK="/dev/nvme0n1"
HOSTNAME="flowz13-arch"
USERNAME="yourusername"      # CHANGE THIS
TIMEZONE="America/New_York"   # CHANGE THIS
LOCALE="en_US.UTF-8"

# WiFi credentials (optional - leave empty to configure manually)
WIFI_SSID=""
WIFI_PASS=""

# ============================================================
# STEP 1: FIX WIFI (ASPM DISABLE)
# ============================================================
fix_wifi() {
    log "Fixing Mediatek WiFi (disabling ASPM)..."
    
    # Check if MT7925 exists
    if lspci | grep -q "MT7925"; then
        echo "options mt7925e aspm=0" > /etc/modprobe.d/mt7925e.conf
        modprobe -r mt7925e 2>/dev/null || true
        modprobe mt7925e
        
        # Verify
        if lspci -vv -s $(lspci | grep MT7925 | awk '{print $1}') 2>/dev/null | grep -q "ASPM.*Disabled"; then
            log "ASPM successfully disabled"
        else
            warn "ASPM may still be enabled - check manually"
        fi
    else
        warn "MT7925 not found - WiFi fix skipped"
    fi
}

# ============================================================
# STEP 2: CONNECT TO WIFI
# ============================================================
connect_wifi() {
    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASS" ]; then
        log "Connecting to WiFi: $WIFI_SSID"
        iwctl --passphrase "$WIFI_PASS" station wlan0 connect "$WIFI_SSID"
        sleep 3
    else
        warn "No WiFi credentials set. Connect manually with:"
        echo "  iwctl"
        echo "  station wlan0 connect YOUR_SSID"
        read -p "Press Enter when connected..."
    fi
    
    # Test connection
    if ping -c 1 archlinux.org >/dev/null 2>&1; then
        log "Internet connection verified"
    else
        err "No internet connection"
    fi
}

# ============================================================
# STEP 3: UPDATE MIRRORS
# ============================================================
update_mirrors() {
    log "Updating pacman mirrors..."
    reflector --country 'United States' --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Sy
    log "Mirrors updated"
}

# ============================================================
# STEP 4: WIPE DISK
# ============================================================
wipe_disk() {
    warn "This will DESTROY ALL DATA on $DISK"
    read -p "Are you sure? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        err "Aborted by user"
    fi
    
    log "Wiping $DISK..."
    sgdisk --zap-all "$DISK"
    wipefs -a "$DISK"
    log "Disk wiped"
}

# ============================================================
# STEP 5: CREATE PARTITIONS
# ============================================================
create_partitions() {
    log "Creating partitions..."
    
    # EFI: 512MB
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"
    
    # Root: rest minus 132GB (for 128GB swap + padding)
    sgdisk -n 2:0:-132G -t 2:8300 -c 2:"ROOT" "$DISK"
    
    # Swap: remaining space
    sgdisk -n 3:0:0 -t 3:8200 -c 3:"SWAP" "$DISK"
    
    # Verify
    sgdisk -p "$DISK"
    log "Partitions created"
}

# ============================================================
# STEP 6: FORMAT PARTITIONS
# ============================================================
format_partitions() {
    log "Formatting partitions..."
    
    mkfs.fat -F32 "${DISK}p1"
    mkfs.btrfs "${DISK}p2"
    mkswap "${DISK}p3"
    
    log "Partitions formatted"
}

# ============================================================
# STEP 7: CREATE BTRFS SUBVOLUMES
# ============================================================
create_subvolumes() {
    log "Creating BTRFS subvolumes..."
    
    mount "${DISK}p2" /mnt
    
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@pkg
    
    umount /mnt
    log "Subvolumes created"
}

# ============================================================
# STEP 8: MOUNT EVERYTHING
# ============================================================
mount_all() {
    log "Mounting subvolumes..."
    
    mount -o compress=zstd,noatime,space_cache=v2,ssd,subvol=@ "${DISK}p2" /mnt
    
    mkdir -p /mnt/{boot,home,var/log,var/cache,var/lib/pacman/pkg}
    
    mount -o compress=zstd,noatime,space_cache=v2,ssd,subvol=@home "${DISK}p2" /mnt/home
    mount -o compress=zstd,noatime,space_cache=v2,ssd,subvol=@log "${DISK}p2" /mnt/var/log
    mount -o compress=zstd,noatime,space_cache=v2,ssd,subvol=@cache "${DISK}p2" /mnt/var/cache
    mount -o compress=zstd,noatime,space_cache=v2,ssd,subvol=@pkg "${DISK}p2" /mnt/var/lib/pacman/pkg
    
    mount "${DISK}p1" /mnt/boot
    
    swapon "${DISK}p3"
    
    log "Everything mounted"
    findmnt /mnt
}

# ============================================================
# STEP 9: PACSTRAP BASE SYSTEM
# ============================================================
install_base() {
    log "Installing base system (this will take a while)..."
    
    pacstrap -K /mnt base linux linux-firmware networkmanager vim snapper \
        grub efibootmgr \
        amd-ucode \
        pipewire wireplumber \
        mesa vulkan-radeon libva-mesa-driver mesa-vdpau
    
    log "Base system installed"
}

# ============================================================
# STEP 10: GENERATE FSTAB
# ============================================================
gen_fstab() {
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Add snapshots entry
    ROOT_UUID=$(blkid -s UUID -o value "${DISK}p2")
    echo "UUID=${ROOT_UUID}  /.snapshots  btrfs  subvol=@snapshots,compress=zstd,noatime,space_cache=v2,ssd  0 2" >> /mnt/etc/fstab
    
    log "fstab generated"
}

# ============================================================
# STEP 11: CHROOT CONFIGURATION
# ============================================================
configure_system() {
    log "Configuring system inside chroot..."
    
    arch-chroot /mnt /bin/bash <<CHROOT_EOF
    # Hostname
    echo "$HOSTNAME" > /etc/hostname
    
    # Timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    
    # Locale
    echo "$LOCALE UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" > /etc/locale.conf
    
    # Hosts
    cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
    
    # Enable services
    systemctl enable NetworkManager
    
    # Root password
    echo "root:changeme" | chpasswd
    
    # Create user
    useradd -mG wheel,audio,video,input,docker "$USERNAME"
    echo "$USERNAME:changeme" | chpasswd
    
    # Sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    
    # Snapper
    snapper -c root create-config /
    
    # GRUB install (no Secure Boot yet)
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # Add ASPM kernel parameter for Flow Z13
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off /' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
    
CHROOT_EOF

    log "System configured"
    warn "Default passwords set to 'changeme' - change them after first boot!"
}

# ============================================================
# STEP 12: FINALIZE
# ============================================================
finalize() {
    log "Finalizing..."
    
    umount -R /mnt
    
    log "========================================"
    log "INSTALLATION COMPLETE"
    log "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Reboot: reboot"
    echo "2. Remove Ventoy USB"
    echo "3. Login as $USERNAME (password: changeme)"
    echo "4. Change passwords: passwd"
    echo "5. Setup Secure Boot (see guide)"
    echo ""
    echo "WiFi should work with ASPM disabled."
}

# ============================================================
# MAIN MENU
# ============================================================
show_menu() {
    clear
    echo "========================================"
    echo "  Arch Linux Auto-Setup"
    echo "  ASUS ROG Flow Z13"
    echo "========================================"
    echo ""
    echo "1. Full Auto-Install (all steps)"
    echo "2. Fix WiFi only"
    echo "3. Wipe disk only"
    echo "4. Create partitions only"
    echo "5. Format & create subvolumes only"
    echo "6. Mount & install base only"
    echo "7. Configure system (chroot) only"
    echo "8. Exit"
    echo ""
    read -p "Select option [1-8]: " choice
    
    case $choice in
        1)
            fix_wifi
            connect_wifi
            update_mirrors
            wipe_disk
            create_partitions
            format_partitions
            create_subvolumes
            mount_all
            install_base
            gen_fstab
            configure_system
            finalize
            ;;
        2) fix_wifi ;;
        3) wipe_disk ;;
        4) create_partitions ;;
        5) format_partitions; create_subvolumes ;;
        6) mount_all; install_base; gen_fstab ;;
        7) configure_system ;;
        8) exit 0 ;;
        *) err "Invalid option" ;;
    esac
}

# Run menu if called directly, or auto-run if from ventoy_hook
if [ "$1" == "auto" ]; then
    fix_wifi
    connect_wifi
    update_mirrors
    # Don't auto-wipe disk - that's too dangerous
    log "Auto-setup prepared. Run manually for disk operations."
else
    show_menu
fi
