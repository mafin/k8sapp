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

## 5. ArgoCD GitOps (volitelné)

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
- Při změně Docker image v registry ArgoCD automaticky aktualizuje deployment
- Přístup přes ArgoCD UI pro monitoring

## 6. DNS konfigurace

### Získání externí IP
```bash
# Zjistěte IP adresu load balanceru
kubectl get ingress -n k8sapp

# Nebo alternativně
kubectl get service -n k8sapp --output wide
```

### Nastavení DNS
1. Přihlaste se k vašemu DNS poskytovateli
2. Vytvořte **A záznam**:
   - **Name:** `api.reefclip.com`
   - **Value:** `<IP_ADDRESS_FROM_INGRESS>`
   - **TTL:** 300 (5 minut)

### Ověření DNS
```bash
# Zkontrolujte DNS překlad
nslookup api.reefclip.com

# Nebo
dig api.reefclip.com
```

## 7. Testování aplikace

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

## 8. Řešení problémů

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

## 9. Údržba a aktualizace

### Ruční aktualizace image
```bash
# Nastavení nového image
kubectl set image deployment/k8sapp-deployment -n k8sapp \
  k8sapp=registry.digitalocean.com/mafin-dev/k8sapp:new-tag

# Sledování rollout
kubectl rollout status deployment/k8sapp-deployment -n k8sapp
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

## 10. Kompletní deployment script

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