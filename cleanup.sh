#!/bin/bash

echo "🧹 Cleaning up MT3 installations..."

echo "Removing installation from root directory..."
sudo rm -rf /root/mt3_setup

echo "Removing installation from home directory..."
rm -rf ~/mt3_setup

echo "Cleaning up any downloaded files..."
rm -f ~/google-cloud-cli-*.tar.gz
rm -f /root/google-cloud-cli-*.tar.gz

echo "✅ Cleanup complete!"
echo "You can now run: sudo bash install_mt3.sh"
