#!/usr/bin/env bash
set -e

# Global Certificate
echo '${ssl_certificate}' | sudo tee /usr/local/share/ca-certificates/vault.crt > /dev/null
sudo update-ca-certificates

# Update apt
echo "Updating apt cache..."
sudo apt-get -qq update

# Install vault
echo "Installing Vault..."
sudo apt-get -yqq install curl unzip
curl -s -L -o "vault.zip" "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip"
unzip "vault.zip"
sudo mv "vault" "/usr/local/bin/vault"
sudo chmod +x "/usr/local/bin/vault"
sudo rm -rf "vault.zip"

# Set PS1
sudo tee /etc/profile.d/ps1.sh > /dev/null <<"EOF"
export PS1="\u@hashicorp > "
EOF
for d in /home/*; do
  if [ -d "$d" ]; then
    sudo tee -a $d/.bashrc > /dev/null <<"EOF"
export PS1="\u@hashicorp > "
EOF
  fi
done

# Get the current IP
PRIVATE_IP=$(ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }')

# Set hostname for sudo
echo "${hostname}" | sudo tee /etc/hostname
sudo hostname -F /etc/hostname
sudo sed -i'' '1i 127.0.0.1 ${hostname}' /etc/hosts

# Vault Certificate
echo '${ssl_certificate}' | sudo tee /usr/local/etc/vault-cert.crt > /dev/null
echo '${ssl_private_key}' | sudo tee /usr/local/etc/vault-cert.key > /dev/null

# Setup Vault
sudo mkdir -p /opt/vault/data
sudo tee /opt/vault/config.hcl > /dev/null <<EOF
backend "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "$$PRIVATE_IP:443"
  tls_cert_file = "/usr/local/etc/vault-cert.crt"
  tls_key_file  = "/usr/local/etc/vault-cert.key"
}
EOF

# Start Vault on boot
echo "Writing Vault upstart config..."
BIND=$(ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }')
sudo tee /etc/init/vault.conf > /dev/null <<EOF
description "Vault"

start on runlevel [2345]
stop on runlevel [06]

respawn

kill signal INT

env VAULT_DEV_ROOT_TOKEN_ID=root
env VAULT_DEV_LISTEN_ADDRESS=$$PRIVATE_IP:80

exec /usr/local/bin/vault server \
  -dev \
  -config="/opt/vault/config.hcl"
EOF

sleep 5
sudo service vault start
