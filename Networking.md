# Arquitectura de Redes y Seguridad en la Nube - Plataforma VOD

## Diseño de Virtual Private Cloud (VPC)

### Arquitectura de Red Multi-Capa

**Configuración VPC Principal:**
```yaml
VPC: vpc-vod-production
CIDR: 10.0.0.0/16  # Proporciona 65,536 direcciones IP disponibles
Region: us-east-1   # Región principal con mayor disponibilidad de servicios
DNS Resolution: Habilitado     # Permite resolución de nombres internos
DNS Hostnames: Habilitado      # Necesario para servicios administrados como RDS
```

> **Justificación del CIDR:** El bloque 10.0.0.0/16 permite suficiente espacio para crecimiento futuro y segmentación granular sin conflictos con redes corporativas típicas que usan 192.168.x.x.

### Segmentación de Subredes por Capas de Seguridad

#### Capa DMZ (Zona Desmilitarizada) - Subredes Públicas
```
Subnet-Public-1a: 10.0.100.0/24 (us-east-1a) → Load Balancers, NAT Gateway
Subnet-Public-1b: 10.0.101.0/24 (us-east-1b) → Load Balancers, NAT Gateway  
Subnet-Public-1c: 10.0.102.0/24 (us-east-1c) → Load Balancers, NAT Gateway
```
**Propósito:** Contiene únicamente recursos que necesitan acceso directo desde internet (Load Balancers) y servicios de conectividad saliente (NAT Gateways).

#### Capa de Aplicación - Subredes Privadas
```
Subnet-App-1a: 10.0.10.0/24 (us-east-1a) → Servicios web, APIs, Kubernetes workers
Subnet-App-1b: 10.0.11.0/24 (us-east-1b) → Servicios web, APIs, Kubernetes workers
Subnet-App-1c: 10.0.12.0/24 (us-east-1c) → Servicios web, APIs, Kubernetes workers
```
**Propósito:** Aloja la lógica de negocio y servicios de aplicación. No tiene acceso directo a internet, solo a través de NAT Gateways para actualizaciones.

#### Capa de Datos - Subredes Privadas Aisladas
```
Subnet-Data-1a: 10.0.20.0/24 (us-east-1a) → RDS, ElastiCache, Storage nodes
Subnet-Data-1b: 10.0.21.0/24 (us-east-1b) → RDS, ElastiCache, Storage nodes
Subnet-Data-2c: 10.0.22.0/24 (us-east-1c) → RDS, ElastiCache, Storage nodes
```
**Propósito:** Máximo aislamiento para datos críticos. Solo accesible desde la capa de aplicación a través de puertos específicos.

### Network ACLs (Access Control Lists) por Capa

#### ACL para Capa DMZ
```yaml
# Reglas de entrada (Inbound)
Rule 100: HTTP (80) desde 0.0.0.0/0 - ALLOW          # Tráfico web público
Rule 110: HTTPS (443) desde 0.0.0.0/0 - ALLOW        # Tráfico web seguro
Rule 120: Ephemeral ports (1024-65535) desde 10.0.0.0/16 - ALLOW  # Respuestas de conexiones internas
Rule 32767: ALL Traffic - DENY                        # Denegar todo lo demás (regla por defecto)

# Reglas de salida (Outbound)
Rule 100: HTTP (80) a 0.0.0.0/0 - ALLOW             # Para descargas y actualizaciones
Rule 110: HTTPS (443) a 0.0.0.0/0 - ALLOW           # Conexiones seguras salientes
Rule 120: All ports a 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW  # Hacia capa de aplicación
Rule 32767: ALL Traffic - DENY
```

