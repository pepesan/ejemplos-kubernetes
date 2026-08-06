# Laboratorio 03: Módulo Completo de Proveedores CNI en RKE2

Este laboratorio implementa y demuestra el temario completo del módulo **"11.- CNI"**, cubriendo la teoría, arquitectura, personalización y pruebas en vivo de los principales proveedores CNI (**Canal**, **Flannel**, **Cilium** y **Calico**).

> 📊 **Matriz de Validación en Vivo**: Consulta el documento **[`MATRIX.md`](MATRIX.md)** para ver el plan de pruebas individual, la comparativa de componentes y los resultados detallados en vivo para cada CNI (`canal`, `flannel`, `cilium` y `calico`).

---

## ⚙️ Cómo Seleccionar el Proveedor CNI del Clúster

El proveedor CNI que desplegará RKE2 durante la instalación se configura en el archivo **`group_vars/all.yml`** mediante la variable **`rke2_cni`**:

```yaml
# group_vars/all.yml
lxd_network: "lxdbr0"
lxd_image: "k8s-template"
rke2_version: "v1.36.3+rke2r1"

# Selección del CNI principal del clúster:
rke2_cni: "canal"       # [Por defecto] Flannel VXLAN + Calico Felix NetworkPolicies
# rke2_cni: "flannel"   # Flannel VXLAN ultraligero sin motor de políticas
# rke2_cni: "calico"    # Calico CNI nativo completo
# rke2_cni: "cilium"    # Cilium eBPF nativo (sustituye kube-proxy)
# rke2_cni: "none"      # Desactiva CNI integrado (para instalar CNI custom vía Helm)
```

### Mecánica Interna de Configuración en RKE2

Durante el aprovisionamiento, Ansible inyecta la directiva `cni` en `/etc/rancher/rke2/config.yaml` en los nodos Server:

```yaml
# /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "10.207.154.60"
token: "secret-rke2-token-2026"
cni: "canal"   # RKE2 despliega automáticamente el HelmChart del CNI indicado al arrancar
```

Para probar un CNI distinto en un clúster desde cero:
```bash
# 1. Edita group_vars/all.yml para cambiar rke2_cni (ej. a "cilium")
# 2. Re-despliega el laboratorio:
./destroy_all.sh && ./run_all.sh
```

---

## 📋 Mapeo de Ejemplos con el Temario "11.- CNI"

| # | Ejemplo / Proveedor CNI | Descripción y Caso de Uso | Fichero / Playbook |
| --- | --- | --- | --- |
| **1** | **Canal (Defecto RKE2)** | Flannel (Overlay VXLAN) + Calico Felix (NetworkPolicies L3/L4). Demuestra aislamiento entre pods `frontend` (autorizado) y `rogue` (bloqueado). | `10_cni_canal_networkpolicies.yml` |
| **2** | **Flannel** | Red Overlay VXLAN ultraligera inter-nodo en puerto UDP 8472 sin motor de políticas para laboratorios de bajo consumo. | `11_cni_flannel_overview.yml` |
| **3** | **Cilium (eBPF)** | CNI eBPF nativo sin `kube-proxy`, aceleración por socket maps y seguridad L7/HTTP. | `12_cni_cilium_ebpf.yml` |
| **4** | **Calico Avanzado** | Personalización declarativa de parámetros CNI (MTU, modo VXLAN, Prometheus metrics) mediante el CRD `HelmChartConfig`. | `13_cni_calico_config.yml` |

---

## ⚖️ Matriz Comparativa de Proveedores CNI

| CNI | Dataplane (Enrutamiento) | Controlplane (Seguridad) | eBPF | Reemplazo `kube-proxy` | Caso de Uso |
| --- | --- | --- | --- | --- | --- |
| **Canal** | Flannel VXLAN (puerto 8472) | Calico Felix (L3/L4) | ❌ No | ❌ No | Equilibrio por defecto en RKE2. |
| **Flannel** | VXLAN / host-gw | ❌ Sin políticas | ❌ No | ❌ No | Labs ultraligeros sin requerimientos de aislamiento. |
| **Calico** | BGP / IP-in-IP / VXLAN | Calico Felix (L3/L4/Global) | 🟡 Parcial | 🟡 Opcional | Datacenters enterprise con enrutamiento BGP. |
| **Cilium** | eBPF Native | Cilium Agent (L3/L4/L7) | ✅ Sí | ✅ Sí | Producción moderna, máximo rendimiento y Zero-Trust. |

---

## 🚀 Ejecución de los Ejemplos del Módulo CNI

```bash
# 1. Selecciona en group_vars/all.yml el CNI que deseas instalar y probar:
#    rke2_cni: "canal"   | "flannel" | "cilium" | "calico"

# 2. Despliega el clúster RKE2 (1 Server + 2 Workers):
./run_all.sh

# Cada CNI tiene su propio playbook de pruebas condicional que se activará
# únicamente si coincide con el rke2_cni seleccionado:
#
# - rke2_cni: "canal"   -> Ejecuta 10_cni_canal_networkpolicies.yml (Flannel + Calico Felix L3/L4)
# - rke2_cni: "flannel" -> Ejecuta 11_cni_flannel_overview.yml (VXLAN Overlay & demuestra ausencia de políticas)
# - rke2_cni: "cilium"  -> Ejecuta 12_cni_cilium_ebpf.yml (eBPF Dataplane & CiliumNetworkPolicy L7)
# - rke2_cni: "calico"  -> Ejecuta 13_cni_calico_config.yml (Calico Nativo + HelmChartConfig MTU/metrics)

# Exportar kubeconfig local para inspección manual:
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes -o wide
kubectl get networkpolicy
kubectl get helmchartconfig -n kube-system

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`). |
| `group_vars/all.yml` | Variables del clúster RKE2 (`rke2_cni: canal`, `rke2_version: v1.36.3+rke2r1`). |
| `10_cni_canal_networkpolicies.yml` | **Ejemplo 1**: Playbook de prueba específico para CNI Canal (`rke2_cni: canal`). |
| `11_cni_flannel_overview.yml` | **Ejemplo 2**: Playbook de prueba específico para CNI Flannel (`rke2_cni: flannel`). |
| `12_cni_cilium_ebpf.yml` | **Ejemplo 3**: Playbook de prueba específico para CNI Cilium (`rke2_cni: cilium`). |
| `13_cni_calico_config.yml` | **Ejemplo 4**: Playbook de prueba específico para CNI Calico Nativo (`rke2_cni: calico`). |
| `MATRIX.md` | **Plan de pruebas y Matriz de resultados** en vivo por cada CNI. |
| `run_all.sh` / `destroy_all.sh` | Scripts de ciclo de vida del laboratorio. |

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que todos los recursos CNI, Pods de prueba y `HelmChartConfig` están presentes sin provocar cambios no deseados (`changed=0`).
