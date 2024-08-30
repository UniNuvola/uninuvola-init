#!/bin/bash

if [ "a$1" == "a--reinstall" ]; then
	cd $HOME/uninuvola/vault
	docker compose down
	cd $HOME/uninuvola/openLDAP
	docker compose down
	cd $HOME/uninuvola/redis
	docker compose down
	cd $HOME/uninuvola/ldapsyncservice/compose
	docker compose down
	cd $HOME
	rm -rf uninuvola
fi

cd $HOME

if [ ! -f uninuvola.yaml ]; then
	echo "File uninuvola.yaml not found"
  	exit 1
fi

if [ -d uninuvola ]; then
	echo "Directory uninuvola already exists"
  	exit 1
fi

mkdir uninuvola
cp uninuvola.yaml uninuvola

cd uninuvola

PROJECT=`cat uninuvola.yaml | yq .general.project`
DOMAIN=`cat uninuvola.yaml | yq .general.domain`

# Vault

VAULT_IP=`cat uninuvola.yaml | yq .vault.ip -r`
VAULT_PORT=`cat uninuvola.yaml | yq .vault.port`

git clone git@github.com:UniNuvola/vault
cd vault
echo "VAULT_IP=$VAULT_IP" > .env
echo "VAULT_PORT=$VAULT_PORT" >> .env
docker compose up -d

# OpenLDAP

cd $HOME/uninuvola

LDAP_IP=`cat uninuvola.yaml | yq .openldap.ip -r`
LDAPADMIN_IP=`cat uninuvola.yaml | yq .ldapadmin.ip -r`
READONLY_USER=`cat uninuvola.yaml | yq .openldap.readonlyuser`
READONLY_PASSWORD=`openssl rand -base64 12`
ADMIN_PASSWORD=`openssl rand -base64 12`
CONFIG_PASSWORD=`openssl rand -base64 12`

git clone git@github.com:UniNuvola/openLDAP
cd openLDAP
echo "LDAP_IP=$LDAP_IP" > .env
echo "LDAPADMIN_IP=$LDAPADMIN_IP" >> .env
echo "PROJECT=$PROJECT" >> .env
echo "DOMAIN=$DOMAIN" >> .env
echo "READONLY_USER_USERNAME=$READONLY_USER" >> .env
echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> .env
echo "CONFIG_PASSWORD=$CONFIG_PASSWORD" >> .env
echo "READONLY_USER_PASSWORD=$READONLY_PASSWORD" >> .env
docker compose up -d

# Redis

cd $HOME/uninuvola

REDIS_IP=`cat uninuvola.yaml | yq .redis.ip -r`
REDIS_PORT=`cat uninuvola.yaml | yq .redis.port`
REDIS_USERNAME=`cat uninuvola.yaml | yq .redis.username`
REDIS_PASSWORD=`openssl rand -base64 12`

git clone git@github.com:UniNuvola/redis
cd redis
echo "REDIS_IP=$REDIS_IP" > .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
docker compose up -d

# Ldapsync

cd $HOME/uninuvola

LDAPSYNC_IP=`cat uninuvola.yaml | yq .ldapsync.ip`

git clone git@github.com:UniNuvola/ldapsyncservice
cd ldapsyncservice/compose
echo "REDIS_URI=$REDIS_IP:$REDIS_PORT" > .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
echo "REDIS_USERNAME=$REDIS_USERNAME" >> .env

docker compose up -d
