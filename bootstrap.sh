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

## Install dependencies
apt-get install -y mongodb-server rabbitmq-server nginx libpython2.7

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

## Setup auth user
apt-get install -y apache2-utils
htpasswd -bcs /etc/st2/htpasswd admin 123

## Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all

## start services
service nginx reload
st2ctl start
wait
