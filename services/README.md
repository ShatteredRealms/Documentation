# Services
Here are the kubernetes services that run on the cluster

# Overview
* Agones: `agones-system`
* Shared: `sro`, `sro-qa`, `sro-dev`
* Accounts: `sro`, `sro-qa`, `sro-dev`
* Frontend: `sro`, `sro-qa`, `sro-dev`

## Agones
Use helm to install agones
```
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro,sro-qa,sro-dev}" \
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
`PROD_UPTRACE_TOKEN`, `QA_UPTRACE_TOKEN`, and `DEV_UPTRACE_TOKEN` to their respective Uptrace token. 
`PROD_UPTRACE_ID`, `QA_UPTRACE_ID`, and `DEV_UPTRACE_ID` to their respective Uptrace id. 
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

openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/shared/certs.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -n sro-qa -f -

openssl genrsa -out private.key 2048
openssl rsa -in private.key -pubout -out public.key
sed -i "s/PUBLIC/RSA PUBLIC/g" public.key
cat $CURRENT_FOLDER/shared/certs.yaml | \
  sed "s/{{JWT_PRIVATE_KEY}}/$(cat private.key | base64 -w 0)/g" | \
  sed "s/{{JWT_PUBLIC_KEY}}/$(cat public.key | base64 -w 0)/g" | \
  kubectl apply -n sro-dev -f -

# Create config secrets

PASSWORD=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{ACCOUNTS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/sro/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{UPTRACE_TOKEN}}/$PROD_UPTRACE_TOKEN/g" | \
  sed "s/{{UPTRACE_ID}}/$PROD_UPTRACE_ID/g" \
  > config.yaml
cat $CURRENT_FOLDER/shared/config.yaml | \
  sed "s/{{SRO_CONFIG}}/$(cat config.yaml | base64 -w 0)/g" | \
  kubectl apply -n sro -f -

PASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{ACCOUNTS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/sro/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{UPTRACE_TOKEN}}/$QA_UPTRACE_TOKEN/g" | \
  sed "s/{{UPTRACE_ID}}/$QA_UPTRACE_ID/g" \
  > config.yaml
cat $CURRENT_FOLDER/shared/config.yaml | \
  sed "s/{{SRO_CONFIG}}/$(cat config.yaml | base64 -w 0)/g" | \
  kubectl apply -n sro-qa -f -

PASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)
cat $CURRENT_FOLDER/shared/files/sro-config.yaml | \
  sed "s/{{ACCOUNTS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHARACTERS_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{GAMEBACKEND_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{CHAT_DB_PASSWORD}}/$PASSWORD/g" | \
  sed "s/{{NAMESPACE}}/sro/g" | \
  sed "s/{{AGONES_IP}}/$(kubectl get svc -n agones-system agones-allocator -o jsonpath={.status.loadBalancer.ingress[0].ip})/g" | \
  sed "s/{{UPTRACE_TOKEN}}/$DEV_UPTRACE_TOKEN/g" | \
  sed "s/{{UPTRACE_ID}}/$DEV_UPTRACE_ID/g" \
  > config.yaml
cat $CURRENT_FOLDER/shared/config.yaml | \
  sed "s/{{SRO_CONFIG}}/$(cat config.yaml | base64 -w 0)/g" | \
  kubectl apply -n sro-dev -f -
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

To install the account services, apply the configurations 
```
istioctl kube-inject -f prod/accounts.yaml | kubectl apply -f -
istioctl kube-inject -f qa/accounts.yaml | kubectl apply -f -
istioctl kube-inject -f dev/accounts.yaml | kubectl apply -f -
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

To install the account services, apply the configurations. 
```
istioctl kube-inject -f prod/characters.yaml | kubectl apply -f -
istioctl kube-inject -f qa/characters.yaml | kubectl apply -f -
istioctl kube-inject -f dev/characters.yaml | kubectl apply -f -
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

kubectl exec -t -n sro-qa pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
  psql \
    -h postgres-postgresql-ha-pgpool \
    -p 5432 \
    -U postgres \
    -d postgres \
    -c 'create database chat;'"

kubectl exec -t -n sro-dev pg-client \
  -- bash -c "PGPASSWORD=$(kubectl get secret -n sro-dev postgres-postgresql-ha-postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d) \
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
istioctl kube-inject -f dev/chat.yaml | kubectl apply -f -
```


## Frontend
To install the frontend services, simply apply the configurations
```
istioctl kube-inject -f prod/frontend.yaml | kubectl apply -f -
istioctl kube-inject -f qa/frontend.yaml | kubectl apply -f -
istioctl kube-inject -f dev/frontend.yaml | kubectl apply -f -
```


## Game Server
Apply the production fleet
```bash
kubectl apply -f prod/fleet.yaml
```

## Gamebackend
Copy the allocator ca cert to the namespaces `sro` `sro-qa` and `sro-dev` namespaces.
```bash
kubectl delete secret allocator-tls-ca -n sro
kubectl delete secret allocator-tls-ca -n sro-qa
kubectl delete secret allocator-tls-ca -n sro-dev
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro-qa/' | kubectl apply -f -
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro-dev/' | kubectl apply -f -
```

To install the gamebackend services, simply apply the configurations
```
istioctl kube-inject -f prod/gamebackend.yaml | kubectl apply -f -
istioctl kube-inject -f qa/gamebackend.yaml | kubectl apply -f -
istioctl kube-inject -f dev/gamebackend.yaml | kubectl apply -f -
```