# Plataforma VOD (Video On Demand) - Proyecto DevOps

## Descripción General

Esta plataforma VOD es un proyecto integral que demuestra la implementación completa de una solución de video bajo demanda utilizando tecnologías modernas de DevOps, containerización y orquestación en la nube.

El proyecto incluye una infraestructura completa desplegada en AWS con Kubernetes (EKS), pipelines de CI/CD automatizados, y mejores prácticas de seguridad y monitoreo.

## Características Principales

### Arquitectura de la Plataforma
- **Streaming de Video**: Entrega de contenido multimedia optimizada
- **Gestión de Usuarios**: Sistema de autenticación y autorización
- **Catálogo de Contenido**: Base de datos de videos con metadata
- **Transcoding**: Procesamiento automático de videos en múltiples calidades
- **CDN Integration**: Distribución global de contenido
- **Analytics**: Métricas de visualización y engagement

### Infraestructura Cloud-Native
- **AWS EKS**: Cluster Kubernetes gestionado para alta disponibilidad
- **RDS MySQL**: Base de datos relacional para metadata y usuarios
- **S3**: Almacenamiento de videos y assets estáticos
- **CloudFront**: CDN para distribución global
- **ElastiCache**: Cache en memoria para mejor rendimiento
- **Auto Scaling**: Escalado automático basado en demanda

## Arquitectura del Sistema

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudFront    │    │  Application     │    │   Database      │
│      (CDN)      │◄──►│  Load Balancer   │◄──►│   RDS MySQL     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   S3 Buckets    │    │   EKS Cluster    │    │  ElastiCache    │
│  (Video Store)  │    │ (Kubernetes Pods)│    │    (Redis)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Tecnologías Utilizadas

### Backend y Servicios
- **Node.js / Express**: API REST principal
- **FFmpeg**: Procesamiento y transcoding de video
- **Redis**: Cache y sesiones de usuario
- **MySQL**: Base de datos principal
- **JWT**: Autenticación y autorización

### DevOps y Infraestructura
- **Docker**: Containerización de aplicaciones
- **Kubernetes**: Orquestación de contenedores
- **Terraform**: Infrastructure as Code (IaC)
- **GitHub Actions**: CI/CD Pipeline
- **AWS**: Proveedor de servicios cloud
- **Helm**: Gestión de paquetes Kubernetes

### Monitoreo y Observabilidad
- **Prometheus**: Recolección de métricas
- **Grafana**: Visualización y dashboards
- **CloudWatch**: Logs y monitoreo AWS
- **Jaeger**: Distributed tracing

## Estructura del Proyecto

```
m6-Vod/
├── .github/
│   └── workflows/
│       ├── deploy-vod-platform.yml    # Pipeline principal CI/CD
│       ├── demo-presentation.yml       # Pipeline demo académico
│       └── demo-simplified.yml         # Pipeline simplificado
├── terraform/
│   ├── main.tf                        # Infraestructura principal
│   ├── providers.tf                   # Configuración de proveedores
│   ├── variables.tf                   # Variables de entrada
│   ├── outputs.tf                     # Salidas del deployment
│   ├── vpc.tf                         # Configuración de red
│   ├── eks.tf                         # Cluster Kubernetes
│   ├── rds.tf                         # Base de datos
│   ├── storage.tf                     # S3 y almacenamiento
│   ├── security.tf                    # Security Groups y IAM
│   ├── kms.tf                         # Cifrado y llaves
│   ├── monitoring.tf                  # CloudWatch y logging
│   └── environments/
│       ├── development.tfvars         # Variables de desarrollo
│       ├── staging.tfvars             # Variables de staging
│       └── production.tfvars          # Variables de producción
├── docs/
│   ├── INFORME-DEMO.md               # Documentación académica
│   ├── README-Pipeline.md            # Documentación del pipeline
│   ├── DEMO-CONFIG.md                # Configuración de demo
│   ├── ArquitecturaKUbe.md           # Arquitectura Kubernetes
│   └── Networking.md                 # Configuración de red
└── README.md                         # Este archivo
```

