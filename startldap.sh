#!/bin/sh

LDAP_LOCAL_PORT=636

LDAP_DOMAIN=ldap.local
LDAP_ORGANISATION=Nextcloud
LDAP_ROOTPASS=admin

LDAP_BASE_DN=dc=ldap,dc=local
LDAP_LOGIN_DN=cn=admin,dc=ldap,dc=local

# start containers
docker run -p 127.0.0.1:$LDAP_LOCAL_PORT:636 \
	-e LDAP_DOMAIN=$LDAP_DOMAIN \
	-e LDAP_ORGANISATION="$LDAP_ORGANISATION" \
	-e LDAP_ROOTPASS=$LDAP_ROOTPASS \
	--name openldap \
	-d blizzz-slapd || exit 1
	
# for  debugging purposes insert
#    -ti --entrypoint=/bin/bash \
# and remove the -d flag

