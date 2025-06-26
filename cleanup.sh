#!/bin/bash

echo "🧹 Cleaning up MT3 installations..."

# Get the correct home directory
REAL_USER=${SUDO_USER:-$(logname)}
HOME_DIR=$(eval echo ~$REAL_USER)

echo "Removing installation from root directory..."
sudo rm -rf /root/mt3_setup

echo "Removing installation from user home directory ($HOME_DIR)..."
rm -rf "$HOME_DIR/mt3_setup"

echo "Cleaning up any downloaded files..."
rm -f ~/google-cloud-cli-*.tar.gz
rm -f /root/google-cloud-cli-*.tar.gz
rm -f "$HOME_DIR/google-cloud-cli-*.tar.gz"

echo "✅ Cleanup complete!"
echo "You can now run: sudo bash install_mt3.sh"
