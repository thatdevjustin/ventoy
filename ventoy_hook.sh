#!/bin/bash
# Runs automatically when Arch ISO boots from Ventoy

# Fix Mediatek WiFi ASPM
echo "options mt7925e aspm=0" > /etc/modprobe.d/mt7925e.conf
modprobe -r mt7925e 2>/dev/null || true
modprobe mt7925e

# Update mirrors
reflector --country 'United States' --latest 20 --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true

echo "=== Ventoy Hook: WiFi fixed, mirrors updated ==="
