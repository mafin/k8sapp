# Kubernetes Deployment Guide

Tento návod popisuje kompletní postup nasazení aplikace do Kubernetes clusteru na DigitalOcean.

## Předpoklady

- ✅ DigitalOcean Kubernetes cluster
- ✅ `kubectl` nainstalovaný lokálně
- ✅ `doctl` CLI nainstalovaný a nakonfigurovaný
- ✅ Docker image v DigitalOcean Container Registry
- ✅ DigitalOcean Personal Access Token s právy pro registry

## 1. Připojení k Kubernetes clusteru

### Stažení kubeconfig
```bash
# Získejte kubeconfig pro váš DigitalOcean cluster
doctl kubernetes cluster kubeconfig save <your-cluster-name>

# Ověřte připojení
kubectl get nodes
```

### Ověření kontextu
```bash
# Zobrazit aktuální kontext
kubectl config current-context

# Zobrazit všechny dostupné kontexty
kubectl config get-contexts
```

## 2. Příprava namespace a secrets

### Vytvoření namespace
```bash
# Vytvořte namespace pro aplikaci
kubectl create namespace k8sapp

# Ověřte vytvoření
kubectl get namespaces
```

### Vytvoření registry secret
```bash
# Vytvořte secret pro přístup k DigitalOcean Container Registry
kubectl create secret docker-registry digitalocean-registry \
  --docker-server=registry.digitalocean.com \
  --docker-username=<YOUR_DO_TOKEN> \
  --docker-password=<YOUR_DO_TOKEN> \
  --namespace=k8sapp

# Ověřte vytvoření secretu
kubectl get secrets -n k8sapp
```

**Poznámka:** `<YOUR_DO_TOKEN>` nahraďte vaším DigitalOcean Personal Access Token.

## 3. Nasazení aplikace

### Aplikace manifestů jednotlivě
```bash
# 1. Namespace (pokud už neexistuje z kroku 2)
kubectl apply -f k8s/namespace.yaml

# 2. Deployment (hlavní aplikace)
kubectl apply -f k8s/deployment.yaml

# 3. Service (interní networking)
kubectl apply -f k8s/service.yaml

# 4. Ingress (externí přístup)
kubectl apply -f k8s/ingress.yaml
```

### Aplikace všech manifestů najednou
```bash
# Aplikuje všechny YAML soubory z k8s/ adresáře
kubectl apply -f k8s/
```

## 4. Ověření deploymentu

### Kontrola stavu podů
```bash
# Zobrazit všechny pody v namespace
kubectl get pods -n k8sapp

# Sledovat pody v reálném čase
kubectl get pods -n k8sapp -w

# Podrobné informace o podu
kubectl describe pod <pod-name> -n k8sapp
```

### Kontrola služeb
```bash
# Zobrazit služby
kubectl get services -n k8sapp

# Zobrazit endpointy
kubectl get endpoints -n k8sapp
```

### Kontrola ingress
```bash
# Zobrazit ingress a externí IP
kubectl get ingress -n k8sapp

# Podrobné informace o ingress
kubectl describe ingress -n k8sapp
```

### Logy aplikace
```bash
# Zobrazit logy deployment
kubectl logs -n k8sapp deployment/k8sapp-deployment

# Sledovat logy v reálném čase
kubectl logs -n k8sapp deployment/k8sapp-deployment -f

# Logy konkrétního podu
kubectl logs -n k8sapp <pod-name>
```

## 5. Instalace NGINX Ingress Controller

### Důležité: Ingress Controller pro DigitalOcean
Pro funkčnost Ingress (externí přístup k aplikaci) musíte nainstalovat NGINX Ingress Controller:

```bash
# Instalace NGINX Ingress Controller pro DigitalOcean
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/do/deploy.yaml

# Čekání na ready stav
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Získání External IP (může trvat několik minut)
kubectl get service ingress-nginx-controller -n ingress-nginx
```

### Aktualizace Ingress manifestu
Ujistěte se, že váš `k8s/ingress.yaml` obsahuje správnou IngressClass:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8sapp-ingress
  namespace: k8sapp
spec:
  ingressClassName: nginx  # Důležité!
  rules:
    - host: api.reefclip.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: k8sapp-service
                port:
                  number: 80
