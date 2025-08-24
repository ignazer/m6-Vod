# Estrategias de Monitorización y Logging - Plataforma VOD

## Arquitectura de Observabilidad Integral

### Principios de Diseño

La estrategia de monitorización y logging para la plataforma VOD sigue los principios de observabilidad moderna, implementando los tres pilares fundamentales:

**Los Tres Pilares de la Observabilidad:**
- **Métricas**: Datos numéricos agregados en el tiempo (CPU, memoria, latencia)
- **Logs**: Registros detallados de eventos discretos del sistema
- **Traces**: Seguimiento de requests a través de múltiples servicios

## Stack de Monitorización Multi-Capa

### Capa 1: Monitorización de Infraestructura

#### AWS CloudWatch - Monitoreo Nativo

**Métricas de Infraestructura Base:**
```yaml
EC2 Instances (Nodos EKS):
  Métricas Estándar:
    - CPUUtilization: Umbral crítico > 80%
    - MemoryUtilization: Umbral crítico > 85%
    - DiskSpaceUtilization: Umbral crítico > 90%
    - NetworkIn/NetworkOut: Para análisis de tráfico
  
  Métricas Personalizadas:
    - GPU Utilization (nodos p3): Para optimización de transcodificación
    - Container Count per Node: Para balanceado de carga
    - Node Readiness: Estado de disponibilidad de nodos

RDS Database:
  Performance Insights:
    - DatabaseConnections: Máximo 80% del límite
    - CPUUtilization: Umbral crítico > 75%
    - FreeableMemory: Mínimo 20% libre
    - ReadLatency/WriteLatency: Umbral > 200ms
    - DeadlockCount: Cualquier deadlock genera alerta
  
  Custom Metrics:
    - Active Connections por servicio
    - Query Performance por tipo de operación
    - Buffer Pool Hit Ratio: Mínimo 95%

S3 Storage:
  Costos y Utilización:
    - BucketSpaceUtilization: Crecimiento mensual
    - NumberOfObjects: Trending de contenido
    - AllRequests: Patrones de acceso
    - 4xxErrors/5xxErrors: Errores de acceso
  
  Content Delivery:
    - GetRequests por región: Análisis de popularidad
    - DataTransfer: Costos de egress
    - TransitionRequests: Efectividad del lifecycle

ELB/ALB:
  Tráfico y Performance:
    - RequestCount: Volumen de tráfico total
    - LatencyHigh: P95 latencia > 2 segundos
    - HTTPCode_Target_4XX_Count: Errores cliente
    - HTTPCode_Target_5XX_Count: Errores servidor
    - HealthyHostCount: Disponibilidad de targets
```

**Dashboards CloudWatch Especializados:**

```yaml
Infrastructure Overview Dashboard:
  Widgets:
    - Mapa de recursos por AZ (alta disponibilidad)
    - Trending de costos por servicio (30 días)
    - Estado de salud general del cluster
    - Alertas activas por severidad
    - Utilización de recursos vs capacidad

Application Performance Dashboard:
  Widgets:
    - Latencia P50/P95/P99 por servicio
    - Throughput de requests por minuto
    - Error rates por endpoint
    - Response time distribution
    - Top slowest endpoints

Business Metrics Dashboard:
  Widgets:
    - Videos uploaded per hour/day
    - Concurrent streaming sessions
    - Content delivery bandwidth usage
    - User registration/login trends
    - Revenue metrics (si aplicable)
```

#### Amazon EKS Container Insights

