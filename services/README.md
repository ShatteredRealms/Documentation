# Services
Here are the kubernetes services that run on the cluster

# Overview
* Shared: `sro`, `sro-qa`, `sro-dev`
* Accounts: `sro`, `sro-qa`, `sro-dev`
* Frontend: `sro`, `sro-qa`, `sro-dev`
* Agones: `agones-system`

## Shared
To install the shared configurations and service, apply the configurations and replace `{{JWT_PUBLIC_KEY}}` and `{{JWT_PRIVATE_KEY}}`
with the public and private keys used for JWT authentication and authorization between all of the microserivces.
```
export CURRENT_FOLDER=$(pwd)
pushd .
cd $(mktemp -d)

openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/prod/shared.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -f -

openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/qa/shared.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -f -

openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/dev/shared.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -f -


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

kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database accounts;'"

kubectl exec -t -n sro-dev pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database accounts;'"
```

To install the account services, apply the configurations with replacing `{{DATABASE_FILE}}` with the correct database file format. Check
the account microservice for more information.
```
DATABASE_PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DATABASE_FILE=$(cat prod/files/accounts-db.yaml | sed "s/{{DATABASE_PASSWORD}}/$DATABASE_PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f prod/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$DATABASE_FILE/g" | \
  kubectl apply -f -

DATABASE_PASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DATABASE_FILE=$(cat qa/files/accounts-db.yaml | sed "s/{{DATABASE_PASSWORD}}/$DATABASE_PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f qa/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$DATABASE_FILE/g" | \
  kubectl apply -f -

DATABASE_PASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DATABASE_FILE=$(cat dev/files/accounts-db.yaml | sed "s/{{DATABASE_PASSWORD}}/$DATABASE_PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f dev/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$DATABASE_FILE/g" | \
  kubectl apply -f -
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

kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database characters;'"

kubectl exec -t -n sro-dev pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database characters;'"
```

To install the account services, apply the configurations with replacing `{{DATABASE_FILE}}` with the correct database file format. Check
the account microservice for more information.
```
PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DB_FILE=$(cat prod/files/characters-db.yaml | sed "s/{{PASSWORD}}/$PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f prod/characters.yaml | \
  sed "s/{{DATABASE_FILE}}/$DB_FILE/g" | \
  kubectl apply -f -

PASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DB_FILE=$(cat qa/files/characters-db.yaml | sed "s/{{PASSWORD}}/$PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f qa/characters.yaml | \
  sed "s/{{DATABASE_FILE}}/$DB_FILE/g" | \
  kubectl apply -f -

PASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
DB_FILE=$(cat dev/files/characters-db.yaml | sed "s/{{PASSWORD}}/$PASSWORD/g" | base64 -w 0)
istioctl kube-inject -f /characters.yaml | \
  sed "s/{{DATABASE_FILE}}/$DB_FILE/g" | \
  kubectl apply -f -
```

## Frontend
To install the frontend services, simply apply the configurations
```
istioctl kube-inject -f prod/frontend.yaml | kubectl apply -f -
istioctl kube-inject -f qa/frontend.yaml | kubectl apply -f -
istioctl kube-inject -f dev/frontend.yaml | kubectl apply -f -
```

## Agones
Use helm to install agones
```
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro,sro-qa,sro-dev}" \
  --set "agones.featureGates=PlayerTracking=true" \
  agones/agones
```

Set the external load balancer IP for agones
```bash
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
helm upgrade --install --wait --reuse-values \
   --set agones.allocator.service.loadBalancerIP=${EXTERNAL_IP} \
   agones agones/agones --namespace agones-system
```

## Game Server
Apply the production fleet
```bash
kubectl apply -f prod/fleet.yaml
```

## Server Finder
Copy the allocator ca cert to the namespaces `sro` `sro-qa` and `sro-dev` namespaces.
```bash
kubectl delete secret allocator-tls-ca -n sro
kubectl delete secret allocator-tls-ca -n sro-qa
kubectl delete secret allocator-tls-ca -n sro-dev
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro-qa/' | kubectl apply -f -
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro-dev/' | kubectl apply -f -
```

Apply the configurations
```bash
istioctl kube-inject -f prod/gamebackend.yaml | kubectl apply -f -
```