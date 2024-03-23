# Services
Here are the kubernetes services that run on the cluster

##### TODO
Update Uptrace setup steps to create secrets for everything when generating. Then those can be re-used easily for the shared SRO config

# Overview
* Agones: `agones-system`
* Shared: `sro`
* Accounts: `sro`
* Frontend: `sro`

## Prerequisites
* Global setup completed
* Networking setup completed
* Database setup completed

## Agones
Use helm to install agones
```
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro}" \
  --set "agones.featureGates=PlayerTracking=true" \
  --set "agones.image.tag=1.39.0" \
  agones/agones
```

Setup RBAC
```
kubectl apply -f prod/rbac/agones.yaml
```

Set the external load balancer IP for agones
```bash
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
helm upgrade --install --wait --reuse-values \
   --set agones.allocator.service.loadBalancerIP=${EXTERNAL_IP} \
   agones agones/agones --namespace agones-system
```

## Keycloak
Setup config
```
export CURRENT_FOLDER=$(pwd)
pushd .
cd $(mktemp -d)
POSTGRES_PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d)
POSTGRES_HOST=postgres-postgresql-ha-pgpool.sro.svc.cluster.local
POSTGRES_PORT=5432

cat $CURRENT_FOLDER/shared/files/keycloak.conf | \
  sed "s/{{POSTGRES_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{POSTGRES_HOST}}/$POSTGRES_HOST/g" | \
  sed "s/{{POSTGRES_PORT}}/$POSTGRES_PORT/g" \
  > keycloak.conf
kubectl delete secret generic keycloak-conf -n sro --ignore-not-found=true
kubectl create secret generic keycloak-conf -n sro --from-file=keycloak.conf

echo "You can delete folder $(pwd) now"
popd
```

Setup database
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
istioctl kube-inject -f prod/keycloak.yaml | kubectl apply -f -
```

Login with the default username `admin` and password `admin`. Change the password and create a new realm with the resource file `shared/files/keycloak.json` with the realm name `default`.

## Uptrace 
The service requires an `uptrace` database to be created on postgres and clickhouse.
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database uptrace;'"
clickhouse-client -h $(kubectl get svc -n sro clickhouse-pv-log -o jsonpath={.status.loadBalancer.ingress[0].ip})   -u admin   --password $(kubectl get secret clickhouse-credentials -n sro -o jsonpath={.data.password} | base64 -d) -q "CREATE DATABASE uptrace"
```
Setup the config. Need to configure username/password for office SMTP server in the following environment variables: \
`UPTRACE_SMTP_USERNAME`: SMTP Username\
`UPTRACE_SMTP_PASSWORD`: SMTP Password
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
SRO_QA_PROJ_SECRET=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
SRO_QA_PROJ_ID=2000
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
  sed "s/{{SRO_QA_PROJ_SECRET}}/$SRO_QA_PROJ_SECRET/g" | \
  sed "s/{{SRO_QA_PROJ_ID}}/$SRO_QA_PROJ_ID/g" | \
  sed "s/{{CLICKHOUSE_HOST}}/$CLICKHOUSE_HOST/g" | \
  sed "s/{{CLICKHOUSE_PASSWORD}}/$CLICKHOUSE_PASSWORD/g" | \
  sed "s/{{KEYCLOAK_UPTRACE_CLIENT_SECRET}}/$KEYCLOAK_UPTRACE_CLIENT_SECRET/g" | \
  sed "s/{{POSTGRES_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{POSTGRES_HOST}}/$POSTGRES_HOST/g" | \
  sed "s/{{POSTGRES_PORT}}/$POSTGRES_PORT/g" | \
  sed "s/{{UPTRACE_SMTP_USERNAME}}/$UPTRACE_SMTP_USERNAME/g" | \
  sed -e "s/{{UPTRACE_SMTP_PASSWORD}}/$UPTRACE_SMTP_PASSWORD/g" \
  > uptrace.yaml
