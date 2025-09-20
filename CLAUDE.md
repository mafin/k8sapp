# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
**Note:** Testing tools are only available in development containers with dev dependencies.

- **Run all tests:** `composer test` or `vendor/bin/phpunit`
- **Run API tests only:** `composer test:api`
- **Run unit tests only:** `composer test:unit`
- **Run specific test:** `vendor/bin/phpunit tests/Api/MessageTest.php`

### Code Quality
- **Static analysis:** `composer phpstan` or `vendor/bin/phpstan analyse`
- **Code style check:** `composer cs:check` or `vendor/bin/php-cs-fixer fix --dry-run --diff`
- **Code style fix:** `composer cs:fix` or `vendor/bin/php-cs-fixer fix`
- **Run all quality checks:** `composer quality` (runs cs:check, phpstan, and tests)

### Docker Development
- **Build and run (production):** `docker-compose up --build`
- **Build and run (development):** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build`
- **Access application:** http://localhost:8080
- **Access API documentation:** http://localhost:8080/api

### Running Development Tools in Container
**Note:** Use development container for tools with dev dependencies.

#### Using Makefile (recommended):
- **PHPStan:** `make phpstan`
- **Code style check:** `make cs-check`
- **Code style fix:** `make cs-fix`
- **Tests:** `make test`
- **All quality checks:** `make quality`
- **Build dev container:** `make build-dev`
- **Shell access:** `make shell`

#### Direct Docker Compose commands:
- **PHPStan:** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app composer phpstan`
- **Code style check:** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app composer cs:check`
- **Code style fix:** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app composer cs:fix`
- **Tests:** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app composer test`
- **All quality checks:** `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec app composer quality`

## Architecture Overview

This is a Symfony 7 application with API Platform for automatic REST API generation. The application follows a containerized, cloud-native approach designed for Kubernetes deployment.

### Key Components
- **Framework:** Symfony 7.3 with PHP 8.4
- **API Layer:** API Platform 4.2 - automatically generates JSON-LD REST API with OpenAPI documentation
- **Database:** SQLite (file-based) for simplicity
- **Container:** Multi-stage Docker build with PHP-FPM + Nginx managed by Supervisord
- **Extensions:** PDO, PDO SQLite, Intl for internationalization support
- **Deployment:** Kubernetes with ArgoCD GitOps workflow

### Domain Model
- **Message Entity** (`src/Entity/Message.php`): Main domain object with UUID primary key, title, body, and timestamps
- **API Resource**: Exposes GET collection endpoint with search filters (exact ID match, partial title search)
- **Repository**: Standard Doctrine repository pattern in `src/Repository/MessageRepository.php`

### Data Flow
1. API Platform automatically generates REST endpoints from Entity annotations
2. Doctrine ORM handles database persistence with SQLite
3. Serialization groups control API input/output (`message:read`, `message:write`)
4. Search filters enable API querying by ID and title

### Testing Strategy
- **API Tests**: Use ApiPlatform\Symfony\Bundle\Test\ApiTestCase for HTTP endpoint testing
- **Test Data**: Uses Doctrine Fixtures with Faker for realistic test data (100 messages)
- **Environment**: Separate test environment with isolated database

### Deployment Pipeline

GitHub Actions automaticky:
1. **CI/CD Tests:** Spustí kompletní test suite:
   - Database setup (create, migrate, fixtures)
   - Code style checks (`composer cs:check`)
   - Static analysis (`composer phpstan`)
   - API tests (`composer test`)
2. **Build & Push:** Buildí Docker image s multiple tagy:
   - `latest` (pro development)
   - `v1.${{ github.run_number }}` (pro production versioning)
   - `${{ github.sha }}` (pro commit tracking)
3. **Automatic Deployment Update:** Po úspěšném push do registry:
   - Automaticky aktualizuje `k8s/deployment.yaml` s novým image tagem
   - Commitne změnu zpět do Git repository s message `deploy: update to v1.XXX 🤖`
4. **ArgoCD Sync:** ArgoCD detekuje změnu v Git a nasadí novou verzi do Kubernetes

**Výhody tohoto přístupu:**
- ✅ **Eliminuje race condition** - ArgoCD vidí změnu až když je image v registry
- ✅ **Automatic deployment** bez manuálního zásahu
- ✅ **Jasná verze tracking** díky specific tagům
- ✅ **Snadné rozpoznání** deployment commitů (🤖 emoji)

### Configuration Notes
- Uses standard Symfony environment variables and `.env` files
- SQLite database file mounted as volume in Docker Compose for persistence
- Nginx serves static assets with proper MIME types, PHP-FPM handles dynamic requests
- Supervisor manages both processes in single container
- Error logging enabled for debugging in production environment

### Production Infrastructure
- **Kubernetes Deployment:** Hosted on DigitalOcean Kubernetes cluster
- **Domain:** `api.reefclip.com` (configured via DigitalOcean DNS)
- **Ingress Controller:** NGINX Ingress Controller for external traffic routing
- **Load Balancer:** DigitalOcean Load Balancer with external IP
- **SSL/TLS:** Automatic Let's Encrypt certificates via cert-manager
- **Certificate Management:** cert-manager with HTTP01 challenge solver
- **HTTPS Redirect:** Automatic HTTP to HTTPS redirection enabled

## Development Workflow

When making changes:
1. Run all quality checks: `composer quality` (or individual commands: `composer cs:check`, `composer phpstan`, `composer test`)
2. Fix code style if needed: `composer cs:fix`
3. Test locally with Docker: `docker-compose up --build`
4. Commit triggers CI/CD pipeline for automatic deployment

## Troubleshooting

### API Documentation not loading properly
If `/api` shows 500 errors or CSS/JS assets have wrong MIME types:
1. Clear production cache: `docker-compose exec app php bin/console cache:clear --env=prod`
2. Clear browser cache with hard refresh (Ctrl+Shift+R)
3. Try incognito/private browsing mode
4. Check that assets are installed: `docker-compose exec app ls -la /var/www/html/public/bundles/`

### Docker Build Issues
- If SQLite extensions fail to install, ensure `sqlite-dev` and `icu-dev` packages are installed before PHP extensions
- For MIME type issues, verify Nginx configuration includes proper `types` block

### Database Issues
- Database file permissions: `docker-compose exec app chown www-data:www-data /var/www/html/var/app.db`
- Run migrations: `docker-compose exec app php bin/console doctrine:migrations:migrate --env=prod --no-interaction`

### SSL/TLS Certificate Issues
Production API uses automatic Let's Encrypt certificates via cert-manager:

**Certificate status check:**
```bash
kubectl get certificate -n k8sapp
kubectl describe certificate api-reefclip-com-tls -n k8sapp
```

**Common issues:**
- **DNS not resolving:** Ensure `api.reefclip.com` points to correct load balancer IP
- **Certificate pending:** Let's Encrypt validation can take 1-5 minutes
- **HTTP challenge failed:** Verify ingress controller is running and accessible

**Manual certificate renewal:**
```bash
kubectl delete certificate api-reefclip-com-tls -n k8sapp
kubectl apply -f k8s/ingress.yaml  # Recreates certificate
```

**Test HTTPS:**
```bash
curl https://api.reefclip.com/api  # Should work with valid SSL
```