#!/bin/bash

ACTUALDIR=$(pwd)
WORKINGDIR=$HOME
CONFIGFILE=config.yaml
SECRETFILE=secrets.yaml

# shared map, shared values are stored here
declare -A SHAREDINFOS


if [ ! -f $CONFIGFILE ]; then
	echo "File $CONFIGFILE not found"
	exit 1
fi


if [[ "a$1" == "a--reinstall" || "a$1" == "a--stop" ]]; then
	cd $WORKINGDIR/uninuvola/vault
	docker compose down
	cd $WORKINGDIR/uninuvola/openLDAP
	docker compose down
	cd $WORKINGDIR/uninuvola/redis
	docker compose down
	cd $WORKINGDIR/uninuvola/ldapsyncservice/docker
	docker compose down
	cd $WORKINGDIR/uninuvola/ldapproxy/docker
	docker compose down
	cd $WORKINGDIR/uninuvola/web/docker
	docker compose down
	cd $WORKINGDIR
	rm -rf uninuvola
fi

if [ "a$1" == "a--stop" ]; then
	exit 0
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


## --- FUNCTIONS
vault()
{
	VAULT_IP=`cat $CONFIGFILE | yq .vault.ip -r`
	VAULT_PORT=`cat $CONFIGFILE | yq .vault.port`
	VAULT_PUBLIC_URL=`cat $CONFIGFILE | yq .vault.public_url`

	git clone git@github.com:UniNuvola/vault
	cd vault

	echo "VAULT_IP=$VAULT_IP" > .env
	echo "VAULT_PORT=$VAULT_PORT" >> .env
	echo "VAULT_PUBLIC_URL=$VAULT_PUBLIC_URL" >> .env

	docker compose up -d
}

ldap()
{
	cd $WORKINGDIR/uninuvola

	LDAP_IP=`cat $CONFIGFILE | yq .openldap.ip -r`
	LDAPADMIN_IP=`cat $CONFIGFILE | yq .ldapadmin.ip -r`
	READONLY_USER=`cat $CONFIGFILE | yq .openldap.readonlyuser`
	READONLY_PASSWORD=`openssl rand -base64 12`
	ADMIN_PASSWORD=`openssl rand -base64 12`
	CONFIG_PASSWORD=`openssl rand -base64 12`
	LDAP_PROXY_PASSWORD=`openssl rand -base64 12`

	# share password with other functions
	SHAREDINFOS['ldap_admin_password']=$ADMIN_PASSWORD
	SHAREDINFOS['ldap_proxy_password']=$LDAP_PROXY_PASSWORD

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
}

# --- REDIS
redis()
{
	cd $WORKINGDIR/uninuvola

	REDIS_IP=`cat $CONFIGFILE | yq .redis.ip -r`
	REDIS_PORT=`cat $CONFIGFILE | yq .redis.port`
	REDIS_USERNAME=`cat $CONFIGFILE | yq .redis.username`
	REDIS_DATABASE=`cat $CONFIGFILE | yq .redis.database`
	REDIS_PASSWORD=`openssl rand -base64 12`

	SHAREDINFOS["redis_password"]=$REDIS_PASSWORD

	# add passwords to config file
	sed  -i "/redis:/a$(printf '\%1s') password: \"$REDIS_PASSWORD\"" $CONFIGFILE

	git clone git@github.com:UniNuvola/redis
	cd redis

	echo "REDIS_IP=$REDIS_IP" > .env
	echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env

	docker compose up -d
}

