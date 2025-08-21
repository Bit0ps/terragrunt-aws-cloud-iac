#!/bin/bash
set -e 

yum update -y
yum install -y ec2-instance-connect

# Install OpenVPN
ENDPOINT="$(dig +short myip.opendns.com @resolver1.opendns.com)"
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
sleep 90
AUTO_INSTALL=y ./openvpn-install.sh

# Remove existing push directives from the OpenVPN server configuration
sed -i '/^push/d' /etc/openvpn/server.conf

# Append new push directives
{
  echo 'push "dhcp-option DNS ${GATEWAY_IP}"'
  echo 'push "route ${ROUTE_IP} ${ROUTE_NETMASK}"'
} >> /etc/openvpn/server.conf

# Update client-template.txt
#echo "pull" >> /etc/openvpn/client-template.txt

# Restart OpenVPN server
service openvpn@server restart