**Métricas de Contenedores y Kubernetes:**
```yaml
Cluster Level:
  Resource Utilization:
    - cluster_cpu_utilization: Promedio del cluster
    - cluster_memory_utilization: Promedio del cluster
    - cluster_network_total_bytes: Tráfico total
    - cluster_failed_node_count: Nodos fallidos
  
  Pod Metrics:
    - pod_cpu_utilization_over_pod_limit: Pods que exceden límites
    - pod_memory_utilization_over_pod_limit: Uso excesivo de memoria
    - pod_network_rx_bytes/pod_network_tx_bytes: Tráfico por pod

Node Level:
  System Resources:
    - node_cpu_limit: Límite total de CPU por nodo
    - node_memory_limit: Límite total de memoria
    - node_filesystem_utilization: Uso de disco por nodo
    - node_number_of_running_pods: Densidad de pods
    - node_number_of_running_containers: Containers activos

Service Level:
  Application Metrics:
    - service_cpu_utilization: CPU por servicio
    - service_memory_utilization: Memoria por servicio
    - service_number_of_running_pods: Réplicas activas
    - namespace_number_of_running_pods: Pods por namespace
```

### Capa 2: Monitorización de Aplicaciones con Prometheus

#### Instalación y Configuración de Prometheus Operator

**Helm Chart Configuration:**
```yaml
# values-prometheus.yaml
prometheus:
  prometheusSpec:
    retention: 15d  # Retención de métricas
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3-storage
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    # Configuración de recursos
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
    
    # Rules de alerting personalizadas
    additionalScrapeConfigs:
      - job_name: 'vod-application-metrics'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true

grafana:
  enabled: true
  adminPassword: [PASSWORD_DESDE_SECRETS_MANAGER]
  
  # Configuración de persistencia
  persistence:
    enabled: true
    storageClassName: gp3-storage
    size: 10Gi
  
  # Datasources automáticos
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-server:80
          access: proxy
          isDefault: true
        - name: CloudWatch
          type: cloudwatch
          jsonData:
            authType: default
            defaultRegion: us-east-1

alertmanager:
  enabled: true
  config:
    global:
      slack_api_url: [SLACK_WEBHOOK_URL]
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'default-receiver'
      routes:
        - match:
            severity: critical
          receiver: 'critical-alerts'
        - match:
            severity: warning
          receiver: 'warning-alerts'
```

#### Métricas Personalizadas de Aplicación

**Instrumentación de Servicios:**
```yaml
API Gateway Service:
  Custom Metrics:
    - http_requests_total: Counter de requests por endpoint y método
    - http_request_duration_seconds: Histogram de latencia por endpoint
    - authentication_attempts_total: Intentos de login (exitosos/fallidos)
    - rate_limit_exceeded_total: Requests bloqueados por rate limiting
    - jwt_tokens_issued_total: Tokens JWT emitidos
    - active_user_sessions: Gauge de sesiones activas

Video Streaming Service:
  Custom Metrics:
    - streaming_sessions_active: Sesiones de streaming concurrentes
    - video_start_time_seconds: Tiempo para iniciar reproducción
    - bandwidth_utilization_bytes: Uso de ancho de banda por stream
    - video_quality_changes_total: Cambios de calidad adaptativa
    - streaming_errors_total: Errores de streaming por tipo
    - concurrent_streams_per_user: Distribución de streams por usuario

Content Management Service:
  Custom Metrics:
    - video_uploads_total: Videos subidos por período
    - transcoding_jobs_duration_seconds: Tiempo de transcodificación
    - storage_space_used_bytes: Espacio utilizado por tipo de contenido
    - content_encoding_errors_total: Errores de codificación
    - video_processing_queue_length: Tamaño de cola de procesamiento

User Management Service:
  Custom Metrics:
    - user_registrations_total: Registros de nuevos usuarios
    - user_login_duration_seconds: Tiempo de proceso de login
    - password_reset_requests_total: Solicitudes de reset
    - user_profile_updates_total: Actualizaciones de perfil
    - subscription_changes_total: Cambios de suscripción
```

**ServiceMonitor para Kubernetes:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vod-applications
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: vod-platform
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
  namespaceSelector:
    matchNames:
    - production
    - staging
    - development
