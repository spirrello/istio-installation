#!/usr/bin/env bash

# this script generates certificates only for the purpose of testing gateway pods

#CA CERT
ORG="example"
CN="example.com"
CA_CERT="ca-cert.crt"
CA_KEY="ca.key"

#CERT REQUEST
CSR="nginx.example.com.csr"
CERT_CN="nginx.example.com"
CERT_KEY="nginx.example.com.key"
CERT_NAME="nginx.example.com.crt"
CERT_ORG="SOME ORG"
K8S_SECRET="istio-ingressgateway-cert"

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
-subj "/O=$ORG Inc./CN=$CN" -keyout $CA_KEY -out $CA_CERT

openssl req -out $CSR -newkey rsa:2048 -nodes \
-keyout $CERT_KEY -subj "/CN=$CERT_CN/O=$CERT_ORG"

openssl x509 -req -days 365 -CA $CA_CERT -CAkey $CA_KEY \
-set_serial 0 -in $CSR -out $CERT_NAME

CHECK_CERT=`openssl verify -verbose -CAfile $CA_CERT  $CERT_NAME`

# Check if certificate is valid
if [[ $CHECK_CERT == *"OK"* ]]; then
  echo "Certificate is valid, creating K8s secret now..."
  kubectl create secret tls $K8S_SECRET --cert=$CERT_NAME --key=$CERT_KEY -n istio-system
else
  echo "ERROR OCCURRED WHILE GENERATING CERTIFICATE"
fi