#### ACL para Capa de Aplicación
```yaml
# Reglas de entrada (Inbound)
Rule 100: HTTPS (443) desde 10.0.100.0/24,10.0.101.0/24,10.0.102.0/24 - ALLOW  # Solo desde DMZ
Rule 110: SSH (22) desde 10.0.100.0/24 - ALLOW       # Acceso administrativo limitado
Rule 120: Kubernetes API (6443) desde 10.0.0.0/16 - ALLOW  # Comunicación del cluster
Rule 130: Ephemeral ports desde 10.0.0.0/16 - ALLOW  # Respuestas de conexiones internas
Rule 32767: ALL Traffic - DENY

# Reglas de salida (Outbound)
Rule 100: HTTPS (443) a 0.0.0.0/0 - ALLOW           # APIs externas y descargas
Rule 110: Database ports (3306,5432,6379) a 10.0.20.0/24,10.0.21.0/24,10.0.22.0/24 - ALLOW  # Hacia datos
Rule 120: All ports a 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW  # Comunicación entre servicios
Rule 32767: ALL Traffic - DENY
```

#### ACL para Capa de Datos
```yaml
# Reglas de entrada (Inbound)
Rule 100: MySQL (3306) desde 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW    # Solo desde aplicación
Rule 110: PostgreSQL (5432) desde 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW
Rule 120: Redis (6379) desde 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW
Rule 32767: ALL Traffic - DENY                       # Máximo aislamiento

# Reglas de salida (Outbound)
Rule 100: Ephemeral ports a 10.0.10.0/24,10.0.11.0/24,10.0.12.0/24 - ALLOW  # Respuestas a aplicación
Rule 32767: ALL Traffic - DENY                       # Sin conectividad externa
```

**Principios de Diseño Aplicados:**
- **Segmentación por funciones:** Separación clara entre capas de responsabilidad
- **Principio de menor privilegio:** Solo el tráfico necesario está permitido
- **Defensa en profundidad:** ACLs + Security Groups proporcionan doble capa de filtrado
- **Disponibilidad multi-AZ:** Distribución en 3 zonas de disponibilidad para resiliencia

## Implementación de CDN para Distribución Global

### CloudFront como CDN Principal

#### Configuración de Distribución Multi-Origin
```yaml
CloudFront Distribution: d1234567890abc.cloudfront.net

# Origins configurados
Origin-1 (S3-Static):
  Domain: vod-static-content.s3.amazonaws.com
  Path: /assets
  Access: Origin Access Identity (OAI)          # Acceso directo solo desde CloudFront

Origin-2 (ALB-Dynamic):
  Domain: api-vod-production.us-east-1.elb.amazonaws.com
  Path: /
  Protocol: HTTPS Only                          # Forzar conexiones seguras
  Headers: Host, User-Agent, Accept-Encoding    # Headers forwardeados al origin
```

#### Comportamientos de Cache Optimizados
```yaml
Cache Behaviors:
  # Videos - Cache agresivo por popularidad
  Pattern: /videos/*
    TTL: 86400s (24 horas)
    Compression: Habilitado
    Query String: Ninguna                       # Videos no cambian por parámetros
    Headers: None
  
  # Thumbnails - Cache largo
  Pattern: /thumbnails/*
    TTL: 604800s (7 días)
    Compression: Habilitado
    Vary: Accept-Encoding                       # Optimizar por tipo de navegador
  
  # API - Sin cache para datos dinámicos
  Pattern: /api/*
    TTL: 0s (sin cache)
    Query String: Todas                         # Pasar todos los parámetros
    Headers: Authorization, Content-Type        # Headers críticos para APIs
  
  # Assets estáticos - Cache máximo
  Pattern: /static/*
    TTL: 2592000s (30 días)
    Compression: Habilitado
    Immutable: true                             # Contenido versionado que no cambia
```

#### Edge Locations Estratégicas por Región

