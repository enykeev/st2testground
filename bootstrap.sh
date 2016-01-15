#!/bin/bash

COLOR_OFF="\033[0m"   # unsets color to term fg color
RED="\033[0;31m"      # red
GREEN="\033[0;32m"    # green
YELLOW="\033[0;33m"   # yellow
MAGENTA="\033[0;35m"  # magenta
CYAN="\033[0;36m"     # cyan

set -eu

sudo su
apt-get update
apt-get install -y software-properties-common

## Install virtualenv
apt-get install -y python-pip
pip install --upgrade pip
pip install virtualenv

## Install dependencies
apt-get install -y mongodb-server rabbitmq-server nginx
apt-get install -y python-dev # [inline]

## Install st2
wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -
add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging unstable main'
apt-get update
apt-get install -y st2bundle st2web

## Copy Nginx config
cp /vagrant/conf/nginx/st2.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/st2.conf /etc/nginx/sites-enabled/st2.conf

## Set up SSL certs
mkdir -p /etc/ssl/st2
openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt -days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

## Copy st2web config
cp /vagrant/conf/st2web/config.js /opt/stackstorm/static/webui/

## Install missing venv dependencies
/usr/share/python/st2/bin/pip install gunicorn uwsgi # [inline]
mkdir -p /etc/uwsgi.d # [inline]
cp /vagrant/conf/uwsgi/st2auth.ini /etc/uwsgi.d/st2auth.ini # [inline]

## Setup auth user
apt-get install -y apache2-utils
htpasswd -bcs /etc/st2/htpasswd admin 123

## Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all

## start services
service nginx reload
mkdir -p /var/sockets # [inline]
touch /var/log/st2/st2api.log # [inline]
chown st2:st2 /var/log/st2/st2api.log # [inline]
chmod 664 /var/log/st2/st2api.log # [inline]
touch /var/log/st2/st2api.audit.log # [inline]
chown st2:st2 /var/log/st2/st2api.audit.log # [inline]
chmod 664 /var/log/st2/st2api.audit.log # [inline]
/usr/share/python/st2/bin/python /usr/share/python/st2/bin/gunicorn_pecan /usr/share/python/st2/lib/python2.7/site-packages/st2api/gunicorn_config.py -k eventlet -b unix:/var/sockets/st2api.sock --threads 10 --workers 1 -u www-data -g st2 -D # [inline]
/usr/share/python/st2/bin/uwsgi --ini /etc/uwsgi.d/st2auth.ini -d /var/log/st2/st2auth.uwsgi.log # [inline]
st2ctl start
service st2api stop
chown -R st2:st2 /opt/stackstorm/packs # [inline]
chmod -R 775 /opt/stackstorm/packs # [inline]
wait
