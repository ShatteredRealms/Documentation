## Keycloak
Install the CRDs
```bash
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/24.0.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/24.0.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
```

Install the Keycloak Operator in the auth namespace. The Operator only watches the namespace it's deployed into.
```bash
kubectl apply -n auth -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/24.0.2/kubernetes/kubernetes.yml
```

Create keycloak postgres database
```bash
kubectl exec -t -n auth pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n auth postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database keycloak;'"
```

Deploy keycloak
```bash
kubectl apply -f keycloak.yaml
```

Add the realm export to the `files` folder, then run the following command to create secrets for select clients.
```bash
kubectl create secret generic -n observability keycloak-grafana \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "grafana").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "grafana").secret')

kubectl create secret generic -n observability keycloak-prometheus \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "prometheus").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "prometheus").secret')

kubectl create secret generic -n sro keycloak-character \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-character").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-character").secret')

kubectl create secret generic -n sro keycloak-chat \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-chat").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-chat").secret')

kubectl create secret generic -n sro keycloak-gamebackend \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-gamebackend").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-gamebackend").secret')

kubectl create secret generic -n sro-gs keycloak-gameserver \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-gameserver").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-gameserver").secret')

kubectl create secret generic -n sro keycloak-web \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "sro-web").id')

kubectl create secret generic -n sro keycloak-oauth2-proxy \
  --from-literal id=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "oauth2-proxy").id')\
  --from-literal secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "oauth2-proxy").secret')

# Kiali uses a special syntax
kubectl create secret generic -n istio-system kiali \
  --from-literal oidc-secret=$(cat files/realm-export.json | jq -j '.clients[] | select(.clientId == "kiali").secret')
```

Get the default username and password and login as the admin user and import the realm.
```bash
echo "user: $(kubectl get secret keycloak-initial-admin -n auth -o jsonpath='{.data.username}' | base64 -d)"
echo "pass: $(kubectl get secret keycloak-initial-admin -n auth -o jsonpath='{.data.password}' | base64 -d)"
```

## OAuth2 Proxy
Reverse proxy to force authorization for some paths

```bash
kubectl create secret generic -n sro oauth2-proxy-secrets\
  --from-literal cookie=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
```
