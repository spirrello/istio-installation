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
}

CLUSTER_NAME=$1
REGION=$2
ISTIO_VERSION=$3
DEFAULT_ISTIO_VERSION="1.4.3"
FIREWALL_RULE="$CLUSTER_NAME-allow-master-to-istiowebhook"


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

#download istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

cd istio-$ISTIO_VERSION

export PATH=$PWD/bin:$PATH

echo "############## deploying default profile of istio ##############"
istioctl manifest apply --set profile=demo

#might need to run this in the case of timeouts for side car injection
#fetch info then create firewall rule
#by default we won't create the firewall rules.
if [[ $4 == "--fw" ]]; then
  echo "############## creating firewall rule for istio webhook ##############"
  CLUSTER_REGION=$(gcloud container clusters list --filter "name:$CLUSTER_NAME" | grep -v NAME | awk '{print $2}')
  NETWORK=$(gcloud container clusters describe $CLUSTER_NAME --region $CLUSTER_REGION --format json | jq -r .network)
  echo "CLUSTER_REGION: $CLUSTER_REGION"
  MASTER_CIDR=$(gcloud container clusters describe $CLUSTER_NAME --region $CLUSTER_REGION --format json | jq -r .privateClusterConfig.masterIpv4CidrBlock)
  echo "MASTER_CIDR: $MASTER_CIDR"
  NODE_POOL=$(gcloud container node-pools list --region $CLUSTER_REGION --cluster $CLUSTER_NAME | grep -v NAME | awk '{print $1}')
  echo "NODE_POOL: $NODE_POOL"
  TARGET_TAG=$(gcloud container node-pools describe $NODE_POOL --region $CLUSTER_REGION --cluster $CLUSTER_NAME --format json | jq -r .config.tags[0])
  echo "TARGET_TAG: $TARGET_TAG"
  gcloud compute firewall-rules create $FIREWALL_RULE --network $NETWORK --allow=tcp:9443 --direction=INGRESS --enable-logging --source-ranges=$MASTER_CIDR --target-tags=$TARGET_TAG || FIREWALL_RULE_STATUS=$?
fi

echo "############## Finished ##############"