# --- LDAPPROXY
ldapproxy()
{
	cd $WORKINGDIR/uninuvola

	LDAPPROXY_IP=`cat $CONFIGFILE | yq .ldapproxy.ip -r`
	LDAPSYNC_IP=`cat $CONFIGFILE | yq .ldapsync.ip -r`
	LDAPSYNC_PORT=`cat $CONFIGFILE | yq .ldapsync.port`
	LDAP_SOURCE_URI=`cat $CONFIGFILE | yq .ldapsync.source_uri -r`
	LDAP_SOURCE_BASEDN=`cat $CONFIGFILE | yq .ldapsync.source_basedn -r`
	LDAP_SOURCE_BINDDN=`cat $ACTUALDIR/$SECRETFILE | yq .ldapsync.source_binddn -r`
	LDAP_SOURCE_PASSWORD=`cat $ACTUALDIR/$SECRETFILE | yq .ldapsync.source_password -r`

	# add passwords to config file
	sed  -i "/ldapsync:/a$(printf '\%1s') source_binddn: \"$LDAP_SOURCE_BINDDN\"" $CONFIGFILE
	sed  -i "/ldapsync:/a$(printf '\%1s') source_password: \"$LDAP_SOURCE_PASSWORD\"" $CONFIGFILE

	LDAP_IP=`cat $CONFIGFILE | yq .openldap.ip -r`
	LDAP_DESTINATION_URI="ldap://$LDAP_IP"
	LDAP_DESTINATION_USERS_BASEDN="ou=users,dc=uninuvola,dc=unipg,dc=it"
	LDAP_DESTINATION_GROUPS_BASEDN="ou=groups,dc=uninuvola,dc=unipg,dc=it"
	LDAP_DESTINATION_BINDDN="cn=admin,dc=uninuvola,dc=unipg,dc=it"
	LDAP_DESTINATION_PASSWORD=${SHAREDINFOS["ldap_admin_password"]}
	LDAP_PROXY_PASSWORD=${SHAREDINFOS["ldap_proxy_password"]}

	SHAREDINFOS["ldap_destination_uri"]=$LDAP_DESTINATION_URI
	SHAREDINFOS["ldap_destination_users_basedn"]=$LDAP_DESTINATION_USERS_BASEDN
	SHAREDINFOS["ldap_destination_groups_basedn"]=$LDAP_DESTINATION_GROUPS_BASEDN
	SHAREDINFOS["ldap_destination_binddn"]=$LDAP_DESTINATION_BINDDN
	SHAREDINFOS["ldap_destination_password"]=$LDAP_DESTINATION_PASSWORD

	sed  -i "/ldapproxy:/a$(printf '\%1s') password: \"$LDAP_PROXY_PASSWORD\"" $CONFIGFILE
	sed  -i "/ldapproxy:/a$(printf '\%1s') user: \"admin\"" $CONFIGFILE

	git clone git@github.com:UniNuvola/ldapproxy
	cd ldapproxy

	echo "LDAPPROXY_IP=$LDAPPROXY_IP" > .env

	echo "debug: true" > config.yaml
	echo "proxy:" >> config.yaml
	echo "  basedn: \"$LDAP_DESTINATION_USERS_BASEDN\"" >> config.yaml
	echo "  binddn: \"$LDAP_DESTINATION_BINDDN\"" >> config.yaml
	echo "  password: \"$LDAP_PROXY_PASSWORD\"" >> config.yaml
	echo "endpoints:" >> config.yaml
	echo "  - name: uninuvola" >> config.yaml
	echo "    uri: \"$LDAP_DESTINATION_URI\"" >> config.yaml
	echo "    basedn: \"$LDAP_DESTINATION_USERS_BASEDN\"" >> config.yaml
	echo "    binddn: \"$LDAP_DESTINATION_BINDDN\"" >> config.yaml
	echo "    password: \"$LDAP_DESTINATION_PASSWORD\"" >> config.yaml
	echo "    override: false" >> config.yaml
	echo "  - name: unipg" >> config.yaml
	echo "    uri: \"$LDAP_SOURCE_URI\"" >> config.yaml
	echo "    basedn: \"$LDAP_SOURCE_BASEDN\"" >> config.yaml
	echo "    binddn: \"$LDAP_SOURCE_BINDDN\"" >> config.yaml
	echo "    password: \"$LDAP_SOURCE_PASSWORD\"" >> config.yaml
	echo "    override: true" >> config.yaml

	cp -a .env docker/.env
	cp -a config.yaml docker/config.yaml

	cd docker
	docker compose up -d
}

influxdb()
{
	cd $WORKINGDIR/uninuvola

	INFLUXDB_IP=`cat $CONFIGFILE | yq .influxdb.ip -r`

	git clone git@github.com:UniNuvola/influx.git
	cd influx

	echo "INFLUX_IP=$INFLUXDB_IP" > .env

	docker compose up -d
	docker compose exec influxdb3-core  influxdb3 create token --admin > secret

	# extract token form unformatted influxdb output
	INFLUXDB_TOKEN=`cat secret | grep '^Token:' | awk '{print $2}'`
	SHAREDINFOS["influxdb_token"]=$INFLUXDB_TOKEN
}

promflux()
{
	cd $WORKINGDIR/uninuvola

	PROMFLUX_IP=`cat $CONFIGFILE | yq .promflux.ip -r`
	INFLUXDB_IP=`cat $CONFIGFILE | yq .influxdb.ip -r`
	INFLUXDB_TOKEN=${SHAREDINFOS["influxdb_token"]}

	git clone git@github.com:UniNuvola/promflux.git
	cd promflux

	# TODO: add prometheus_url !!
	echo "PROMETHEUS_URL=" > .env
	echo "INFLUX_URL=$INFLUXDB_IP:8181" >> .env
	echo "INFLUX_TOKEN=$INFLUXDB_TOKEN" >> .env
	echo "IGNORE_TLS=true" >> .env
	echo "FILE_PATH=rules.yaml" >> .env

	echo "PROMFLUX_IP=$PROMFLUX_IP" > docker/.env

	cd docker
	docker compose up -d
}

uninuvolainit()
{
	cd $ACTUALDIR

	cp -a README.md uninuvola_init pyproject.toml poetry.lock $WORKINGDIR/uninuvola 

	cd $WORKINGDIR/uninuvola
	docker run -it --network uninuvola --dns 8.8.8.8 -v .:/project harbor1.fisgeo.unipg.it/uninuvola/web:latest /bin/bash -c 'poetry install && uninuvola-init -v DEBUG config.yaml'
}

