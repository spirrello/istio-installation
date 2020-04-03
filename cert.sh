#!/usr/bin/env bash

K8S_SECRET="istio-ingressgateway-certs"
NAMESPACE="istio-system"

CERT=$1
KEY=$2

if [[ -z $CERT ]] || [[ -z $KEY ]]; then
  echo "CERT and KEY values must be provided"
  exit 1
fi
# check if the certs match
CERT_CHECK=$(openssl x509 -modulus -noout -in $CERT  | sha256sum | awk '{print $1}')
KEY_CHECK=$(openssl rsa -modulus -noout -in $KEY | sha256sum | awk '{print $1}')



if [[ $CERT_CHECK == $KEY_CHECK ]]; then
  echo "Certificate is valid, creating K8s secret now..."
  kubectl create secret tls $K8S_SECRET --cert=$CERT --key=$KEY -n $NAMESPACE
  echo "Deleting istio gateway pods to mount certs"
  kubectl delete pods -n istio-system -l app=istio-ingressgateway
  kubectl delete pods -n istio-system -l app=istio-egressgateway

else
  echo "ERROR OCCURRED WHILE GENERATING CERTIFICATE"
  echo "CERT_CHECK: " $CERT_CHECK
  echo "KEY_CHECK: " $KEY_CHECK
fi
