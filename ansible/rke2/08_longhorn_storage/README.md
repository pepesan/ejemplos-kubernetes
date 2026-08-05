# Laboratorio 08: Módulo Completo de Almacenamiento Persistente con Longhorn

Este laboratorio implementa el temario completo de los módulos **"5.- Almacenamiento Avanzado"** y **"6.- Longhorn"**, demostrando desde los conceptos de PVs, PVCs, StorageClasses y modos de acceso (RWO y RWX) hasta la automatización en Ansible del despliegue de Longhorn, operaciones de volumen en vivo y tolerancia a fallos.

---

## 📋 Mapeo con los Temarios "5.- Almacenamiento Avanzado" y "6.- Longhorn"

### Temario "5.- Almacenamiento Avanzado"
| Punto del Temario | Ejemplo e Implementación en el Lab | Fichero / Tarea |
| --- | --- | --- |
| **• Introducción** | Conceptos de abstracción de almacenamiento persistente desacoplado del ciclo de vida del Pod. | Documentado en `README.md` |
| **• Persistent Volumes (PV)** | Creación automática del `PersistentVolume` subyacente asignado dinámicamente por el aprovisionador de Longhorn. | `10_instalar_longhorn.yml` (Play 4 y 5) |
| **• Persistent Volume Claims (PVC)** | Manifiestos K8s de solicitud de almacenamiento: PVC RWO (`longhorn-test-pvc`) y PVC RWX (`longhorn-rwx-pvc`). | `10_instalar_longhorn.yml` (Play 4 y 5) |
| **• Modos de Acceso** | Verificación de los modos de acceso soportados: `ReadWriteOnce` (exclusivo a un solo nodo) y `ReadWriteMany` (compartido). | `10_instalar_longhorn.yml` (Play 4 y 5) |
| **• ReadWriteMany (RWX)** | Acceso concurrente de múltiples Pods corriendo en nodos distintos (`rke2-worker1` y `rke2-worker2`) escribiendo/leyendo en el mismo volumen. | `10_instalar_longhorn.yml` (Play 5) |
| **• Storage Classes** | Registro y verificación de la `StorageClass` `longhorn` (driver `driver.longhorn.io`) con aprovisionamiento dinámico. | `10_instalar_longhorn.yml` (Play 3) |

### Temario "6.- Longhorn"

| Punto del Temario | Implementación / Ejemplo en el Lab | Estado / Fichero |
| --- | --- | --- |
| **• Introducción** | Solución Cloud-Native Distributed Block Storage (CNCF Sandbox / Rancher) diseñada para Kubernetes. | Documentado en `README.md` |
| **• Funcionalidades** | Replicación sincrónica iSCSI, snapshots, backup a S3/NFS, volumen expansion en caliente, volumen cloning y soporte RWX. | Documentado en `README.md` |
| **• Instalación** | Habilitación de `iscsid.service` y `iscsi_tcp` + despliegue del Helm Chart `longhorn/longhorn` (v1.12.0) en `longhorn-system`. | `10_instalar_longhorn.yml` (Play 1 y 2) |
| **• Configuración básica** | Registro y verificación de la `StorageClass` por defecto `longhorn` con replicación en 3 nodos. | `10_instalar_longhorn.yml` (Play 3) |
| **• Creación Volúmenes** | Aprovisionamiento dinámico de `PersistentVolumeClaim` (PVC `longhorn-test-pvc`) de `1Gi`. | `10_instalar_longhorn.yml` (Play 4) |
| **• Ampliación de Volumen** | **Online Expansion en vivo**: modificación declarativa del PVC de `1Gi` a `2Gi` sin detener la carga de trabajo (`busybox`). | `10_instalar_longhorn.yml` (Play 4) |
| **• Reducción de Volumen** | Explicación técnica de la restricción de la API de Kubernetes (los campos de PVC son inmutables para reducción). | Documentado en `README.md` |
| **• Acceso al Volumen** | Modo de acceso exclusivo `ReadWriteOnce` (RWO) montado en `longhorn-test-pod`. | `10_instalar_longhorn.yml` (Play 4) |
| **• ReadWriteMany (RWX)** | Modo de acceso concurrente multi-nodo `ReadWriteMany` (RWX) con `share-manager` NFS, montado simultáneamente en `rke2-worker1` y `rke2-worker2`. | `10_instalar_longhorn.yml` (Play 5) |

