# Configuración de Ejemplo para Demo Pipeline

## GitHub Secrets - Plantilla

```bash
# Copiar y configurar estos secrets en tu repositorio GitHub
# Settings > Secrets and variables > Actions > New repository secret

# === AWS Configuration ===
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secret...
AWS_ACCESS_KEY_ID_PROD=AKIA...
AWS_SECRET_ACCESS_KEY_PROD=secret...

# === SonarQube (Opcional para demo) ===
SONAR_TOKEN=sqp_...
SONAR_HOST_URL=https://sonarcloud.io

# === Testing URLs ===
STAGING_URL=https://vod-staging.example.com
TEST_API_KEY=test_api_key_123
PROD_API_KEY=prod_api_key_456

# === Performance Testing ===
K6_CLOUD_TOKEN=k6_token_123

# === Notifications ===
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
MONITORING_WEBHOOK_URL=https://monitoring.example.com/webhook

# === Kubernetes (Base64 encoded kubeconfig) ===
KUBE_CONFIG_DATA=LS0tLS1CRUdJTi...
```

## GitHub Environments - Configuración

### 1. Development Environment
```yaml
Name: development
Protection Rules: None
Secrets: Inherit from repository
Variables:
  - REPLICAS: 1
  - RESOURCES_CPU: 100m
  - RESOURCES_MEMORY: 256Mi
```

### 2. Staging Environment
```yaml
Name: staging
Protection Rules: None
Secrets: Inherit from repository
Variables:
  - REPLICAS: 3
  - RESOURCES_CPU: 500m
  - RESOURCES_MEMORY: 1Gi
```

### 3. Production Environment
```yaml
Name: production
Protection Rules: 
  - Required reviewers: 1
  - Restrict pushes to protected branches
URL: https://vod.company.com
Secrets: Use production-specific secrets
Variables:
  - REPLICAS: 10
  - RESOURCES_CPU: 1000m
  - RESOURCES_MEMORY: 2Gi
```

## Estructura de Archivos Demo

```bash
proyecto/
├── .github/
│   └── workflows/
│       └── deploy-vod-platform.yml    # Pipeline principal
├── terraform/                         # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── environments/
│       ├── staging.tfvars
│       └── production.tfvars
├── helm/                              # Kubernetes manifests
│   └── vod-platform/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-development.yaml
│       ├── values-staging.yaml
│       └── values-production.yaml
├── src/                               # Código fuente (demo)
├── tests/                             # Tests
│   ├── unit/
│   ├── integration/
│   ├── e2e/
│   └── performance/
├── docs/                              # Documentación
└── README-Pipeline.md                 # Esta documentación
```

## Comandos de Demo

### Simular Push a Development:
```bash
git checkout -b develop
echo "Demo change" >> demo.txt
git add demo.txt
git commit -m "demo: trigger development deployment"
git push origin develop
```

### Simular Push a Production:
```bash
git checkout main
git merge develop
git push origin main
```

### Trigger Manual:
1. Ve a GitHub Actions
2. Selecciona "VOD Platform CI/CD Pipeline (Demo)"
3. Click "Run workflow"
4. Selecciona:
   - Environment: staging/production
   - Action: plan/apply/destroy

## Monitoreo del Pipeline

### GitHub Actions UI:
- Ve a tu repositorio
- Click en "Actions"
- Observa los workflows en ejecución

### Logs Detallados:
```bash
# Ver logs en tiempo real (si tienes GitHub CLI)
gh run list
gh run view <run-id> --log
```

### Notificaciones Slack:
```json
{
  "channel": "#deployments",
  "message": "🚀 VOD Platform deployment successful!",
  "fields": {
    "Branch": "main",
    "Commit": "abc123",
    "Environment": "production"
  }
}
```

## Troubleshooting Demo

### Errores Comunes:

1. **Secrets faltantes:**
   ```
   Error: Context access might be invalid: AWS_ACCESS_KEY_ID
   Solución: Configurar secrets en GitHub
   ```

2. **Environments no configurados:**
   ```
   Error: Value 'production' is not valid
   Solución: Crear environments en GitHub Settings
   ```

3. **Permisos AWS:**
   ```
   Error: AccessDenied
   Solución: Verificar IAM roles y policies
   ```

## Personalización para tu Demo

### Cambiar nombres:
```yaml
# En deploy-vod-platform.yml
env:
  ECR_REPOSITORY: tu-app-name
  EKS_CLUSTER_NAME: tu-cluster-name
```

### Simplificar para demo:
- Comentar jobs de security scanning
- Reducir tests a mínimos
- Usar repositorios públicos
- Mock de servicios externos

### Agregar visualización:
- Badges en README
- Dashboards de métricas
- Logs centralizados
- Screenshots de deployments

---

**💡 Tip:** Para una demo efectiva, ejecuta el pipeline paso a paso explicando cada stage y mostrando los resultados en tiempo real.
