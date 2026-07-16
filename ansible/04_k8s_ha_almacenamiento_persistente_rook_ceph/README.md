# Laboratorio K8s Multi-Node con Rook Ceph Hiperconvergente sobre LXD

Este laboratorio contiene una serie de playbooks de Ansible para desplegar de forma automatizada un clúster de Kubernetes (1 nodo Control-Plane/Manager y 3 nodos Workers) y, sobre este, aprovisionar un clúster de almacenamiento distribuido Ceph utilizando el operador **Rook**.

Cada nodo worker cuenta con un disco virtual secundario `/dev/vdb` que Rook Ceph utilizará automáticamente para crear OSDs (Object Storage Daemons) y replicar los datos en 3 vías.

## 📋 Estructura de Playbooks

*   **`ansible.cfg`**: Configuración de Ansible para este entorno.
*   **`inventory.ini`**: Definición de los nodos con sus IPs estáticas:
    *   `k8s-manager` (`10.207.154.50` - 4GB RAM, 4 CPUs, 20GB root disk)
    *   `k8s-worker1` (`10.207.154.51` - 6GB RAM, 4 CPUs, 20GB root disk + 20GB disk OSD Ceph)
    *   `k8s-worker2` (`10.207.154.52` - 6GB RAM, 4 CPUs, 20GB root disk + 20GB disk OSD Ceph)
    *   `k8s-worker3` (`10.207.154.53` - 6GB RAM, 4 CPUs, 20GB root disk + 20GB disk OSD Ceph)
*   **`group_vars/all.yml`**: Variables globales del sistema (red, versión de k8s, etc.).
*   **`../check_requisitos.yml`**: Playbook unificado en el directorio raíz. Se encarga de verificar las herramientas locales del host (LXD, red, imagen base) y asegurar la actualización de las colecciones de Ansible.
*   **`02_crear_nodos.yml`**: Creación de las 4 máquinas virtuales de LXD, inyección de claves SSH y **adición en caliente del disco secundario `ceph-disk` de 20GB** en cada uno de los workers.
*   **`03_configurar_os.yml`**: Ajustes de kernel y sysctl obligatorios para Kubernetes en todos los nodos.
*   **`04_instalar_containerd.yml`**: Instalación del Container Runtime Interface (CRI) en todo el clúster.
*   **`05_instalar_k8s_tools.yml`**: Instalación de `kubeadm`, `kubelet` y `kubectl` en todos los nodos.
*   **`06_inicializar_manager.yml`**: Inicialización del plano de control en el Manager, configuración de CNI Flannel y generación/propagación del token de unión.
*   **`07_unir_workers.yml`**: Ejecución de `kubeadm join` en los workers para conectarlos al Manager de forma automatizada.
*   **`08_desplegar_rook_ceph.yml`**: Despliegue del operador de Rook Ceph y creación del clúster Ceph (`CephCluster` con 3 réplicas) junto con las clases de almacenamiento `ceph-block` (RBD / RWO) y `ceph-filesystem` (CephFS / RWX). Se configura con recursos ligeros adaptados para el laboratorio (mon/mgr: 512Mi, osd: 1Gi). La StorageClass `ceph-filesystem` se crea aparte (no vía el chart) apuntando al `ClientProfile` de ceph-csi-operator correcto para el subvolume group, ya que el `clusterID` que genera el chart por defecto no lo resuelve. La contraseña del Ceph Dashboard se guarda en `ceph_dashboard_password.txt` (fuera de git).
*   **`09_verificar_rook_persistencia.yml`**: Verificación de persistencia mediante la creación de PVCs de prueba RBD y CephFS, y la validación de lecturas/escrituras concurrentes desde pods de prueba.
*   **`10_desplegar_prometheus.yml`**: Despliegue de un Prometheus mínimo (namespace `monitoring`, sin Alertmanager/Grafana) que scrapea el exporter de `rook-ceph-mgr`, y configuración del Ceph Dashboard para usarlo (`ceph dashboard set-prometheus-api-host`), evitando los errores 404 al consultar métricas desde el dashboard. También despliega de forma permanente el pod `rook-ceph-tools` (namespace `rook-ceph`) con credenciales admin, útil para ejecutar comandos `ceph` manualmente.
*   **`11_desplegar_headlamp.yml`**: Despliegue del dashboard web Headlamp expuesto vía NodePort en el puerto `32082` del Manager.
*   **`20_destroy.yml`**: Detención forzada y eliminación de las máquinas virtuales de LXD, además de la limpieza de archivos locales y almacenamiento.

