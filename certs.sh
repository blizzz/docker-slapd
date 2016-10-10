#!/bin/bash

# creates a RootCA, a sub CA called DeptCA and a certificate for ldap.local

set -e

CA_PATH=/root
CAS=(RootCA DeptCA)
CA_DIRS=(certs crl newcerts private)
CA_FILES=(index.txt serial)
CERT_SECTIONS[RootCA]=ca_cert
CERT_SECTIONS[DeptCA]=dept_cert
CERT_SERIAL[RootCA]=00
CERT_SERIAL[DeptCA]=01

COUNTRY=DE
STATE=BERLIN
LOCALITY=BERLIN
ORG="Nextcloud Devel"
ORGUNIT=U23

for CA in ${CAS[@]}; do
    for NEWDIR in ${CA_DIRS[@]}; do
        mkdir -p "$CA_PATH/$CA/$NEWDIR"
    done
    touch "$CA_PATH/$CA/index.txt"
    echo "01" > "$CA_PATH/$CA/serial"
    openssl rand -out "$CA_PATH/$CA/private/.rand" 1024
    tee -a /etc/ssl/openssl.cnf > /dev/null <<EOF
[ $CA ]
dir              = $CA_PATH/$CA
certs            = \$dir/certs
crl_dir          = \$dir/crl
database         = \$dir/index.txt
new_certs_dir    = \$dir/newcerts
certificate      = \$dir/$CA.cacert.pem
serial           = \$dir/serial
crl              = \$dir/crl.pem
private_key      = \$dir/private/$CA.cakey.pem
RANDFILE         = \$dir/private/.rand
x509_extensions  = ${CERT_SECTIONS[$CA]}
name_opt         = ca_default
cert_opt         = ca_default
crl_extension    = crl_ext
default_days     = 365
default_crl_days = 60
default_md       = sha256
preserve         = no
policy           = policy_anything

EOF
done

tee -a /etc/ssl/openssl.cnf > /dev/null <<EOF
[ ca_cert ]
basicConstraints=CA:TRUE
nsComment              = "OpenSSL generated certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always

[ dept_cert ]
basicConstraints=CA:FALSE
nsComment              = "OpenSSL generated certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
keyUsage=digitalSignature, keyEncipherment
extendedKeyUsage=serverAuth

EOF

for CA in ${CAS[@]}; do
    #echo -e "genpkey $CA\n"
    openssl genpkey -aes256 -pass pass:zweiundvierzig -outform PEM -algorithm RSA -out "$CA_PATH/$CA/private/$CA.cakey.pem" 2048
    #echo -e "req $CA\n"
    if [ "$CA" == "RootCA" ]; then
        openssl req -batch -new -x509 -set_serial "${CERT_SERIAL[$CA]}" -key "$CA_PATH/$CA/private/$CA.cakey.pem" -out "$CA_PATH/$CA/$CA.cacert.pem" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORGUNIT/CN=$CA/emailAddress=$CA@example.org" -passin pass:zweiundvierzig
    else
        openssl req -batch -new -key "$CA_PATH/$CA/private/$CA.cakey.pem" -out "$CA_PATH/$CA/$CA.careq.pem" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORGUNIT/CN=$CA/emailAddress=$CA@example.org" -passin pass:zweiundvierzig
    fi
#echo -e "\n$CA preperations done\n"
done

#echo -e "cert DeptCA\n"
openssl ca -batch -name RootCA -in "$CA_PATH/DeptCA/DeptCA.careq.pem" -out "$CA_PATH/DeptCA/DeptCA.cacert.pem" -passin pass:zweiundvierzig

mv "$CA_PATH/RootCA/newcerts/${CERT_SERIAL[DeptCA]}.pem" "$CA_PATH/RootCA/certs/"
ln -s "$CA_PATH/RootCA/certs/${CERT_SERIAL[DeptCA]}.pem" "$CA_PATH/DeptCA/$(openssl x509 -hash -noout -in "$CA_PATH/RootCA/certs/${CERT_SERIAL[DeptCA]}.pem").0"

#echo -e "key LDAP\n"
openssl genpkey -aes256 -pass pass:zweiundvierzig -outform PEM -algorithm RSA -out "$CA_PATH/DeptCA/ldap.local.key.pem" 2048
openssl rsa -in "$CA_PATH/DeptCA/ldap.local.key.pem" -out "$CA_PATH/DeptCA/ldap.local.key.pem" -passin pass:zweiundvierzig
#echo -e "req LDAP\n"
openssl req -batch -new -key "$CA_PATH/DeptCA/ldap.local.key.pem" -out "$CA_PATH/DeptCA/ldap.local.req.pem" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORGUNIT/CN=ldap.local/emailAddress=ldap@example.org" -passin pass:zweiundvierzig
#echo -e "cert LDAP\n"
openssl ca -batch -name DeptCA -in "$CA_PATH/DeptCA/ldap.local.req.pem" -out "$CA_PATH/DeptCA/ldap.local.cert.pem" -passin pass:zweiundvierzig

mv "$CA_PATH/DeptCA/newcerts/01.pem" "$CA_PATH/DeptCA/certs/"
ln -s "$CA_PATH/DeptCA/certs/01.pem" "$CA_PATH/DeptCA/$(openssl x509 -hash -noout -in "$CA_PATH/DeptCA/certs/01.pem").0"

# copy files so that openldap can read them
mkdir -p /etc/ldap/ssl
cp "$CA_PATH/DeptCA/certs/01.pem" /etc/ldap/ssl/ldap.local.cert.pem
cp "$CA_PATH/DeptCA/ldap.local.key.pem" /etc/ldap/ssl/ldap.local.key.pem
cat "$CA_PATH/DeptCA/DeptCA.cacert.pem" > /etc/ldap/ssl/ca-certs.pem
cat "$CA_PATH/RootCA/RootCA.cacert.pem" >> /etc/ldap/ssl/ca-certs.pem
