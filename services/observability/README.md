## Prometheus
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus -n observability -f files/prometheus-values.yaml
```

## OpenTelemetry
Deploy with helm
```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector -n observability -f files/otel-collector-ds-values.yaml
helm upgrade --install otel-collector-cluster open-telemetry/opentelemetry-collector -n observability -f files/otel-collector-deploy-values.yaml
```

## Grafan, Loki & Promtail, Tempo
Setup AWS S3 secrets
```bash
kubectl create secret generic loki-s3-secrets -n observability \
  --from-literal grafana-loki-s3-endpoint="s3.us-east-1.amazonaws.com" \
  --from-literal grafana-loki-s3-accessKeyId="" \
  --from-literal grafana-loki-s3-secretAccessKey=""
kubectl create secret generic tempo-s3-secrets -n observability \
  --from-literal tempo-s3-endpoint="s3.us-east-1.amazonaws.com" \
  --from-literal tempo-s3-accessKeyId="" \
  --from-literal tempo-s3-secretAccessKey=""
```

Install with helm
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install grafana grafana/grafana -n observability -f files/grafana-values.yaml
helm upgrade --install loki grafana/loki -n observability -f files/loki-values.yaml
helm upgrade --install tempo grafana/tempo-distributed -n observability -f files/tempo-values.yaml
helm upgrade --install promtail grafana/promtail -n observability -f files/loki-values.yaml
```

## Kiali
Setup the operator is it's own namespace and the CR in the observability namespace
```bash
helm repo add kiali https://kiali.org/helm-charts
helm repo update
helm upgrade --install -n kiali-operator --create-namespace \
  kiali-operator kiali/kiali-operator \
  -f files/kiali-values.yaml
```
