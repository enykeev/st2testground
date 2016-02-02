#!/bin/bash
set -eu

sudo su

yum install -y epel-release

# Install dependencies
cat >/etc/yum.repos.d/mongodb-org-3.2.repo <<EOL
[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/7/mongodb-org/3.2/x86_64/
gpgcheck=0
enabled=1
EOL
yum install -y mongodb-org rabbitmq-server nginx python-simplejson erlang postgresql-server

# Install st2
cat >/etc/yum.repos.d/bintray-stackstorm-el7_staging-unstable.repo <<EOL
[bintray-stackstorm-el7_staging-unstable]
name=bintray-stackstorm-el7_staging-unstable
baseurl=https://dl.bintray.com/stackstorm/el7_staging/unstable
gpgcheck=0
enabled=1
EOL
cat >/etc/yum.repos.d/bintray-stackstorm-el7_staging-stable.repo <<EOL
[bintray-stackstorm-el7_staging-stable]
name=bintray-stackstorm-el7_staging-stable
baseurl=https://dl.bintray.com/stackstorm/el7_staging/stable
gpgcheck=0
enabled=1
EOL
yum install -y st2bundle st2web mistral st2mistral

# Copy Nginx config
sed -i.bak '/ default_server/d' /etc/nginx/nginx.conf
mkdir -p /etc/nginx/conf.d/
cp /vagrant/conf/nginx/st2.conf /etc/nginx/conf.d/

# Set up SSL certs
mkdir -p /etc/ssl/st2
openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt -days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

# Setup auth user
yum install -y httpd-tools
htpasswd -bcs /etc/st2/htpasswd admin 123

# Open ports on firewall
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https
sudo firewall-cmd --reload

# Init postgres
postgresql-setup initdb

pg_hba_config=/var/lib/pgsql/data/pg_hba.conf
sed -i 's/^local\s\+all\s\+all\s\+peer/local all all trust/g' ${pg_hba_config}
sed -i 's/^local\s\+all\s\+all\s\+ident/local all all trust/g' ${pg_hba_config}
sed -i 's/^host\s\+all\s\+all\s\+127.0.0.1\/32\s\+ident/host all all 127.0.0.1\/32 md5/g' ${pg_hba_config}
sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+ident/host all all ::1\/128 md5/g' ${pg_hba_config}

# Start services
service mongod start
service rabbitmq-server start
service postgresql start
service nginx start

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

/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

# Start st2
st2ctl start

# Install examples
git clone https://github.com/stackstorm/st2 /tmp/st2
cp -R /tmp/st2/contrib/examples /opt/stackstorm/packs

# Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all

echo 'IPs:'
ifconfig -a | grep inet | grep -v inet6 | awk '{print $2}'
