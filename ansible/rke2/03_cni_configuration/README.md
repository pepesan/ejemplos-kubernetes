# Laboratorio 03: Configuración de CNI en RKE2

RKE2 incluye soporte nativo y empaquetado para varios controladores de red de pods (CNI - Container Network Interface).

## 🔌 CNIs Soportados

1. **Canal (Defecto):** Combinación de Flannel (para la red overlay VXLAN) y Calico (para políticas de red de nivel 3/4).
2. **Cilium:** CNI moderno basado en eBPF para alta performance, observabilidad y sustitución de kube-proxy.
3. **Calico:** CNI orientado a políticas de red avanzadas y enrutamiento BGP puro o VXLAN.
4. **Multus:** CNI secundario que permite adjuntar múltiples interfaces de red a un mismo pod.
5. **None:** Permite instalar manualmente un CNI personalizado deshabilitando el CNI por defecto de RKE2.

---

## ⚙️ Declaración en `config.yaml`

Para seleccionar el CNI al instalar RKE2 Server:

```yaml
cni:
  - "cilium"
# O para Multus + Cilium:
# cni:
#   - "multus"
#   - "cilium"
```

---

## 📄 Personalización con `HelmChartConfig`

RKE2 gestiona sus componentes empaquetados mediante Custom Resources de tipo `HelmChartConfig` colocados en `/var/lib/rancher/rke2/server/manifests/`.

Ejemplo: `/var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml`

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: "10.207.154.60"
    k8sServicePort: 6443
```
