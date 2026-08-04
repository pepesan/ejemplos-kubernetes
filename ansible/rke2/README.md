# Módulo RKE2: Despliegue de Kubernetes con Rancher RKE2

Este directorio contiene los laboratorios y ejemplos de automatización con Ansible para **RKE2 (Rancher Kubernetes Engine 2)** sobre infraestructura de Máquinas Virtuales LXD.

## 📋 Mapeo con el Temario: "4.- RKE2 Despliegue de Kubernetes"

Cada subdirectorio se corresponde con los puntos clave del temario:

| Sección Temario | laboratorio / Directorio | Descripción |
| --- | --- | --- |
| **Requisitos: Hardware y Red** | [`01_requisitos_hardware_red/`](01_requisitos_hardware_red/) | Dimensionamiento de hardware (vCPU, RAM, discos), puertos de red (6443, 9345, etcd, VXLAN), perfiles LXD VM y preparación de kernel/SO. |
| **Server Node** & **Instalación RKE** | [`02_rke2_server_single_node/`](02_rke2_server_single_node/) | Instalación del primer Server Node (Control Plane + etcd + API) usando el instalador oficial y `/etc/rancher/rke2/config.yaml`. |
| **CNI** | [`03_cni_configuration/`](03_cni_configuration/) | Configuración y personalización del CNI (Canal por defecto, Cilium, Calico) mediante manifiestos `HelmChartConfig`. |
| **Worker Node** | [`04_worker_node_agent/`](04_worker_node_agent/) | Instalación de nodos trabajadores (`rke2-agent`), unión al clúster vía el puerto `9345` y token de registro. |
| **HA (Alta Disponibilidad)** | [`05_ha_cluster_etcd/`](05_ha_cluster_etcd/) | Clúster HA con 3 Server Nodes (etcd distribuido) + VIP/LoadBalancer para el API server (6443) y el supervisor (9345). |
| **Docker Registry** | [`06_docker_private_registry/`](06_docker_private_registry/) | Configuración de registros de imágenes privados / mirrors en Containerd vía `/etc/rancher/rke2/registries.yaml`. |
| **Actualizaciones** | [`07_actualizaciones_cluster/`](07_actualizaciones_cluster/) | Estrategias de actualización de RKE2 (rolling upgrade vía Ansible y vía Rancher System Upgrade Controller). |

---

## 🛠️ Requisitos Previos en el Host

Igual que en los laboratorios base de Kubernetes (`ansible/base/`), los nodos se despliegan en **Máquinas Virtuales LXD** sobre el host local.

Asegúrate de haber ejecutado previamente el bootstrap del host:
```bash
cd ../base
./00_instalar_ansible.sh
```

---

## 🚀 Uso General

Cada laboratorio es autocontenido y dispone de:
* `inventory.ini`: Definición de nodos y variables del clúster.
* `group_vars/`: Configuración específica de RKE2 (versión, CNI, tokens, SANs).
* `run_all.sh`: Script para aprovisionar las VMs y desplegar RKE2 de principio a fin.
* `destroy_all.sh`: Script para destruir las VMs y limpiar el entorno.
