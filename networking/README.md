# Networking
## Kubernetes
Kubernetes uses [istio](https://istio.io/) to route traffic. The configuration files can be found here. The network is split between 3 main namespaces: `sro`, `sro-qa`, `sro-dev` for the 3 main piplines production, quality assurance and development respectively. 

### Prereqesuites
* All global configurations is done.

### Installation
For AWS, configure the [Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller).

Next install istio with [istioctl](https://istio.io/latest/docs/setup/getting-started/)
```
istioctl install \
  --set profile=demo \
  --set values.gateways.istio-ingressgateway.type=NodePort \
  -f istio-operators.yaml
```

Setup istio injection for the 3 namespaces if it already isn't
```
kubectl label ns sro istio-injection=enabled --overwrite
kubectl label ns sro-qa istio-injection=enabled --overwrite
kubectl label ns sro-dev istio-injection=enabled --overwrite
```

Generate a certificate for self-signing certificates in the 3 environments.
```
pushd .
cd $(mktemp -d)
mkdir -p certs

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/key.pem -out certs/cert.pem -subj "/CN=shatteredrealmsonline.com" \
  -addext "subjectAltName=DNS:*.shatteredrealmsonline.com"

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/qa-key.pem -out certs/qa-cert.pem -subj "/CN=shatteredrealmsonline.com" \
  -addext "subjectAltName=DNS:*.shatteredrealmsonline.com"

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/dev-key.pem -out certs/dev-cert.pem -subj "/CN=shatteredrealmsonline.com" \
  -addext "subjectAltName=DNS:*.shatteredrealmsonline.com"

kubectl create -n sro secret generic istio-tls-secret \
  --from-file=key=certs/key.pem \
  --from-file=cert=certs/cert.pem

kubectl create -n sro-qa secret generic istio-qa-tls-secret \
  --from-file=key=certs/qa-key.pem \
  --from-file=cert=certs/qa-cert.pem

kubectl create -n sro-dev secret generic istio-dev-tls-secret \
  --from-file=key=certs/dev-key.pem \
  --from-file=cert=certs/dev-cert.pem

echo "You can delete folder $(pwd) to remove used certs"
popd 
```

Apply the gateway
```
kubectl apply -f gateway.yaml
```

Create 2 public AWS certificates. One for the wildcard base domain(s) (ex. `domain.tld` and `*.domain.tld`). Then create another for the `api.domain.tld` and `*.api.domain.tld`. Add these ARNs to the `alb-ingress.yaml`.

Apply the ALB ingress and reaplce `{{SRO_ARN}}` and `{{SRO_API_ARN}}` with the arns for the two certs just created.
```
cat alb-ingress.yaml | \
  sed \
    -e "s|{{SRO_ARN}}|$(aws acm list-certificates --output text --query 'CertificateSummaryList[?DomainName==`shatteredrealmsonline.com`].CertificateArn')|g" \
    -e "s|{{SRO_API_ARN}}|$(aws acm list-certificates --output text --query 'CertificateSummaryList[?DomainName==`api.shatteredrealmsonline.com`].CertificateArn')|g" | \
  kubectl apply -f -
```

Get the ingress loadbalanced endpoints and setup DNS 
```
echo Production Main Ingress: $(kubectl get ingress gw-main-ingress -n sro \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}") && \
echo Production API Ingress: $(kubectl get ingress gw-api-ingress -n sro \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}") && \
echo Quality-Assurance Main Ingress: $(kubectl get ingress gw-main-ingress -n sro-qa \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}") && \
echo Quality-Assurance API Ingress: $(kubectl get ingress gw-api-ingress -n sro-qa \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}") && \
echo Development Main Ingress: $(kubectl get ingress gw-main-ingress -n sro-dev \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}") && \
echo Development API Ingress: $(kubectl get ingress gw-api-ingress -n sro-dev \
-o jsonpath="{.status.loadBalancer.ingress[*].hostname}")
```

Create the Virtual Services
```
kubectl apply -f services/.
```