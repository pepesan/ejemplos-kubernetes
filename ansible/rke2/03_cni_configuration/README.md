# Laboratorio 03: Módulo Completo de Proveedores CNI en RKE2

Este laboratorio implementa y demuestra el temario completo del módulo **"11.- CNI"**, cubriendo la teoría, arquitectura, personalización y pruebas en vivo de los principales proveedores CNI (**Canal**, **Flannel**, **Calico** y **Cilium**).

---

## 📋 Mapeo de Ejemplos con el Temario "11.- CNI"

| # | Ejemplo / Proveedor CNI | Descripción y Caso de Uso | Fichero / Playbook |
| --- | --- | --- | --- |
| **1** | **Canal (Defecto RKE2)** | Flannel (Overlay VXLAN) + Calico Felix (NetworkPolicies L3/L4). Demuestra aislamiento entre pods `frontend` (autorizado) y `rogue` (bloqueado). | `10_cni_canal_networkpolicies.yml` |
| **2** | **Flannel** | Red Overlay VXLAN ultraligera sin motor de políticas para laboratorios de bajo consumo. | `group_vars/all.yml` (`rke2_cni: flannel`) |
| **3** | **Cilium (eBPF)** | CNI eBPF nativo sin `kube-proxy`, observabilidad e inspección de seguridad L7 HTTP/DNS. | `11_cni_cilium_ebpf.yml` |
| **4** | **Calico Avanzado** | Personalización declarativa de parámetros Calico (MTU, modo VXLAN, IPAM) mediante el CRD `HelmChartConfig`. | `12_cni_calico_config.yml` |

---

## ⚖️ Matriz Comparativa de Proveedores CNI

| CNI | Dataplane (Enrutamiento) | Controlplane (Seguridad) | eBPF | Reemplazo `kube-proxy` | Caso de Uso |
| --- | --- | --- | --- | --- | --- |
| **Canal** | Flannel VXLAN (puerto 8472) | Calico Felix (L3/L4) | ❌ No | ❌ No | Equilibrio por defecto en RKE2. |
| **Flannel** | VXLAN / host-gw | ❌ Sin políticas | ❌ No | ❌ No | Labs ultraligeros sin requerimientos de aislamiento. |
| **Calico** | BGP / IP-in-IP / VXLAN | Calico Felix (L3/L4/Global) | 🟡 Parcial | 🟡 Opcional | Datacenters enterprise con enrutamiento BGP. |
| **Cilium** | eBPF Native | Cilium Agent (L3/L4/L7) | ✅ Sí | ✅ Sí | Producción moderna, máximo rendimiento y Zero-Trust. |

---

## 🚀 Uso del Ejemplo 1 (CNI Canal & NetworkPolicies)

```bash
# Desplegar el clúster RKE2 (1 Server + 2 Workers) con CNI Canal:
./run_all.sh

# El playbook 10_cni_canal_networkpolicies.yml ejecutará automáticamente:
# 1. Despliegue de backend-pod, frontend-pod y rogue-pod.
# 2. Aplicación de NetworkPolicy allow-frontend-to-backend en puerto 8080.
# 3. Verificación de que el tráfico desde frontend-pod a backend-pod:8080 es PERMITIDO.
# 4. Verificación de que el tráfico desde rogue-pod a backend-pod:8080 es BLOQUEADO.

# Exportar kubeconfig local para inspección manual:
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes -o wide
kubectl get networkpolicy
kubectl describe networkpolicy allow-frontend-to-backend

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`). |
| `group_vars/all.yml` | Variables del clúster RKE2 (`rke2_cni: canal`, `rke2_version: v1.36.3+rke2r1`). |
| `10_cni_canal_networkpolicies.yml` | **Ejemplo 1**: Playbook que valida Canal y aislamiento con `NetworkPolicy` L3/L4. |
| `run_all.sh` / `destroy_all.sh` | Scripts de ciclo de vida del laboratorio. |

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que los Pods de prueba y las `NetworkPolicies` están presentes sin provocar cambios no deseados (`changed=0`).
