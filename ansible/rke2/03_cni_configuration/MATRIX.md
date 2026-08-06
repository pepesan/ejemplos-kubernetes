# 📊 Matriz de Pruebas y Resultados en Vivo: Módulo CNI RKE2 (`03_cni_configuration`)

Este documento especifica el **Plan de Pruebas Individuales** para evaluar cada proveedor CNI admitido por RKE2 (`canal`, `flannel`, `cilium` y `calico`), detallando las opciones disponibles, la fecha de ejecución, el procedimiento de prueba paso a paso y los resultados observados en vivo sobre la infraestructura de máquinas virtuales LXD.

---

## 📋 Matriz Resumen de Pruebas en Vivo (2026-08-06)

| Opción `rke2_cni` | Proveedor CNI | Playbook de Prueba Específico | Componentes Verificados | Aislamiento NetworkPolicy | Pruebas de Tráfico | Resultado en Vivo | Idempotencia (`changed=0`) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **`canal`** *(Defecto)* | **Canal** (Flannel VXLAN + Calico Felix) | `10_cni_canal_networkpolicies.yml` | `rke2-canal` DaemonSet en `kube-system` | **L3/L4** con `networking.k8s.io/v1` | `frontend` $\rightarrow$ `backend:8080` (PERMITIDO)<br>`rogue` $\rightarrow$ `backend:8080` (BLOQUEADO) | ✅ **PASADO** | ✅ **PASADO** |
| **`flannel`** | **Flannel** (VXLAN Overlay) | `11_cni_flannel_overview.yml` | `kube-flannel-ds` DaemonSet en `kube-system` | ❌ **Sin Motor de Políticas** (Ignoradas por diseño) | `sender` $\rightarrow$ `receiver:8080` (PERMITIDO)<br>`rogue` $\rightarrow$ `receiver:8080` (PERMITIDO) | ✅ **PASADO** | ✅ **PASADO** |
| **`cilium`** | **Cilium** (eBPF Native) | `12_cni_cilium_ebpf.yml` | `cilium` DaemonSet y `cilium-operator` en `kube-system` | **L3/L4/L7** con `cilium.io/v2` (`CiliumNetworkPolicy`) | `cilium-auth` $\rightarrow$ `server:8080` (PERMITIDO)<br>`cilium-unauth` $\rightarrow$ `server:8080` (BLOQUEADO por eBPF) | ✅ **PASADO** | ✅ **PASADO** |
| **`calico`** | **Calico Nativo** (Felix BGP/VXLAN) | `13_cni_calico_config.yml` | `calico-node` DaemonSet en `calico-system` + `HelmChartConfig` | **L3/L4** con `networking.k8s.io/v1` + `vethMTU=1450` | `frontend` $\rightarrow$ `backend:8080` (PERMITIDO)<br>`rogue` $\rightarrow$ `backend:8080` (BLOQUEADO por Felix) | ✅ **PASADO** | ✅ **PASADO** |

---

## 🛠️ Plan de Pruebas Individual Paso a Paso

Para probar individualmente un CNI sin interferencia de otros proveedores:

```bash
# 1. Configurar el CNI deseado en group_vars/all.yml
#    Ejemplo: rke2_cni: "cilium"

# 2. Desplegar el clúster RKE2 limpio y ejecutar su test específico
./destroy_all.sh && ./run_all.sh

# 3. Validar la idempotencia ejecutando por segunda vez
./run_all.sh   # (Debe reportar changed=0 en la suite CNI)
```

---

## 🔍 Detalle de Pruebas e Inspección en Vivo por CNI

### 1️⃣ Caso 1: `rke2_cni: "canal"` (Canal: Flannel VXLAN + Calico Felix)
* **Fecha de Prueba**: 2026-08-06
* **Infraestructura**: 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`).
* **Componentes**:
  ```bash
  kubectl get ds -n kube-system rke2-canal
  # STATUS: 3/3 READY
  ```
* **Prueba de Tráfico y Aislamiento**:
  - `frontend-pod` $\rightarrow$ `backend-pod:8080`: `rc=0` $\rightarrow$ **PERMITIDO**
  - `rogue-pod` $\rightarrow$ `backend-pod:8080`: `rc=1` $\rightarrow$ **BLOQUEADO** por Calico Felix.
* **Resultado**: **✅ Validado en Vivo** (`changed=0` en 2ª pasada).

---

### 2️⃣ Caso 2: `rke2_cni: "flannel"` (Flannel: VXLAN Overlay Ultraligero)
* **Fecha de Prueba**: 2026-08-06
* **Infraestructura**: 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`).
* **Componentes**:
  ```bash
  kubectl get ds -n kube-system kube-flannel-ds
  # STATUS: 3/3 READY
  ```
* **Prueba de Tráfico y Aislamiento**:
  - Inter-nodo `flannel-sender` $\rightarrow$ `flannel-receiver:8080`: `rc=0` $\rightarrow$ **PERMITIDO** sobre UDP 8472.
  - Demostración de NetworkPolicy en Flannel: `flannel-rogue` $\rightarrow$ `flannel-receiver:8080`: `rc=0` $\rightarrow$ **PERMITIDO**.
* **Conclusión Técnica**: Flannel no incluye un agente de filtrado de políticas en el kernel; el tráfico no autorizado es transmitido por el overlay VXLAN por diseño.
* **Resultado**: **✅ Validado en Vivo** (`changed=0` en 2ª pasada).

---

### 3️⃣ Caso 3: `rke2_cni: "cilium"` (Cilium: eBPF Native & L7 Security)
* **Fecha de Prueba**: 2026-08-06
* **Infraestructura**: 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`).
* **Componentes**:
  ```bash
  kubectl get ds,deploy -n kube-system -l k8s-app=cilium
  # STATUS: daemonset/cilium 3/3 READY, deployment/cilium-operator 1/1 READY
  ```
* **Prueba de Tráfico y Aislamiento L7**:
  - Recurso aplicado: `CiliumNetworkPolicy` (`cilium.io/v2`).
  - `cilium-auth-client` $\rightarrow$ `cilium-http-server:8080`: `rc=0` $\rightarrow$ **PERMITIDO**.
  - `cilium-unauth-client` $\rightarrow$ `cilium-http-server:8080`: `rc=1` $\rightarrow$ **BLOQUEADO directamente por eBPF en el kernel**.
* **Resultado**: **✅ Validado en Vivo** (`changed=0` en 2ª pasada).

---

### 4️⃣ Caso 4: `rke2_cni: "calico"` (Calico Nativo & Customización HelmChartConfig)
* **Fecha de Prueba**: 2026-08-06
* **Infraestructura**: 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`).
* **Componentes**:
  ```bash
  kubectl get ds -n calico-system calico-node
  # STATUS: 3/3 READY
  kubectl get helmchartconfig -n kube-system rke2-calico
  # STATUS: Applied (vethMTU: 1450, prometheusMetricsEnabled: true)
  ```
* **Prueba de Tráfico y Aislamiento**:
  - `calico-frontend-pod` $\rightarrow$ `calico-backend-pod:8080`: `rc=0` $\rightarrow$ **PERMITIDO**.
  - `calico-rogue-pod` $\rightarrow$ `calico-backend-pod:8080`: `rc=1` $\rightarrow$ **BLOQUEADO** por Calico Felix en `calico-system`.
* **Resultado**: **✅ Validado en Vivo** (`changed=0` en 2ª pasada).
