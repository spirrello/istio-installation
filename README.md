# Scripts for installing Istio on GKE


# Requirements

* GKE cluster 1.14.x
* Firewall rules allowing webhooks initiated from master CIDR to node pool on ports 443, 9443, 10250, 15017
* Istio 1.4.x, 1.5.x (default included in this script is 1.5.1)

# Install Procedure

Installation procedure for installing Istio from istio.io.

## install.sh

Installation script

* A valid cluster name and region must be provided in the following order.
* You might substitute a zone for the region parameter if required.
* Be sure to include the host in quotes
* Ignore any errors until cert.sh is executed

```
./install.sh -install CLUSTER REGION MYHOST.COM

Example

/install.sh -install test-cluster-1 us-central1-c *.preprod.ncrsaas.com

```

## cert.sh

This script creates the `istio-ingressgateway-certs` secret for Istio that matches the host name provided earlier.  Once the secret is generated it will delete the istioingress pod in order to mount the new secret.

```
./cert.sh CERT KEY

Example
./cert.sh nginx.example.com.crt nginx.example.com.key

```
## Verification

After running the following script with the `-verify` flag you should no longer see any errors.

```
./install.sh -verify
```

# Uninstalling Istio

The uninstall deletes the RBAC permissions, the istio-system namespace, and all resources hierarchically under it. It is safe to ignore errors for non-existent resources because they may have been deleted hierarchically.

```
./install.sh -uninstall
```

# Generating manifests

Manifests are recommended for keeping your deployment as code and is `required when upgrading Istio`.

* Be sure to generate a manifest with the corresponding version of Istio
* istioctl manifest generate --set profile=demo > manifests/VERSION/full-deployment.yaml
* Update the ingressgateway gateway to use TLS, see existing manifests for reference

Istio gateway with TLS:

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ingressgateway
  namespace: istio-system
  labels:
    release: istio
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - 'INGRESS_GATEWAY_HOST'
    port:
      name: https
      number: 443
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-certs/tls.key
```
## Reference

https://istio.io/
