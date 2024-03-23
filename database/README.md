# Database
The dedicated database is given to each stage: `sro`, `sro-qa`, and `sro-dev` for the production, quality-assurance, and development stages respectively. 

The configuration is setup for 3 stateful postgresql databases. It has one master, and two slaves. It also uses `pgpool` to handle load balancing, read/write to correct master/slave instance, liminting requests, queueing and more.

# Setup

## Postgres
Install using the defaults for bitnami postgresql high availability chart as well as a psql client to connect to the database.
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install postgres bitnami/postgresql-ha -n sro --set persistence.storageClass=nvme-hostpath
helm install postgres bitnami/postgresql-ha -n sro-qa
kubectl apply -f psql-client.yaml -n sro
kubectl apply -f psql-client.yaml -n sro-qa
```

## ClickHouse
Install clickhouse operator
```
kubectl apply -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml
```

Create password
```
PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
PASSWORD_SHA256=$(echo -n "$PASSWORD" | sha256sum | tr -d ' -')
kubectl delete secret clickhouse-credentials -n sro
cat clickhouse-credentials.yaml | \
  sed "s/{{PASSWORD}}/$PASSWORD/g" | \
  kubectl apply -n sro -f -
PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
PASSWORD_SHA256=$(echo -n "$PASSWORD" | sha256sum | tr -d ' -')
kubectl delete secret clickhouse-credentials -n sro-qa
cat clickhouse-credentials.yaml | \
  sed "s/{{PASSWORD}}/$PASSWORD/g" | \
  kubectl apply -n sro-qa -f -
```

Deploy server with PVC
```
kubectl apply -f clickhouse.yaml -n sro
kubectl apply -f clickhouse.yaml -n sro-qa
```

You can test the connections like
```
clickhouse-client \
  -h $(kubectl get svc -n sro clickhouse-pv-log -o jsonpath={.status.loadBalancer.ingress[0].ip}) \
  -u admin \
  --password $(kubectl get secret clickhouse-credentials -n sro -o jsonpath={.data.password} | base64 -d)
```

Get the passwords
```
echo "Prod: $(kubectl get secret clickhouse-credentials -n sro -o jsonpath={.data.password} | base64 -d)"; \
echo "Qa: $(kubectl get secret clickhouse-credentials -n sro-qa -o jsonpath={.data.password} | base64 -d)"
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