---

## ⚙️ Arquitectura del Almacenamiento

```mermaid
graph TD
    subgraph Clúster RKE2 HA (3S + 3W)
        subgraph Control Plane / Managers
            S1["rke2-server1 (10.207.154.61)"]
            S2["rke2-server2 (10.207.154.62)"]
            S3["rke2-server3 (10.207.154.63)"]
        end

        subgraph Workers (Longhorn Replicas & Share Manager)
            W1["rke2-worker1 (10.207.154.64)<br/>Pod 1 RWO / RWX Writer 1"]
            W2["rke2-worker2 (10.207.154.65)<br/>RWX Writer 2"]
            W3["rke2-worker3 (10.207.154.66)<br/>Longhorn Replicas"]
        end

        VIP["VIP Control Plane (10.207.154.60)"]
    end

    RWO_PVC["PVC RWO 1Gi -> 2Gi (Expanded)"] --> SC["StorageClass longhorn"]
    RWX_PVC["PVC RWX (ReadWriteMany)"] --> NFSSM["Longhorn NFS Share-Manager"]
    NFSSM --> W1
    NFSSM --> W2
```

---

## 🔍 Detalle Técnico: Reducción de Volúmenes en Kubernetes

En Kubernetes y Longhorn, **la reducción de tamaño de un PVC (Shrinking) NO está permitida por la especificación de la API de Kubernetes** (`field is immutable: status.capacity`). 

Si un usuario intenta reducir el campo `storage` de un PVC en un manifiesto o comando `kubectl`, la API de Kubernetes rechazará la solicitud con un error HTTP 422:
> *Forbidden: field is immutable: spec.resources.requests.storage*.

### Procedimiento estándar para Reducir Almacenamiento:
1. Crear una nueva `PVC` de menor tamaño (p. ej. `1Gi`).
2. Copiar los datos desde la PVC grande a la nueva PVC (usando un Pod de migración o un Job de `rsync`/`cp`).
3. Apuntar la aplicación a la nueva PVC y eliminar la PVC antigua.

---

## 🚀 Uso del Laboratorio

```bash
# Desplegar el clúster HA (6 VMs) + Longhorn + Operaciones de Volumen (RWO, 2Gi Expansion, RWX):
./run_all.sh

# Exportar el kubeconfig local:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Verificar el estado de los nodos:
kubectl get nodes -o wide

# Verificar PVCs (longhorn-test-pvc de 2Gi y longhorn-rwx-pvc):
kubectl get pvc -A

# Verificar Pods montando volumen ReadWriteMany en distintos workers:
kubectl get pod longhorn-rwx-pod1 longhorn-rwx-pod2 -o wide

# Acceder al Dashboard UI de Longhorn:
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Abrir en el navegador: http://localhost:8080

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 3 Servers (`rke2-server1/2/3`) + 3 Workers (`rke2-worker1/2/3`). |
| `group_vars/all.yml` | Variables del clúster RKE2 (v1.36.3+rke2r1), VIP (10.207.154.60) y Longhorn (v1.12.0). |
| `10_instalar_longhorn.yml` | Playbook Ansible con la automatización completa de prerrequisitos iSCSI, Helm, StorageClass, Online Expansion 1Gi->2Gi y acceso RWX multi-nodo. |
| `run_all.sh` / `destroy_all.sh` | Scripts de ciclo de vida del laboratorio. |

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` confirma que el release de Helm, los servicios iSCSI, la PVC expandida de 2Gi y los pods RWX están presentes sin provocarse modificaciones innecesarias (`changed=0`).