```

### Capa 3: Logging Centralizado con ELK Stack

#### Arquitectura de Logging Distribuido

**Componentes del Stack de Logging:**
```yaml
Fluentd (DaemonSet):
  Propósito: Recolección y forwarding de logs
  Configuración:
    - Recolectar logs de todos los pods en el nodo
    - Enriquecer logs con metadata de Kubernetes
    - Buffer y retry en caso de fallos de Elasticsearch
    - Filtros para PII (información personal identificable)
  
  Sources:
    - /var/log/containers/*.log: Logs de containers
    - /var/log/pods/*/: Logs específicos de pods
    - /var/log/audit/: Logs de auditoría del sistema
  
  Outputs:
    - Elasticsearch: Para búsqueda y análisis
    - S3: Para archivado a largo plazo
    - CloudWatch: Para integración con alerting AWS

Elasticsearch Cluster:
  Topology:
    - 3 Master nodes (c6g.large): Para coordinación del cluster
    - 6 Data nodes (r6g.xlarge): Para almacenamiento e indexing
    - 2 Coordinating nodes (c6g.large): Para balancear queries
  
  Configuración:
    - Replication factor: 1 (balance entre disponibilidad y storage)
    - Shard size target: 20-50GB por shard
    - Index templates por tipo de log
    - ILM policies para lifecycle management
    - Security: X-Pack con RBAC habilitado

Kibana:
  Features:
    - Dashboards por servicio y ambiente
    - Alerting integrado con Slack/Email
    - Canvas para reportes ejecutivos
    - Maps para análisis geográfico de accesos
  
  Access Control:
    - Developers: Solo logs de development y staging
    - DevOps: Acceso completo a todos los ambientes
    - Business Users: Solo dashboards de métricas de negocio
```

#### Configuración de Fluentd

**FluentD ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    # Input: Kubernetes container logs
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type multi_format
        <pattern>
          format json
          time_key timestamp
          time_format %Y-%m-%dT%H:%M:%S.%NZ
        </pattern>
        <pattern>
          format /^(?<timestamp>[^ ]*) (?<stream>stdout|stderr) [^ ]* (?<message>.*)$/
          time_format %Y-%m-%dT%H:%M:%S.%N%:z
        </pattern>
      </parse>
    </source>
    
    # Filter: Add Kubernetes metadata
    <filter kubernetes.**>
      @type kubernetes_metadata
      @log_level warn
      skip_labels true
      skip_container_metadata true
      skip_master_url true
      skip_namespace_metadata true
    </filter>
    
    # Filter: Parse application logs
    <filter kubernetes.var.log.containers.**vod-api**.log>
      @type parser
      key_name message
      reserve_data true
      <parse>
        @type json
        json_parser_error_class JSONError
      </parse>
    </filter>
    
    # Filter: Add environment and service tags
    <filter kubernetes.**>
      @type record_transformer
      <record>
        environment ${ENV_NAME}
        service ${record["kubernetes"]["labels"]["app"] || "unknown"}
        version ${record["kubernetes"]["labels"]["version"] || "unknown"}
        region ${AWS_REGION}
      </record>
    </filter>
    
    # Filter: Remove sensitive information
    <filter **>
      @type grep
      <exclude>
        key message
        pattern /password|token|secret|key/i
      </exclude>
    </filter>
    
    # Output: Elasticsearch
    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch-master
      port 9200
      scheme http
      
      # Index management
      index_name vod-logs
      template_name vod-template
      template_file /fluentd/etc/elasticsearch-template.json
      
      # Buffer configuration for reliability
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_thread_count 2
        flush_interval 5s
        retry_forever
        retry_max_interval 30
        chunk_limit_size 2M
        queue_limit_length 8
        overflow_action block
      </buffer>
    </match>
    
    # Output: S3 for long-term storage
    <match kubernetes.**>
      @type copy
      <store>
        @type s3
        aws_key_id "#{ENV['AWS_ACCESS_KEY_ID']}"
        aws_sec_key "#{ENV['AWS_SECRET_ACCESS_KEY']}"
        s3_bucket vod-logs-archive
        s3_region us-east-1
        path logs/%Y/%m/%d/
        s3_object_key_format %{path}%{time_slice}_%{index}.%{file_extension}
        
        <buffer time>
          @type file
          path /var/log/fluentd-buffers/s3
          timekey 3600  # 1 hour chunks
          timekey_wait 10m
          timekey_use_utc true
        </buffer>
        
        <format>
          @type json
        </format>
      </store>
    </match>
```

