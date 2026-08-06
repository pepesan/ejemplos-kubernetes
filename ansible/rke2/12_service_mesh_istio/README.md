# Laboratorio 12: Service Mesh con Istio & Envoy Proxies

Este laboratorio implementa y demuestra el despliegue de **Istio Service Mesh**, cubriendo inyección automática de sidecars Envoy, mTLS estricto entre microservicios, enrutamiento con `Gateway` y `VirtualService`, filtrado por Host, filtrado por Ruta y certificados SSL/TLS.

---

## 🏗️ Arquitectura y Componentes

* **Control Plane**: `istiod` desplegado en el namespace `istio-system` mediante Helm.
* **Ingress Gateway**: `istio-ingressgateway` expuesto en NodePorts `30080` (HTTP) y `30443` (HTTPS).
* **Proxies Sidecar**: Envoy inyectado automáticamente en los Pods del namespace `istio-demo` (`istio-injection: enabled`).
* **Seguridad mTLS & TLS**:
  * Certificado Server TLS inyectado en Istio Gateway para el dominio `istio.example.com`.
  * `PeerAuthentication` con `mode: STRICT` para forzar cifrado mTLS entre sidecars Envoy dentro de la malla.
* **Recursos Istio CRD**:
  * `Gateway`: Punto de entrada HTTP/HTTPS.
  * `VirtualService`: Encaminamiento por URL (`istio.example.com`) y por Ruta (`/web` y `/api`).

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 y el Service Mesh Istio:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar componentes de la malla Istio:
kubectl get pods -n istio-system
kubectl get pods -n istio-demo
kubectl get gateway,virtualservice,peerauthentication -n istio-demo

# Probar encaminamiento por VirtualService (Path-based routing):
curl -s -k --resolve istio.example.com:30080:10.207.154.60 http://istio.example.com:30080/web
curl -s -k --resolve istio.example.com:30080:10.207.154.60 http://istio.example.com:30080/api

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que el Service Mesh Istio, los sidecars Envoy y los recursos CRD están presentes sin provocar cambios no deseados (`changed=0`).
