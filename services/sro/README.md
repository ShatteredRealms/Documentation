# Overview
This section describes how to deploy all SRO environments

# Instructions
## Prerequisites
* The following sections completed:
  * `global`
  * `networking`
  * `database`
  * `services/auth`
* Helm
* Kubectl

## AWS ECR Cronjob
Create the cronjob that runs in the default namespace to refresh the ECR docker access token for the necessary namespace.
The cronjob requires the following secret be created first:
```bash
kubectl create secret generic ecr-registry-helper-secrets \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(kubectl get secret -n sro ecr-registry-helper-secrets -o jsonpath="{.data.AWS_SECRET_ACCESS_KEY}" | base64 -d)\
  --from-literal=AWS_ACCESS_KEY_ID=$(kubectl get secret -n sro ecr-registry-helper-secrets -o jsonpath="{.data.AWS_ACCESS_KEY_ID}" | base64 -d)\
  --from-literal=AWS_ACCOUNT=$(kubectl get secret -n sro ecr-registry-helper-secrets -o jsonpath="{.data.AWS_ACCOUNT}" | base64 -d)
kubectl apply -f prod/aws-ecr-cronjob.yaml
```

## Agones
Setup sro gameserver namespace and use helm to install agones
```bash
kubectl create namespace sro-gs
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro-gs}" \
  --set "agones.featureGates=PlayerTracking=true" \
  --set "agones.image.tag=1.39.0" \
  agones/agones
```

Setup RBAC
```bash
kubectl apply -f prod/rbac/agones.yaml
```

Set the external load balancer IP for agones
```bash
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
helm upgrade --install --wait --reuse-values \
   --set agones.allocator.service.loadBalancerIP=${EXTERNAL_IP} \
   agones agones/agones --namespace agones-system
```

## SRO Shared
Create the config
```
kubectl apply -f prod/files/sro-config.yaml
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
kubectl apply -f prod/characters.yaml
```

To remove
```
kubectl delete -f prod/characters.yaml
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
kubectl apply -f prod/chat.yaml
```

To remove
```
kubectl delete -f prod/chat.yaml
```

## Frontend
To install the frontend services, simply apply the configurations
```
kubectl apply -f prod/frontend.yaml
```

To remove
```
kubectl delete -f prod/frontend.yaml
```

## Gamebackend
Copy the allocator ca cert to the namespace `sro`.
```bash
kubectl delete secret allocator-tls-ca -n sro --ignore-not-found
kubectl delete secret allocator-tls-ca -n sro-qa --ignore-not-found
kubectl get secret allocator-tls-ca -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
kubectl get secret allocator-client.default -n agones-system -o yaml | sed 's/namespace: .*/namespace: sro/' | kubectl apply -f -
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
```

To install the gamebackend services, simply apply the configurations
```
kubectl apply -f prod/gamebackend.yaml
```

To remove
```
kubectl delete -f prod/gamebackend.yaml
```
