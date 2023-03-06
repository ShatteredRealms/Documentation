# Services
Here are the kubernetes services that run on the cluster

# Overview
* Agones: `agones-system`
* Shared: `sro`
* Accounts: `sro`
* Frontend: `sro`

## Agones
Use helm to install agones
```
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro}" \
  --set "agones.featureGates=PlayerTracking=true" \
  --set "agones.image.tag=1.30.0" \
  agones/agones
```

Set the external load balancer IP for agones
```bash
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
helm upgrade --install --wait --reuse-values \
   --set agones.allocator.service.loadBalancerIP=${EXTERNAL_IP} \
   agones agones/agones --namespace agones-system
```

## Shared
To install the shared configurations and service, apply the configurations and replace all text in the surrounded in double brackets like: `{{}}`. \

If using the script below, please set the the following environment variables: \
`PROD_UPTRACE_TOKEN` to the Uptrace token and `PROD_UPTRACE_ID` to the Uptrace id. 
```
export CURRENT_FOLDER=$(pwd)
pushd .
cd $(mktemp -d)

# Create jwt secrets
openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/shared/certs.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -n sro -f -
# Create config secrets

PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{ACCOUNTS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{KEYCLOAK_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/sro/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{UPTRACE_TOKEN}}/$PROD_UPTRACE_TOKEN/g" | \
  sed "s/{{UPTRACE_ID}}/$PROD_UPTRACE_ID/g" \
  > config.yaml
cat $CURRENT_FOLDER/shared/config.yaml | \
  sed "s/{{SRO_CONFIG}}/$(cat config.yaml | base64 -w 0)/g" | \
  kubectl apply -n sro -f -
rm -rf $CURRENT_FOLDER/shared/config.yaml

cat $CURRENT_FOLDER/shared/files/keycloak.conf | \
  sed "s/{{KEYCLOAK_DB_PASSWORD}}/$PASSWORD/g" \
  > $CURRENT_FOLDER/shared/keycloak.conf
kubectl create secret generic keycloak-conf -n sro --from-file=$CURRENT_FOLDER/shared/ekycloak.conf
rm -rf $CURRENT_FOLDER/shared/keycloak.conf

echo "You can delete folder $(pwd) now"
popd
```

## Accounts
**This service requires shared services to be configured first**
The account service requires an `accounts` database to be created. First create that for each environment.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database accounts;'"
```

To install the account services, apply the configurations 
```
istioctl kube-inject -f prod/accounts.yaml | kubectl apply -f -
```

## Characters 
The account service requires an `characters` database to be created. First create that for each environment.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database characters;'"
```

To install the account services, apply the configurations. 
```
istioctl kube-inject -f prod/characters.yaml | kubectl apply -f -
```

## Chat 
The account service requires an `chat` database to be created. First create that for each environment.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database chat;'"
```

To install the account services, apply the configurations. 
```
istioctl kube-inject -f prod/chat.yaml | kubectl apply -f -
```


## Frontend
To install the frontend services, simply apply the configurations
```
istioctl kube-inject -f prod/frontend.yaml | kubectl apply -f -
```


## Game Server
Apply the production fleet
```bash
kubectl apply -f prod/fleet.yaml
```

## Gamebackend
Copy the allocator ca cert to the namespace `sro`.
```bash
kubectl delete secret allocator-tls-ca -n sro
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
```

To install the gamebackend services, simply apply the configurations
```
istioctl kube-inject -f prod/gamebackend.yaml | kubectl apply -f -
```

## Keycloak
Deploy keycloak with

```bash
kubectl apply -f prod/keycloak.yaml
```

Login with the default username `admin` and password `admin`. Change the password and create a new realm with the resource file `shared/files/keycloak-sro.json` with the realm name `default`.

Then go to the client `sro-client` credentials section and copy the client authenticator secret. Create a new basic auth secret in the `sro` namespace with this information.
```
PASSWORD=<PASSWORD HERE>
cat shared/keycloak-login.yaml | \
  sed "s/{{PASSWORD}}/$PASSWORD/g" | \
  kubectl apply -f -