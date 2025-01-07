# Overview
This section describes how to deploy agones in a local development kubernetes cluster. Useful for development and testing with agones.

## Instructions
Create the namespace and setup rbac
```bash
kubectl create namespace sro-gs
kubectl apply -f agones-rbac.yaml
```


Install and configure agones with helm
```bash
helm repo add agones https://agones.dev/chart/stable
helm repo update
helm install agones --namespace agones-system \
  --create-namespace \
  --set "gameservers.namespaces={sro-gs}" \
  --set "agones.featureGates=PlayerTracking=true" \
  --set "agones.image.tag=1.39.0" \
  --set "agones.allocator.serviceType=ClusterIp" \
  --set "agones.allocator.service.clusterIp=None" \
  --set "agones.allocator.disableTLS=true" \
  --set "agones.allocator.disableMTLS=true" \
  agones/agones
```
