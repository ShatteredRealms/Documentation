# Database
The dedicated database is given to each stage: `sro`, `sro-qa`, and `sro-dev` for the production, quality-assurance, and development stages respectively. 

The configuration is setup for 3 stateful postgresql databases. It has one master, and two slaves. It also uses `pgpool` to handle load balancing, read/write to correct master/slave instance, liminting requests, queueing and more.

# Setup
Install using the defaults for bitnami postgresql high availability chart as well as a psql client to connect to the database.
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install postgres bitnami/postgresql-ha -n sro
helm install postgres bitnami/postgresql-ha -n sro-qa
helm install postgres bitnami/postgresql-ha -n sro-dev
kubectl apply -f psql-client.yaml -n sro
kubectl apply -f psql-client.yaml -n sro-qa
kubectl apply -f psql-client.yaml -n sro-dev
```