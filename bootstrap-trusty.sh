#!/bin/bash
set -eu

sudo su

apt-get update
apt-get install -y software-properties-common

# Install dependencies
apt-get install -y mongodb-server rabbitmq-server nginx postgresql

# Install st2
wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -
add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging unstable main'
add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging stable main'
apt-get update
apt-get install -y st2bundle st2web mistral st2mistral

# Copy Nginx config
cp /vagrant/conf/nginx/st2.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/st2.conf /etc/nginx/sites-enabled/st2.conf

# Set up SSL certs
mkdir -p /etc/ssl/st2
openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt -days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

# Copy st2web config
cp /vagrant/conf/st2web/config.js /opt/stackstorm/static/webui/

# Setup auth user
apt-get install -y apache2-utils
htpasswd -bcs /etc/st2/htpasswd admin 123

# Start services
service nginx reload

# Config Mistral
cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD

cat >/etc/mistral/mistral.conf <<EOF
[DEFAULT]
transport_url = rabbit://guest:guest@localhost:5672
[database]
connection = postgresql://mistral:StackStorm@localhost/mistral
max_pool_size = 50
[pecan]
auth_enable = false
EOF

# Start st2
st2ctl start

# Install examples
git clone https://github.com/stackstorm/st2 /tmp/st2
cp -R /tmp/st2/contrib/examples /opt/stackstorm/packs

# Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all
/usr/share/python/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
/usr/share/python/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

echo 'IPs:'
ifconfig -a | grep inet | grep -v inet6 | awk '{print $2}'
