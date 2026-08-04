# Laboratorio 01: Requisitos de Hardware y Red para RKE2

Este laboratorio cubre los requisitos mínimos y recomendados de hardware, kernel, red y puertos para desplegar RKE2 (Rancher Kubernetes Engine 2) de forma correcta.

## 💻 Requisitos de Hardware

### Server Node (Control Plane + etcd)
* **CPU:** Mínimo 2 vCPUs (Recomendado 4 vCPUs para HA o carga media).
* **RAM:** Mínimo 4 GB (Recomendado 8 GB). `etcd` requiere baja latencia de disco y RAM adecuada para evitar compacidades o timeouts.
* **Disco:** 20 GB o más (SSD/NVMe recomendado para el directorio `/var/lib/rancher/rke2` por latencia de escritura en `etcd`).

### Worker Node (Agent)
* **CPU:** Mínimo 1 vCPU (Recomendado 2 vCPUs o según la carga de trabajo).
* **RAM:** Mínimo 2 GB (Recomendado 4 GB o más).
* **Disco:** 20 GB o más (dependiendo del tamaño y volumen de imágenes de contenedores).

---

## 🌐 Requisitos de Red y Puertos

RKE2 requiere que los siguientes puertos estén abiertos entre los nodos del clúster:

| Puerto | Protocolo | Origen | Destino | Propósito |
| --- | --- | --- | --- | --- |
| `6443` | TCP | Clientes, kubectl, Workers | Server Nodes | Kubernetes API Server |
| `9345` | TCP | Worker Nodes, Server Nodes | Server Nodes | RKE2 Supervisor (registro y join de nodos) |
| `2379-2380` | TCP | Server Nodes | Server Nodes | Comunicación y sincronización del clúster etcd |
| `10250` | TCP | Server Nodes | Todos los nodos | Kubelet Metrics / Exec / Logs |
| `8472` | UDP | Todos los nodos | Todos los nodos | CNI Canal / Flannel VXLAN overlay |
| `51820` / `51821` | UDP | Todos los nodos | Todos los nodos | Wireguard (si se activa en Canal/Calico) |
| `30000-32767` | TCP/UDP | Clientes externos | Workers / Managers | Rango de servicios `NodePort` de Kubernetes |

---

## ⚙️ Requisitos del Sistema Operativo y Kernel

1. **Módulos de Kernel requeridos:**
   - `overlay`
   - `br_netfilter`
2. **Parámetros Sysctl (`/etc/sysctl.d/99-kubernetes-cri.conf`):**
   - `net.bridge.bridge-nf-call-iptables = 1`
   - `net.ipv4.ip_forward = 1`
   - `net.bridge.bridge-nf-call-ip6tables = 1`
3. **Swap:** Desactivado por defecto (`swapoff -a`), aunque RKE2 soporta la ejecución con swap en versiones recientes si se configura explícitamente en Kubelet.
4. **Firewall / NetworkManager:**
   - Si se usa `firewalld` o `ufw`, se deben habilitar las reglas anteriores o permitir el tráfico en las interfaces del CNI (`rke2-cni*`, `flannel*`, `calico*`, `cilium*`).
