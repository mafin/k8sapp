# k8sapp - Message API

Jednoduchá API aplikace postavená na Symfony 7, určená pro správu zpráv. Aplikace je od začátku navržena pro běh v kontejnerovém prostředí a nasazení do Kubernetes pomocí GitOps přístupu s ArgoCD.

## Architektura

- **Backend:** Symfony 7.3 s PHP 8.4
- **API:** RESTful API ve formátu JSON-LD, automaticky generované pomocí [API Platform](https://api-platform.com/).
- **Dokumentace API:** OpenAPI (Swagger UI) specifikace je automaticky generována a dostupná na endpointu `/api`.
- **Databáze:** Lokální souborová databáze SQLite.
- **Kontejnerizace:** Docker - vícestupňový `Dockerfile` využívající PHP-FPM a Nginx. Procesy jsou spravovány pomocí Supervisord.
- **PHP rozšíření:** PDO, PDO SQLite, Intl pro internacionalizaci.
- **CI/CD:** GitHub Actions workflow, které zajišťuje:
    1.  Kontrolu kvality kódu (PHP CS Fixer, PHPStan).
    2.  Spuštění automatizovaných testů (PHPUnit).
    3.  Sestavení Docker image.
    4.  Nahrání image do DigitalOcean Container Registry.
- **Deployment (GitOps):**
    - **Orchestrace:** Kubernetes (připraveno pro DigitalOcean Kubernetes).
    - **Správa nasazení:** ArgoCD, které sleduje Git repozitář a automaticky synchronizuje stav v Kubernetes clusteru.

---

## Požadavky

- Git
- Docker & Docker Compose
- `kubectl` pro komunikaci s Kubernetes clusterem
- Přístup do Kubernetes clusteru (např. DigitalOcean)
- Přístup do ArgoCD instance
- DigitalOcean účet s vytvořenou Container Registry a Personal Access Tokenem (PAT)

---

## Lokální vývoj

Pro spuštění aplikace v lokálním prostředí postupujte následovně:

1.  **Klonování repozitáře:**
    ```bash
    git clone https://github.com/mafin/k8sapp.git
    cd k8sapp
    ```

2.  **Instalace závislostí:**
    Composer závislosti se nainstalují automaticky při sestavování Docker image.

3.  **Spuštění kontejnerů:**
    ```bash
    docker-compose up --build
    ```
    Tento příkaz sestaví Docker image a spustí kontejner.

4.  **Přístup k aplikaci:**
    - **Web:** `http://localhost:8080`
    - **API:** `http://localhost:8080/api`

---

## Nasazení do produkce (CI/CD & GitOps)

1.  **GitHub Repozitář:**
    Ujistěte se, že je veškerý kód nahrán do vašeho Git repozitáře `github.com/mafin/k8sapp`.

2.  **Nastavení GitHub Secrets:**
    V nastavení vašeho GitHub repozitáře (`Settings -> Secrets and variables -> Actions`) vytvořte **secret** s názvem `DO_PAT` a vložte do něj váš DigitalOcean Personal Access Token s právy pro čtení a zápis do Container Registry.

3.  **Vytvoření Kubernetes Secret:**
    Přihlaste se ke svému Kubernetes clusteru a vytvořte namespace a secret pro přístup k DigitalOcean registry. Tento secret umožní Kubernetes stahovat váš privátní Docker image.
    ```bash
    # Vytvoření namespace
    kubectl create namespace k8sapp

    # Vytvoření secretu
    kubectl create secret docker-registry digitalocean-registry \
      --docker-server=registry.digitalocean.com \
      --docker-username=VÁŠ_DO_TOKEN \
      --docker-password=VÁŠ_DO_TOKEN \
      --namespace=k8sapp
    ```

4.  **Nastavení DNS:**
    Nasměrujte DNS `A` záznam pro doménu `api.reefclip.com` na IP adresu vašeho Kubernetes Load Balanceru.

5.  **Nasazení přes ArgoCD:**
    Vytvořte v ArgoCD novou aplikaci pomocí manifestu `k8s/argocd-application.yaml`. Můžete to udělat přes UI nebo pomocí CLI:
    ```bash
    argocd app create -f k8s/argocd-application.yaml
    ```
    ArgoCD automaticky provede první synchronizaci a nasadí aplikaci do clusteru. Od této chvíle bude každá změna v `main` větvi vašeho repozitáře automaticky nasazena.

---

## Nástroje pro kvalitu kódu a testování

### Composer skripty (doporučeno)
- **Všechny testy:** `composer test`
- **API testy:** `composer test:api`
- **Unit testy:** `composer test:unit`
- **Statická analýza:** `composer phpstan`
- **Kontrola stylu kódu:** `composer cs:check`
- **Oprava stylu kódu:** `composer cs:fix`
- **Všechny kontroly najednou:** `composer quality`

### Přímé spuštění nástrojů
- **PHPUnit (testy):**
  ```bash
  vendor/bin/phpunit
  ```

- **PHPStan (statická analýza):**
  ```bash
  vendor/bin/phpstan analyse
  ```

- **PHP CS Fixer (kontrola a oprava stylu kódu):**
  ```bash
  # Pouze kontrola
  vendor/bin/php-cs-fixer fix --dry-run --diff

  # Automatická oprava
  vendor/bin/php-cs-fixer fix
  ```

---

## Řešení problémů

### API dokumentace se nenačítá správně
Pokud endpoint `/api` zobrazuje chybu 500 nebo CSS/JS soubory mají špatné MIME typy:

1. **Vyčistit cache aplikace:**
   ```bash
   docker-compose exec app php bin/console cache:clear --env=prod
   ```

2. **Vyčistit cache prohlížeče:**
   - Použijte hard refresh (Ctrl+Shift+R)
   - Zkuste anonymní/privátní režim prohlížeče

3. **Ověřit instalaci assets:**
   ```bash
   docker-compose exec app ls -la /var/www/html/public/bundles/
   ```

### Problémy s databází
- **Oprava práv databázového souboru:**
  ```bash
  docker-compose exec app chown www-data:www-data /var/www/html/var/app.db
  ```

- **Spuštění migrací:**
  ```bash
  docker-compose exec app php bin/console doctrine:migrations:migrate --env=prod --no-interaction
  ```