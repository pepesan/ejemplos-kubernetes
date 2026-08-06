# Laboratorio 13: Traefik Ingress Controller (Native RKE2)

Este laboratorio implementa y demuestra el uso del controlador **Traefik Ingress** (integrado nativamente en RKE2), cubriendo filtrado por URL/Host, filtrado por ruta, Middlewares de Traefik y terminación de certificados SSL/TLS.

---

## 🏗️ Arquitectura y Componentes

* **Controlador Ingress**: `rke2-traefik` desplegado por defecto en el namespace `kube-system` escudriñando los recursos `Ingress` (`ingressClassName: traefik`) y CRDs de Traefik (`traefik.io/v1alpha1`).
* **Servicios Backend**:
  * `traefik-web-svc` (puerto 8080): Aplicación servida en `/web`.
  * `traefik-api-svc` (puerto 8080): Aplicación servida en `/api`.
* **Middlewares Traefik**: Recurso `Middleware` (`strip-prefix`) para eliminar el prefijo de ruta antes de reenviar el tráfico al backend.
* **Seguridad SSL/TLS**: Certificado X.509 autofirmado generado con `openssl` e inyectado como `Secret` `kubernetes.io/tls` (`traefik-tls-secret`).

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 y Traefik Ingress:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar Pods y recursos Traefik:
kubectl get pods -n traefik-demo
kubectl get ingress,middleware -n traefik-demo

# Probar encaminamiento por ruta (Path-based routing):
curl -s -k --resolve traefik.example.com:80:10.207.154.60 http://traefik.example.com/web
curl -s -k --resolve traefik.example.com:80:10.207.154.60 http://traefik.example.com/api

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que el controlador Traefik Ingress, los Middlewares y los recursos SSL están presentes sin provocar cambios no deseados (`changed=0`).