## Quick Start

### Prerrequisitos

1. **Herramientas requeridas:**
   ```bash
   # AWS CLI
   aws --version
   
   # Terraform
   terraform --version
   
   # kubectl
   kubectl version --client
   
   # Docker
   docker --version
   ```

2. **Credenciales AWS:**
   ```bash
   aws configure
   # AWS Access Key ID: [Tu Access Key]
   # AWS Secret Access Key: [Tu Secret Key]
   # Default region name: us-east-1
   ```

### Despliegue de Infraestructura

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/ignazer/m6-Vod.git
   cd m6-Vod
   ```

2. **Configurar Terraform:**
   ```bash
   cd terraform
   terraform init
   ```

3. **Planificar el despliegue:**
   ```bash
   terraform plan -var-file="environments/development.tfvars"
   ```

4. **Aplicar la infraestructura:**
   ```bash
   terraform apply -var-file="environments/development.tfvars"
   ```

### Pipeline CI/CD

1. **Configurar GitHub Secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `SONAR_TOKEN` (opcional)
   - `SLACK_WEBHOOK_URL` (opcional)

2. **Ejecutar el pipeline:**
   - Push a `develop` → Deploy automático a Development
   - Push a `main` → Deploy automático a Staging
   - Deploy manual a Production con aprobación

## Ambientes

### Development
- **Propósito**: Desarrollo y testing inicial
- **Recursos**: Mínimos (1 replica, t3.small)
- **Base de datos**: db.t3.micro
- **Costo estimado**: ~$50/mes

### Staging
- **Propósito**: Testing pre-producción
- **Recursos**: Medios (3 replicas, t3.medium)
- **Base de datos**: db.t3.small
- **Costo estimado**: ~$120/mes

### Production
- **Propósito**: Ambiente de producción
- **Recursos**: Completos (10+ replicas, t3.large)
- **Base de datos**: db.t3.medium Multi-AZ
- **Costo estimado**: ~$400/mes

## Funcionalidades de la Plataforma VOD

### Para Usuarios Finales
- **Registro y Login**: Sistema de cuentas de usuario
- **Catálogo de Videos**: Exploración y búsqueda de contenido
- **Streaming Adaptativo**: Calidad ajustada automáticamente
- **Favoritos y Listas**: Personalización de contenido
- **Historial de Visualización**: Seguimiento de progreso
- **Múltiples Dispositivos**: Web, móvil, smart TV

### Para Administradores
- **Gestión de Contenido**: Subida y organización de videos
- **Analytics Avanzados**: Métricas de uso y engagement
- **Gestión de Usuarios**: Administración de cuentas
- **Configuración de Calidad**: Perfiles de transcoding
- **Monitoreo del Sistema**: Dashboards en tiempo real

## Seguridad

### Implementaciones de Seguridad
- **Cifrado en Tránsito**: TLS 1.3 para todas las comunicaciones
- **Cifrado en Reposo**: KMS para RDS, S3 y EBS
- **Network Security**: Security Groups y NACLs restrictivos
- **Identity Management**: IAM roles con principio de menor privilegio
- **Container Security**: Scanning de vulnerabilidades con Trivy
- **Secret Management**: AWS Secrets Manager
- **WAF**: Protección contra ataques web comunes

### Compliance
- **GDPR**: Protección de datos personales
- **COPPA**: Protección de menores
- **PCI DSS**: Seguridad en pagos (si aplica)
- **SOC 2**: Controles de seguridad organizacional

## Monitoreo y Observabilidad

### Métricas Clave
- **Application Performance**: Tiempo de respuesta, throughput
- **Infrastructure Health**: CPU, memoria, disco, red
- **Business Metrics**: Usuarios activos, tiempo de visualización
- **Error Rates**: 4xx/5xx responses, failed requests
- **Security Events**: Intentos de acceso, anomalías

### Dashboards Disponibles
- **Infrastructure Overview**: Estado general del sistema
- **Application Performance**: Métricas de la aplicación
- **User Experience**: Métricas de usuario final
- **Security Dashboard**: Eventos de seguridad
- **Cost Management**: Optimización de costos

## Performance y Escalabilidad

### Optimizaciones Implementadas
- **CDN Global**: CloudFront para reducir latencia
- **Caching Strategy**: Redis para datos frecuentes
- **Database Optimization**: Índices y query optimization
- **Auto Scaling**: Escalado automático basado en métricas
- **Load Balancing**: Distribución inteligente de carga

### Capacidad del Sistema
- **Usuarios Concurrentes**: 10,000+ (con auto-scaling)
- **Streaming Concurrent**: 5,000+ streams simultáneos
- **Storage Capacity**: Ilimitado (S3)
- **Bandwidth**: Auto-escalable según demanda
- **Availability**: 99.9% uptime SLA

## Desarrollo y Contribución

### Configuración del Entorno de Desarrollo
```bash
# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env

