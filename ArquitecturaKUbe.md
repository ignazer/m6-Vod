# Arquitectura del Cluster EKS - Plataforma VOD

##  Visión General de la Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS REGION (us-east-1)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                 PLANO DE CONTROL EKS                      │  │
│  │              (Administrado por AWS)                       │  │
│  │                                                           │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │  │
│  │  │ Servidor    │ │    etcd     │ │    Planificador     │  │  │
│  │  │ API         │ │             │ │    (Scheduler)      │  │  │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘  │  │
│  │                                                           │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │  │
│  │  │Controlador  │ │ Controlador │ │   Complementos      │  │  │
│  │  │de Recursos  │ │ de Nube     │ │   (CoreDNS, etc)    │  │  │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          ┌─────────┼─────────┐
                          │         │         │
          ┌───────────────▼─┐   ┌───▼───────┐ ┌▼─────────────┐
          │  AZ-1a         │   │  AZ-1b     │ │  AZ-1c       │
          │ (Zona Este A)  │   │(Zona Este B│ │(Zona Este C) │
          └────────────────┘   └────────────┘ └──────────────┘
```

> ** Punto Clave:** El plano de control está completamente administrado por AWS, eliminando la complejidad operacional de mantener los masters de Kubernetes.

## Nodos Worker - Distribución Multi-Availability Zone

### **Zona de Disponibilidad 1a - Propósito General**
```
┌─────────────────────────────────────────────────┐
│                    AZ-1a                        │
│  ┌─────────────────────────────────────────────┐│
│  │      GRUPO DE NODOS 1 - Propósito General  ││
│  │                                             ││
│  │  Tipo de Instancia: t3.large               ││
│  │  Nodos Mín: 2   Nodos Máx: 10              ││
│  │  Deseado: 3                                 ││
│  │                                             ││
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐      ││
│  │  │ Nodo-1a │ │ Nodo-2a │ │ Nodo-3a │      ││
│  │  │         │ │         │ │         │      ││
│  │  │ Pods:   │ │ Pods:   │ │ Pods:   │      ││
│  │  │ • API   │ │ • Users │ │ • Auth  │      ││
│  │  │ • Web   │ │ • Meta  │ │ • Cache │      ││
│  │  └─────────┘ └─────────┘ └─────────┘      ││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

> ** Explicación:** Las instancias t3.large (2 vCPUs, 8GB RAM) son ideales para servicios web con cargas variables. El autoescalado permite manejar picos de tráfico automáticamente..

### **Zona de Disponibilidad 1b - Optimizado para Cómputo**
```
┌─────────────────────────────────────────────────┐
│                    AZ-1b                        │
│  ┌─────────────────────────────────────────────┐│
│  │    GRUPO DE NODOS 2 - Optimizado Cómputo   ││
│  │                                             ││
│  │  Tipo de Instancia: c5.xlarge              ││
│  │  Nodos Mín: 1   Nodos Máx: 20              ││
│  │  Deseado: 2                                 ││
│  │                                             ││
│  │  ┌─────────┐ ┌─────────┐                   ││
│  │  │ Nodo-1b │ │ Nodo-2b │                   ││
│  │  │         │ │         │                   ││
│  │  │ Pods:   │ │ Pods:   │                   ││
│  │  │ • Stream│ │ • CDN   │                   ││
│  │  │ • Proc  │ │ • Analytics                 ││
│  │  └─────────┘ └─────────┘                   ││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

> ** Ventaja:** Las instancias c5.xlarge (4 vCPUs, 8GB RAM) ofrecen mayor potencia de procesamiento para streaming y análisis de datos en tiempo real.

### **Zona de Disponibilidad 1c - Instancias GPU**
```
┌─────────────────────────────────────────────────┐
│                    AZ-1c                        │
│  ┌─────────────────────────────────────────────┐│
│  │       GRUPO DE NODOS 3 - Instancias GPU    ││
│  │                                             ││
│  │  Tipo de Instancia: p3.2xlarge             ││
│  │  Nodos Mín: 0   Nodos Máx: 5               ││
│  │  Deseado: 1                                 ││
│  │                                             ││
│  │  ┌─────────┐                               ││
│  │  │ Nodo-1c │                               ││
│  │  │ 1x V100 │ ← GPU Tesla V100              ││
│  │  │ Pods:   │                               ││
│  │  │ • ML/IA │ ← Inteligencia Artificial     ││
│  │  │ • Transco ← Transcodificación          ││
│  │  │ • Render│ ← Renderizado                 ││
│  │  └─────────┘                               ││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

> ** Importante:** Mín=0 permite que estos nodos caros solo se activen cuando hay demanda de procesamiento GPU, optimizando costos.

##  Distribución de Microservicios por Grupo de Nodos

### **Nodos de Propósito General (t3.large)**
| Servicio | Réplicas | CPU Solicitado | Memoria Solicitada | Propósito |
|----------|----------|----------------|-------------------|-----------|
| API Gateway | 3-10 | 200m | 512Mi | Enrutamiento y Autenticación |
| Servicio Usuario | 3-8 | 150m | 256Mi | Gestión de Usuarios |
| Servicio Auth | 2-6 | 100m | 128Mi | Autenticación JWT |
| Servicio Metadatos | 2-5 | 100m | 256Mi | Info de Contenido |
| Frontend Web | 3-10 | 100m | 256Mi | Contenido Estático |

> **💻 Nota:** "200m" significa 200 milicores (0.2 de un CPU). Esto permite que múltiples pods compartan recursos eficientemente.

### **Nodos Optimizados para Cómputo (c5.xlarge)**
| Servicio | Réplicas | CPU Solicitado | Memoria Solicitada | Propósito |
|----------|----------|----------------|-------------------|-----------|
| Servicio Streaming | 5-20 | 500m | 1Gi | Entrega de Video |
| Servicio CDN | 3-15 | 300m | 512Mi | Distribución de Contenido |
| Servicio Analytics | 2-8 | 400m | 1Gi | Procesamiento de Datos |
| Recomendaciones | 2-10 | 600m | 2Gi | Inferencia de ML |

> **📊 Clave:** Estos servicios requieren más CPU para manejar streaming de video y análisis de datos en tiempo real.

### **Instancias GPU (p3.2xlarge)**
| Servicio | Réplicas | CPU Solicitado | Memoria Solicitada | GPU | Propósito |
|----------|----------|----------------|-------------------|-----|-----------|
| Transcodificación | 1-3 | 2000m | 8Gi | 1 | Procesamiento de Video |
| Entrenamiento ML | 0-2 | 4000m | 16Gi | 1 | Entrenamiento de Modelos |
| Renderizado IA | 0-1 | 1000m | 4Gi | 1 | Miniaturas/Previews |

> ** Optimización de Costos:** Réplicas mínimas en 0-1 para servicios GPU, ya que son los más costosos del cluster.

##  Componentes de Infraestructura

### **Configuración de Red**
```yaml
# Configuración de VPC para el cluster
Configuración VPC:
  CIDR: 10.0.0.0/16  # ← Rango de IPs privadas para todo el cluster
  
  Subredes Privadas:  # ← Aquí van los nodos worker (sin acceso directo a internet)
    - 10.0.1.0/24 (AZ-1a)  # 254 IPs disponibles por subred
    - 10.0.2.0/24 (AZ-1b)
    - 10.0.3.0/24 (AZ-1c)
  
  Subredes Públicas:  # ← Para Load Balancers y NAT Gateways
    - 10.0.101.0/24 (AZ-1a)
    - 10.0.102.0/24 (AZ-1b)
    - 10.0.103.0/24 (AZ-1c)
```

> ** Seguridad:** Los nodos worker están en subredes privadas, solo accesibles a través de Load Balancers en subredes públicas.

### **Complementos del Cluster**
| Complemento | Versión | Propósito | Comentario |
|-------------|---------|-----------|------------|
| VPC CNI | v1.18.1 | Plugin de Red | Asigna IPs de VPC a cada pod |
| CoreDNS | v1.11.1 | Descubrimiento de Servicios | DNS interno para comunicación entre servicios |
| kube-proxy | v1.28.1 | Proxy de Red | Balanceador de carga interno |
| EBS CSI Driver | v1.24.0 | Almacenamiento Persistente | Para bases de datos y logs |
| AWS Load Balancer Controller | v2.6.3 | Gestión de Ingress | Integración nativa con ALB/NLB |

> ** Integración:** Todos estos complementos son administrados por AWS, garantizando compatibilidad y actualizaciones automáticas.

### **Service Mesh y Observabilidad**
```yaml
# Service Mesh con Istio - Para comunicación segura entre microservicios
Service Mesh (Istio):
  - Gestión de Tráfico    # ← Control granular de routing entre servicios
  - Políticas de Seguridad # ← mTLS automático entre pods
  - Observabilidad        # ← Métricas automáticas de latencia y errores

# Stack de Monitoreo - Para visibilidad completa del cluster
Stack de Monitoreo:
  - Prometheus: Recolección de Métricas    # ← Base de datos de series temporales
  - Grafana: Visualización               # ← Dashboards para métricas
  - Jaeger: Trazado Distribuido         # ← Seguimiento de requests entre servicios
  - AlertManager: Alertas               # ← Notificaciones automáticas de problemas

# Logging Centralizado - Para análisis de logs
Logging:
  - Fluentd: Agregación de Logs         # ← Recolecta logs de todos los pods
  - CloudWatch Logs: Almacenamiento     # ← Storage managed por AWS
  - Elasticsearch: Búsqueda y Análisis  # ← Para queries complejas en logs
```

##  Estrategias de Escalado

### **Configuración del Cluster Autoscaler**
```yaml
# Configuración para escalado automático de nodos
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
spec:
  template:
    spec:
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.28.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4                           # ← Nivel de logging detallado
        - --stderrthreshold=info
        - --cloud-provider=aws            # ← Integración con AWS Auto Scaling Groups
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste          # ← Estrategia de selección: minimizar desperdicio
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/vod-cluster
        - --balance-similar-node-groups   # ← Distribuir pods uniformemente
        - --scale-down-delay-after-add=10m # ← Esperar 10min antes de reducir nodos
        - --scale-down-unneeded-time=10m   # ← Tiempo mínimo que un nodo debe estar vacío
```

> ** Gestión de Costos:** Los delays de scale-down evitan el "flapping" (agregar/quitar nodos constantemente), optimizando costos.

### **Ejemplo de Configuración HPA**
```yaml
# Horizontal Pod Autoscaler para el servicio de streaming
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: streaming-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: streaming-service             # ← Servicio objetivo para escalar
  minReplicas: 5                        # ← Mínimo para garantizar disponibilidad
  maxReplicas: 50                       # ← Máximo para controlar costos
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70          # ← Escalar cuando CPU promedio > 70%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80          # ← Escalar cuando memoria promedio > 80%
```

> ** Escalado Inteligente:** Se basa en múltiples métricas (CPU + memoria) para decisiones más precisas de escalado.

##  Estrategia de Almacenamiento Persistente

### **Clases de Almacenamiento**
```yaml
# SSD de Propósito General - Para la mayoría de aplicaciones
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp3-storage                     # ← Nombre para referenciar en PVCs
provisioner: ebs.csi.aws.com           # ← Driver CSI de AWS EBS
parameters:
  type: gp3                             # ← Tipo de volumen EBS más moderno
  iops: "3000"                          # ← IOPS base garantizado
  throughput: "125"                     # ← MB/s de throughput

# Alto IOPS para bases de datos críticas
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: io2-storage
provisioner: ebs.csi.aws.com
parameters:
  type: io2                             # ← Tipo premium para alta performance
  iopsPerGB: "100"                      # ← 100 IOPS por cada GB de almacenamiento
```

> ** Caso de Uso:** gp3 para aplicaciones web, io2 para bases de datos con alta carga transaccional.

##  Seguridad y Control de Acceso (RBAC)

### **Grupos de Seguridad de Nodos**
```yaml
# Reglas de firewall para los nodos worker
Reglas de Entrada:
  - Puerto 443: HTTPS desde ALB          # ← Tráfico web desde Load Balancer
  - Puerto 10250: API Kubelet desde Control Plane  # ← Comunicación con master
  - Puerto 53: DNS desde CIDR del Cluster # ← Resolución DNS interna
  
Reglas de Salida:
  - Todo el tráfico a internet           # ← Para descargar imágenes de contenedores
  - Comunicación inter-nodos             # ← Para comunicación entre pods
  - Comunicación con plano de control    # ← Reportar estado al master
```

### **Políticas RBAC**
```yaml
# Principios de seguridad implementados:
#  Service Account por microservicio    - Cada servicio tiene su identidad única
#  Principio de menor privilegio       - Solo permisos mínimos necesarios
#  Network Policies                    - Control de comunicación pod-a-pod
#  Pod Security Standards             - Políticas de seguridad a nivel de pod
```

> ** Defensa en Profundidad:** Múltiples capas de seguridad desde red hasta aplicación.

##  Asignación y Límites de Recursos

### **Planificación de Recursos**
| Componente | Núcleos CPU | Memoria (GB) | Almacenamiento (GB) | Comentario |
|------------|-------------|--------------|---------------------|------------|
| Plano de Control | Administrado | Administrado | Administrado | Sin costo adicional |
| Nodos Generales | 16 (total) | 64 | 200 | Para servicios web |
| Nodos Cómputo | 32 (total) | 128 | 400 | Para streaming/analytics |
| Nodos GPU | 32 (total) | 244 | 500 | Para ML/transcodificación |
| **Capacidad Total** | **80 núcleos** | **436 GB** | **1.1 TB** | Escalable bajo demanda |

> ** Ventaja de la Nube:** Esta capacidad puede aumentar automáticamente hasta los límites configurados, pagando solo por lo que se usa.

##  Beneficios de esta Arquitectura

1. **Alta Disponibilidad**: Distribución en 3 zonas evita puntos únicos de fallo
2. **Escalabilidad Automática**: Responde a demanda sin intervención manual  
3. **Optimización de Costos**: Nodos GPU solo cuando se necesitan
4. **Seguridad Robusta**: Múltiples capas de protección
5. **Observabilidad Completa**: Visibilidad total del sistema en tiempo real
6. **Mantenimiento Reducido**: AWS administra la infraestructura base

Esta arquitectura proporciona una base sólida, escalable y resiliente para la plataforma VOD, capaz de manejar desde cargas bajas hasta picos de demanda extremos manteniendo costos optimizados.