ldapsync()
{
	cd $WORKINGDIR/uninuvola

	LDAPSYNC_IP=`cat $CONFIGFILE | yq .ldapsync.ip -r`
	LDAPSYNC_PORT=`cat $CONFIGFILE | yq .ldapsync.port`
	LDAP_SOURCE_URI=`cat $CONFIGFILE | yq .ldapsync.source_uri -r`
	LDAP_SOURCE_BASEDN=`cat $CONFIGFILE | yq .ldapsync.source_basedn -r`
	LDAP_SOURCE_BINDDN=`cat $ACTUALDIR/$SECRETFILE | yq .ldapsync.source_binddn -r`
	LDAP_SOURCE_PASSWORD=`cat $ACTUALDIR/$SECRETFILE | yq .ldapsync.source_password -r`

	LDAP_DESTINATION_URI=${SHAREDINFOS["ldap_destination_uri"]}
	LDAP_DESTINATION_USERS_BASEDN=${SHAREDINFOS["ldap_destination_users_basedn"]}
	LDAP_DESTINATION_GROUPS_BASEDN=${SHAREDINFOS["ldap_destination_groups_basedn"]}
	LDAP_DESTINATION_BINDDN=${SHAREDINFOS["ldap_destination_binddn"]}
	LDAP_DESTINATION_PASSWORD=${SHAREDINFOS["ldap_destination_password"]}

	REDIS_IP=`cat $CONFIGFILE | yq .redis.ip -r`
	REDIS_PORT=`cat $CONFIGFILE | yq .redis.port`
	REDIS_USERNAME=`cat $CONFIGFILE | yq .redis.username`
	REDIS_DATABASE=`cat $CONFIGFILE | yq .redis.database`
	REDIS_PASSWORD=${SHAREDINFOS["redis_password"]}

	git clone git@github.com:UniNuvola/ldapsyncservice
	cd ldapsyncservice

	echo "LDAPSYNC_IP=$LDAPSYNC_IP" > .env
	echo "TRIGGER_PORT=$LDAPSYNC_PORT" >> .env
	echo "REDIS_URI=\"$REDIS_IP:$REDIS_PORT\"" >> .env
	echo "REDIS_DATABASE=$REDIS_DATABASE" >> .env
	echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
	echo "REDIS_USERNAME=$REDIS_USERNAME" >> .env
	echo "LDAP_SOURCE_URI=\"$LDAP_SOURCE_URI\"" >> .env
	echo "LDAP_SOURCE_BASEDN=\"$LDAP_SOURCE_BASEDN\"" >> .env
	echo "LDAP_SOURCE_BINDDN=\"$LDAP_SOURCE_BINDDN\"" >> .env
	echo "LDAP_SOURCE_PASSWORD=\"$LDAP_SOURCE_PASSWORD\"" >> .env
	echo "LDAP_DESTINATION_URI=\"$LDAP_DESTINATION_URI\"" >> .env
	echo "LDAP_DESTINATION_USERS_BASEDN=\"$LDAP_DESTINATION_USERS_BASEDN\"" >> .env
	echo "LDAP_DESTINATION_GROUPS_BASEDN=\"$LDAP_DESTINATION_GROUPS_BASEDN\"" >> .env
	echo "LDAP_DESTINATION_BINDDN=\"$LDAP_DESTINATION_BINDDN\"" >> .env
	echo "LDAP_DESTINATION_PASSWORD=\"$LDAP_DESTINATION_PASSWORD\"" >> .env

	cp -a .env docker/.env

	cd docker
	docker compose up -d
}

web(){
	cd $WORKINGDIR/uninuvola
	git clone git@github.com:UniNuvola/web

	# copy generated envs
	cp web.env $WORKINGDIR/uninuvola/web/.env

	WEB_IP=`cat $CONFIGFILE | yq .web.ip -r`
	DNS_IP=`cat $CONFIGFILE | yq .web.dns_ip -r`
	WEB_PUBLIC_URL=`cat $CONFIGFILE | yq .web.public_url`
	LDAPSYNC_IP=`cat $CONFIGFILE | yq .ldapsync.ip -r`
	LDAPSYNC_PORT=`cat $CONFIGFILE | yq .ldapsync.port`

	cd web

	echo "WEB_IP=$WEB_IP" >> .env
	echo "WEB_PUBLIC_URL=$WEB_PUBLIC_URL" >> .env
	echo "DNS_IP=$DNS_IP" >> .env
	echo "LDAPSYNC_IP=$LDAPSYNC_IP" >> .env
	echo "LDAPSYNC_PORT=$LDAPSYNC_PORT" >> .env

	cp -a .env docker/.env

	cd docker
	docker compose up -d
}

main()
{
	vault
	ldap
	redis
	ldapproxy
	influxdb
	promflux
	uninuvolainit
	ldapsync
	web
}


# run script execution
main