#### Elasticsearch Index Templates y Policies

**Index Template para Logs de Aplicación:**
```json
{
  "index_patterns": ["vod-logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.codec": "best_compression",
      "index.refresh_interval": "30s",
      "index.translog.flush_threshold_size": "512mb"
    },
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "level": {
          "type": "keyword"
        },
        "service": {
          "type": "keyword"
        },
        "environment": {
          "type": "keyword"
        },
        "message": {
          "type": "text",
          "analyzer": "standard"
        },
        "kubernetes": {
          "properties": {
            "namespace": {"type": "keyword"},
            "pod_name": {"type": "keyword"},
            "container_name": {"type": "keyword"},
            "labels": {
              "type": "object",
              "dynamic": true
            }
          }
        },
        "request_id": {
          "type": "keyword"
        },
        "user_id": {
          "type": "keyword"
        },
        "ip_address": {
          "type": "ip"
        },
        "response_time": {
          "type": "long"
        }
      }
    }
  }
}
```

**Index Lifecycle Management (ILM) Policy:**
```json
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "30GB",
            "max_age": "1d"
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "set_priority": {
            "priority": 50
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "set_priority": {
            "priority": 0
          }
        }
      },
      "delete": {
        "min_age": "90d"
      }
    }
  }
}
```

### Capa 4: Distributed Tracing con Jaeger

#### Implementación de Tracing Distribuido

**Jaeger Deployment Configuration:**
```yaml
# Jaeger Operator installation
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-production
  namespace: observability
spec:
  strategy: production
  
  storage:
    type: elasticsearch
    elasticsearch:
      server-urls: http://elasticsearch-master:9200
      index-prefix: jaeger
      
  collector:
    maxReplicas: 5
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  
  query:
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "200m"

  ingester:
    maxReplicas: 3
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

**Instrumentación de Aplicaciones:**
```yaml
Application Instrumentation:
  OpenTelemetry SDK:
    - Auto-instrumentation para HTTP requests
    - Database query tracing
    - External API calls tracing
    - Custom spans para operaciones críticas
  
  Tracing Context:
    - Propagación de trace ID entre servicios
    - Correlation con logs usando trace ID
    - Baggage para metadata adicional
  
  Sampling Strategy:
    - Production: 1% sampling rate (reducir overhead)
    - Staging: 10% sampling rate
    - Development: 100% sampling rate
    - Critical paths: Always sample (overrides)

Service Map Generation:
  Automatic Discovery:
    - Service dependencies via traces
    - Performance bottlenecks identification
    - Error propagation paths
    - Load distribution analysis
```

### Capa 5: Alerting y Notification

#### Estrategia de Alerting Multi-Canal

**Alertmanager Configuration:**
```yaml
# alertmanager.yml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@company.com'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
    group_wait: 0s
    repeat_interval: 5m
  - match:
      severity: warning
    receiver: 'warning-alerts'
    repeat_interval: 30m
  - match:
      service: payment
    receiver: 'business-critical'
    group_wait: 0s

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://webhook-service/alerts'

- name: 'critical-alerts'
  slack_configs:
  - channel: '#alerts-critical'
    username: 'Prometheus'
    color: 'danger'
    title: 'Critical Alert - {{ .GroupLabels.service }}'
    text: >-
      {{ range .Alerts }}
      *Alert:* {{ .Annotations.summary }}
      *Description:* {{ .Annotations.description }}
      *Severity:* {{ .Labels.severity }}
      {{ end }}
  pagerduty_configs:
  - routing_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
    description: '{{ .GroupLabels.service }} - {{ .GroupLabels.alertname }}'

