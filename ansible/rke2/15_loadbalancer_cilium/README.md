# Laboratorio 15: Cilium Native L2 LoadBalancer & IPAM Pool

Este laboratorio demuestra cómo utilizar las capacidades nativas de **Cilium eBPF** para actuar como gestor de direcciones IP (**IPAM**) y anunciador L2 ARP/BGP para servicios de tipo `type: LoadBalancer` en un clúster Kubernetes bare-metal sobre LXD.

---

## 🏗️ Arquitectura y Componentes

* **Cilium CNI**: Instalado en el clúster (`rke2_cni: "cilium"`).
* **CiliumLoadBalancerIPPool**: Definición declarativa del rango IP asignable por eBPF (`10.207.154.220/29`, IPs `10.207.154.220 - 10.207.154.227`).
* **CiliumL2AnnouncementPolicy**: Habilita la respuesta ARP L2 procesada directamente en el dataplane eBPF del kernel Linux sin usar `iptables` ni demonios externos como MetalLB.
* **Servicio de Prueba**: Deployment `cilium-lb-web-app` expuesto mediante un `Service` de tipo `LoadBalancer` en el puerto 80.

---

## 🚀 Despliegue Automatizado y Pruebas

```bash
# Desplegar las VMs LXD, instalar RKE2 con Cilium y configurar el LoadBalancer L2:
./run_all.sh

# Exportar kubeconfig local para inspección:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Comprobar componentes de Cilium LoadBalancer y el servicio:
kubectl get ciliumloadbalancerippool,ciliuml2announcementpolicy -n kube-system
kubectl get svc -n cilium-lb-demo

# Obtener la IP externa asignada por Cilium IPAM:
LB_IP=$(kubectl get svc cilium-lb-web-service -n cilium-lb-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Probar acceso HTTP directo a la IP del LoadBalancer:
curl -i http://${LB_IP}:80

# Destruir el laboratorio:
./destroy_all.sh
```

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que los pools de IP de Cilium y el servicio `LoadBalancer` están presentes sin provocar cambios no deseados (`changed=0`).
