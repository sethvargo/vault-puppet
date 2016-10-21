#!/usr/bin/env bash
set -e

# Update apt
echo "Updating apt cache..."
sudo apt-get -qq update

# Global Certificate
echo '${ssl_certificate}' | sudo tee /usr/local/share/ca-certificates/vault.crt > /dev/null
sudo update-ca-certificates

# Install vault
echo "Installing Vault..."
sudo apt-get -yqq install curl jq unzip vim
curl -s -L -o "vault.zip" "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip"
unzip "vault.zip"
sudo mv "vault" "/usr/local/bin/vault"
sudo chmod +x "/usr/local/bin/vault"
sudo rm -rf "vault.zip"

# Consul Template
echo "Installing Consul Template..."
curl -s -L -o "consul-template.zip" "https://releases.hashicorp.com/consul-template/0.16.0/consul-template_0.16.0_linux_amd64.zip"
unzip "consul-template.zip"
sudo mv "consul-template" "/usr/local/bin/consul-template"
sudo chmod +x "/usr/local/bin/consul-template"
sudo rm -rf "consul-template.zip"

# Puppet
echo "Installing puppet..."
cd /tmp
curl -sLo puppet.deb https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
sudo dpkg -i puppet.deb
rm -rf puppet.deb
sudo apt-get -yqq update
sudo apt-get -yqq install puppet-agent

# Puppet typos
echo "Installing puppet aliases..."
sudo tee /etc/profile.d/puppet-typos.sh > /dev/null <<"EOF"
alias puppey="puppet"
alias pupet="puppet"
alias pupett="puppet"
alias puppett="puppet"
EOF

# Install eyaml
pushd /home/ubuntu
sudo /opt/puppetlabs/puppet/bin/gem install hiera-eyaml --no-doc
/opt/puppetlabs/puppet/bin/eyaml createkeys
encrypted_password=$(/opt/puppetlabs/puppet/bin/eyaml encrypt \
  -l database_password \
  -s "3n(ryPted" \
  -o string)
popd
sudo chown -R ubuntu:ubuntu /home/ubuntu/keys

# Setup hiera
echo "Configuring hiera..."
sudo mkdir -p /home/ubuntu/.puppetlabs/etc/puppet/
sudo tee /home/ubuntu/.puppetlabs/etc/puppet/hiera.yaml > /dev/null <<"EOF"
---
:backends:
  - eyaml
  - yaml

:hierarchy:
  - data

:yaml:
  :datadir: /opt/hiera

:eyaml:
  :datadir: /opt/hiera
  :pkcs7_private_key: /home/ubuntu/keys/private_key.pkcs7.pem
  :pkcs7_public_key: /home/ubuntu/keys/public_key.pkcs7.pem
EOF
sudo chown -R ubuntu:ubuntu /home/ubuntu/.puppetlabs

# YAML
sudo mkdir -p /opt/hiera
sudo tee /opt/hiera/data.yaml > /dev/null <<"EOF"
---
secrets:
  plaintext:
    database_password: pL@inT3xt
EOF

# EYAML
sudo tee /opt/hiera/data.eyaml > /dev/null <<EOF
---
secrets:
  encrypted:
    $$encrypted_password
EOF

# Write manifests
sudo tee /home/ubuntu/direct.pp > /dev/null <<"EOF"
$$content = "---
production:
  adapter: postgresql
  database: myapp
  username: myapp_production
  password: \"suP3rSe(r3t!\"
"

