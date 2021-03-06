#!/usr/bin/env bash



set -e


CLUSTER_NAME=$2
REGION=$3
HOST_RECORD=$4
ISTIO_VERSION=${ISTIO_VERSION:-"1.5.1"}
ISTIO_PROFILE=${ISTIO_PROFILE:-"demo"}

FIREWALL_RULE="$CLUSTER_NAME-allow-master-to-istiowebhook"
SCRIPT_DIR=$PWD

# error return function
error_exit() {
	echo "$1" 1>&2
	exit 1
}

# used for uninstalling istio
uninstall_istio() {
	echo "############ uninstalling istio-$ISTIO_VERSION ############"
  cd $SCRIPT_DIR
  cd istio-$ISTIO_VERSION
  export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
  istioctl manifest generate --set profile=demo | kubectl delete -f -
}

# check cluster and region provided
environment_validation() {
  echo "############ validating provided options ############"
  if [[ -z "$REGION" ]]; then
    error_exit  "$LINENO: need a region" 1>&2
  else
    REGION_CHECK=$(gcloud compute regions list --filter "name=$REGION" --format='value(name)')
    if [[ "$REGION" != "$REGION_CHECK" ]]; then
      REGION_CHECK=$(gcloud compute zones list --filter "name=$REGION" --format='value(name)')
      if [[ "$REGION" != "$REGION_CHECK" ]]; then
        error_exit  "$LINENO: $REGION not a valid zone or region" 1>&2
      fi
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
  echo "############## all environment options passed ##############"
}

# install istio
install_istio() {
  # traverse back to the root dir
  cd $SCRIPT_DIR
  echo "############## installing istio $ISTIO_VERSION  ##############"
  echo "HOST_RECORD:" $HOST_RECORD
  sed "s/INGRESS_GATEWAY_HOST/$HOST_RECORD/g" manifests/$ISTIO_VERSION/full-deployment.yaml | kubectl apply -f -
}

download_istio() {
  echo "############## downloading Istio $ISTIO_VERSION ##############"
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
  #cd istio-$ISTIO_VERSION
  export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
  # run pre-flight check
  istioctl verify-install
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

# used for uninstalling istio
uninstall_istio() {
	echo "############ uninstalling istio-$ISTIO_VERSION ############"
  cd $SCRIPT_DIR
  export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
  istioctl manifest generate --set profile=demo | kubectl delete -f -
}

# used for uninstalling istio
verify_install() {
	echo "############ verifying installation istio-$ISTIO_VERSION ############"
  cd $SCRIPT_DIR
  export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
  sed "s/INGRESS_GATEWAY_HOST/$HOST_RECORD/g" manifests/$ISTIO_VERSION/full-deployment.yaml | istioctl verify-install -f -
}


echo "working with version: " $ISTIO_VERSION

while [ -n "$1" ]; do # while loop starts

	case "$1" in

	-install)
    environment_validation
    prep_gke
    download_istio
    install_istio
    verify_install
    ;;

	-uninstall)
		uninstall_istio
		;;

  -verify)
    verify_install
    ;;

	esac

	shift

done
