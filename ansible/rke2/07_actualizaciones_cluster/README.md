# Laboratorio 07: Estrategias de Actualización de Clúster RKE2

Este laboratorio cubre los dos métodos principales para actualizar la versión de Kubernetes / RKE2 en un clúster de forma controlada y con mínima interrupción.

## 🛠️ Método 1: Actualización Manual / Automatizada con Ansible

En este método, se actualiza el binario de RKE2 nodo a nodo.

### Secuencia de actualización:
1. **Server Nodes:** De uno en uno (`serial: 1`).
   ```bash
   # En el Server Node:
   curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.31.2+rke2r1" sudo sh -
   sudo systemctl restart rke2-server
   ```
2. **Worker Nodes:** Drenar (`kubectl drain`), actualizar binario, reiniciar `rke2-agent` y reactivar (`kubectl uncordon`).
   ```bash
   kubectl drain <nodo-worker> --ignore-daemonsets --delete-emptydir-data
   # En el Worker Node:
   curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_VERSION="v1.31.2+rke2r1" sudo sh -
   sudo systemctl restart rke2-agent
   # En el Server:
   kubectl uncordon <nodo-worker>
   ```

---

## 🤖 Método 2: System Upgrade Controller de Rancher

Rancher proporciona el operador `system-upgrade-controller`, que automatiza la actualización del clúster mediante Custom Resources (`Plan`).

### 1. Desplegar el controlador:
```bash
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml
```

### 2. Ejemplo de Plan de Actualización para Server Nodes:
```yaml
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: server-plan
  namespace: system-upgrade
spec:
  concurrency: 1
  version: v1.31.2+rke2r1
  nodeSelector:
    matchExpressions:
      - {key: node-role.kubernetes.io/master, operator: In, values: ["true"]}
  serviceAccountName: system-upgrade
  cordon: true
  upgrade:
    image: rancher/rke2-upgrade
```