kubectl delete secret uptrace-conf -n sro --ignore-not-found=true
kubectl create secret generic uptrace-conf -n sro --from-file=uptrace.yaml

cat $CURRENT_FOLDER/shared/files/otel-collector.yaml | \
  sed "s/{{UPTRACE_PROJ_SECRET}}/$UPTRACE_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_ID}}/$UPTRACE_PROJ_ID/g" \
  > otel-collector.yaml
kubectl delete secret otel-collector-conf -n sro --ignore-not-found=true
kubectl create secret generic otel-collector-conf -n sro --from-file=otel-collector.yaml

echo "You can delete folder $(pwd) now"
popd
```

To install the services, apply the configurations. 
```
istioctl kube-inject -f prod/uptrace.yaml | kubectl apply -f -
```

To remove
```
kubectl delete -f prod/uptrace.yaml
```


## SRO Shared
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

NAMESPACE=sro
POSTGRES_PASSWORD=$(kubectl get secret -n $NAMESPACE postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d)
POSTGRES_HOST=postgres-postgresql-ha-pgpool.sro.svc.cluster.local
POSTGRES_PORT=5432
MONGO_PASSWORD=$(kubectl get secret -n $NAMESPACE mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)

cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{CHARACTERS_MONGO_PASSWORD}}/$MONGO_PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{KEYCLOAK_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/$NAMESPACE/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{KEYCLOAK_CHARACTERS_CLIENT_ID}}/$KEYCLOAK_CHARACTERS_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_CHARACTERS_CLIENT_SECRET}}/$KEYCLOAK_CHARACTERS_CLIENT_SECRET/g" | \
  sed "s/{{KEYCLOAK_CHAT_CLIENT_ID}}/$KEYCLOAK_CHAT_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_CHAT_CLIENT_SECRET}}/$KEYCLOAK_CHAT_CLIENT_SECRET/g" | \
  sed "s/{{KEYCLOAK_GAMEBACKEND_CLIENT_ID}}/$KEYCLOAK_GAMEBACKEND_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_GAMEBACKEND_CLIENT_SECRET}}/$KEYCLOAK_GAMEBACKEND_CLIENT_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_SECRET}}/$SRO_PROD_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_ID}}/$SRO_PROD_PROJ_ID/g" \
  > config.yaml
  kubectl delete secret sro-config -n $NAMESPACE --ignore-not-found=true
  kubectl create secret generic sro-config -n $NAMESPACE --from-file=config.yaml

NAMESPACE=sro-qa
POSTGRES_PASSWORD=$(kubectl get secret -n $NAMESPACE postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d)
POSTGRES_HOST=postgres-postgresql-ha-pgpool.sro.svc.cluster.local
POSTGRES_PORT=5432
MONGO_PASSWORD=$(kubectl get secret -n $NAMESPACE mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{CHARACTERS_MONGO_PASSWORD}}/$MONGO_PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{KEYCLOAK_DB_PASSWORD}}/$POSTGRES_PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/$NAMESPACE/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{KEYCLOAK_CHARACTERS_CLIENT_ID}}/$KEYCLOAK_CHARACTERS_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_CHARACTERS_CLIENT_SECRET}}/$KEYCLOAK_CHARACTERS_CLIENT_SECRET/g" | \
  sed "s/{{KEYCLOAK_CHAT_CLIENT_ID}}/$KEYCLOAK_CHAT_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_CHAT_CLIENT_SECRET}}/$KEYCLOAK_CHAT_CLIENT_SECRET/g" | \
  sed "s/{{KEYCLOAK_GAMEBACKEND_CLIENT_ID}}/$KEYCLOAK_GAMEBACKEND_CLIENT_ID/g" | \
  sed "s/{{KEYCLOAK_GAMEBACKEND_CLIENT_SECRET}}/$KEYCLOAK_GAMEBACKEND_CLIENT_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_SECRET}}/$SRO_QA_PROJ_SECRET/g" | \
  sed "s/{{UPTRACE_PROJ_ID}}/$SRO_QA_PROJ_ID/g" \
  > config-qa.yaml
  kubectl delete secret sro-config -n $NAMESPACE --ignore-not-found=true
  kubectl create secret generic sro-config -n $NAMESPACE --from-file=config-qa.yaml

echo "You can delete folder $(pwd) now"
popd
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
kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
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
istioctl kube-inject -f qa/characters.yaml | kubectl apply -f -
```

