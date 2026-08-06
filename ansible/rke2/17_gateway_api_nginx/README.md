# Laboratorio 17: NGINX Gateway Fabric & MariaDB Operator TCPRoute (HTTP, HTTPS y Clustered MariaDB TCP)

Este laboratorio implementa y demuestra la especificación **Kubernetes Gateway API** (`gateway.networking.k8s.io/v1`) utilizando **NGINX Gateway Fabric** (`nginx-gateway-fabric` de NGINX Inc / F5) y el operador **MariaDB Operator** (`mariadb-operator`), cubriendo enrutamiento HTTP, HTTPS con terminación TLS y enrutamiento L4 TCP (`TCPRoute`) hacia una **Base de Datos en Clúster MariaDB** (puerto 3306).

---

## 🏗️ Arquitectura y Componentes

* **Controlador**: NGINX Gateway Fabric (`gateway.nginx.org/nginx-gateway-controller` vía Helm chart `nginx-stable/nginx-gateway-fabric`).
* **Operador de Base de Datos**: MariaDB Operator (`mariadb-operator/mariadb-operator`) que gestiona el ciclo de vida del clúster MariaDB mediante el CRD `MariaDB`.
* **GatewayClass**: `nginx` (NGINX Gateway Fabric).
* **Listeners & Recurso Gateway**:
  * Listener **HTTP** (Puerto 80) $\rightarrow$ `HTTPRoute` por ruta (`/web` y `/api`).
  * Listener **HTTPS** (Puerto 443 con terminación SSL/TLS `Secret nginx-gw-tls-secret`).
  * Listener **TCP** (Puerto 3306) $\rightarrow$ `TCPRoute` encaminamiento L4 hacia el servicio del clúster MariaDB (`mariadb-cluster:3306`).

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2, MariaDB Operator y NGINX Gateway Fabric:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar pods del operador MariaDB, NGINX Gateway y recursos Gateway API:
kubectl get mariadb,pod -n nginx-gateway-demo
kubectl get gatewayclass,gateway,httproute,tcproute -n nginx-gateway-demo

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que NGINX Gateway Fabric, el clúster MariaDB y las rutas HTTP/TCP están presentes sin provocar cambios no deseados (`changed=0`).
