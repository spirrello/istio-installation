#!/usr/bin/env bash



set -e

# error return function
error_exit() {
	echo "$1" 1>&2
	exit 1
}

# used for uninstalling istio
uninstall_istio() {
	echo "############ uninstalling istio-$ISTIO_VERSION ############"
  cd istio-$ISTIO_VERSION
  export PATH=$PWD/bin:$PATH
  istioctl manifest generate --set profile=demo | kubectl delete -f -
}

# check cluster and region provided
environment_validation() {
  if [[ -z "$REGION" ]]; then
    error_exit  "$LINENO: need a region" 1>&2
  else
    REGION_CHECK=$(gcloud compute regions list --filter "name=$REGION" --format='value(name)')
    if [[ "$REGION" != "$REGION_CHECK" ]]; then
      error_exit  "$LINENO: $REGION not a valid region" 1>&2
    fi
  fi

  if [[ -z "$CLUSTER_NAME" ]]; then
    error_exit  "$LINENO: Need a cluster name" 1>&2
  else
    CLUSTER_NAME_CHECK=$(gcloud container clusters list --region $REGION --filter "name:$CLUSTER_NAME" --format='value(name)')
    if [[ "$CLUSTER_NAME" != "$CLUSTER_NAME_CHECK" ]]; then
      error_exit  "$LINENO: $CLUSTER_NAME not a valid cluster" 1>&2
    fi
  fi

  if [[ -z "$HOST_RECORD" ]]; then
    error_exit  "$LINENO: need a host record for Istio ingress gateway" 1>&2
  else
    if [[ "$HOST_RECORD" != *".com"* ]]; then
      error_exit  "$LINENO: $HOST_RECORD is not a valid host rcord for the Istio ingress gateway." 1>&2
    fi
  fi
}

# update manifest per environment
update_istio_manifests() {
  # traverse back to the root dir
  cd $SCRIPT_DIR
  echo "############## updating Istio gateway ##############"
  sed -i "s/INGRESS_GATEWAY_HOST/$HOST_RECORD/g" manifests/ingressgateway.yaml
  sed -i "s/ISTIO_VERSION/$ISTIO_VERSION/g" manifests/ingressgateway.yaml
  kubectl apply -f manifests/ingressgateway.yaml
}

install_istio() {
  echo "############## downloading Istio $ISTIO_VERSION ##############"
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
  cd istio-$ISTIO_VERSION
  export PATH=$PWD/bin:$PATH
  echo "############## deploying default profile of Istio ##############"
  istioctl manifest apply --set profile=demo
}

# function for prepping gke
prep_gke() {
  #check if cluster rolebinding exists
  kubectl get clusterrolebinding cluster-admin-binding || CLUSTER_ROLE_STATUS=$?
  if [[ $CLUSTER_ROLE_STATUS > 0 ]]; then
    echo "############## Creating clusterrolebinding ##############"
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
  else
    echo "############## clusterrolebinding already exists ##############"
  fi

  #label default namespace
  kubectl label namespace default istio-injection=enabled || NS_LABEL_STATUS=$?
  if [[ $NS_LABEL_STATUS > 0 ]]; then
    echo "############## default namespace is already labeled ##############"
  else
    echo "############## default namespace now labeled ##############"
  fi
}

CLUSTER_NAME=$1
REGION=$2
ISTIO_VERSION=$3
HOST_RECORD=$4
DEFAULT_ISTIO_VERSION="1.4.3"
FIREWALL_RULE="$CLUSTER_NAME-allow-master-to-istiowebhook"
SCRIPT_DIR=$PWD

# uninstall and then exit
if [[ $1 == "uninstall" ]]; then
  if [ -z "$2" ]; then
    ISTIO_VERSION=$DEFAULT_ISTIO_VERSION
  else
    ISTIO_VERSION=$2
  fi
  uninstall_istio
  exit 0
fi


# invoke validation function
environment_validation


if [[ -z "$ISTIO_VERSION" ]]; then
  echo "############## Installing Istio 1.4.3 ##############"
  ISTIO_VERSION=$DEFAULT_ISTIO_VERSION
else
  echo "Installing Istio $ISTIO_VERSION"
fi

# prep k8s for istio installation
prep_gke

# install istio function
install_istio

# update Istio manifests
update_istio_manifests

echo "############## Finished ##############"
