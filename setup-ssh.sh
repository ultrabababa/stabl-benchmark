#!/bin/bash
set -e

# Setup sshd directory
mkdir -p /var/run/sshd

# Configure SSH daemon for passwordless login
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*UseDNS .*/UseDNS no/' /etc/ssh/sshd_config

# Create ubuntu user if it doesn't exist, otherwise ensure it is in sudo group
if ! id -u ubuntu >/dev/null 2>&1; then
    useradd -rm -d /home/ubuntu -s /bin/bash -G sudo -u 1000 ubuntu
else
    usermod -aG sudo ubuntu
    usermod -s /bin/bash ubuntu
fi

# Configure passwordless sudo
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu

# Setup SSH key for ubuntu user
mkdir -p /home/ubuntu/.ssh
if [ -f /tmp/stabl_key.pub ]; then
    cat /tmp/stabl_key.pub >> /home/ubuntu/.ssh/authorized_keys
fi
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