**Distribución Global Optimizada:**
```yaml
Americas:
  North America:
    - us-east-1 (N. Virginia) - Primary
    - us-west-2 (Oregon) - Secondary
    - ca-central-1 (Toronto) - Canada coverage
  Latin America:
    - sa-east-1 (São Paulo) - Brazil hub
    - Edge: Mexico City, Buenos Aires

Europe:
  Western Europe:
    - eu-west-1 (Frankfurt) - Primary hub
    - eu-west-2 (London) - UK coverage
    - eu-west-3 (Paris) - France coverage
  Eastern Europe:
    - eu-central-1 (Frankfurt) - Regional hub
    - Edge: Amsterdam, Milan, Stockholm

Asia-Pacific:
  East Asia:
    - ap-northeast-1 (Tokyo) - Japan hub
    - ap-southeast-1 (Singapore) - Southeast hub
  South Asia:
    - ap-south-1 (Mumbai) - India hub
  Oceania:
    - ap-southeast-2 (Sydney) - Australia hub
```

### Configuraciones Avanzadas de Performance

```yaml
HTTP/2 y HTTP/3: Habilitado                    # Protocolo moderno para mejor performance
Gzip Compression: 
  - text/html, text/css, application/javascript
  - application/json, application/xml
  - Ratio promedio: 70% reducción en tamaño

Origin Shield:
  Region: us-east-1                             # Capa adicional de cache entre edge y origin
  Benefit: Reduce carga en origin hasta 80%    # Especialmente útil para contenido popular

Real-time Logs:
  Destination: Amazon Kinesis Data Streams      # Para análisis en tiempo real
  Fields: timestamp, c-ip, sc-status, cs-uri   # Métricas clave para optimización
```

### Estrategia Multi-CDN para Máxima Disponibilidad

```yaml
CDN Primary: Amazon CloudFront
  Coverage: Global, 400+ edge locations
  Integration: Native con servicios AWS
  Cost: Optimizado para tráfico desde AWS

CDN Secondary: Azure CDN (Failover)
  Coverage: Regiones específicas donde CloudFront tiene latencia alta
  Use Case: Europa del Este, África, ciertas regiones de Asia
  Activation: Route 53 health checks automáticos

Failover Logic:
  Health Check Interval: 30 segundos
  Failure Threshold: 3 consecutive failures
  Recovery: Automatic failback cuando primary esté saludable
```

**Justificación Técnica del CDN:**
- **Reducción de latencia:** Contenido servido desde edge locations cercanas al usuario
- **Optimización de ancho de banda:** Cache reduce la carga en servidores origin hasta 90%
- **Mejora de disponibilidad:** Múltiples POPs evitan puntos únicos de falla
- **Protección DDoS:** AWS Shield Advanced integrado proporciona protección automática

## Estrategias de Seguridad Integral

### Conectividad Segura (VPN/IPSec)

#### Site-to-Site VPN para Oficinas Corporativas
```yaml
AWS VPN Gateway Configuration:
  Type: Virtual Private Gateway (VGW)
  ASN: 65000                                    # Amazon side ASN
  Attachment: vpc-vod-production
  
Customer Gateway:
  IP Address: 203.0.113.12                      # IP pública de oficina corporativa
  Type: Static routing                          # Para conexiones simples
  BGP ASN: 65001                               # Customer side ASN

IPSec Tunnels:
  Tunnel 1:
    Customer Gateway IP: 203.0.113.12
    Virtual Private Gateway IP: 52.95.255.1
    Pre-shared Key: [Administrado por AWS]
    Encryption: AES-256                         # Cifrado fuerte
    Authentication: SHA-256                     # Hash seguro
    
  Tunnel 2:                                     # Redundancia automática
    Customer Gateway IP: 203.0.113.12
    Virtual Private Gateway IP: 52.95.255.2
    [Mismas configuraciones de seguridad]

Routing:
  Static Routes: 192.168.1.0/24 → Customer     # Red corporativa
  Propagation: Habilitado                       # Distribución automática de rutas
```