- name: 'warning-alerts'
  slack_configs:
  - channel: '#alerts-warning'
    username: 'Prometheus'
    color: 'warning'
    title: 'Warning Alert - {{ .GroupLabels.service }}'

- name: 'business-critical'
  email_configs:
  - to: 'cto@company.com,business@company.com'
    subject: 'URGENT: Business Critical Alert'
    body: |
      Alert: {{ .GroupLabels.alertname }}
      Service: {{ .GroupLabels.service }}
      
      {{ range .Alerts }}
      Description: {{ .Annotations.description }}
      Runbook: {{ .Annotations.runbook_url }}
      {{ end }}
```

#### PrometheusRules Personalizadas

**Reglas de Alerting Críticas:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vod-platform-alerts
  namespace: monitoring
spec:
  groups:
  - name: vod.infrastructure
    rules:
    - alert: HighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 2m
      labels:
        severity: warning
        service: infrastructure
      annotations:
        summary: "High CPU usage detected"
        description: "CPU usage is above 80% for more than 2 minutes on {{ $labels.instance }}"
        runbook_url: "https://runbooks.company.com/high-cpu"

    - alert: HighMemoryUsage
      expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
      for: 1m
      labels:
        severity: critical
        service: infrastructure
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is above 85% on {{ $labels.instance }}"

  - name: vod.application
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5
      for: 2m
      labels:
        severity: critical
        service: "{{ $labels.service }}"
      annotations:
        summary: "High error rate in {{ $labels.service }}"
        description: "Error rate is {{ $value }}% for service {{ $labels.service }}"

    - alert: HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
      for: 1m
      labels:
        severity: warning
        service: "{{ $labels.service }}"
      annotations:
        summary: "High latency in {{ $labels.service }}"
        description: "95th percentile latency is {{ $value }}s for {{ $labels.service }}"

    - alert: StreamingSessionsDown
      expr: streaming_sessions_active < 100
      for: 5m
      labels:
        severity: critical
        service: streaming
      annotations:
        summary: "Streaming sessions critically low"
        description: "Only {{ $value }} active streaming sessions"

  - name: vod.business
    rules:
    - alert: VideoUploadFailure
      expr: increase(video_uploads_failed_total[5m]) > 5
      for: 1m
      labels:
        severity: critical
        service: content-management
      annotations:
        summary: "Multiple video upload failures"
        description: "{{ $value }} video uploads failed in the last 5 minutes"

    - alert: TranscodingQueueBacklog
      expr: video_processing_queue_length > 50
      for: 5m
      labels:
        severity: warning
        service: transcoding
      annotations:
        summary: "Transcoding queue backlog"
        description: "{{ $value }} videos waiting for transcoding"
```

### Capa 6: Performance Monitoring y APM

#### Application Performance Monitoring

**New Relic Integration (Alternativa a Jaeger):**
```yaml
APM Features:
  Code-Level Visibility:
    - Function-level performance metrics
    - Database query analysis
    - External service dependency mapping
    - Memory leak detection
    - Garbage collection impact analysis
  
  Real User Monitoring (RUM):
    - Frontend performance metrics
    - User journey tracking
    - Browser compatibility issues
    - Geographic performance variations
  
  Synthetic Monitoring:
    - Proactive endpoint testing
    - Multi-step user flow validation
    - Global performance baselines
    - SLA compliance tracking

Custom Dashboards:
  Executive Dashboard:
    - Business KPIs (MAU, revenue, conversion)
    - System health overview
    - Cost optimization opportunities
    - Performance trending (month-over-month)
  
  Engineering Dashboard:
    - Deployment impact analysis
    - Error budgets vs SLI compliance
    - Performance regression detection
    - Capacity planning metrics
  
  Operations Dashboard:
    - Real-time system status
    - Alert fatigue analysis
    - MTTR trending
    - Infrastructure utilization efficiency
```

