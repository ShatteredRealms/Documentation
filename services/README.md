# Services
Here are the kubernetes services that run on the cluster

# Overview
* Accounts: `sro`, `sro-qa`, `sro-dev`
* Frontend: `sro`, `sro-qa`, `sro-dev`
* Agones: `agones-system`

## Accounts
To install the account services, simply apply the configurations
```
kubectl apply -f prod/accounts.yaml
kubectl apply -f qa/accounts.yaml
kubectl apply -f dev/accounts.yaml
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