#### Client VPN para Acceso Remoto de Empleados
```yaml
AWS Client VPN Endpoint:
  Associated Subnets: 
    - subnet-app-1a (10.0.10.0/24)            # Acceso a recursos de aplicación
  
Authentication:
  Type: Federated (Active Directory)           # Integración con AD corporativo
  Multi-Factor Authentication: Habilitado      # Segundo factor obligatorio
  Certificate: AWS Certificate Manager         # Certificados administrados

Network Configuration:
  Client CIDR: 172.16.0.0/22                  # Red separada para clientes VPN
  Split Tunneling: Habilitado                 # Solo tráfico corporativo por VPN
  DNS Servers: 10.0.0.2, 8.8.8.8             # DNS interno + público

Connection Logging:
  CloudWatch Logs: vpn-client-connections     # Log de todas las conexiones
  Metrics: Conexiones activas, bytes transferidos
  Alerts: Intentos de conexión fallidos
```

### Control de Acceso IAM (Identity and Access Management)

#### Estrategia de Roles y Políticas por Función

**Roles para Desarrolladores:**
```yaml
Developer-Role:
  Trust Policy: 
    - AWS SSO Users en grupo "Developers"
    - MFA Required: true                        # Factor adicional obligatorio
  
  Attached Policies:
    - EKSReadOnlyAccess:
        Resources: cluster/vod-*
        Actions: 
          - eks:DescribeCluster
          - eks:ListClusters
          - kubectl get/describe pods/services    # Solo lectura en Kubernetes
    
    - S3DeveloperAccess:
        Resources: arn:aws:s3:::vod-dev-*/*     # Solo buckets de desarrollo
        Actions:
          - s3:GetObject
          - s3:PutObject
          - s3:DeleteObject                     # CRUD en buckets dev
    
    - CloudWatchLogsRead:
        Resources: log-group:/aws/eks/vod-*
        Actions:
          - logs:DescribeLogGroups
          - logs:GetLogEvents                   # Acceso a logs para debugging
```

**Roles para DevOps Engineers:**
```yaml
DevOps-Role:
  Trust Policy:
    - AWS SSO Users en grupo "DevOps"
    - Session Duration: 4 hours                # Sesiones más largas para tareas complejas
  
  Attached Policies:
    - EKSFullAccess:
        Resources: cluster/vod-*
        Actions: eks:*                          # Control total del cluster
    
    - InfrastructureDeployment:
        Resources: "*"
        Actions:
          - cloudformation:*                    # Despliegue de infraestructura
          - ec2:*                              # Gestión de instancias
          - iam:PassRole                       # Necesario para crear recursos
        Conditions:
          StringEquals:
            aws:RequestedRegion: [us-east-1, us-west-2]  # Limitado a regiones específicas
    
    - SecretsManagerAccess:
        Resources: arn:aws:secretsmanager:*:*:secret:vod/*
        Actions:
          - secretsmanager:GetSecretValue
          - secretsmanager:UpdateSecret         # Gestión de secretos de aplicación
```

**Roles para Content Managers:**
```yaml
ContentManager-Role:
  Trust Policy:
    - AWS SSO Users en grupo "Content"
  
  Attached Policies:
    - S3ContentManagement:
        Resources: 
          - arn:aws:s3:::vod-content-*/*
        Actions:
          - s3:GetObject
          - s3:PutObject
          - s3:DeleteObject
          - s3:ListBucket                       # Gestión completa de contenido
        Conditions:
          StringLike:
            s3:prefix: ["videos/", "thumbnails/"] # Solo carpetas específicas
    
    - CloudFrontInvalidation:
        Resources: arn:aws:cloudfront::*:distribution/*
        Actions:
          - cloudfront:CreateInvalidation       # Limpiar cache cuando sea necesario
    
    - TranscodingJobs:
        Resources: arn:aws:elastictranscoder:*:*:*
        Actions:
          - elastictranscoder:CreateJob         # Iniciar trabajos de codificación
          - elastictranscoder:ReadJob           # Monitorear progreso
```

