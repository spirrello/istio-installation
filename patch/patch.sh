kubectl -n istio-system patch svc istio-ingressgateway \
    --type=json -p="$(cat istio-ingressgateway-patch.json)" \
    --dry-run=true -o yaml | kubectl apply -f -
