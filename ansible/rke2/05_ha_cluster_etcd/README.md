# Laboratorio 05: Clúster en Alta Disponibilidad (HA) con etcd Embebido y Redundancia Supervisor 9345

Este laboratorio describe y despliega automáticamente un clúster RKE2 en **Alta Disponibilidad (HA)** formado por 3 Server Nodes con `etcd` distribuido (quórum de 3) y una VIP flotante (`kube-vip` v1.2.2 en modo ARP) con **Redundancia Dual (API 6443 + Supervisor 9345)**.

---

## 🏗️ Arquitectura del Clúster HA

* **VIP Flotante ARP (`10.207.154.60`):**
  - **Puerto `6443`**: Punto de entrada de alta disponibilidad para la API Server de Kubernetes (utilizado por `kubectl` y clientes).
  - **Puerto `9345`**: Punto de entrada de alta disponibilidad para el **Supervisor de RKE2**, utilizado por nodos Server adicionales y Worker Nodes para unirse al clúster sin dependencia de una IP fija (elimina el SPOF de bootstrap).
* **Server Nodes (Control-Plane + etcd):**
  - `rke2-server1` (`10.207.154.61`): Inicializador del clúster `etcd`.
  - `rke2-server2` (`10.207.154.62`): Segundo Server unido vía `https://10.207.154.60:9345`.
  - `rke2-server3` (`10.207.154.63`): Tercer Server unido vía `https://10.207.154.60:9345` (completa quórum de 3).
* **Worker Nodes (Agentes):**
  - `rke2-worker1` (`10.207.154.64`), `rke2-worker2` (`10.207.154.65`), `rke2-worker3` (`10.207.154.66`).

---

## 🚀 Despliegue Automatizado y Verificación

```bash
# Desplegar las 6 VMs LXD, configurar el SO, instalar RKE2 HA y validar redundancia:
./run_all.sh

# El script ejecutará automáticamente el playbook de laboratorio:
# - 10_verify_ha_supervisor_redundancy.yml

# Exportar kubeconfig local apuntando a la VIP:
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes -o wide
kubectl get pods -n kube-system -l component=etcd

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🔒 Mecánica de Redundancia del Supervisor 9345

1. **Eliminación del SPOF**: En despliegues tradicionales, los nodos se unen apuntando al primer servidor (`https://server1-ip:9345`). Si `server1` cae, no se pueden añadir nuevos nodos. Con la VIP flotante (`https://10.207.154.60:9345`), la petición de join siempre es recibida por el nodo activo de la VIP.
2. **Failover Automático `kube-vip`**: `kube-vip` gestiona la VIP en modo ARP mediante leader election (`plndr-cp-lock`). Si el servidor primario cae, la VIP se conmuta a `server2` o `server3` en menos de 5 segundos, manteniendo disponibles tanto el API `6443` como el Supervisor `9345`.

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida la presencia y salud del clúster HA sin provocar cambios no deseados (`changed=0`).
