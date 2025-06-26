#!/bin/bash

# Exit on any error
set -e

echo "🚀 Complete MT3 Installation Script"
echo "=================================="

# Step 1: Fix apt_pkg module issue
echo ""
echo "🔧 Step 1: Fixing apt_pkg module issue..."
sudo rm -f /usr/lib/python3/dist-packages/apt_pkg.so
sudo apt install --reinstall python3-apt

# Find and create the correct symlink
APT_PKG_PATH=$(find /usr/lib/python3/dist-packages -name "apt_pkg.cpython-*.so" | head -1)
if [ -n "$APT_PKG_PATH" ]; then
    sudo ln -sf "$APT_PKG_PATH" /usr/lib/python3/dist-packages/apt_pkg.so
    echo "✅ Created symlink: $APT_PKG_PATH -> /usr/lib/python3/dist-packages/apt_pkg.so"
else
    echo "⚠️  Warning: Could not find apt_pkg.cpython-*.so file"
fi

# Step 2: Update package lists
echo ""
echo "📦 Step 2: Updating package lists..."
sudo apt update

# Step 3: Install system dependencies
echo ""
echo "📋 Step 3: Installing system dependencies..."
sudo apt install -y \
    software-properties-common \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    pkg-config

# Step 4: Add Python 3.10 repository
echo ""
echo "🐍 Step 4: Adding Python 3.10 repository..."
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update

# Step 5: Install Python 3.10 and dependencies
echo ""
echo "🐍 Step 5: Installing Python 3.10 and dependencies..."
sudo apt install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-apt \
    sox \
    ffmpeg \
    libsndfile1 \
    gcc \
    libffi-dev \
    libssl-dev \
    zip \
    g++

# Step 6: Create project directory and clone MT3
echo ""
echo "📁 Step 6: Setting up MT3 project..."
mkdir -p ~/mt3_setup && cd ~/mt3_setup
git clone https://github.com/magenta/mt3.git
cd mt3

# Step 7: Create virtual environment
echo ""
echo "🐍 Step 7: Creating virtual environment with Python 3.10..."
python3.10 -m venv mt3-3.10
source mt3-3.10/bin/activate

# Step 8: Install Python dependencies
echo ""
echo "📦 Step 8: Installing Python dependencies..."
pip install --upgrade pip
pip install --upgrade setuptools wheel
pip install -e .

# Install TensorFlow
echo ""
echo "🤖 Step 9: Installing TensorFlow..."
pip install tensorflow==2.11.0

# Install additional dependencies
echo ""
echo "📚 Step 10: Installing additional dependencies..."
pip install gin-config t5x note-seq

# Step 11: Install Google Cloud SDK
echo ""
echo "☁️ Step 11: Installing Google Cloud SDK..."
cd ~/mt3_setup
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-474.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-474.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

# Add to PATH for current shell
source ./google-cloud-sdk/path.bash.inc

# Step 12: Download MT3 checkpoints
echo ""
echo "📥 Step 12: Downloading MT3 checkpoints..."
mkdir -p checkpoints
cd checkpoints
gsutil -m cp -r gs://mt3/checkpoints/ismir2021 .
cd ..

echo ""
echo "🎉 Installation complete!"
echo "========================"
echo ""
echo "To activate your MT3 environment in the future, run:"
echo "  source ~/mt3_setup/mt3/mt3-3.10/bin/activate"
echo ""
echo "To test the installation, run:"
echo "  source ~/mt3_setup/mt3/mt3-3.10/bin/activate"
echo "  cd ~/mt3_setup/mt3"
echo "  python -c \"import mt3; print('MT3 imported successfully!')\""
