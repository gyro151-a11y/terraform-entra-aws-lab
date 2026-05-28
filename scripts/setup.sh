#!/bin/bash
set -e

# Wait for apt-get locks to clear (standard for cloud-init on fresh VMs)
echo "Waiting for apt system to settle..."
sleep 15

# Update system packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install baseline utilities needed for administration and monitoring
sudo apt-get install -y curl wget git unzip htop software-properties-common

echo "System baseline packages installed successfully!"