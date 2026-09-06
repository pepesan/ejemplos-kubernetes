# 💾 Escenario 03: Almacenamiento Distribuido Replicado con Longhorn

Este laboratorio despliega un clúster de Kubernetes avanzado de **6 nodos** virtuales sobre LXD, divididos estrictamente por funciones: **plano de control**, **nodos de cómputo (carga de trabajo)** y **nodos de almacenamiento dedicado**.

Utiliza **Longhorn** como motor de almacenamiento de bloques y sistema de archivos distribuido nativo de Kubernetes para dar soporte a volúmenes persistentes multi-nodo (**ReadWriteMany - RWX**) y mono-nodo (**ReadWriteOnce - RWO**) con tolerancia a fallos mediante replicación en 3 vías.

## 💻 Requisitos del Host

Recursos que este laboratorio reserva en LXD (8 VMs) — el host debe tener al menos esto libre, más margen para su propio sistema operativo:

| Nodos | vCPU (c/u) | RAM (c/u) | Disco (c/u) |
|-------|------------|-----------|-------------|
| 3 managers | 2 | 3 GB | 20 GB |
| 2 workers (cómputo) | 2 | 2 GB | 15 GB |
| 3 workers (storage) | 1 | 2 GB | 15 GB |

**Total: 13 vCPU · 19 GB RAM · 135 GB disco** (+ margen recomendado para el host: 2 vCPU / 2 GB RAM / 10 GB disco libres adicionales)

## 📋 Estructura de Playbooks

*   **`ansible.cfg`**: Configuración de Ansible para este entorno.
*   **`inventory.ini`**: Definición de los 6 nodos LXD.
*   **`group_vars/all.yml`**: Variables globales del sistema (red, versión de k8s, etc.).
*   **`../check_requisitos.yml`**: Playbook unificado en el directorio raíz. Se encarga de verificar las herramientas locales del host (LXD, red, imagen base) y asegurar la actualización de las colecciones de Ansible.
*   **`02_crear_nodos.yml`**: Creación de las 8 máquinas virtuales de LXD e inyección de claves SSH.
*   **`03_configurar_os.yml`**: Ajustes de kernel, sysctl y dependencias de Longhorn (`open-iscsi`, `nfs-common`) en los nodos.
*   **`04_instalar_containerd.yml`**: Instalación del Container Runtime Interface (CRI) en todo el clúster.
*   **`05_instalar_k8s_tools.yml`**: Instalación de `kubeadm`, `kubelet` y `kubectl` en todos los nodos.
*   **`06_inicializar_primer_manager.yml`**: Inicialización del primer manager (kube-vip + `kubeadm init` con `--control-plane-endpoint` y `--upload-certs`).
*   **`07_unir_managers.yml`**: Unión de los managers adicionales al plano de control HA vía `--certificate-key`.
*   **`08_unir_workers.yml`**: Ejecución de `kubeadm join` en los workers y storage nodes para conectarlos al clúster (vía la VIP).
*   **`09_desplegar_headlamp.yml`**: Despliegue de Headlamp Dashboard vía Helm y configuración del token de acceso administrador, justo después de formar el clúster para poder seguir el resto de despliegues desde su consola web.
*   **`10_desplegar_longhorn.yml`**: Despliegue de Longhorn Engine y Dashboard en Kubernetes usando Helm.
*   **`11_verificar_persistencia_rwx.yml`**: Verificación de persistencia mediante la creación de un PVC RWX y la validación de lecturas/escrituras concurrentes desde pods de prueba.
*   **`12_add_node.yml`** / **`13_integrar_nodo_longhorn.yml`** / **`14_eliminar_nodo.yml`**: Playbooks de escalado (añadir/quitar nodos) — ver la sección "Escalar el Clúster" más abajo.
*   **`20_destroy.yml`**: Detención forzada y eliminación de las máquinas virtuales de LXD, además de la limpieza de archivos locales.

---

## 🆚 Diferencias respecto al ejemplo 02 (base HA sin storage)

