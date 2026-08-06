# Laboratorio 16: Kubernetes Gateway API con Envoy Gateway (HTTP, HTTPS, gRPC, TCP y UDP)

Este laboratorio implementa y demuestra la especificación estándar **Kubernetes Gateway API** (`gateway.networking.k8s.io/v1`) utilizando el controlador **Envoy Gateway** (`gateway.envoyproxy.io`), cubriendo los 5 protocolos principales: **HTTP**, **HTTPS**, **gRPC**, **TCP** y **UDP**.

---

## 🏗️ Arquitectura y Componentes

* **CRDs Gateway API**: Instalación de los CRDs estándar y experimentales oficiales de `kubernetes-sigs/gateway-api` v1.0.0+.
* **Controlador**: Envoy Gateway (`gateway.envoyproxy.io` vía Helm chart `envoy-gateway/gateway-helm`) en el namespace `envoy-gateway-system`.
* **GatewayClass**: `eg` (Envoy Gateway).
* **Listeners & Recurso Gateway**:
  * Listener **HTTP** (Puerto 80) $\rightarrow$ `HTTPRoute` por ruta (`/web` y `/api`).
  * Listener **HTTPS** (Puerto 443 con terminación SSL/TLS `Secret envoy-tls-secret`).
  * Listener **TCP** (Puerto 9000) $\rightarrow$ `TCPRoute` encaminamiento L4.
  * Listener **UDP** (Puerto 9001) $\rightarrow$ `UDPRoute` encaminamiento L4.

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 y el controlador Envoy Gateway:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar componentes de Gateway API:
kubectl get gatewayclass,gateway,httproute,tcproute,udproute -n envoy-gateway-demo

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que Envoy Gateway, la `GatewayClass` y las rutas para los 5 protocolos están presentes sin provocar cambios no deseados (`changed=0`).
