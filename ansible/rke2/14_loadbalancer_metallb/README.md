# Laboratorio 14: MetalLB LoadBalancer en Modo Layer 2 (ARP)

Este laboratorio demuestra cómo instalar y configurar **MetalLB** en un clúster Kubernetes bare-metal sobre LXD para proporcionar direcciones IP públicas/externas reales a servicios de tipo `type: LoadBalancer`.

---

## 🏗️ Arquitectura y Componentes

* **MetalLB Controller & Speaker**: Desplegados mediante el Helm chart oficial (`metallb/metallb`) en el namespace `metallb-system`.
* **Modo Layer 2 (ARP)**: Anuncio de direcciones IP en la red local del puente LXD (`lxdbr0`) mediante respuesta ARP coordinada entre los nodos del clúster.
* **IPAddressPool & L2Advertisement**:
  * Rango de IPs asignable: `10.207.154.200 - 10.207.154.210`.
* **Servicio de Prueba**: Deployment `metallb-web-app` expuesto mediante un `Service` de tipo `LoadBalancer` en el puerto 80.

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 y MetalLB LoadBalancer:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar componentes de MetalLB y el servicio LoadBalancer:
kubectl get pods -n metallb-system
kubectl get ipaddresspool,l2advertisement -n metallb-system
kubectl get svc -n metallb-demo

# Obtener la IP externa asignada por MetalLB:
LB_IP=$(kubectl get svc metallb-web-service -n metallb-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Probar acceso HTTP directo a la IP del LoadBalancer:
curl -i http://${LB_IP}:80

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que MetalLB, los pools de IP y el servicio `LoadBalancer` están presentes sin provocar cambios no deseados (`changed=0`).
