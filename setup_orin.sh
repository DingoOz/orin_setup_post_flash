#!/bin/bash

# Jetson Orin Setup Script
# Copyright (C) 2024 DingoOz
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Description: Script to set up development environment on Ubuntu 22.04 / Jetson Orin Nano
# Author: DingoOz
# Date: December 2024
# Version: 1.0

# Script to set up basic development environment on Ubuntu 22.04 / Jetson Orin Nano
# Create a log file to track installation progress
exec 1> >(tee "install_log.txt") 2>&1
echo "Starting installation script at $(date)"

# Run unminimize to restore standard Ubuntu server packages
echo "Running unminimize to restore standard Ubuntu server packages..."
echo "y" | sudo unminimize

# Update package lists and upgrade existing packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Configure time synchronization
echo "Configuring system time synchronization..."
sudo apt install -y systemd-timesyncd
sudo timedatectl set-ntp true
# Set timezone to UTC (change this to your timezone if needed)
sudo timedatectl set-timezone UTC
# Verify time sync status
timedatectl status

# Install basic utilities
echo "Installing basic utilities..."
BASIC_UTILS=(
    chromium-browser    # Web browser
    btop               # Resource monitor with advanced features
    geany              # Lightweight IDE
    htop               # Interactive process viewer
    tmux               # Terminal multiplexer
    python3-pip        # Python package manager
    git                # Version control
    curl               # Command line tool for transfers
    wget               # File downloader
    neofetch          # System information tool
    net-tools         # Network utilities
    nmon              # Performance monitoring
    tree              # Directory structure viewer
    vim               # Text editor
    vlc               # Media player
    unzip             # Archive extraction
    openssh-server    # SSH server
    terminator        # Advanced terminal emulator
    iotop             # I/O monitoring tool
    nethogs           # Network traffic monitor
    speedtest-cli     # Internet speed test
    arp-scan          # Network scanning tool
    cowsay            # ASCII art cow
    figlet            # ASCII art text
    lolcat            # Rainbow text coloring
)

# Install basic utilities
for util in "${BASIC_UTILS[@]}"; do
    echo "Installing $util..."
    sudo apt install -y $util
done

# Install jtop for Jetson monitoring
echo "Installing jtop..."
sudo -H pip3 install -U jetson-stats

# Install Visual Studio Code (if desired)
echo "Installing Visual Studio Code..."
wget -O vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
sudo apt install -y ./vscode.deb
rm vscode.deb

# Install Docker (optional but useful for development)
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Add current user to dialout group for serial port access
echo "Adding user to dialout group..."
sudo usermod -aG dialout $USER
echo "Note: Group changes will take effect after logout/login or reboot"

# Give permissions for arp-scan to non-root users
echo "Configuring arp-scan permissions..."
sudo setcap cap_net_raw+ep /usr/bin/arp-scan

# Create custom MOTD script
echo "Setting up custom MOTD..."
sudo tee /etc/update-motd.d/01-custom << 'EOF'
#!/bin/bash

