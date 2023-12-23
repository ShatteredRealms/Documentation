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
  --set "agones.image.tag=1.33.0" \
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
`KEYCLOAK_CHARACTERS_CLIENT_ID` and `KEYCLOAK_CHARACTERS_CLIENT_SECRET` to the keycloak client id and secret respectively for the characters client. \
`KEYCLOAK_CHAT_CLIENT_ID` and `KEYCLOAK_CHAT_CLIENT_SECRET` to the keycloak client id and secret respectively for the chat client. \
`KEYCLOAK_GAMEBACKEND_CLIENT_ID` and `KEYCLOAK_GAMEBACKEND_CLIENT_SECRET` to the keycloak client id and secret respectively for the gamebackend client. \
`KEYCLOAK_UPTRACE_CLIENT_SECRET` to the keycloak secret for the uptrace client.
```
export CURRENT_FOLDER=$(pwd)
pushd .
cd $(mktemp -d)

# Create uptrace config
UPTRACE_JWT_SECRET_KEY=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
UPTRACE_PROJ_SECRET=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
UPTRACE_PROJ_ID=1
SRO_PROD_PROJ_SECRET=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
SRO_PROD_PROJ_ID=1000
CLICKHOUSE_HOST=$(kubectl get svc -n sro clickhouse-pv-log -o jsonpath={.status.loadBalancer.ingress[0].ip})
CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-credentials -n sro -o jsonpath={.data.password} | base64 -d)
POSTGRES_PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d)
POSTGRES_HOST=postgres-postgresql-ha-pgpool.sro.svc.cluster.local
POSTGRES_PORT=5432

cat $CURRENT_FOLDER/shared/files/uptrace.yaml | \
  sed "s/{{UPTRACE_JWT_SECRET_KEY}}/$UPTRACE_JWT_SECRET_KEY/g" | \
  sed "s/{{UPTRACE_PROJ_SECRET}}/$UPTRACE_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_ID}}/$UPTRACE_PROJ_ID/g" | \
  sed "s/{{SRO_PROD_PROJ_SECRET}}/$SRO_PROD_PROJ_SECRET/g" | \
  sed "s/{{SRO_PROD_PROJ_ID}}/$SRO_PROD_PROJ_ID/g" | \
  sed "s/{{CLICKHOUSE_HOST}}/$CLICKHOUSE_HOST/g" | \
  sed "s/{{CLICKHOUSE_PASSWORD}}/$CLICKHOUSE_PASSWORD/g" | \
  sed "s/{{KEYCLOAK_UPTRACE_CLIENT_SECRET}}/$KEYCLOAK_UPTRACE_CLIENT_SECRET/g" | \
  sed "s/{{POSTGRES_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{POSTGRES_HOST}}/$POSTGRES_HOST/g" | \
  sed "s/{{POSTGRES_PORT}}/$POSTGRES_PORT/g" \
  > uptrace.yaml
kubectl create secret generic uptrace-conf -n sro --from-file=uptrace.yaml

cat $CURRENT_FOLDER/shared/files/otel-collector.yaml | \
  sed "s/{{UPTRACE_PROJ_SECRET}}/$UPTRACE_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_ID}}/$UPTRACE_PROJ_ID/g" \
  > otel-collector.yaml
kubectl create secret generic otel-collector-conf -n sro --from-file=otel-collector.yaml

# Create sro config secrets
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{KEYCLOAK_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/sro/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{UPTRACE_TOKEN}}/$SRO_PROD_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_ID}}/$SRO_PROD_PROJ_ID/g" \
  > config.yaml
cat $CURRENT_FOLDER/shared/config.yaml | \
  sed "s/{{SRO_CONFIG}}/$(cat config.yaml | base64 -w 0)/g" | \
  kubectl apply -n sro -f -
rm -rf $CURRENT_FOLDER/shared/config.yaml


# Keycloak config
cat $CURRENT_FOLDER/shared/files/keycloak.conf | \
  sed "s/{{POSTGRES_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{POSTGRES_HOST}}/$POSTGRES_HOST/g" | \
  sed "s/{{POSTGRES_PORT}}/$POSTGRES_PORT/g" \
  > keycloak.conf
kubectl create secret generic keycloak-conf -n sro --from-file=keycloak.conf

echo "You can delete folder $(pwd) now"
popd
```

## Uptrace 
The service requires an `uptrace` database to be created.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database uptrace;'"
```

To install the services, apply the configurations. 
```
istioctl kube-inject -f prod/uptrace.yaml | kubectl apply -f -
```

## Characters 
The account service requires an `characters` database to be created. First create that for each environment.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
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
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
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

create the database
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database gamebackend;'"
```

To install the gamebackend services, simply apply the configurations
```
istioctl kube-inject -f prod/gamebackend.yaml | kubectl apply -f -
```

## Keycloak
Create the database for keycloak
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database keycloak;'"
```

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
```
