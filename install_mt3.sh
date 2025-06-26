#!/bin/bash

# Exit on any error
set -e

echo "✅ Updating and installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-apt \
    build-essential \
    git \
    curl \
    unzip \
    sox \
    ffmpeg \
    libsndfile1 \
    wget \
    gcc \
    libffi-dev \
    libssl-dev \
    pkg-config \
    zip \
    g++

echo "✅ Creating project directory..."
mkdir -p ~/mt3_setup && cd ~/mt3_setup

echo "✅ Cloning MT3 repo..."
git clone https://github.com/magenta/mt3.git
cd mt3

echo "✅ Creating and activating virtual environment with Python 3.10..."
python3.10 -m venv mt3-3.10
source mt3-3.10/bin/activate

echo "✅ Upgrading pip..."
pip install --upgrade pip

echo "✅ Installing Python dependencies..."
pip install --upgrade setuptools wheel
pip install -e .

# TensorFlow can be very specific; use a known compatible version
pip install tensorflow==2.11.0

echo "✅ Installing additional dependencies for inference..."
pip install gin-config t5x note-seq

echo "✅ Installing Google Cloud SDK for gsutil..."
cd ~/mt3_setup
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-474.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-474.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

# Add to PATH for current shell
source ./google-cloud-sdk/path.bash.inc

echo "✅ Downloading MT3 checkpoints (ismir2021)..."
mkdir -p checkpoints
cd checkpoints
gsutil -m cp -r gs://mt3/checkpoints/ismir2021 .
cd ..

echo "✅ Setup complete!"
echo "To activate your environment in the future, run:"
echo "  source ~/mt3_setup/mt3/mt3-3.10/bin/activate"