# Function for rainbow text without lolcat
rainbow_text() {
    local text="$1"
    local colors=("\e[38;5;196m" "\e[38;5;214m" "\e[38;5;226m" "\e[38;5;118m" "\e[38;5;45m" "\e[38;5;171m")
    for i in $(seq 0 $((${#text} - 1))); do
        echo -en "${colors[$(($i % 6))]}${text:$i:1}"
    done
    echo -e "\e[0m"
}

# Print Orin Nano Super ASCII art with rainbow effect
figlet -f standard "Orin Nano Super" | lolcat -a -d 1 -s 50

# Print a fancy separator
echo -e "\e[38;5;51m╔════════════════════════════════════════════════════════════╗\e[0m" | lolcat

# System Information
rainbow_text "🖥️  System Information"
echo -e "\e[38;5;213m├─ Distribution: \e[38;5;219m$(lsb_release -ds)"
echo -e "\e[38;5;213m├─ Kernel: \e[38;5;219m$(uname -r)"
echo -e "\e[38;5;213m├─ CPU: \e[38;5;219m$(cat /proc/device-tree/model 2>/dev/null || echo "NVIDIA Jetson")"
echo -e "\e[38;5;213m├─ Memory: \e[38;5;219m$(free -h | awk '/^Mem:/ {printf "%s/%s", $3, $2}')"
echo -e "\e[38;5;213m└─ Temperature: \e[38;5;219m$(sensors 2>/dev/null | grep -i "CPU" || echo "$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{ printf "%.1f°C", $1/1000 }' | head -n1)")"

# Fancy separator
echo -e "\e[38;5;51m╠════════════════════════════════════════════════════════════╣\e[0m" | lolcat

# Network Information
rainbow_text "🌐 Network Information"
echo -e "\e[38;5;119m├─ Ethernet Connection:"
ip -br addr show | grep -w UP | grep -v "lo" | grep eth | awk '{printf "\e[38;5;156m│  ├─ Interface: %s\n│  └─ IP: %s\n", $1, $3}' || echo -e "\e[38;5;156m│  └─ No ethernet connection"
echo -e "\e[38;5;119m└─ WiFi Connection:"
iwconfig 2>/dev/null | grep -A 1 wlan | grep -v "no wireless" | sed 's/^/│  /' | \
    awk '{printf "\e[38;5;156m│  ├─ %s\n", $0}' || echo -e "\e[38;5;156m   └─ No WiFi connection"
ip -br addr show | grep wlan | awk '{printf "\e[38;5;156m│  └─ IP: %s\n", $3}' || echo -e "\e[38;5;156m   └─ No WiFi IP"

# Fancy separator
echo -e "\e[38;5;51m╠════════════════════════════════════════════════════════════╣\e[0m" | lolcat

# Package Updates Information
rainbow_text "📦 Package Status"
updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | grep -c "upgradable")

if [ $updates -gt 0 ]; then
    echo -e "\e[38;5;203m├─ Total updates available: $updates"
    echo -e "\e[38;5;203m└─ Security updates available: $security_updates"
else
    echo -e "\e[38;5;82m└─ System is up to date! 🎉"
fi

# Fancy separator
echo -e "\e[38;5;51m╠════════════════════════════════════════════════════════════╣\e[0m" | lolcat

# Disk Usage
rainbow_text "💾 Disk Usage"
df -h / | awk 'NR==2 {printf "\e[38;5;227m└─ Root filesystem: %s used of %s (%s)\n", $3, $2, $5}'

# Fancy separator
echo -e "\e[38;5;51m╠════════════════════════════════════════════════════════════╣\e[0m" | lolcat

# Quote of the day
rainbow_text "💭 Quote of the Day"
quote=$(curl -s "https://api.quotable.io/random" | python3 -c "import sys, json; print(json.load(sys.stdin)['content'])" 2>/dev/null)
if [ -n "$quote" ]; then
    echo "$quote" | cowsay | lolcat -a -d 1
else
    echo "Unable to fetch quote" | cowsay | lolcat -a -d 1
fi

# Fancy separator
echo -e "\e[38;5;51m╚════════════════════════════════════════════════════════════╝\e[0m" | lolcat

echo ""
EOF

# Make the MOTD script executable
sudo chmod +x /etc/update-motd.d/01-custom

# Disable default MOTD messages
sudo sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news
sudo rm -f /etc/update-motd.d/10-help-text
sudo rm -f /etc/update-motd.d/50-motd-news
sudo rm -f /etc/update-motd.d/80-livepatch
sudo rm -f /etc/update-motd.d/91-release-upgrade

# Clean up
echo "Cleaning up..."
sudo apt autoremove -y
sudo apt clean

# Final system update
echo "Running final system update..."
sudo apt update && sudo apt upgrade -y

# Print time synchronization status
echo "Time Synchronization Status:"
timedatectl status

echo "Installation completed at $(date)"
echo "System Information:"
neofetch

echo "Please reboot your system to ensure all changes take effect."
echo "Note: Serial port access (dialout group) and Docker group changes will take effect after reboot."