#### Políticas de Seguridad Corporativas

```yaml
Organización AWS:
  SCP (Service Control Policies):
    - DenyRootAccess: Prohibir uso de cuenta root excepto para tareas específicas
    - RequireMFA: Obligar MFA para todas las acciones sensibles
    - RegionRestriction: Limitar operaciones a regiones aprobadas
    - CostControl: Limitar tipos de instancias costosas sin aprobación

Políticas de Password:
  MinLength: 14 caracteres
  Complexity: Mayúsculas, minúsculas, números, símbolos
  History: Recordar últimas 12 contraseñas
  Expiration: 90 días para usuarios regulares, 60 días para privilegiados
  
Rotación de Credenciales:
  Access Keys: Rotación obligatoria cada 90 días
  Service Accounts: Rotación automática cada 30 días
  Database Passwords: Rotación automática semanal
```

### Gestión de Secretos

#### AWS Secrets Manager Integration

```yaml
Secretos Críticos Administrados:
  Database Credentials:
    Secret Name: vod/database/master
    Auto-rotation: Cada 30 días
    Engine: mysql
    Encryption: aws/secretsmanager KMS key      # Clave dedicada para secretos
    
  API Keys Externos:
    Secret Name: vod/external-apis
    Structure:
      stripe_api_key: sk_live_xxxx
      sendgrid_api_key: SG.xxxx
      analytics_token: xxxx
    Encryption: Customer managed KMS key
    
  JWT Signing Keys:
    Secret Name: vod/jwt-keys
    Auto-rotation: Cada 24 horas              # Rotación frecuente para seguridad
    Structure:
      current_key: [RSA Private Key]
      previous_key: [RSA Private Key]         # Para validar tokens emitidos antes de rotación
```

#### Integración con Kubernetes

```yaml
# External Secrets Operator - Sincroniza secretos de AWS a Kubernetes
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: vod-production
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:                                    # Usa IRSA (IAM Roles for Service Accounts)
          serviceAccountRef:
            name: external-secrets-sa

---
# Sincronización automática de secretos de base de datos
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h                           # Verificar cambios cada hora
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-credentials                        # Nombre del secret en Kubernetes
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: vod/database/master
      property: username
  - secretKey: password
    remoteRef:
      key: vod/database/master
      property: password
```

#### CSI Secret Store Driver (Alternativa para Casos Específicos)
```yaml
# Para casos donde se necesitan secretos como archivos en el filesystem
apiVersion: v1
kind: SecretProviderClass
metadata:
  name: app-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "vod/jwt-keys"
        objectType: "secretsmanager"
        objectVersionStage: "AWSCURRENT"      # Usar siempre la versión actual
        jmesPath:
          - path: "current_key"
            objectAlias: "jwt-current.key"    # Archivo disponible en /mnt/secrets/
          - path: "previous_key"
            objectAlias: "jwt-previous.key"
```

### Cifrado de Datos

#### Cifrado en Tránsito

**Configuraciones de TLS:**
```yaml
Load Balancer (ALB):
  SSL Policy: ELBSecurityPolicy-TLS-1-2-2019-07  # TLS 1.2 mínimo
  Certificates: AWS Certificate Manager
  SSL Termination: ALB level                     # Descarga trabajo de instancias

Kubernetes Ingress:
  TLS Version: 1.3                              # Protocolo más reciente
  Cipher Suites: 
    - TLS_AES_128_GCM_SHA256
    - TLS_AES_256_GCM_SHA384                   # Solo cifrados fuertes
    - TLS_CHACHA20_POLY1305_SHA256

Service Mesh (Istio):
  mTLS Mode: STRICT                             # Comunicación cifrada obligatoria entre pods
  Certificate Management: Automatic             # Rotación automática cada 24h
  Root CA: Istio self-signed                   # CA dedicada para el mesh
```