## 🚀 Uso del Laboratorio

1.  Otorga permisos de ejecución a los scripts:
    ```bash
    chmod +x run_all.sh destroy_all.sh
    ```

2.  Ejecuta el despliegue automático del clúster:
    ```bash
    ./run_all.sh
    ```

3.  Para interactuar con el clúster usando `kubectl` desde tu host, Ansible te dejará el archivo `kubeconfig.yaml` en esta carpeta. Puedes usarlo así:
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig.yaml
    kubectl get nodes -o wide
    ```

4.  **Acceso al Dashboard (Headlamp):**
    *   **URL:** [http://10.207.154.50:32082](http://10.207.154.50:32082)
    *   **Token:** Abre el archivo generado [headlamp_token.txt](headlamp_token.txt) para copiar el token de administrador e iniciar sesión.

5.  **Acceso a la Consola de Monitoreo de Ceph (Ceph Dashboard):**
    *   **Contraseña:** Abre el archivo generado [ceph_dashboard_password.txt](ceph_dashboard_password.txt).
    *   **Acceso:** Entra en tu navegador a: **[http://10.207.154.50:32070](http://10.207.154.50:32070)** (Usuario: `admin`).
    *   Las gráficas de métricas del dashboard usan el Prometheus desplegado en el paso `10` (namespace `monitoring`).

6.  **Escalar el Clúster (Añadir/Quitar nodos):**

    A diferencia de Longhorn (escenario 03), aquí **no existe la opción de añadir un nodo de cómputo puro sin almacenamiento**: todo nodo que se añade a este laboratorio es, por diseño, un nodo de almacenamiento (recibe siempre un disco secundario para OSD). Es decir, el comportamiento es "almacenamiento por defecto" de forma incondicional, sin necesidad de ninguna excepción ni lista de opt-out — simplemente no se ofrece la alternativa de cómputo-sin-disco en este escenario.

    *   **Añadir un nuevo nodo worker (con disco Ceph OSD):**
        1. Abre el archivo `inventory.ini` y define el nuevo nodo en el grupo `[new_workers]`. Recuerda especificar la variable `lxd_ceph_disk`. Por ejemplo:
           ```ini
           [new_workers]
           k8s-worker4 ansible_host=10.207.154.54 lxd_cpu=4 lxd_mem=6GB lxd_disk=20GB lxd_ceph_disk=20GB
           ```
        2. Ejecuta el playbook de creación y unión al clúster de Kubernetes:
           ```bash
           ansible-playbook 13_add_node.yml
           ```
        3. Ejecuta el playbook de integración en Rook Ceph:
           ```bash
           ansible-playbook 14_integrar_nodo_rook_ceph.yml
           ```
           *Rook Ceph detectará de forma automática el nuevo nodo y expandirá el almacenamiento aprovisionando un OSD en su disco secundario /dev/vdb.*
    *   **Quitar un nodo worker (con disco Ceph OSD):**
        1. Ejecuta el playbook de eliminación especificando el nombre del nodo:
           ```bash
           ansible-playbook 15_eliminar_nodo.yml -e "node_name=k8s-worker3"
           ```
           *Esto drenará el nodo, lo eliminará de Kubernetes, destruirá su VM en LXD y eliminará su volumen de almacenamiento OSD, obligando a Ceph a redistribuir y reconstruir los datos en los workers restantes.*

7.  Para limpiar todo el entorno y liberar recursos de tu máquina:
    ```bash
    ./destroy_all.sh
    ```