```

### Aplikace aktualizovaného Ingress
```bash
kubectl apply -f k8s/ingress.yaml
```

## 6. SSL/TLS Certificate Setup (doporučeno)

### Instalace cert-manager
Pro automatické SSL certifikáty z Let's Encrypt nainstalujte cert-manager:

```bash
# Instalace cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Čekání na ready stav
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=120s

# Ověření instalace
kubectl get pods -n cert-manager
```

### Způsoby challenge - HTTP-01 vs DNS-01

#### Option A: HTTP-01 Challenge (základní)
Vytvořte `k8s/letsencrypt-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### Option B: DNS-01 Challenge (doporučeno pro production)
**Výhody:** Spolehlivější, funguje za firewallem, podporuje wildcard certifikáty

1. **Vytvořte DigitalOcean API token:**
   - **DigitalOcean Dashboard** → **API** → **Personal Access Tokens**
   - **Generate New Token** s **Write** scope
   - **Zkopírujte token**

2. **Vytvořte secret:**
```bash
kubectl create secret generic digitalocean-dns \
  --from-literal=access-token=YOUR_DO_API_TOKEN \
  -n cert-manager
```

3. **Vytvořte `k8s/letsencrypt-dns.yaml`:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-dns
    solvers:
    - dns01:
        digitalocean:
          tokenSecretRef:
            name: digitalocean-dns
            key: access-token
```

### Aplikace ClusterIssuer
```bash
# Pro HTTP-01 challenge
kubectl apply -f k8s/letsencrypt-issuer.yaml

# NEBO pro DNS-01 challenge (doporučeno)
kubectl apply -f k8s/letsencrypt-dns.yaml

# Ověřte stav
kubectl get clusterissuer
```

### Aktualizace Ingress pro SSL
Upravte `k8s/ingress.yaml` pro podporu SSL:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8sapp-ingress
  namespace: k8sapp
  annotations:
    # Použijte název vašeho ClusterIssuer
    cert-manager.io/cluster-issuer: "letsencrypt-dns"  # nebo "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.reefclip.com
    secretName: api-reefclip-com-tls
  rules:
    - host: api.reefclip.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: k8sapp-service
                port:
                  number: 80
```

```bash
# Aplikujte aktualizovaný ingress
kubectl apply -f k8s/ingress.yaml
```

### Ověření SSL certifikátu
```bash
# Zkontrolujte stav certifikátu
kubectl get certificate -n k8sapp
kubectl describe certificate api-reefclip-com-tls -n k8sapp

# Zkontrolujte challenge průběh
kubectl get challenge -n k8sapp
kubectl describe challenge <challenge-name> -n k8sapp

# Ověřte typ certifikátu (production vs staging)
kubectl get secret api-reefclip-com-tls -n k8sapp -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep Issuer

# Test HTTPS připojení
curl https://api.reefclip.com/api
curl -k https://api.reefclip.com/api  # Ignoruje SSL chyby pro test
```

### Troubleshooting SSL problémů

#### Challenge stuck v "pending" stavu
```bash
# Pro HTTP-01 challenge
# - Zkontrolujte dostupnost /.well-known/acme-challenge/ endpoint
curl http://api.reefclip.com/.well-known/acme-challenge/test

# Pro DNS-01 challenge
# - Čekejte 2-10 minut na DNS propagaci
# - Zkontrolujte DigitalOcean API token permissions
```

#### "EOF" chyby u HTTP-01 challenge
- **Řešení:** Přepněte na DNS-01 challenge (spolehlivější)
- HTTP-01 může selhat kvůli síťovým problémům nebo firewallu

#### Staging certifikát místo production
```bash
# Zkontrolujte Issuer v certifikátu
kubectl get secret api-reefclip-com-tls -n k8sapp -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep Issuer

# Mělo by být: "Issuer: C=US, O=Let's Encrypt, CN=R13"
# NE: "Issuer: C=US, O=(STAGING) Let's Encrypt"

# Oprava: Ujistěte se, že ClusterIssuer používá production server
# server: https://acme-v02.api.letsencrypt.org/directory
```

#### Force obnova certifikátu
```bash
kubectl delete certificate api-reefclip-com-tls -n k8sapp
kubectl delete secret api-reefclip-com-tls -n k8sapp
# Certifikát se automaticky znovu vytvoří
```

