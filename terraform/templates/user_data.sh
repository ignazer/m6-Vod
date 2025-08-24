#!/bin/bash
# User data script para nodos EKS
# Variables: cluster_name, node_group, environment

set -o xtrace

# Configurar el nodo para unirse al cluster EKS
/etc/eks/bootstrap.sh ${cluster_name}

# Configuraciones específicas por node group
case "${node_group}" in
  "gpu")
    # Instalar drivers NVIDIA para nodos GPU
    echo "Installing NVIDIA drivers for GPU nodes..."
    # Aquí irían los comandos específicos para GPU
    ;;
  "compute")
    # Configuraciones optimizadas para compute-intensive workloads
    echo "Configuring compute-optimized settings..."
    # Configuraciones específicas de CPU
    ;;
  *)
    echo "Configuring general purpose node..."
    ;;
esac

# Configurar logging
echo "Environment: ${environment}" >> /var/log/eks-bootstrap.log
echo "Node Group: ${node_group}" >> /var/log/eks-bootstrap.log
echo "Cluster: ${cluster_name}" >> /var/log/eks-bootstrap.log

# Configurar CloudWatch agent si es necesario
if [ "${environment}" = "production" ]; then
  echo "Setting up enhanced monitoring for production..."
  # Configuraciones adicionales de monitoreo
fi