To remove
```
kubectl delete -f prod/characters.yaml
kubectl delete -f qa/characters.yaml
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
kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
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
istioctl kube-inject -f qa/chat.yaml | kubectl apply -f -
```

To remove
```
kubectl delete -f prod/chat.yaml
kubectl delete -f qa/chat.yaml
```

## Frontend
To install the frontend services, simply apply the configurations
```
istioctl kube-inject -f prod/frontend.yaml | kubectl apply -f -
```

To remove
```
kubectl delete -f prod/frontend.yaml
```

## Game Server
Apply the production fleet
```bash
kubectl apply -f prod/fleet.yaml
```

## Gamebackend
Copy the allocator ca cert to the namespace `sro`.
```bash
kubectl delete secret allocator-tls-ca -n sro --ignore-not-found
kubectl delete secret allocator-tls-ca -n sro-qa --ignore-not-found
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro-qa/' | kubectl apply -f -
```
Setup database
```
kubectl exec -t -n sro pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database gamebackend;'"
kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.password}' | base64 -d) \
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
istioctl kube-inject -f qa/gamebackend.yaml | kubectl apply -f -
```

To remove
```
kubectl delete -f prod/gamebackend.yaml
kubectl delete -f qa/gamebackend.yaml
```

# TBD Config
## ECK
```
kubectl create -f https://download.elastic.co/downloads/eck/2.7.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.7.0/operator.yaml
kubectl create namespace logging
```
See status with
```
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

Create the eck keystore secret
```
kubectl create secret generic es-oidc-secret -n logging --from-literal=xpack.security.authc.realms.oidc.sro.rp.client_secret=YOUR_SECRET_HERE
```

Create ES, Fluent Bit and Kibana
```
kubectl apply -f prod/eck.yaml
```

Get Kibana password
```
kubectl get secret production-es-elastic-user -o=jsonpath='{.data.elastic}' -n sro | base64 --decode; echo
```

And login with the user `elastic`.


## Grafana
The service requires a secret `grafana-ini` to be created. Copy the grafana keycloak oidc secret into the environment variable `KEYCLOAK_GRAFANA_SECRET` then run the following command.
```
CURR_DIR=$(pwd)
TMP_DIR=$(mktemp -d)
pushd $TMP_DIR
cat $CURR_DIR/prod/files/grafana.ini | \
  sed "s/{{KEYCLOAK_GRAFANA_SECRET}}/$KEYCLOAK_GRAFANA_SECRET/g" \
  > grafana.ini
kubectl delete secret grafana-cnf -n sro
kubectl create secret generic grafana-cnf -n sro --from-file=grafana.ini
popd
rm -rf "$TMP_DIR"
```

Then deploy the service
```
istioctl kube-inject -f prod/grafana.yaml | kubectl apply -f -

```


## Prometheus
The service requires a config-map `prometheus-cnf` to be created. Save the keycloak oidc client secret into `PROMETHEUS_CLIENT_SECRET` and create it with the following command:
```
kubectl delete -f prod/files/prometheus-config-map.yaml
cat prod/files/prometheus-config-map.yaml | \
  sed "s/{{PROMETHEUS_CLIENT_SECRET}}/$PROMETHEUS_CLIENT_SECRET/g" |
  kubectl apply -f -
```

Then create the service
```
istioctl kube-inject -f prod/prometheus.yaml | kubectl apply -f -
```