### Capa 7: Log Analytics y Business Intelligence

#### ELK Stack para Análisis de Negocio

**Kibana Dashboards Especializados:**
```yaml
Business Intelligence Dashboard:
  Content Performance:
    - Most watched videos by region/time
    - Content engagement metrics (completion rates)
    - Popular content categories
    - Seasonal viewing patterns
    - Revenue per content type
  
  User Behavior Analytics:
    - User registration funnels
    - Session duration distributions
    - Device/platform usage patterns
    - Geographic user distribution
    - Churn prediction indicators
  
  Operational Insights:
    - System performance impact on user experience
    - Cost per active user
    - Infrastructure efficiency metrics
    - Support ticket correlation with system issues
    - Deployment success rate analysis

Security Analytics Dashboard:
  Threat Detection:
    - Failed authentication patterns
    - Suspicious IP activity
    - Unusual access patterns
    - DDoS attempt indicators
    - Data exfiltration detection
  
  Compliance Monitoring:
    - GDPR compliance metrics
    - Data retention policy adherence
    - Access audit trails
    - Encryption status monitoring
    - Privacy policy violations
```

## Implementación por Fases

### Fase 1: Fundamentos (Semanas 1-2)
```yaml
Objetivos:
  - Configurar CloudWatch básico
  - Implementar Prometheus + Grafana
  - Configurar alerting crítico
  - Establecer logging centralizado básico

Entregables:
  - Infrastructure monitoring funcional
  - Alerting para métricas críticas
  - Dashboards básicos de sistema
  - Log aggregation de aplicaciones
```

### Fase 2: Observabilidad Avanzada (Semanas 3-4)
```yaml
Objetivos:
  - Implementar distributed tracing
  - Configurar métricas personalizadas de aplicación
  - Establecer SLIs/SLOs
  - Implementar business metrics

Entregables:
  - Jaeger tracing completo
  - Custom application metrics
  - SLO dashboards
  - Business intelligence básico
```

### Fase 3: Optimización y Analytics (Semanas 5-6)
```yaml
Objetivos:
  - Implementar APM avanzado
  - Configurar predictive analytics
  - Optimizar costos de observabilidad
  - Establecer chaos engineering monitoring

Entregables:
  - Performance optimization insights
  - Cost optimization reportes
  - Predictive alerting
  - Chaos engineering metrics
```

## Costos y Optimización

### Estimación de Costos Mensuales

```yaml
CloudWatch:
  Metrics: ~$150/mes (10,000 custom metrics)
  Logs: ~$200/mes (100GB ingestion)
  Dashboards: ~$9/mes (3 dashboards)
  Alarms: ~$10/mes (100 alarms)

Elasticsearch (Self-managed):
  EC2 Instances: ~$800/mes (6 r6g.xlarge)
  EBS Storage: ~$300/mes (3TB gp3)
  Data Transfer: ~$50/mes

Prometheus Stack:
  EC2 Instances: ~$200/mes (monitoring nodes)
  EBS Storage: ~$100/mes (metrics storage)
  Load Balancer: ~$20/mes

Total Estimado: ~$1,839/mes
```

### Estrategias de Optimización de Costos

```yaml
Log Retention Optimization:
  Hot tier (7 days): Critical logs, full indexing
  Warm tier (30 days): Reduced indexing, slower queries
  Cold tier (90 days): Archive, manual restoration
  Deleted: After 365 days (compliance dependent)

Metrics Cardinality Control:
  - Limit high-cardinality labels
  - Use recording rules for expensive queries
  - Implement metric dropping for unused metrics
  - Regular cleanup of stale metrics

Storage Optimization:
  - Compress old indices
  - Use S3 for long-term log archival
  - Implement data sampling for high-volume streams
  - Use lifecycle policies aggressively
```

Esta estrategia de monitorización y logging proporciona visibilidad completa del sistema, desde la infraestructura hasta las métricas de negocio, con un enfoque escalable y costo-efectivo para la plataforma VOD.