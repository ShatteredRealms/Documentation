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
```

To install the account services, apply the configurations with replacing `{{DATABASE_FILE}}` with the correct database file format. Check
the account microservice for more information.
```
cat prod/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$(cat prod/files/accounts-db.yaml | base64 -w 0)/g" | \
  kubectl apply -f -

cat qa/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$(cat qa/files/accounts-db.yaml | base64 -w 0)/g" | \
  kubectl apply -f -

cat dev/accounts.yaml | \
  sed "s/{{DATABASE_FILE}}/$(cat dev/files/accounts-db.yaml | base64 -w 0)/g" | \
  kubectl apply -f -
```

## Frontend
To install the frontend services, simply apply the configurations
```
kubectl apply -f prod/frontend.yaml
kubectl apply -f qa/frontend.yaml
kubectl apply -f dev/frontend.yaml
```

## Agones
Use helm to install agones
```
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro-gs,sro-qa-gs,sro-dev-gs}" \
  --set "agones.featureGates=PlayerTracking=true" \
  agones/agones
```