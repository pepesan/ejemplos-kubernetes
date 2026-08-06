# Laboratorio 18: Cilium eBPF Gateway API & MariaDB Operator TCPRoute (HTTP, HTTPS y Clustered MariaDB TCP)

Este laboratorio implementa y demuestra la especificación **Kubernetes Gateway API** (`gateway.networking.k8s.io/v1`) utilizando el controlador nativo eBPF de **Cilium** (`io.cilium/gateway-controller`) y el operador de base de datos **MariaDB Operator** (`mariadb-operator`), cubriendo enrutamiento HTTP, HTTPS con terminación TLS y enrutamiento L4 TCP (`TCPRoute`) hacia un clúster MariaDB (puerto 3306).

---

## 🏗️ Arquitectura y Componentes

* **Controlador eBPF**: Cilium CNI con soporte Gateway API activado declarativamente (`gatewayAPI.enabled: true` vía `HelmChartConfig` en `kube-system`).
* **Operador de Base de Datos**: MariaDB Operator (`mariadb-operator`) gestionando un clúster MariaDB mediante el CRD `MariaDB`.
* **GatewayClass**: `cilium` (`io.cilium/gateway-controller`).
* **Listeners & Recurso Gateway**:
  * Listener **HTTP** (Puerto 80) $\rightarrow$ `HTTPRoute` por ruta (`/web` y `/api`).
  * Listener **HTTPS** (Puerto 443 con terminación SSL/TLS `Secret cilium-gw-tls-secret`).
  * Listener **TCP** (Puerto 3306) $\rightarrow$ `TCPRoute` encaminamiento L4 eBPF hacia el clúster MariaDB (`mariadb-cluster:3306`).

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 con Cilium eBPF, MariaDB Operator y Gateway API:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar componentes de Cilium Gateway API y el clúster MariaDB:
kubectl get gatewayclass,gateway,httproute,tcproute -n cilium-gateway-demo
kubectl get mariadb -n cilium-gateway-demo

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que el controlador Cilium Gateway API, el clúster MariaDB y las rutas HTTP/TCP están presentes sin provocar cambios no deseados (`changed=0`).
