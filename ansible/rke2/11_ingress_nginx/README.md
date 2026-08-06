# Laboratorio 11: Ingress NGINX Controller (Community kubernetes/ingress-nginx)

Este laboratorio implementa y demuestra el despliegue del controlador **Ingress NGINX** oficial mantenido por la comunidad Kubernetes (`kubernetes/ingress-nginx`), cubriendo filtrado por URL/Host, filtrado por ruta, filtrado por puerto y terminación de certificados SSL/TLS.

---

## 🏗️ Arquitectura y Componentes

* **Controlador Ingress**: Community `ingress-nginx` desplegado vía Helm Chart oficial (`ingress-nginx/ingress-nginx`) en el namespace `ingress-nginx-demo`.
* **Servicios Backend**:
  * `web-app-svc` (puerto 8080): Aplicación frontend servida en la ruta `/web`.
  * `api-app-svc` (puerto 8080): Aplicación backend API servida en la ruta `/api`.
* **Seguridad SSL/TLS**: Certificado X.509 autofirmado generado con `openssl` e inyectado como `Secret` de tipo `kubernetes.io/tls` (`nginx-tls-secret`).

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 e Ingress NGINX Controller:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar pods del controlador y servicios de prueba:
kubectl get pods -n ingress-nginx-demo
kubectl get ingress -n ingress-nginx-demo

# Probar encaminamiento por ruta (Path-based routing):
curl -s -k --resolve nginx.example.com:30080:10.207.154.60 http://nginx.example.com:30080/web
curl -s -k --resolve nginx.example.com:30080:10.207.154.60 http://nginx.example.com:30080/api

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que el controlador Ingress NGINX, las reglas Ingress y los certificados SSL están presentes sin provocar cambios no deseados (`changed=0`).