Este escenario 03 parte del clúster HA del ejemplo `02_k8s_base_ha_3_managers_3_workers`
y le añade Longhorn. Los playbooks `02` (crear nodos), `04` (containerd), `05` (kubeadm/
kubelet/kubectl), `06`-`08` (inicializar/unir managers y workers) y `09` (Headlamp) son
simples `import_playbook` de sus equivalentes en el 02 — no tienen tareas propias, para
no duplicar esa lógica entre labs. Los que sí cambian, y por qué, son:

*   **`03_configurar_os.yml`**: en el 02 este playbook aplica directamente el ajuste
    base del sistema operativo (swap, módulos de kernel, sysctl, `/dev/kmsg`...). Aquí
    ese ajuste se **reutiliza sin cambios** vía `import_playbook` del propio 02, y se le
    añade un segundo play exclusivo de Longhorn que instala `open-iscsi`/
    `iscsi-initiator-utils` (Longhorn expone cada réplica como un target iSCSI local;
    sin el iniciador el kubelet no puede montarlas) y `nfs-common`/`nfs-utils`
    (necesario para el modo ReadWriteMany, que Longhorn implementa reexportando el
    volumen por NFS), y se asegura de que el servicio `iscsid` quede arrancado y
    habilitado en el arranque.
*   **`10_desplegar_longhorn.yml`** (sin equivalente en el 02, que en su paso 10
    despliega una app de prueba sin storage persistente): etiqueta los nodos según su
    rol (`workload_workers` / `storage_workers` del inventario), aplica el taint
    `storage-node=true:NoSchedule` a los nodos de storage y despliega Longhorn vía Helm
    con 3 réplicas por defecto y su UI expuesta como NodePort en el puerto 32085.
*   **`11_verificar_persistencia_rwx.yml`** (sin equivalente en el 02, cuyo paso 11
    valida la alta disponibilidad del *plano de control*, no el almacenamiento): crea
    un PVC RWX, despliega 2 pods que escriben a la vez sobre el mismo volumen
    compartido, y comprueba leyendo el fichero resultante que contiene líneas de
    ambos hostnames — demostrando que el volumen es realmente compartido entre nodos.
*   **`12_add_node.yml`** (evolución de `12_adicionar_nodo.yml` del 02): se renombra
    porque aquí un nodo nuevo ya no es "un worker más" — puede terminar siendo de
    storage o de workload. Este playbook solo se ocupa de la infraestructura
    (VM LXD + `kubeadm join`); deliberadamente **no asigna ningún rol de Longhorn**,
    para poder reutilizarlo tal cual en escenarios que no usan Longhorn. Termina
    indicando que el siguiente paso obligatorio es `13_integrar_nodo_longhorn.yml`.
*   **`13_integrar_nodo_longhorn.yml`** (sin equivalente en el 02, que no tiene
    concepto de rol de nodo): segundo paso al añadir un nodo — decide su rol con la
    regla "almacenamiento por defecto, cómputo como excepción" (ver más abajo) y le
    aplica las labels y el taint correspondientes.
*   **`14_eliminar_nodo.yml`** (evolución de `13_eliminar_nodo.yml` del 02, renumerado
    a 14 por ir tras el nuevo paso 13): antes de drenar el nodo comprueba si tiene la
    label `node.longhorn.io/storage-node`; si es un nodo de storage, primero desactiva
    el *scheduling* de réplicas en Longhorn (`allowScheduling: false`) y espera unos
    segundos para que Longhorn deje de intentar reconstruir réplicas ahí, y al final
    borra también su recurso `nodes.longhorn.io` explícitamente (si no, Longhorn lo
    seguiría viendo como un nodo "perdido" en su propio inventario).
*   **`group_vars/all.yml`**: añade `longhorn_chart_version`, `longhorn_test_pvc_size`
    y `test_alpine_image`, variables que no existen en el 02.
*   **Inventario (`inventory.ini`)**: añade los grupos `workload_workers` y
    `storage_workers` (y, para el escalado, `new_workload_workers`) que no existen en
    el 02, donde todos los workers son equivalentes entre sí.

### ⚠️ Variables compartidas con el ejemplo 02 — ¿dónde tengo que cambiar la versión?

Los playbooks `02`, `04`, `05`, `06`, `07`, `08`, `09` (y el primer play del `03`) de
este lab **no tienen tareas propias**: son un `import_playbook` del fichero equivalente
en `../02_k8s_base_ha_3_managers_3_workers/`, para no duplicar esa lógica entre labs.
Por ejemplo, `05_instalar_k8s_tools.yml` de este 03 es literalmente:

```yaml
---
- import_playbook: ../02_k8s_base_ha_3_managers_3_workers/05_instalar_k8s_tools.yml
```

**El problema**: Ansible carga `group_vars/`/`host_vars/` de forma independiente para
cada fichero de playbook que participa en la ejecución — no solo del que se lanza desde
`ansible-playbook`/`run_all.sh`. Como la tarea real que instala `kubelet`/`kubeadm`/
`kubectl` vive físicamente en el directorio del ejemplo 02, para esa tarea concreta
Ansible también lee `../02_k8s_base_ha_3_managers_3_workers/group_vars/all.yml` — y ese
valor **gana** sobre el de `group_vars/all.yml` de este 03.

Consecuencia real que motivó esta nota: se cambió aquí `k8s_major_version` de `v1.36` a
`v1.37`, se ejecutó `run_all.sh`, y el clúster se instaló igualmente con `v1.36` —
porque el `group_vars/all.yml` del ejemplo 02 todavía decía `v1.36`.

**Variables afectadas por este mecanismo** (usadas dentro de playbooks importados del
02) y **dónde hay que tocarlas**:

| Variable | Se aplica en | Hay que cambiarla en |
| :--- | :--- | :--- |
| `k8s_major_version` | `05_instalar_k8s_tools.yml` (import del 02) | **group_vars/all.yml del 02 Y del 03** (los dos, a la vez) |
| `kube_vip_image` | `06_inicializar_primer_manager.yml` (import del 02) | **group_vars/all.yml del 02 Y del 03** (los dos, a la vez) |
| `k8s_vip_address` / `k8s_vip_port` / `k8s_vip_interface` | `02`, `06`, `07`, `08` (imports del 02) | **group_vars/all.yml del 02 Y del 03** (los dos, a la vez) |
| `lxd_image` / `lxd_network` / `lxd_kernel_modules` | `02`, `03` (imports del 02) | **group_vars/all.yml del 02 Y del 03** (los dos, a la vez) |
| `headlamp_chart_version` | `09_desplegar_headlamp.yml` (import del 02) | **group_vars/all.yml del 02 Y del 03** (los dos, a la vez) |
| `longhorn_chart_version`, `longhorn_test_pvc_size`, `test_alpine_image` | `10`, `11` (propios de este 03, no existen en el 02) | Solo `group_vars/all.yml` del 03 |

**Regla práctica**: si la variable que quieres cambiar también existe en
`../02_k8s_base_ha_3_managers_3_workers/group_vars/all.yml`, cámbiala en **ambos**
ficheros a la vez, o el cambio en el 03 no tendrá ningún efecto en los playbooks
importados. `group_vars/all.yml` de este 03 lleva un aviso `⚠️` en cada variable
afectada, con esta misma indicación.

---

## 📐 Arquitectura del Clúster (Separación de Roles)

Para evitar que el tráfico de E/S del almacenamiento y la replicación del disco afecte al rendimiento de tus aplicaciones (y viceversa), el clúster separa los nodos de carga de trabajo de los nodos de almacenamiento utilizando **Taints & Labels**.

```mermaid
graph TD
    subgraph Plano de Control
        Manager["k8s-manager (10.207.154.50)<br/>Control Plane<br/>Taint: NoSchedule"]
    end

    subgraph Nodos de Cómputo (Carga de Trabajo)
        Worker1["k8s-worker1 (10.207.154.51)<br/>Pod escritor (Replica 1)<br/>Label: workload-node=true"]
        Worker2["k8s-worker2 (10.207.154.52)<br/>Pod escritor (Replica 2)<br/>Label: workload-node=true"]
    end

    subgraph Nodos de Almacenamiento Dedicados
        Storage1["k8s-storage1 (10.207.154.56)<br/>Réplica de Datos 1 (Longhorn)<br/>Taint: storage-node=true:NoSchedule"]
        Storage2["k8s-storage2 (10.207.154.57)<br/>Réplica de Datos 2 (Longhorn)<br/>Taint: storage-node=true:NoSchedule"]
        Storage3["k8s-storage3 (10.207.154.58)<br/>Réplica de Datos 3 (Longhorn)<br/>Taint: storage-node=true:NoSchedule"]
    end

    Worker1 & Worker2 -->|Petición PVC RWX| Manager
    Manager -->|CSI Provisioner| Storage1 & Storage2 & Storage3
    Worker1 & Worker2 -->|Montaje NFS CSI| Storage1 & Storage2 & Storage3
```

