# Database
The dedicated database is given to each stage: `sro`, `sro-qa`, and `sro-dev` for the production, quality-assurance, and development stages respectively. 

The configuration is setup for 3 stateful postgresql databases. It has one master, and two slaves. It also uses `pgpool` to handle load balancing, read/write to correct master/slave instance, liminting requests, queueing and more.

# Setup
## Postgres
Install using the defaults for bitnami postgresql high availability chart as well as a psql client to connect to the database.
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install postgres bitnami/postgresql-ha -n observability -f files/postgres-observability-values.yaml
helm install postgres bitnami/postgresql-ha -n auth -f files/postgres-auth-values.yaml
helm install postgres bitnami/postgresql-ha -n sro -f files/postgres-sro-values.yaml
helm install postgres bitnami/postgresql-ha -n sro-qa -f files/postgres-sro-qa-values.yaml
kubectl apply -f psql-client.yaml -n observability
kubectl apply -f psql-client.yaml -n auth 
kubectl apply -f psql-client.yaml -n sro
kubectl apply -f psql-client.yaml -n sro-qa
```

When upgrading
```
helm upgrade --install postgres bitnami/postgresql-ha -n observability -f files/postgres-observability-values.yaml \
  --set postgresql.password=$(kubectl get secret -n observability postgres-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d) \
  --set postgresql.repmgrPassword=$(kubectl get secret -n observability postgres-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d) \
  --set pgpool.adminPassword=$(kubectl get secret -n observability postgres-postgresql-ha-pgpool -o jsonpath="{.data.admin-password}" | base64 -d)
helm upgrade --install postgres bitnami/postgresql-ha -n auth -f files/postgres-auth-values.yaml \
  --set postgresql.password=$(kubectl get secret -n auth postgres-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d) \
  --set postgresql.repmgrPassword=$(kubectl get secret -n auth postgres-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d) \
  --set pgpool.adminPassword=$(kubectl get secret -n auth postgres-postgresql-ha-pgpool -o jsonpath="{.data.admin-password}" | base64 -d)
helm upgrade --install postgres bitnami/postgresql-ha -n sro -f files/postgres-sro-values.yaml \
  --set postgresql.password=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d) \
  --set postgresql.repmgrPassword=$(kubectl get secret -n sro postgres-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d) \
  --set pgpool.adminPassword=$(kubectl get secret -n sro postgres-postgresql-ha-pgpool -o jsonpath="{.data.admin-password}" | base64 -d)
helm upgrade --install postgres bitnami/postgresql-ha -n sro-qa -f files/postgres-sro-qa-values.yaml  \
  --set postgresql.password=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d) \
  --set postgresql.repmgrPassword=$(kubectl get secret -n sro-qa postgres-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d) \
  --set pgpool.adminPassword=$(kubectl get secret -n sro-qa postgres-postgresql-ha-pgpool -o jsonpath="{.data.admin-password}" | base64 -d)
```

## MongoDB
Install with helm
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install mongodb bitnami/mongodb -n sro --set persistence.storageClass=nvme-hostpath
helm install mongodb bitnami/mongodb -n sro-qa
```

Get root password
```
MONGODB_PROD_ROOT_PASSWORD=$(kubectl get secret -n sro mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)
MONGODB_QA_ROOT_PASSWORD=$(kubectl get secret -n sro-qa mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)
```

## Kafka
Create namespace
```
kubectl create namespace kafka
```

Setup strimzi and wait for ready
```
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
kubectl get pod -n kafka --watch
```

Setup kafka cluster and wait for ready
```
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-persistent-single.yaml -n kafka
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka
```

## Redis
Install with helm
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install redis bitnami/redis-cluster -n sro -f files/redis-sro-values.yaml
```

When updating use the following command
```bash
helm upgrade --install redis bitnami/redis-cluster -n sro -f files/redis-sro-values.yaml \
  --set password=$(kubectl get secret -n sro redis-redis-cluster -o jsonpath="{.data.redis-password}" | base64 -d)
```

Testing can be done by creating a temporary client
```bash
kubectl run --namespace sro redis-redis-cluster-client --rm --tty -i --restart='Never' \
  --env REDIS_PASSWORD=$(kubectl get secret -n sro redis-redis-cluster -o jsonpath="{.data.redis-password}" | base64 -d) \
  --image docker.io/bitnami/redis-cluster:7.2.4-debian-12-r11 -- bash
```

And connecting with the command
```bash
redis-cli -c -h redis-redis-cluster -a $REDIS_PASSWORD
```

