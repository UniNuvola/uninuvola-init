#!/bin/bash

ACTUALDIR=$(pwd)
WORKINGDIR=$HOME
CONFIGFILE=config.yaml

if [ ! -f $CONFIGFILE ]; then
	echo "File $CONFIGFILE not found"
	exit 1
fi


if [ "a$1" == "a--reinstall" ]; then
	cd $WORKINGDIR/uninuvola/vault
	docker compose down
	cd $WORKINGDIR/uninuvola/openLDAP
	docker compose down
	cd $WORKINGDIR/uninuvola/redis
	docker compose down
	cd $WORKINGDIR/uninuvola/ldapsyncservice/docker
	docker compose down
	cd $WORKINGDIR/uninuvola/web/docker
	docker compose down
	cd $WORKINGDIR
	rm -rf uninuvola
fi

if [ -d $WORKINGDIR/uninuvola ]; then
	echo "Directory uninuvola already exists"
  	exit 1
fi

mkdir $WORKINGDIR/uninuvola
cp $ACTUALDIR/$CONFIGFILE $WORKINGDIR/uninuvola
cd $WORKINGDIR/uninuvola


# Loading General Configs
PROJECT=`cat $CONFIGFILE | yq .general.project`
DOMAIN=`cat $CONFIGFILE | yq .general.domain`


# --- VAULT

VAULT_IP=`cat $CONFIGFILE | yq .vault.ip -r`
VAULT_PORT=`cat $CONFIGFILE | yq .vault.port`
VAULT_PUBLIC_URL=`cat $CONFIGFILE | yq .vault.public_url`

git clone git@github.com:UniNuvola/vault
cd vault

echo "VAULT_IP=$VAULT_IP" > .env
echo "VAULT_PORT=$VAULT_PORT" >> .env
echo "VAULT_PUBLIC_URL=$VAULT_PUBLIC_URL" >> .env

docker compose up -d


# --- LDAP

cd $WORKINGDIR/uninuvola

LDAP_IP=`cat $CONFIGFILE | yq .openldap.ip -r`
LDAPADMIN_IP=`cat $CONFIGFILE | yq .ldapadmin.ip -r`
READONLY_USER=`cat $CONFIGFILE | yq .openldap.readonlyuser`
READONLY_PASSWORD=`openssl rand -base64 12`
ADMIN_PASSWORD=`openssl rand -base64 12`
CONFIG_PASSWORD=`openssl rand -base64 12`

# add passwords to config file
sed  -i "/readonlyuser:/a$(printf '\%1s') readonlypassword: \"$READONLY_PASSWORD\"" $CONFIGFILE
sed  -i "/readonlyuser:/a$(printf '\%1s') password: \"$ADMIN_PASSWORD\"" $CONFIGFILE

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

# --- REDIS

cd $WORKINGDIR/uninuvola

REDIS_IP=`cat $CONFIGFILE | yq .redis.ip -r`
REDIS_PORT=`cat $CONFIGFILE | yq .redis.port`
REDIS_USERNAME=`cat $CONFIGFILE | yq .redis.username`
REDIS_PASSWORD=`openssl rand -base64 12`

# add passwords to config file
sed  -i "/redis:/a$(printf '\%1s') password: \"$REDIS_PASSWORD\"" $CONFIGFILE

git clone git@github.com:UniNuvola/redis
cd redis

echo "REDIS_IP=$REDIS_IP" > .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env

docker compose up -d

# --- LDAPSYNC

cd $WORKINGDIR/uninuvola

LDAPSYNC_IP=`cat $CONFIGFILE | yq .ldapsync.ip -r`

git clone git@github.com:UniNuvola/ldapsyncservice
cd ldapsyncservice

echo "LDAPSYNC_IP=$LDAPSYNC_IP" > .env
echo "REDIS_URI=$REDIS_IP:$REDIS_PORT" >> .env
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
echo "REDIS_USERNAME=$REDIS_USERNAME" >> .env

cp -a .env docker/.env

cd docker
docker compose up -d

# --- LDAPPROXY

cd $WORKINGDIR/uninuvola

LDAPPROXY_IP=`cat $CONFIGFILE | yq .ldapproxy.ip -r`

git clone git@github.com:UniNuvola/ldapproxy
cd ldapproxy

echo "LDAPPROXY_IP=$LDAPPROXY_IP" > .env

cp -a .env docker/.env

cd docker
docker compose up -d

# --- RUN PYTHON

cd $ACTUALDIR

cp -a README.md uninuvola_init pyproject.toml poetry.lock $WORKINGDIR/uninuvola 

cd $WORKINGDIR/uninuvola
docker run -it --network uninuvola --dns 8.8.8.8 -v .:/project harbor1.fisgeo.unipg.it/uninuvola/web:latest /bin/bash -c 'poetry install && uninuvola-init -v DEBUG config.yaml'

# --- WEB 

cd $WORKINGDIR/uninuvola
git clone git@github.com:UniNuvola/web

# copy generated envs
cp web.env $WORKINGDIR/uninuvola/web/.env

WEB_IP=`cat $CONFIGFILE | yq .web.ip -r`
DNS_IP=`cat $CONFIGFILE | yq .web.dns_ip -r`
WEB_PUBLIC_URL=`cat $CONFIGFILE | yq .web.public_url`
cd web

echo "WEB_IP=$WEB_IP" >> .env
echo "WEB_PUBLIC_URL=$WEB_PUBLIC_URL" >> .env
echo "DNS_IP=$DNS_IP" >> .env
echo "LDAPSYNC_IP=$LDAPSYNC_IP" >> .env

cp -a .env docker/.env

cd docker
docker compose up -d