file { "database.yml":
  path      => "/tmp/database.yml",
  ensure    => present,
  backup    => false,
  content   => $$content,
  mode      => "0600",
  show_diff => false,
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/direct.pp

sudo tee /home/ubuntu/hiera.pp > /dev/null <<"EOF"
$$password = hiera("secrets.plaintext.database_password")

$$content = "---
production:
  adapter: postgresql
  database: myapp
  username: myapp_production
  password: \"$$password\"
"

file { "database.yml":
  path      => "/tmp/database.yml",
  ensure    => present,
  backup    => false,
  content   => $$content,
  mode      => "0600",
  show_diff => false,
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/hiera.pp

sudo tee /home/ubuntu/hiera-encrypted.pp > /dev/null <<"EOF"
$$password = hiera("secrets.encrypted.database_password")

$$content = "---
production:
  adapter: postgresql
  database: myapp
  username: myapp_production
  password: \"$$password\"
"

file { "database.yml":
  path      => "/tmp/database.yml",
  ensure    => present,
  backup    => false,
  content   => $$content,
  mode      => "0600",
  show_diff => false,
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/hiera-encrypted.pp

sudo tee /home/ubuntu/summon-conjur.pp > /dev/null <<"EOF"
$$content = "---
production:
  adapter: postgresql
  database: myapp
  username: myapp_production
  password: |-
    I read 3 blog posts, spent 4 hours, and drank 7 diet cokes and still had
    no idea how to make this thing work so I reverted to plaintext because it
    was easier.
"

file { "database.yml":
  path      => "/tmp/database.yml",
  ensure    => present,
  backup    => false,
  content   => $$content,
  mode      => "0600",
  show_diff => false,
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/summon-conjur.pp

sudo tee /home/ubuntu/vault-direct.pp > /dev/null <<"EOF"
exec { "get-credentials":
  command => "/usr/local/bin/vault read -format=json postgresql/creds/readonly | jq -r .data > /tmp/database.json",
  creates => "/tmp/database.json",
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/vault-direct.pp

sudo mkdir -p /etc/consul-template.d/
sudo mkdir -p /opt/consul-template/
sudo tee /home/ubuntu/vault-ct.pp > /dev/null <<"EOF"
$$upstart = "
description \"Consul Template\"

start on runlevel [2345]
stop on runlevel [06]

respawn

exec /usr/local/bin/consul-template \\
  -config=/etc/consul-template.d/
"

file { "consul-template-upstart":
  path      => "/etc/init/consul-template.conf",
  ensure    => present,
  content   => $$upstart,
}

service { "consul-template":
  name       => "consul-template",
  provider   => "upstart",
  ensure     => "running",
  enable     => true,
  hasrestart => true,
  require    => File["consul-template-upstart"],
}

$$template = "
{{- with secret \"postgresql/creds/readonly\" -}}
---
production:
  adapter: postgresql
  database: myapp
  username: {{ .Data.username }}
  password: {{ .Data.password }}
{{ end }}
"

file { "consul-template-template":
  path    => "/opt/consul-template/database.yml.tpl",
  ensure  => present,
  content => $$template,
}

$$config = "
vault {
  address = \"https://${vault_address}\"

  token       = \"root\"
  renew_token = false
}

template {
  source      = \"/opt/consul-template/database.yml.tpl\"
  destination = \"/tmp/database.yml\"
  command     = \"echo Config changed!\"
}
"

file { "consul-template-config":
  path    => "/etc/consul-template.d/config.hcl",
  ensure  => present,
  content => $$config,
  require => File["consul-template-template"],
  notify  => Service["consul-template"],
}
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/vault-ct.pp

# Set Vault helpers
sudo tee /home/ubuntu/connection_url.txt > /dev/null <<"EOF"
postgresql://${postgres_username}:${postgres_password}@${postgres_ip}/myapp
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/connection_url.txt

sudo tee /home/ubuntu/readonly.sql > /dev/null <<"EOF"
CREATE ROLE "{{name}}"
WITH LOGIN PASSWORD '{{password}}'
VALID UNTIL '{{expiration}}';

GRANT SELECT ON ALL TABLES IN SCHEMA public
TO "{{name}}";
EOF
sudo chown ubuntu:ubuntu /home/ubuntu/readonly.sql

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

# Set hostname for sudo
echo "${hostname}" | sudo tee /etc/hostname
sudo hostname -F /etc/hostname
sudo sed -i'' '1i 127.0.0.1 ${hostname}' /etc/hosts
echo "${vault_ip} ${vault_address}" | sudo tee -a /etc/hosts > /dev/null