**Poznámky:**
- **HTTP-01:** Certifikát se vystaví za 1-5 minut
- **DNS-01:** Certifikát se vystaví za 2-10 minut (kvůli DNS propagaci)
- **Auto-renewal:** Certifikáty se automaticky obnovují 30 dní před expirací

## 7. ArgoCD GitOps (volitelné)

### Instalace ArgoCD (pokud není nainstalovaný)
```bash
# 1. Vytvoření ArgoCD namespace
kubectl create namespace argocd

# 2. Instalace ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Čekání na ready pody
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# 4. Ověření instalace
kubectl get pods -n argocd
```

### Přístup k ArgoCD UI
```bash
# Port-forward pro přístup k UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Získání admin hesla
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Přístup: https://localhost:8080
# Login: admin / <heslo-z-předchozího-příkazu>
```

### Nasazení ArgoCD aplikace
```bash
# Aplikuje ArgoCD manifest pro automatické nasazení
kubectl apply -f k8s/argocd-application.yaml

# Ověřte ArgoCD aplikaci (pokud máte ArgoCD CLI)
argocd app list
argocd app sync k8sapp
```

### Alternativa bez ArgoCD
Pokud nechcete ArgoCD, použijte přímé nasazení:
```bash
# Nasazení bez ArgoCD (vynechá argocd-application.yaml)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

### Sledování ArgoCD
- ArgoCD automaticky sleduje změny v Git repository
- Při změně Docker image tagu v deployment.yaml ArgoCD automaticky aktualizuje deployment
- Přístup přes ArgoCD UI pro monitoring

**Automatický deployment proces:**
1. **GitHub Actions CI/CD** → spustí testy a buildí Docker image
2. **Registry push** → image je pushnut do DigitalOcean Container Registry
3. **Automatická aktualizace** → GitHub Actions aktualizuje `k8s/deployment.yaml` s novým tagem
4. **Git commit** → změna je commitnuta zpět do repository s message `deploy: update to v1.XXX 🤖`
5. **ArgoCD sync** → detekuje změnu a nasadí novou verzi

**Výhody tohoto přístupu:**
- ✅ Eliminuje race condition - ArgoCD vidí změnu až když je image v registry
- ✅ Automatický deployment bez manuálního zásahu
- ✅ Jasná version tracking díky specific tagům

## 8. DNS konfigurace

### Získání externí IP
```bash
# Zjistěte IP adresu z ingress controller load balanceru
kubectl get service ingress-nginx-controller -n ingress-nginx

# Ověřte ingress status
kubectl get ingress -n k8sapp
```

### Nastavení DNS v DigitalOcean
Pokud používáte DigitalOcean DNS:

1. **DigitalOcean Dashboard** → **Networking** → **Domains**
2. **Klikněte na vaši doménu** (např. `reefclip.com`)
3. **Najděte A záznam pro** `api` nebo **přidejte nový záznam**:
   - **Type:** `A`
   - **Hostname:** `api`
   - **Value:** `<EXTERNAL_IP_FROM_INGRESS_CONTROLLER>`
   - **TTL:** `300` (5 minut)
4. **Save**

### Alternativně - jiný DNS poskytovatel
1. Přihlaste se k vašemu DNS poskytovateli
2. Vytvořte **A záznam**:
   - **Name:** `api.reefclip.com`
   - **Value:** `<EXTERNAL_IP_FROM_INGRESS_CONTROLLER>`
   - **TTL:** 300 (5 minut)

### Ověření DNS
```bash
# Zkontrolujte DNS překlad
nslookup api.reefclip.com

# Nebo
dig api.reefclip.com
```

## 9. Testování aplikace

### Lokální test přes port-forward
```bash
# Přesměrování portu na lokální počítač
kubectl port-forward -n k8sapp service/k8sapp-service 8080:80

# Testování API
curl http://localhost:8080/api/messages
curl http://localhost:8080/api
```

### Test přes externí URL
```bash
# Po konfiguraci DNS
curl https://api.reefclip.com/api/messages
curl https://api.reefclip.com/api

# Test v prohlížeči
# https://api.reefclip.com/api
```

## 10. Řešení problémů

### Časté problémy a řešení

#### Pod se nespouští
```bash
# Zkontrolujte events
kubectl get events -n k8sapp --sort-by='.lastTimestamp'

# Podrobnosti o podu
kubectl describe pod <pod-name> -n k8sapp
```

#### Image pull errors
```bash
# Ověřte registry secret
kubectl get secret digitalocean-registry -n k8sapp -o yaml

