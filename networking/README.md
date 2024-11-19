# Networking
## Kubernetes
Kubernetes uses [istio](https://istio.io/) to route traffic. The configuration files can be found here. The network is split between 2 main namespaces: `sro` and `sro-qa`. 

### Prereqesuites
* All global configurations is done.

### Installation
For AWS, configure the [Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller).

Next install istio with [istioctl](https://istio.io/latest/docs/setup/getting-started/)

#### Setup Istio
##### AWS Only
```bash
istioctl install \
  --set profile=minimal \
  --set values.gateways.istio-ingressgateway.type=NodePort \
  -f istio-operators.yaml
```

##### Microk8s Only
```bash
istioctl install \
  --set profile=minimal \
  -f istio-operators.yaml
```

##### All
Generate a certificate for self-signing certificates.
```bash
pushd .
cd $(mktemp -d)
mkdir -p certs

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/key.pem -out certs/cert.pem -subj "/CN=shatteredrealmsonline.com" \
  -addext "subjectAltName=DNS:*.shatteredrealmsonline.com"
openssl x509 -req -sha256 -days 365 -CA certs/sro.crt -CAkey certs/sro.key -set_serial 1 -in certs/cert.pem -out certs/sro.com.crt

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout certs/qa-key.pem -out certs/qa-cert.pem -subj "/CN=shatteredrealmsonline.com" \
  -addext "subjectAltName=DNS:*.shatteredrealmsonline.com"

kubectl create -n sro secret generic istio-tls-secret \
  --from-file=key=certs/key.pem \
  --from-file=cert=certs/cert.pem

kubectl create -n sro-qa secret generic istio-qa-tls-secret \
  --from-file=key=certs/qa-key.pem \
  --from-file=cert=certs/qa-cert.pem

echo "You can delete folder $(pwd) to remove used certs"
popd 
```

#### Apply the gateway
##### AWS 
```bash
kubectl apply -f aws-gateway.yaml
```

Create 2 public AWS certificates. One for the wildcard base domain(s) (ex. `domain.tld` and `*.domain.tld`). Then create another for the `api.domain.tld` and `*.api.domain.tld`. Add these ARNs to the `alb-ingress.yaml`.

Apply the ALB ingress and reaplce `{{SRO_ARN}}` and `{{SRO_API_ARN}}` with the arns for the two certs just created.
```bash
cat alb-ingress.yaml | \
  sed \
    -e "s|{{SRO_ARN}}|$(aws acm list-certificates --output text --query 'CertificateSummaryList[?DomainName==`shatteredrealmsonline.com`].CertificateArn')|g" \
    -e "s|{{SRO_API_ARN}}|$(aws acm list-certificates --output text --query 'CertificateSummaryList[?DomainName==`api.shatteredrealmsonline.com`].CertificateArn')|g" | \
  kubectl apply -f -
```

Get the ingress loadbalanced endpoints and setup DNS. The load balancer is a hostname
```bash
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


##### Microk8s
```bash
kubectl apply -f microk8s-gateway.yaml
kubectl apply -f microk8s-clusterissuer.yaml
kubectl apply -f microk8s-certs.yaml
```

##### All
Create the Virtual Services
```bash
kubectl apply -f services/.
```
