#!/bin/bash

WORKINGDIR=$HOME
CONFIGFILE=config.yaml

if [ ! -f $CONFIGFILE ]; then
	echo "File $CONFIGFILE not found"
  	exit 1
fi

# Loading Configs

# general
PROJECT=`cat $CONFIGFILE | yq .general.project`
DOMAIN=`cat $CONFIGFILE | yq .general.domain`

# vault
VAULT_IP=`cat $CONFIGFILE | yq .vault.ip -r`
VAULT_PORT=`cat $CONFIGFILE | yq .vault.port`

# ldap
LDAP_IP=`cat $CONFIGFILE | yq .openldap.ip -r`
LDAPADMIN_IP=`cat $CONFIGFILE | yq .ldapadmin.ip -r`
READONLY_USER=`cat $CONFIGFILE | yq .openldap.readonlyuser`
READONLY_PASSWORD=`openssl rand -base64 12`
ADMIN_PASSWORD=`openssl rand -base64 12`
CONFIG_PASSWORD=`openssl rand -base64 12`

# redis
REDIS_IP=`cat $CONFIGFILE | yq .redis.ip -r`
REDIS_PORT=`cat $CONFIGFILE | yq .redis.port`
REDIS_USERNAME=`cat $CONFIGFILE | yq .redis.username`
REDIS_PASSWORD=`openssl rand -base64 12`

# ldapsync
LDAPSYNC_IP=`cat $CONFIGFILE | yq .ldapsync.ip`


if [ "a$1" == "a--reinstall" ]; then
	cd $WORKINGDIR/uninuvola/vault
	docker compose down
	cd $WORKINGDIR/uninuvola/openLDAP
	docker compose down
	cd $WORKINGDIR/uninuvola/redis
	docker compose down
	cd $WORKINGDIR/uninuvola/ldapsyncservice/compose
	docker compose down
	cd $WORKINGDIR
	rm -rf uninuvola
fi

cd $WORKINGDIR

if [ -d uninuvola ]; then
	echo "Directory uninuvola already exists"
  	exit 1
fi

mkdir uninuvola
# cp $CONFIGFILE uninuvola
cd uninuvola

# Vault

git clone git@github.com:UniNuvola/vault
cd vault
echo "VAULT_IP=$VAULT_IP" > .env
echo "VAULT_PORT=$VAULT_PORT" >> .env
docker compose up -d

# OpenLDAP

cd $WORKINGDIR/uninuvola
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

cd $WORKINGDIR/uninuvola
git clone git@github.com:UniNuvola/redis
cd redis
echo "REDIS_IP=$REDIS_IP" > .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
docker compose up -d

# Ldapsync

cd $WORKINGDIR/uninuvola
git clone git@github.com:UniNuvola/ldapsyncservice
cd ldapsyncservice/compose
echo "LDAPSYNC_IP=$LDAPSYNC_IP" > .env
echo "REDIS_URI=$REDIS_IP:$REDIS_PORT" >> .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
echo "REDIS_USERNAME=$REDIS_USERNAME" >> .env
docker compose up -d