# Zkontrolujte, zda je secret správně připojen k deployment
kubectl describe deployment k8sapp-deployment -n k8sapp
```

#### Ingress nefunguje
```bash
# Zkontrolujte ingress controller
kubectl get pods -n ingress-nginx

# Ověřte ingress konfiguraci
kubectl describe ingress -n k8sapp
```

#### ArgoCD version tracking problémy
```bash
# Problém: ArgoCD ukazuje "Synced" ale neznáte jaká verze je nasazená

# 1. Zjistěte aktuální image tag v deploymentu
kubectl get deployment k8sapp-deployment -n k8sapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# Výstup: registry.digitalocean.com/mafin-dev/k8sapp:v1.123

# 2. Porovnejte s nejnovějším GitHub Actions run
# GitHub Actions vytváří tagy ve formátu: v1.${{ github.run_number }}
# Run number 123 = v1.123 tag

# 3. Zkontrolujte Git commit hash v ArgoCD
kubectl describe application k8sapp -n argocd | grep -E "(Revision|Target)"

# 4. Force refresh ArgoCD pokud je potřeba
kubectl patch application k8sapp -n argocd --type merge --patch='{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```

### Užitečné příkazy pro debugging
```bash
# Připojení do běžícího kontejneru
kubectl exec -it -n k8sapp <pod-name> -- sh

# Kopírování souborů z/do podu
kubectl cp -n k8sapp <pod-name>:/path/to/file ./local-file

# Restart deployment
kubectl rollout restart deployment/k8sapp-deployment -n k8sapp

# Historie rollout
kubectl rollout history deployment/k8sapp-deployment -n k8sapp
```

## 11. Údržba a aktualizace

### Ruční aktualizace image
```bash
# Nastavení nového image (použijte specific tag z GitHub Actions)
kubectl set image deployment/k8sapp-deployment -n k8sapp \
  k8sapp=registry.digitalocean.com/mafin-dev/k8sapp:v1.123

# Sledování rollout
kubectl rollout status deployment/k8sapp-deployment -n k8sapp

# Alternativně - editace deployment YAML
kubectl edit deployment k8sapp-deployment -n k8sapp
# Změňte image tag a uložte
```

### Škálování
```bash
# Změna počtu replik
kubectl scale deployment k8sapp-deployment --replicas=3 -n k8sapp

# Ověření škálování
kubectl get pods -n k8sapp
```

### Čištění
```bash
# Smazání celé aplikace
kubectl delete -f k8s/

# Nebo smazání namespace (smaže vše)
kubectl delete namespace k8sapp
```

## 12. Kompletní deployment script

```bash
#!/bin/bash

# Nastavte proměnné
CLUSTER_NAME="your-cluster-name"
DO_TOKEN="your-do-token"

echo "🚀 Starting Kubernetes deployment..."

# 1. Připojení ke clusteru
echo "📡 Connecting to cluster..."
doctl kubernetes cluster kubeconfig save $CLUSTER_NAME

# 2. Vytvoření namespace
echo "📦 Creating namespace..."
kubectl create namespace k8sapp --dry-run=client -o yaml | kubectl apply -f -

# 3. Vytvoření registry secret
echo "🔐 Creating registry secret..."
kubectl create secret docker-registry digitalocean-registry \
  --docker-server=registry.digitalocean.com \
  --docker-username=$DO_TOKEN \
  --docker-password=$DO_TOKEN \
  --namespace=k8sapp \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Aplikace manifestů
echo "🚢 Deploying application..."
kubectl apply -f k8s/

# 5. Čekání na ready pody
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=k8sapp -n k8sapp --timeout=300s

# 6. Zobrazení stavu
echo "✅ Deployment complete!"
kubectl get pods,services,ingress -n k8sapp

# 7. Zobrazení URL
echo "🌐 Application should be available at:"
kubectl get ingress -n k8sapp -o jsonpath='{.items[0].spec.rules[0].host}'
echo ""
```

Uložte jako `deploy.sh`, nastavte executable (`chmod +x deploy.sh`) a spusťte `./deploy.sh`.

## Dokumentace

- [DigitalOcean Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
- [kubectl dokumentace](https://kubernetes.io/docs/reference/kubectl/)
- [ArgoCD dokumentace](https://argo-cd.readthedocs.io/)