**Database Connections:**
```yaml
RDS MySQL:
  SSL Mode: REQUIRED                            # Conexiones no cifradas rechazadas
  SSL CA: rds-ca-2019                          # Certificado raíz de AWS RDS
  Cipher: AES256-SHA256                        # Cifrado fuerte

ElastiCache Redis:
  Transit Encryption: Enabled
  Auth Token: Rotated weekly                   # Token adicional para autenticación
  TLS Version: 1.2
```

#### Cifrado en Reposo

**Servicios con Cifrado Habilitado:**
```yaml
Amazon S3:
  Default Encryption: SSE-KMS                  # Server-Side Encryption con KMS
  KMS Key: Customer Managed                    # Control total sobre la clave
  Key ID: arn:aws:kms:us-east-1:123456789:key/12345678-1234-1234-1234-123456789012
  Bucket Policies: Deny unencrypted uploads   # Forzar cifrado en todas las subidas

Amazon RDS:
  Encryption: Enabled at rest                  # Cifrado de la instancia completa
  KMS Key: Customer Managed
  Performance Impact: <5%                      # Overhead mínimo
  Backups: Automatically encrypted             # Snapshots también cifrados

Amazon EBS:
  Default Encryption: Account-level enabled    # Todos los volúmenes cifrados por defecto
  Key: Customer Managed per application
  Snapshot Encryption: Inherited               # Snapshots mantienen cifrado

ElastiCache:
  Encryption at Rest: Enabled
  Encryption in Transit: Enabled
  KMS Integration: Customer managed keys
```

#### AWS KMS (Key Management Service) - Jerarquía de Claves

```yaml
Root Keys (Customer Managed):
  vod-master-key:
    Description: "Master key for VOD platform"
    Usage: Encrypt other keys and critical data
    Rotation: Annual (automatic)
    Policy: Restricted to admin roles only

Application-Specific Keys:
  vod-database-key:
    Description: "Database encryption key"
    Usage: RDS instances, ElastiCache
    Rotation: Every 6 months
    
  vod-storage-key:
    Description: "Storage encryption key"
    Usage: S3 buckets, EBS volumes
    Rotation: Annual
    
  vod-secrets-key:
    Description: "Secrets Manager encryption key"
    Usage: Application secrets, API keys
    Rotation: Quarterly

Key Policies:
  Principle of Least Privilege: Solo roles necesarios pueden usar cada clave
  Logging: Todas las operaciones loggeadas en CloudTrail
  Cross-Region: Keys replicadas en región de backup
  Deletion Protection: Waiting period de 30 días para eliminación
```

### Monitoreo y Detección de Amenazas

#### AWS GuardDuty - Detección de Amenazas con IA

```yaml
GuardDuty Configuration:
  Threat Intelligence: Habilitado              # Feeds de inteligencia de amenazas
  Malware Detection: Habilitado                # Escaneo de archivos en S3
  DNS Logging: Habilitado                      # Análisis de consultas DNS
  
Finding Types Monitored:
  - Cryptocurrency mining                       # Detección de miners
  - Command & Control communication            # Comunicación con botnets
  - Unusual API activity                       # Patrones anómalos de acceso
  - Compromised instances                      # Instancias potencialmente comprometidas
  
Integration:
  EventBridge: Envío automático de alertas     # Para respuesta automatizada
  Lambda Functions: Respuesta automática       # Aislar instancias comprometidas
  SNS Notifications: Alertas a equipo SOC      # Notificación humana para casos críticos
```

#### AWS Security Hub - Centralización de Alertas

```yaml
Security Standards:
  - AWS Foundational Security Standard         # Mejores prácticas básicas
  - PCI DSS                                   # Para procesamiento de pagos
  - CIS AWS Foundations Benchmark             # Estándar de la industria
  
Automated Remediation:
  Non-compliant S3 buckets: Auto-enable encryption
  Overly permissive Security Groups: Auto-restrict
  Unused IAM users: Flag for review
  
Dashboard Integration:
  Custom insights para métricas específicas de VOD
  Trending de vulnerabilidades por tiempo
  Compliance score tracking
```

