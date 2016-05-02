#!/usr/bin/env bash

## This script should be part of a master image:

set -e

source `pwd`/env-setup.sh

log "Updating system..."
sudo yum update -y

# We need pip and virtualenv:
log "Updating pip and virtualenv..."
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
sudo python get-pip.py
sudo rm -rf get-pip.py
sudo pip install virtualenv

# Add docker repo:
log "Adding docker repo..."
sudo tee /etc/yum.repos.d/docker.repo <<'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

# Install components:
log "Installing Docker with dependencies..."
sudo yum install -y docker-engine wget tar xz unzip curl tree ipset

# Configure docker:
log "Creating, enabling and starting Docker service..."
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf <<EOF 
[Service] 
ExecStart= 
ExecStart=/usr/bin/docker daemon --storage-driver=overlay -H fd:// 
EOF

# Enable docker:
sudo systemctl enable docker
sudo systemctl start docker

# Other required stuff:
log "Changing system configuration for DCOS..."
sudo sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
sudo groupadd nogroup
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

chmod +x consul*.py
chmod +x bootstrap-machine-init.sh
chmod +x bootstrap-machine-ready.sh
chmod +x setup-dcos-node.sh

log "Installing jq..."
sudo wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O /usr/bin/jq
sudo chmod 0775 /usr/bin/jq

log "Reboot required, rebooting..."
sudo reboot