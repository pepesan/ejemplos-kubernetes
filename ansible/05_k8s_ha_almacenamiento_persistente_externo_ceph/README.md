# Laboratorio K8s + Clúster Ceph Externo e Independiente sobre LXD

Este laboratorio contiene el diseño y las herramientas para desplegar e integrar un clúster de Kubernetes con un clúster de almacenamiento **Ceph Externo** e independiente, simulando un entorno empresarial donde el almacenamiento no reside dentro de Kubernetes sino en un clúster de almacenamiento físico o virtual separado.

---

## 🏗️ Arquitectura del Entorno

```mermaid
graph TD
    subgraph Clúster Kubernetes (LXD)
        Manager["k8s-manager (10.207.154.50)<br/>Control Plane"]
        Worker1["k8s-worker1 (10.207.154.51)<br/>Worker Cómputo"]
        Worker2["k8s-worker2 (10.207.154.52)<br/>Worker Cómputo"]
    end

    subgraph Clúster Ceph Externo (LXD)
        Mon["ceph-mon (10.207.154.60)<br/>Monitor & Manager Ceph"]
        OSD1["ceph-osd1 (10.207.154.61)<br/>OSD Storage (/dev/vdb)"]
        OSD2["ceph-osd2 (10.207.154.62)<br/>OSD Storage (/dev/vdb)"]
        OSD3["ceph-osd3 (10.207.154.63)<br/>OSD Storage (/dev/vdb)"]
    end

    Worker1 & Worker2 -->|Conexión RBD/CephFS CSI| Mon
    Mon --> OSD1 & OSD2 & OSD3
```

---

## 📋 Inventario de Nodos LXD

Las máquinas virtuales se dividen en dos grupos aislados dentro del mismo hipervisor:

| Nombre | Dirección IP | Grupo / Función | CPU | Memoria | Disco Principal | Disco OSD |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-manager`** | `10.207.154.50` | K8s Control Plane | 2 | 3 GB | 20 GB | - |
| **`k8s-worker1`** | `10.207.154.51` | K8s Worker | 2 | 2 GB | 15 GB | - |
| **`k8s-worker2`** | `10.207.154.52` | K8s Worker | 2 | 2 GB | 15 GB | - |
| **`ceph-mon`** | `10.207.154.60` | Ceph Monitor & Mgr | 1 | 2 GB | 15 GB | - |
| **`ceph-osd1`** | `10.207.154.61` | Ceph OSD | 1 | 2 GB | 15 GB | 20 GB |
| **`ceph-osd2`** | `10.207.154.62` | Ceph OSD | 1 | 2 GB | 15 GB | 20 GB |
| **`ceph-osd3`** | `10.207.154.63` | Ceph OSD | 1 | 2 GB | 15 GB | 20 GB |

---

## 🚀 Escalar el Clúster (Añadir/Quitar Nodos de forma segura)

Este escenario permite escalar de forma completamente independiente tanto la capacidad de almacenamiento (nodos OSD en el Ceph externo) como la capacidad de cómputo (workers de K8s). Son dos clústeres distintos e independientes (K8s y Ceph externo, unidos solo por el driver CSI), así que un nodo nuevo pertenece a uno u otro, nunca a ambos.

**El caso de escalado por defecto de este laboratorio es añadir capacidad de ALMACENAMIENTO** (un nuevo OSD al clúster Ceph externo): el propósito específico del escenario 05, a diferencia del 02/03/04, no es demostrar el escalado de cómputo de un clúster HA (eso ya lo cubren los escenarios anteriores), sino precisamente **cómo se monta un clúster Ceph independiente y cómo se engancha a un clúster de Kubernetes externo vía CSI**. Por eso el flujo de referencia de esta sección es el de añadir un OSD; añadir un worker K8s puro se documenta también, pero es una operación genérica ya cubierta conceptualmente en los escenarios 02-04, no el foco de este laboratorio.

El proceso está separado en dos playbooks con responsabilidades distintas, igual que en los escenarios 03 y 04:

1.  **`13_add_node.yml` — Creación de la(s) VM(s) e integración de los workers K8s.** Crea las máquinas virtuales en LXD (para el grupo que corresponda) y, si has añadido nodos en `[new_workers]`, los une al clúster de Kubernetes. Si solo has añadido nodos Ceph (`[new_ceph_osds]`), este playbook únicamente crea sus VMs y deja pendiente la integración en Ceph.
2.  **`14_integrar_nodo_ceph_externo.yml` — Integración del nuevo OSD en el clúster Ceph externo.** Instala los requisitos (`python3`, `lvm2`) en los nuevos nodos Ceph y los da de alta en el clúster vía `cephadm` (`ceph orch host add` + escaneo de discos). **Este paso solo hace falta si has añadido nodos en `[new_ceph_osds]`**; si solo escalas cómputo K8s, no es necesario ejecutarlo.

### 1. Añadir un nodo de ALMACENAMIENTO (caso por defecto — nuevo OSD Ceph)
1. Abre `inventory.ini` y añade la línea en el grupo `[new_ceph_osds]`, especificando `lxd_ceph_disk`:
   ```ini
   [new_ceph_osds]
   ceph-osd4 ansible_host=10.207.154.64 lxd_cpu=1 lxd_mem=2GB lxd_disk=15GB lxd_ceph_disk=20GB
   ```
2. Crea la VM:
   ```bash
   ansible-playbook 13_add_node.yml
   ```
3. Intégrala en el clúster Ceph externo:
   ```bash
   ansible-playbook 14_integrar_nodo_ceph_externo.yml
   ```

### 2. Añadir un nodo de CÓMPUTO K8s (caso secundario, sin almacenamiento)
1. Abre `inventory.ini` y añade la línea en el grupo `[new_workers]` (sin `lxd_ceph_disk`, no aplica a este clúster):
   ```ini
   [new_workers]
   k8s-worker4 ansible_host=10.207.154.56 lxd_cpu=2 lxd_mem=2GB lxd_disk=15GB
   ```
2. Crea la VM y únela al clúster de Kubernetes (no hace falta ejecutar `14_integrar_nodo_ceph_externo.yml`, este nodo no es de Ceph):
   ```bash
   ansible-playbook 13_add_node.yml
   ```

### 3. Quitar Nodos
1. Ejecuta el playbook de eliminación especificando el nombre exacto del nodo:
   ```bash
   # Para eliminar un worker de K8s:
   ansible-playbook 15_eliminar_nodo.yml -e "node_name=k8s-worker3"

   # Para eliminar un OSD del clúster Ceph Externo:
   ansible-playbook 15_eliminar_nodo.yml -e "node_name=ceph-osd3"
   ```
   *El playbook gestiona los procesos específicos para cada uno:*
   *   *Nodos K8s: Drena el nodo de Kubernetes, limpia `kubeadm` y destruye la VM.*
   *   *Nodos Ceph: Fuerza la salida del host del orquestador Ceph (`ceph orch host rm`), destruye la VM y elimina el volumen de almacenamiento de disco de LXD.*
