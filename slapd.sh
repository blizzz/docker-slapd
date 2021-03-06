#!/bin/sh

set -eu

status () {
  echo "---> ${@}" >&2
}

set -x
: LDAP_ROOTPASS=${LDAP_ROOTPASS}
: LDAP_DOMAIN=${LDAP_DOMAIN}
: LDAP_ORGANISATION=${LDAP_ORGANISATION}

if [ ! -e /var/lib/ldap/docker_bootstrapped ]; then
  status "configuring slapd for first run"

  cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ROOTPASS}
slapd slapd/internal/adminpw password ${LDAP_ROOTPASS}
slapd slapd/password2 password ${LDAP_ROOTPASS}
slapd slapd/password1 password ${LDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string HDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

  dpkg-reconfigure -f noninteractive slapd

  touch /var/lib/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

status "starting slapd"
set -x
/usr/sbin/slapd -h "ldapi:/// ldaps:///" -u openldap -g openldap -d 0 &
RESULT=$?

if [ ! -e /var/lib/ldap/tls_configured ]; then
    # we configure the certificate
    sleep 2 # ldap might not be ready, yet
    ldapmodify -Q -Y EXTERNAL -H ldapi:///<<EOF
dn: cn=config
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ssl/ldap.local.cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ssl/ldap.local.key.pem
-
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ssl/ca-certs.pem
EOF
    # now restart slapd
    killall slapd
    sleep 2 # ensure ldap is stopped before restarting
    touch /var/lib/ldap/tls_configured
    /etc/service/slapd/run
fi

exit $RESULT
