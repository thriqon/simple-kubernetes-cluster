#!/bin/bash

# https://coreos.com/kubernetes/docs/latest/openssl.html

set -e

# ROOT CA
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"

# APISERVER
cat > openssl.apiserver.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 11.1.2.1
IP.2 = 192.168.50.100
EOF

openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.apiserver.cnf
openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.apiserver.cnf

# WORKERS
cat > openssl.worker.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = \$ENV::WORKER_IP
EOF

for i in $(seq 1 5); do
	openssl genrsa -out worker-$i-key.pem 2048
	WORKER_IP=192.168.50.11$i openssl req -new -key worker-$i-key.pem -out worker-$i.csr -subj "/CN=192.168.50.11$i" -config openssl.worker.cnf
	WORKER_IP=192.168.50.11$i openssl x509 -req -in worker-$i.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out worker-$i.pem -days 365 -extensions v3_req -extfile openssl.worker.cnf
done

# CLUSTER ADMIN
openssl genrsa -out admin-key.pem 2048
openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in admin.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out admin.pem -days 365

openssl pkcs12 -export -in admin.pem -inkey admin-key.pem -out admin.p12 -name "KubeAdmin" -passout pass:
