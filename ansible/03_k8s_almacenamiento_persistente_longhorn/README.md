# 💾 Escenario 03: Almacenamiento Distribuido Replicado con Longhorn

Este laboratorio despliega un clúster de Kubernetes avanzado de **6 nodos** virtuales sobre LXD, divididos estrictamente por funciones: **plano de control**, **nodos de cómputo (carga de trabajo)** y **nodos de almacenamiento dedicado**.

Utiliza **Longhorn** como motor de almacenamiento de bloques y sistema de archivos distribuido nativo de Kubernetes para dar soporte a volúmenes persistentes multi-nodo (**ReadWriteMany - RWX**) y mono-nodo (**ReadWriteOnce - RWO**) con tolerancia a fallos mediante replicación en 3 vías.

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

En la pestaña **Nodes**, verás que:
*   `k8s-storage1`, `k8s-storage2` y `k8s-storage3` muestran espacio de disco disponible y albergan las réplicas.
*   `k8s-worker1` y `k8s-worker2` aparecen en la lista pero sin ningún disco activo asignado (0 bytes para almacenamiento).

### Destruir el Entorno:
Para detener, eliminar las 6 VMs y limpiar los archivos locales del host:
```bash
./destroy_all.sh
```