#### Logging Centralizado de Seguridad

```yaml
VPC Flow Logs:
  Capture: ALL (Accept + Reject)               # Análisis completo de tráfico
  Destination: S3 + CloudWatch Logs
  Format: Custom fields específicos para análisis
  Retention: 1 año para compliance
  
CloudTrail:
  Multi-region: Enabled                        # Captura actividad en todas las regiones
  Event Types: Management + Data               # APIs y acceso a datos
  Log File Validation: Enabled                # Detección de tampering
  Encryption: KMS encrypted
  
WAF Logs:
  Sampling Rate: 100%                          # Todos los requests para análisis completo
  Fields: IP, User-Agent, URI, Action         # Información clave para detección
  Real-time Analysis: Kinesis Data Streams    # Procesamiento inmediato
  
EKS Audit Logs:
  Level: Metadata                              # Balance entre detalle y volumen
  Namespaces: All                             # Auditoría completa del cluster
  Resources: Secrets, ConfigMaps, RBAC        # Recursos críticos de seguridad
```

#### SIEM Integration y Analytics

```yaml
Elasticsearch Cluster:
  Nodes: 3 (Multi-AZ)                         # Alta disponibilidad
  Instance Type: r6g.large                    # Optimizado para análisis
  Storage: 500GB per node                     # Capacidad para logs históricos
  
Kibana Dashboards:
  Security Overview: Alertas críticas, tendencias
  Network Analysis: Flow logs, conexiones anómalas
  Access Patterns: Intentos de login, accesos privilegiados
  Compliance: PCI DSS, SOC 2 metrics
  
Automated Alerting:
  Failed login attempts > 5 en 5 minutos      # Potencial brute force
  API calls from new geographic locations     # Acceso desde ubicaciones inusuales
  Privilege escalation attempts               # Cambios en permisos IAM
  Data exfiltration patterns                  # Transferencias inusuales de datos
```

## Arquitectura de Seguridad Zero Trust

### Principios Implementados

```yaml
Never Trust, Always Verify:
  - Toda comunicación requiere autenticación   # Incluso tráfico interno
  - Verificación continua de identidad         # Re-validación periódica
  - Contexto de seguridad dinámico            # Ubicación, dispositivo, comportamiento

Microsegmentación:
  Network Policies por namespace:
    production: Solo comunicación necesaria entre servicios
    staging: Aislado de production
    development: Sin acceso a datos de producción
  
  Service-to-Service:
    mTLS obligatorio via Istio
    RBAC granular por service account
    Rate limiting por servicio
```

### Respuesta Automatizada a Incidentes

```yaml
Incident Response Workflow:
  Detection: GuardDuty + Security Hub          # Múltiples fuentes de detección
  
  Automated Response (Lambda Functions):
    - Isolate compromised instances             # Mover a security group restrictivo
    - Rotate credentials                        # Invalidar tokens comprometidos
    - Scale down suspicious workloads          # Reducir impacto potencial
    - Capture forensic snapshots               # Preservar evidencia
  
  Human Notification:
    Critical: Immediate page (PagerDuty)       # 5 minutos para respuesta
    High: Slack alert                          # 30 minutos para respuesta
    Medium: Email notification                 # 4 horas para respuesta
    
  Recovery:
    Automated health checks                    # Verificar que la amenaza fue neutralizada
    Gradual restoration of services            # Restauración controlada
    Post-incident review automation            # Documentación automática del incidente
```

## Beneficios de la Arquitectura de Seguridad

### Compliance y Auditabilidad
- **SOC 2 Type II:** Controles operacionales documentados y auditables
- **PCI DSS:** Si se procesa información de pagos.