# Ejecutar en modo desarrollo
npm run dev

# Ejecutar tests
npm test

# Build para producción
npm run build
```

### Guías de Contribución
1. Fork del repositorio
2. Crear rama feature: `git checkout -b feature/nueva-funcionalidad`
3. Commits descriptivos siguiendo conventional commits
4. Tests para nueva funcionalidad
5. Pull request con descripción detallada

## Troubleshooting

### Problemas Comunes

**Pipeline Fails en GitHub Actions:**
```bash
# Verificar secrets configurados
# Revisar logs en Actions tab
# Validar permisos AWS
```

**Terraform Errors:**
```bash
# Verificar credenciales AWS
terraform refresh
terraform plan

# Estado corrupto
terraform import [resource] [id]
```

**EKS Connection Issues:**
```bash
# Actualizar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name vod-platform-dev

# Verificar conectividad
kubectl get nodes
```

## Documentación Adicional

- [Pipeline CI/CD](./README-Pipeline.md) - Documentación detallada del pipeline
- [Infraestructura Terraform](./terraform/README.md) - Guía de infraestructura
- [Demo Académico](./INFORME-DEMO.md) - Documentación para presentaciones
- [Arquitectura Kubernetes](./ArquitecturaKUbe.md) - Detalles de K8s
- [Configuración de Red](./Networking.md) - Setup de networking

## Roadmap

### Próximas Funcionalidades
- **Machine Learning**: Recomendaciones personalizadas
- **Live Streaming**: Transmisión en vivo
- **Mobile Apps**: Aplicaciones nativas iOS/Android
- **Multi-tenancy**: Soporte para múltiples organizaciones
- **Advanced Analytics**: BI y reporting avanzado
- **Global Expansion**: Deployment multi-región

### Mejoras Técnicas
- **Service Mesh**: Implementación de Istio
- **GitOps**: Migración a ArgoCD
- **Chaos Engineering**: Pruebas de resiliencia
- **Performance Optimization**: Micro-optimizaciones
- **Cost Optimization**: Análisis y reducción de costos

## Soporte y Contacto

### Recursos de Ayuda
- **Documentación**: [Wiki del proyecto](./docs/)
- **Issues**: [GitHub Issues](https://github.com/ignazer/m6-Vod/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ignazer/m6-Vod/discussions)

### Información del Proyecto
- **Autor**: [ignazer](https://github.com/ignazer)
- **Licencia**: MIT License
- **Versión**: 1.0.0
- **Estado**: En desarrollo activo

---

**Nota**: Este proyecto fue desarrollado con fines educativos y de demostración. Para uso en producción real, se requieren adaptaciones adicionales de seguridad, compliance y optimización según los requisitos específicos del negocio.

**Adalid Bootcamp DevOps**
Modulo 6
