# Laboratorio 05: Clúster en Alta Disponibilidad (HA) con etcd Embebido

Este laboratorio describe cómo desplegar un clúster RKE2 en **Alta Disponibilidad (HA)** formado por 3 Server Nodes con `etcd` distribuido y un balanceador de carga / VIP para la API y el puerto de supervisor.

## 🏗️ Arquitectura del Clúster HA

* **Server Node 1 (`10.207.154.61`):** Primer Server (inicializa el clúster `etcd`).
* **Server Node 2 (`10.207.154.62`):** Segundo Server (se une al clúster `etcd`).
* **Server Node 3 (`10.207.154.63`):** Tercer Server (completa el quórum de 3 en `etcd`).
* **Worker Nodes (`10.207.154.64-66`):** 3 nodos de trabajo (`rke2-worker1`, `rke2-worker2`, `rke2-worker3`).
* **VIP / LoadBalancer (`10.207.154.60`):**
  - Puerto `6443` -> Balancea tráfico hacia los 3 servers.
  - Puerto `9345` -> Balancea tráfico de registro hacia los 3 servers.

---

## ⚙️ Paso 1: Configuración del Primer Server (`rke2-server1`)

En `/etc/rancher/rke2/config.yaml`:
```yaml
token: "secret-ha-token"
tls-san:
  - "10.207.154.60"   # IP del LoadBalancer / VIP
cni: "canal"
```

Arrancar el servicio:
```bash
sudo systemctl enable --now rke2-server.service
```

---

## ⚙️ Paso 2: Configuración de los Server Nodes Adicionales (`rke2-server2` y `rke2-server3`)

En `/etc/rancher/rke2/config.yaml`:
```yaml
server: "https://10.207.154.60:9345" # Apunta al VIP o al primer Server
token: "secret-ha-token"
tls-san:
  - "10.207.154.60"
cni: "canal"
```

Arrancar el servicio en cada server adicional:
```bash
sudo systemctl enable --now rke2-server.service
```

---

## 🔍 Verificación del Quórum de etcd

```bash
kubectl get nodes -o wide
# Verificar miembros de etcd dentro de los pods estáticos de kube-system
kubectl get pods -n kube-system -l app=etcd
```
