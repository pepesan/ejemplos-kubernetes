# 🗺️ Plan de Ruta: Módulo RKE2 (Rancher Kubernetes Engine 2)

Este documento detalla el plan de trabajo, el estado de implementación de los ejemplos de RKE2 y el seguimiento de validación para el temario **"4.- RKE2 Despliegue de Kubernetes"**.

---

## 🏛️ Arquitectura Modular Reutilizable (`ansible/rke2/shared/`)

Para evitar duplicar código entre los laboratorios, toda la lógica de infraestructura vive en `shared/`:

- [x] **`shared/01_crear_vms.yml`**: Aprovisionamiento dinámico de VMs LXD en función del `inventory.ini`.
- [x] **`shared/02_configurar_os.yml`**: Ajuste de kernel (`overlay`, `br_netfilter`), sysctl (`ip_forward=1`), swap y paquetes base.
- [x] **`shared/03_instalar_rke2_server.yml`**: Instalación y configuración declarativa de RKE2 Server Node(s) (mono-nodo o HA) y extracción del `kubeconfig.yaml`.
- [x] **`shared/04_instalar_rke2_agent.yml`**: Instalación y conexión de RKE2 Agent / Worker Nodes al puerto `9345`.
- [x] **`shared/destroy_vms.yml`**: Limpieza automática de las VMs del inventario.
- [x] **`shared/run_lab.sh` & `shared/destroy_lab.sh`**: Scripts de orquestación común.

---

## 📊 Estado de Implementación y Validación de Laboratorios

| # | Laboratorio | Estado | Versión RKE2/K8s | Notas / Avance |
| --- | --- | --- | --- | --- |
| **01** | **Requisitos: Hardware y Red** (`01_requisitos_hardware_red`) | ✅ Validado | `v1.35.6+rke2r1` | Documentación completa de vCPU/RAM/disco, sysctl y matriz de puertos (`6443`, `9345`, `2379-2380`, `8472`). |
| **02** | **Server Node Mono-nodo** (`02_rke2_server_single_node`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | VM LXD `rke2-server1` aprovisionada, `rke2-server.service` en ejecución, `kubeconfig.yaml` local ajustado y verificado en vivo. |
| **03** | **Configuración de CNI** (`03_cni_configuration`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado con CNI Cilium (`cni: cilium`). Pendiente de validación de tráfico de pods e Ingress con Cilium. |
| **04** | **Worker Node (Agent)** (`04_worker_node_agent`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado para 1 Server + 2 Workers (`rke2-worker1/2`). Pendiente de prueba de carga y resiliencia. |
| **05** | **Alta Disponibilidad (HA)** (`05_ha_cluster_etcd`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado con 3 Servers (etcd distribuido) + 2 Workers. Pendiente de prueba de conmutación y caída de nodos. |
| **06** | **Docker Registry Privado** (`06_docker_private_registry`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado para inyectar `/etc/rancher/rke2/registries.yaml` (mirrors y auth). Pendiente de prueba con registry local. |
| **07** | **Actualizaciones del Clúster** (`07_actualizaciones_cluster`) | 🟡 Estructurado | `v1.35.6` -> `v1.36.2` | Estructurado para rolling upgrade de RKE2 `v1.35.6+rke2r1` a `v1.36.2+rke2r1` y System Upgrade Controller. |

---

## 🎯 Próximos Pasos (Backlog de Trabajo)

1. **Laboratorio 03 (CNI):** Ejecutar prueba en vivo de `03_cni_configuration` verificando el arranque de Cilium (`rke2-cilium`) frente al CNI Canal por defecto.
2. **Laboratorio 04 (Workers):** Ejecutar prueba en vivo de `04_worker_node_agent` verificando el registro de los 2 workers en el puerto `9345` y la distribución de pods de prueba.
3. **Laboratorio 05 (HA):** Ejecutar prueba en vivo de `05_ha_cluster_etcd` validando la formación del quórum etcd de 3 miembros y la resiliencia ante la parada de un Server Node.
4. **Laboratorio 06 (Registry):** Crear un registro local Docker de prueba e integrar el archivo `registries.yaml` para comprobar el pulling de imágenes privadas o espejadas.
5. **Laboratorio 07 (Actualizaciones):** Ejecutar la actualización en vivo de `v1.35.6+rke2r1` a `v1.36.2+rke2r1` sin pérdida de disponibilidad.
