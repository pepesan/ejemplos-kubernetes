# Laboratorio 07: Estrategias de Actualización de Clúster RKE2

Este laboratorio demuestra cómo realizar una **actualización de versión de Kubernetes/RKE2 sin interrupción (rolling upgrade)** en un clúster vivo, pasando de `v1.35.6+rke2r1` a `v1.36.2+rke2r1`, y despliega el **System Upgrade Controller** de Rancher para actualizaciones automáticas declarativas.

---

## 📋 Métodos de Actualización Cubiertos

### 1. Actualización Automatizada con Ansible (`10_upgrade_cluster.yml`)

El playbook ejecuta la secuencia de actualización recomendada por Rancher/RKE2:

1. **Server Nodes (`serial: 1`)**:
   - Comprueba la versión actual de RKE2 con `rke2 --version`.
   - Si difiere de `rke2_version_upgrade`, descarga el instalador y actualiza el binario Server.
   - Reinicia el servicio `rke2-server` y espera a que el nodo reporte `Ready`.
2. **Worker Nodes (`serial: 1`)**:
   - Drena el nodo trabajador (`kubernetes.core.k8s_drain`, evacuando pods con `--ignore-daemonsets --delete-emptydir-data`).
   - Actualiza el binario de RKE2 Agent con la nueva versión.
   - Reinicia `rke2-agent` y re-activa el nodo (`uncordon`).
   - Espera a que el nodo reporte `Ready`.
3. **Verificación**:
   - Consulta el API Server y afirma que todos los nodos reportan la versión `v1.36.2` en `status.nodeInfo.kubeletVersion`.

### 2. System Upgrade Controller de Rancher

El operador `system-upgrade-controller` (v0.20.1) se despliega automáticamente en el namespace `system-upgrade` junto con los manifiestos `Plan`:

- `templates/system-upgrade-controller.yaml`: Despliegue del controlador CRD `upgrade.cattle.io/v1`.
- `templates/upgrade-plan-server.yaml`: Plan de actualización para Server Nodes (`concurrency: 1`, filtro `node-role.kubernetes.io/control-plane`).
- `templates/upgrade-plan-worker.yaml`: Plan de actualización para Worker Nodes (`concurrency: 1`, `drain` habilitado, coordinado tras el `server-plan`).

---

## 🚀 Uso

```bash
# Desplegar el lab completo (VMs + RKE2 v1.35.6 + upgrade a v1.36.2 + System Upgrade Controller):
./run_all.sh

# Verificar las versiones de Kubernetes en los nodos:
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes -o wide

# Ver los planes del System Upgrade Controller:
kubectl get plans -n system-upgrade
kubectl get pods -n system-upgrade

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`) y 1 Worker (`rke2-worker1`). |
| `group_vars/all.yml` | `rke2_version: "v1.35.6+rke2r1"` y `rke2_version_upgrade: "v1.36.2+rke2r1"`. |
| `10_upgrade_cluster.yml` | Playbook lab-local: realiza el rolling upgrade, verifica la versión y despliega el System Upgrade Controller. |
| `templates/system-upgrade-controller.yaml` | Manifiesto v0.20.1 del controlador de upgrades de Rancher. |
| `templates/upgrade-plan-server.yaml` | CRD `Plan` para actualizar Server Nodes. |
| `templates/upgrade-plan-worker.yaml` | CRD `Plan` para actualizar Worker Nodes. |

---

## ✅ Validación

- **2026-08-05**: Validado en vivo con 2 ejecuciones consecutivas idempotentes (`changed=0` en la 2ª pasada). Nodos actualizados de `v1.35.6+rke2r1` a `v1.36.2+rke2r1` con drain/uncordon correcto y `system-upgrade-controller` desplegado.

---

## ⚙️ Requisitos Previos

- Ansible 2.16+
- LXD 5.0+ (para VMs)
- Acceso a una máquina con privilegios de root
- Kubectl instalado para verificar el clúster

---

## 🛠️ Solución de Problemas Comunes

### Problema: `rke2-server` no inicia después de actualización
- **Solución**: Verifica los logs del servicio:
  ```bash
  journalctl -u rke2-server.service -b
  ```

### Problema: Nodos en estado `NotReady`
- **Solución**: Reinicia el nodo manualmente y verifica que se conecte al clúster:
  ```bash
  systemctl restart rke2-agent
  kubectl get nodes
  ```

### Problema: Error de permisos en LXD
- **Solución**: Asegúrate de ejecutar con usuario con permisos de LXD:
  ```bash
  sudo usermod -aG lxd $USER
  newgrp lxd
  ```