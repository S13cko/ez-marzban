#!/bin/bash

# Update and upgrade system packages
apt update && apt -y upgrade

# Install necessary packages
apt-get install -y fail2ban
apt install -y nodejs npm wget

# Run NetOptix script
bash <(curl -Ls https://raw.githubusercontent.com/MrAminiDev/NetOptix/main/NetOptix.sh) << EOF
1
3
4096
5
EOF

# Install AdGuardHome
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# Configure sysctl to disable IPv6
echo "
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
" >> /etc/sysctl.conf
sysctl -p

# Configure Fail2Ban for SSH
echo "
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 2
bantime = 17280000
findtime = 7200
ignoreip = 127.0.0.1/8 ::1
banaction = iptables-xt-wrapper banip %s
" >> /etc/fail2ban/jail.local
systemctl restart fail2ban

# Install Marzban
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
echo "Please press Ctrl+C after Marzban installation completes."
sleep 60

# Prompt user to determine if the domain is under CDN
read -p "Is your domain under CDN? (yes/no): " cdn

if [ "$cdn" = "no" ]; then
    # Issue certificate without CDN
    curl https://get.acme.sh | sh -s email=jgffhlef@gmail.com
    read -p "Enter your domain: " DOMAIN
    export DOMAIN=$DOMAIN

    mkdir -p /var/lib/marzban/certs

    ~/.acme.sh/acme.sh --issue --force --standalone -d "$DOMAIN" --fullchain-file "/var/lib/marzban/certs/$DOMAIN.cer" --key-file "/var/lib/marzban/certs/$DOMAIN.cer.key"
else
    # Issue certificate with CDN
    curl https://get.acme.sh | sh -s email=jgffhlef@gmail.com
    read -p "Enter your domain: " DOMAIN
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --dns --yes-I-know-dns-manual-mode-enough-go-ahead-please
    echo "Please create a TXT record for your domain."
    echo "Press Enter after creating the TXT record."
    read
    ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --yes-I-know-dns-manual-mode-enough-go-ahead-please
fi

# Update Marzban configuration
cd /opt/marzban
sed -i 's/UVICORN_PORT=8000/UVICORN_PORT=2096/' .env

# Update docker-compose configuration
sed -i '/volumes:/a \ \ \ \ - /opt/marzban/home/index.html:/code/app/templates/home/index.html\n\ \ \ \ - /opt/marzban/index.html:/code/app/templates/subscription/index.html' docker-compose.yml

# Download and set up Marzban templates
mkdir -p /opt/marzban/home
cd /opt/marzban/home
wget https://cdn.jsdelivr.net/gh/MuhammadAshouri/marzban-templates@master/mock-login/index.html

cd /opt/marzban
wget -O index.html https://raw.githubusercontent.com/MuhammadAshouri/marzban-templates/master/template-01/index.html

# Update and restart Marzban
marzban update
marzban restart