---

## 📋 Inventario de Nodos LXD

Las máquinas virtuales se crean en Ubuntu 26.04 con los siguientes perfiles de recursos optimizados:

| Nombre | Dirección IP | Función / Rol | CPU | Memoria | Disco |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`k8s-manager`** | `10.207.154.50` | Control Plane | 2 | 3 GB | 20 GB |
| **`k8s-worker1`** | `10.207.154.51` | Cómputo (Workload) | 2 | 2 GB | 15 GB |
| **`k8s-worker2`** | `10.207.154.52` | Cómputo (Workload) | 2 | 2 GB | 15 GB |
| **`k8s-storage1`** | `10.207.154.56` | Almacenamiento Réplica | 1 | 1.5 GB | 15 GB |
| **`k8s-storage2`** | `10.207.154.57` | Almacenamiento Réplica | 1 | 1.5 GB | 15 GB |
| **`k8s-storage3`** | `10.207.154.58` | Almacenamiento Réplica | 1 | 1.5 GB | 15 GB |

---

## 🔒 Aislamiento y Configuración de Longhorn

### 1. Taints y Tolerancias
Para evitar que las aplicaciones normales de los usuarios se programen en los nodos de almacenamiento, los nodos `k8s-storage1`, `k8s-storage2` y `k8s-storage3` se marcan con un Taint:
*   `storage-node=true:NoSchedule`

El Helm Chart de Longhorn configura estas tolerancias:
*   `defaultSettings.taintToleration="storage-node=true:NoSchedule"` para los componentes gestionados por Longhorn (CSI y componentes del sistema).
*   `longhornManager.tolerations` para que el DaemonSet `longhorn-manager` también pueda ejecutarse en los nodos de almacenamiento.

Con ambas configuraciones, todos los componentes necesarios de Longhorn ignoran el Taint y `longhorn-manager` registra los tres discos de almacenamiento dedicados. Las aplicaciones normales, sin toleración, se quedan en `k8s-worker1` y `k8s-worker2`.

### 2. Discos de Réplicas Limitados
Para evitar que Longhorn guarde datos en los nodos de cómputo:
*   Se activa la directiva `defaultSettings.createDefaultDiskLabeledNodes=true`.
*   Solo los nodos de almacenamiento se etiquetan con `node.longhorn.io/create-default-disk=true`.
*   Esto asegura que **el 100% de los datos replicados se aloja físicamente en los tres nodos de storage dedicados**.

---

## 🚀 Instrucciones de Uso

### Desplegar el Entorno:
1. Accede al directorio del escenario:
   ```bash
   cd 03_k8s_almacenamiento_persistente_longhorn
   ```
2. Ejecuta el script de despliegue completo:
   ```bash
   ./run_all.sh
   ```

