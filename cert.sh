#!/usr/bin/env bash

K8S_SECRET="istio-ingressgateway-cert"

CERT=$2
CERT_KEY=$3

# check if the certs match
CERT_CHECK=$(openssl pkey -in $CERT_KEY -pubout -outform pem | sha256sum)
CERT=$(openssl x509 -in $CERT -pubkey -noout -outform pem | sha256sum)


# Check if certificate is valid
if [[ $CERT_CHECK == $CERT ]]; then
  echo "Certificate is valid, creating K8s secret now..."
  kubectl create secret tls $K8S_SECRET --cert=$CERT_NAME --key=$CERT_KEY -n istio-system
else
  echo "ERROR OCCURRED WHILE GENERATING CERTIFICATE"
fi