### Acceso al Panel de Longhorn:
Una vez terminado el script, abre tu navegador y entra en la interfaz web de Longhorn expuesta en el Manager:
*   🔗 **Longhorn Dashboard:** [http://10.207.154.50:32085](http://10.207.154.50:32085)

### Acceso al Dashboard (Headlamp):
*   🔗 **Headlamp Dashboard:** [http://10.207.154.50:32082](http://10.207.154.50:32082) (vía la VIP del plano de control)
*   **Token:** guardado en `headlamp_token.txt` tras ejecutar `run_all.sh`. Para consultarlo o regenerarlo manualmente:
    ```bash
    kubectl --kubeconfig=kubeconfig.yaml create token headlamp-admin -n headlamp --duration=8760h
    ```

En la pestaña **Nodes**, verás que:
*   `k8s-storage1`, `k8s-storage2` y `k8s-storage3` muestran espacio de disco disponible y albergan las réplicas.
*   `k8s-worker1` y `k8s-worker2` aparecen en la lista pero sin ningún disco activo asignado (0 bytes para almacenamiento).

### Escalar el Clúster (Añadir/Quitar nodos):

El proceso de añadir un nodo está deliberadamente separado en **dos playbooks independientes**, cada uno con una responsabilidad distinta:

1.  **`12_add_node.yml` — Creación de la VM y unión al clúster de Kubernetes.**
    Solo se ocupa de la infraestructura: crea la máquina virtual en LXD, instala el sistema operativo/containerd/kubeadm, y ejecuta `kubeadm join` para incorporar el nodo al clúster de Kubernetes ya existente (a través de la VIP). Al terminar, el nodo aparece en `kubectl get nodes` como un worker más, **sin ningún rol de Longhorn todavía**.
2.  **`13_integrar_nodo_longhorn.yml` — Integración específica en Longhorn.**
    Una vez que el nodo ya es parte del clúster de Kubernetes, este segundo playbook decide su **rol de almacenamiento**: le aplica las labels (`node.longhorn.io/storage-node` o `node.longhorn.io/workload-node`) y, si corresponde, el taint `storage-node=true:NoSchedule` que impide que se le asignen pods de carga de trabajo normal.

Esta separación permite razonar cada paso por separado (¿el nodo ya está en el clúster? ¿ya tiene el rol correcto de Longhorn?) y reutilizar `12_add_node.yml` tal cual en otros escenarios que no usan Longhorn.

*   **¿Cómo decide `13_integrar_nodo_longhorn.yml` si el nodo es workload o storage?**
    La regla es **"almacenamiento por defecto, cómputo como excepción"**:
    *   Cualquier nodo que añadas en el grupo `[new_workers]` de `inventory.ini` se integra **por defecto como nodo de ALMACENAMIENTO** (recibe las labels de storage y el taint dedicado — no correrá pods de aplicación, solo réplicas de Longhorn).
    *   Si en cambio quieres que ese nodo sea de **cómputo puro (workload)**, sin rol de almacenamiento, debes añadir su nombre de host **también**, y solo el nombre (sin repetir `ansible_host=...`, esas variables ya están definidas en `[new_workers]`), al grupo `[new_workload_workers]`. Es una lista de excepción (opt-out): estar ahí es lo único que saca a un nodo del rol de storage por defecto.

    Ejemplo — añadir `k8s-storage4` como nodo de almacenamiento (comportamiento por defecto, no hace falta nada más):
    ```ini
    [new_workers]
    k8s-storage4 ansible_host=10.207.154.59 lxd_cpu=1 lxd_mem=2GB lxd_disk=15GB
    ```
    Ejemplo — añadir `k8s-worker3` como nodo de cómputo (workload), excluido explícitamente del rol de storage:
    ```ini
    [new_workers]
    k8s-worker3 ansible_host=10.207.154.58 lxd_cpu=2 lxd_mem=2GB lxd_disk=15GB

    [new_workload_workers]
    k8s-worker3
    ```

*   **Añadir nuevos nodos — pasos:**
    1. Edita `inventory.ini` como se describe arriba.
    2. Crea la VM y únela al clúster de Kubernetes:
       ```bash
       ansible-playbook 12_add_node.yml
       ```
    3. Intégralo en Longhorn (por defecto como storage, salvo que lo hayas puesto en `[new_workload_workers]`):
       ```bash
       ansible-playbook 13_integrar_nodo_longhorn.yml
       ```
*   **Quitar un nodo (workload o storage):**
    1. Ejecuta el playbook de eliminación especificando el nombre del nodo:
       ```bash
       ansible-playbook 14_eliminar_nodo.yml -e "node_name=k8s-storage3"
       ```
       *Nota: Si eliminas un nodo de storage, el playbook desactivará automáticamente la programación de Longhorn en él para migrar réplicas activas antes de borrarlo de Kubernetes.*

### Destruir el Entorno:
Para detener, eliminar las 6 VMs y limpiar los archivos locales del host:
```bash
./destroy_all.sh
```
