# 🗺️ Plan de Ruta: Módulo RKE2 (Rancher Kubernetes Engine 2)

Este documento detalla el plan de trabajo, el estado de implementación de los ejemplos de RKE2 y el seguimiento de validación para el temario **"4.- RKE2 Despliegue de Kubernetes"**.

---

## 🏛️ Arquitectura Modular Reutilizable (`ansible/rke2/shared/`)

Para evitar duplicar código entre los laboratorios, toda la lógica de infraestructura vive en `shared/`:

- [x] **`shared/01_crear_vms.yml`**: Aprovisionamiento dinámico de VMs LXD en función del `inventory.ini`.
- [x] **`shared/02_configurar_os.yml`**: Ajuste de kernel (`overlay`, `br_netfilter`), sysctl (`ip_forward=1`), swap y paquetes base (`curl`, `open-iscsi`, `nfs-common`).
- [x] **`shared/03_instalar_rke2_server.yml`**: Instalación y configuración declarativa de RKE2 Server Node(s) (mono-nodo o HA) y extracción del `kubeconfig.yaml`.
- [x] **`shared/04_instalar_rke2_agent.yml`**: Instalación y conexión de RKE2 Agent / Worker Nodes al puerto `9345`.
- [x] **`shared/destroy_vms.yml`**: Limpieza automática de las VMs del inventario.
- [x] **`shared/run_lab.sh` & `shared/destroy_lab.sh`**: Scripts de orquestación común con descubrimiento dinámico de playbooks lab-specific (`[0-9][0-9]_*.yml` y `destroy_*.yml`).

---

## ⚠️ Reglas Permanentes de Diseño (aplicar SIEMPRE)

1. **Todo el código del módulo se escribe SIEMPRE en inglés**: nombres de tareas y plays en
   playbooks, variables, comentarios, plantillas y mensajes de los scripts shell. La
   documentación (README.md, PLAN.md) se mantiene en español, como en el resto del repo.
2. **Regla del Boy Scout**: cada vez que se revisite un fichero del módulo (por una feature,
   un bugfix o una revalidación), se deja mejor de lo que estaba — proponer y aplicar mejoras
   incrementales en ese mismo fichero (tareas más idempotentes, variables con `default`,
   comentarios de diseño que falten, módulos Ansible más modernos que sustituyan a
   `command`/`shell`, simplificación de bucles), en vez de limitarse al cambio estricto que
   trajo la visita. Si la mejora detectada es grande o afecta a otros ficheros, se anota en
   el backlog de este PLAN.md en vez de abordarla en caliente.
3. **Idempotencia obligatoria en TODO el código Ansible del módulo** (misma disciplina que los
   laboratorios base, ver `.agents/rules/idempotencia.md`): ningún laboratorio se marca como
   validado hasta completar 2 ejecuciones consecutivas de `run_all.sh`, donde la segunda debe
   reportar `changed=0` salvo excepciones conocidas y documentadas (p. ej. el `fetch`/`replace`
   del `kubeconfig.yaml` local, que siempre se regenera). Concretamente:
   - Nada de `command`/`shell` sin guarda: todo comando se protege con `stat`/`when`
     (p. ej. el instalador de RKE2 solo corre si `/usr/local/bin/rke2` no existe) o con
     `changed_when: false` si es de solo lectura.
   - En `kubectl apply`, parsear la salida (`created`/`configured` vs `unchanged`) para que
     `changed_when` refleje la realidad; preferir los módulos idempotentes `kubernetes.core.k8s`
     y `kubernetes.core.helm` siempre que sea viable (regla ya establecida en los labs base).
   - Si una tarea modifica `/etc/rancher/rke2/config.yaml`, notificar un handler que reinicie
     `rke2-server`/`rke2-agent` — el cambio de config sin reinicio es una divergencia silenciosa.
4. **Módulos Ansible sobre comandos (aplicar SIEMPRE)**: usar módulos nativos de Ansible
   (`kubernetes.core.k8s`, `kubernetes.core.k8s_info`, `ansible.posix.sysctl`,
   `community.general.lxd_container`, `ansible.builtin.get_url`, etc.) en lugar de
   `command`/`shell` con `kubectl`, `sysctl`, `lxc`, `curl | sh`, etc. Los únicos usos
   legítimos de `command`/`shell` son:
   - Bootstrap de SSH en VMs recién creadas (problema del huevo y la gallina: no hay SSH
     hasta inyectar la clave vía `lxc exec`/`lxc file push`).
   - `swapoff -a` (no existe módulo nativo de Ansible para desactivar swap).
   - Instaladores que solo se distribuyen como script de shell (p. ej. `get.rke2.io`),
     siempre protegidos con `when: not rke2_bin.stat.exists`.
5. **Actualizar este PLAN.md en cada feature**: al implementar/probar un laboratorio, se marca
   su estado y fecha en la tabla del mismo commit/feature que lo valida — nunca "ya se
   actualizará después".

---

## 📊 Estado de Implementación y Validación de Laboratorios

| # | Laboratorio | Estado | Versión RKE2/K8s | Notas / Avance |
| --- | --- | --- | --- | --- |
| **01** | **Requisitos: Hardware y Red** (`01_requisitos_hardware_red`) | ✅ Validado | `v1.36.3+rke2r1` | Documentación completa de vCPU/RAM/disco, sysctl y matriz de puertos (`6443`, `9345`, `2379-2380`, `8472`). |
| **02** | **Server Node Mono-nodo** (`02_rke2_server_single_node`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | VM LXD `rke2-server1` aprovisionada, `rke2-server.service` en ejecución, `kubeconfig.yaml` local ajustado y verificado en vivo. |
| **03** | **Configuración de CNI** (`03_cni_configuration`) | ✅ Validado en Vivo | `v1.36.3+rke2r1` | Probado en vivo con CNI **Cilium** (`cni: cilium`), pod `cilium-operator` y agentes `cilium` en estado `Running`. Replanificado para incluir matriz completa del temario CNI (Canal, Flannel, Calico, Cilium, Weave). |
| **04** | **Worker Node (Agent)** (`04_worker_node_agent`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | Probado en vivo con 1 Server + 2 Workers (`rke2-worker1/2`), registro en puerto `9345` y etiquetado `worker` (2026-08-04). |
| **05** | **Alta Disponibilidad (HA)** (`05_ha_cluster_etcd`) | ✅ Validado en Vivo | `v1.36.3+rke2r1` | 3 Servers (etcd distribuido) + 3 Workers (`rke2-worker1/2/3`). VIP kube-vip `10.207.154.60` (v1.2.2, ARP, `enp5s0`). Workers etiquetados `worker` via `kubernetes.core.k8s`. 2 ejecuciones consecutivas idempotentes (2026-08-05). |
| **06** | **Docker Registry Privado** (`06_docker_private_registry`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | Registry `registry:2` como pull-through cache de `docker.io` en `host` networking, `registries.yaml.j2` desplegado a todos los nodos con handler de reinicio. Pod `busybox:1.36` verificado Running + mirror catalog confirma `library/busybox` cacheado. 2 ejecuciones idempotentes (`changed=0`, 2026-08-05). |
| **07** | **Actualizaciones del Clúster** (`07_actualizaciones_cluster`) | ✅ Validado en Vivo | `v1.35.6` -> `v1.36.2` | Rolling upgrade en vivo Ansible (`serial: 1`, drain con `kubernetes.core.k8s_drain`, re-instalación binario, restart service, uncordon). Despliegue de System Upgrade Controller v0.20.1 + `Plan` server y worker. Idempotente (`changed=0`, 2026-08-05). |
| **08** | **Almacenamiento Avanzado & Longhorn** (`08_longhorn_storage`) | ✅ Validado en Vivo | `v1.36.3+rke2r1` | Módulo completo de Almacenamiento Avanzado (Temario 5 y 6): **PV**, **PVC**, **StorageClasses**, modos de acceso **RWO** y **ReadWriteMany (RWX)** multi-nodo (`rke2-worker1/2`), junto con Longhorn v1.12.0 (iSCSI, Helm, Online Expansion 1Gi->2Gi). 2 ejecuciones idempotentes (`changed=0`, 2026-08-05). |
| **09** | **Panel de Control Web (Headlamp)** (`09_dashboard_headlamp`) | ✅ Validado en Vivo | `v1.36.3+rke2r1` | Despliegue de Headlamp (CNCF Dashboard v0.44.0) via `kubernetes.core.helm`, NodePort 30090 (`http://10.207.154.60:30090`), RBAC `headlamp-admin`, generación de Secret token y guardado en `headlamp_token.txt`. 2 ejecuciones idempotentes (`changed=0`, 2026-08-05). |
| **10** | **Monitorización y Logging** (`10_observabilidad_prometheus_grafana_loki`) | ✅ Validado en Vivo | `v1.36.3+rke2r1` | Módulo completo de Monitorización y Logging (Temario 8): **kube-prometheus-stack** (Prometheus Operator, Grafana 30080, Prometheus 30090), **loki-stack** (Loki, Promtail/FluentBit), Loki Datasource registrado en Grafana y pod generador de logs JSON. 2 ejecuciones idempotentes (`changed=0`, 2026-08-05). |

---

## 📝 Resumen del Trabajo Realizado Hasta Ahora (2026-08-05)

1. **Refactorización de la Arquitectura Modular (`shared/`):**
   - Extraída toda la lógica duplicada a `ansible/rke2/shared/` para hacer el temario 100% DRY.
   - Enlaces simbólicos y wrappers `run_all.sh` / `destroy_all.sh` en cada directorio.
   - Extensión del runner genérico para ejecutar playbooks lab-specific (`[0-9][0-9]_*.yml` y `destroy_*.yml`).
   - Aplicada Regla del Boy Scout en `shared/03_instalar_rke2_server.yml` y `04_instalar_rke2_agent.yml` aumentando retries a 60 (5m) para evitar cancelaciones prematuras en arranques en frío.

2. **Validación del Lab 05 (Alta Disponibilidad 3S+3W con etcd + kube-vip v1.2.2):**
   - Desplegado un clúster HA de 3 Servers + 3 Workers con RKE2 `v1.36.3+rke2r1`.
   - `kube-vip` expone VIP flotante `10.207.154.60` por ARP en `lxdbr0`. 2 pasadas idempotentes (`changed=0`).

3. **Validación del Lab 06 (Docker Registry Privado / Pull-through Cache):**
   - Registry `registry:2` en el host en modo pull-through cache de `docker.io`.
   - Template `registries.yaml.j2` con handler de reinicio de RKE2. Verificado con pod probe `busybox:1.36` y assert contra `http://10.207.154.1:5000/v2/_catalog`. 2 pasadas idempotentes (`changed=0`).

4. **Validación del Lab 07 (Rolling Upgrade RKE2 + System Upgrade Controller v0.20.1):**
   - Rolling upgrade en vivo de `v1.35.6+rke2r1` a `v1.36.2+rke2r1` con `kubernetes.core.k8s_drain`.
   - Despliegue del System Upgrade Controller y manifiestos CRD `Plan` (`server-plan` y `worker-plan`). 2 pasadas idempotentes (`changed=0`).

5. **Validación del Lab 08 (Almacenamiento Avanzado & Longhorn v1.12.0):**
   - Clúster HA de 3 Servers + 3 Workers sobre RKE2 `v1.36.3+rke2r1`.
   - Configuración de `iscsid.service` y módulo `iscsi_tcp`.
   - Instalación de Longhorn v1.12.0 mediante `kubernetes.core.helm`.
   - Demostración completa del temario: PVC RWO 1Gi, **Ampliación en caliente a 2Gi**, documentación de la restricción de reducción K8s, y acceso concurrente **ReadWriteMany (RWX)** multi-nodo (`rke2-worker1/2`). 2 pasadas idempotentes (`changed=0`).

6. **Validación del Lab 09 (Panel de Control Web Moderno con Headlamp v0.44.0):**
   - Despliegue de Headlamp (CNCF Dashboard) vía Helm en NodePort `30090` (`http://10.207.154.60:30090`).
   - Creación de RBAC `headlamp-admin` y generación de Secret token guardado automáticamente en `headlamp_token.txt`. 2 pasadas idempotentes (`changed=0`).

7. **Validación del Lab 10 (Monitorización y Logging / Prometheus, Grafana, Loki):**
   - Despliegue de `kube-prometheus-stack` (Grafana en 30080, Prometheus en 30090) y `loki-stack` (Loki + Promtail/FluentBit).
   - ConfigMap de datasource Loki pre-registrado en Grafana + pod emisor de logs JSON (`log-producer-pod`). 2 pasadas idempotentes (`changed=0`).

---

## 🎯 Replanificación: Próximos Pasos y Backlog de Evolución

Los 10 laboratorios principales del temario están **100% completados y validados en vivo**. Las siguientes secciones detallan la planificación pedagógica y técnica para ampliar el módulo CNI y continuar evolucionando la infraestructura:

### 🌐 Replanificación Pedagógica del Módulo "11.- CNI" (`03_cni_configuration/`)

Desglose de ejemplos prácticos paso a paso para cubrir los 4 proveedores CNI activos y los 3 pilares del networking K8s (IPAM, Dataplane VXLAN/BGP/eBPF y Controlplane NetworkPolicies L3/L4/L7):

- [ ] **Ejemplo 1: Canal (Default RKE2)** — *VXLAN Overlay + NetworkPolicies K8s L3/L4*
  - Despliegue `rke2_cni: canal`. Flannel (interfaz `flannel.1`, UDP 8472) + Calico Felix.
  - Playbook `10_cni_canal_networkpolicies.yml`: Pod `frontend` y Pod `backend` con `NetworkPolicy` L3/L4 permitiendo únicamente el puerto `8080`.
- [ ] **Ejemplo 2: Flannel** — *Red Overlay Ultraligera sin Overhead de Seguridad*
  - Despliegue `rke2_cni: flannel`. Red VXLAN directa sin motor de políticas.
  - Verificación de tablas de ruta y demostración de que las `NetworkPolicies` son ignoradas por diseño.
- [ ] **Ejemplo 3: Cilium (eBPF)** — *Aceleración eBPF, Reemplazo de kube-proxy y Seguridad L7*
  - Despliegue `rke2_cni: cilium`. Sustitución de `iptables` por programas eBPF cargados en el kernel.
  - Playbook `11_cni_cilium_ebpf.yml`: Verificación de `cilium status` y aplicación de `CiliumNetworkPolicy` L7 (permitir `GET /public`, denegar `POST /admin`).
- [ ] **Ejemplo 4: Calico Avanzado** — *Personalización con `HelmChartConfig`*
  - Personalización declarativa vía `/var/lib/rancher/rke2/server/manifests/rke2-calico-config.yaml` (`HelmChartConfig`).
  - Ajuste de MTU, modo de encapsulamiento (`vxlanAlways` vs `Never`) y rangos IPAM.

---

### 🚀 Nuevos Laboratorios Día 2 (Operaciones y Seguridad Avanzada)

- [ ] **Lab 11: Backup & Disaster Recovery de etcd (`11_etcd_backup_restore`)**:
  - Snapshots manuales (`rke2 etcd-snapshot save`) y automatización programada en `config.yaml` (`etcd-snapshot-schedule-cron`).
  - Procedimiento de Disaster Recovery: restauración de etcd tras fallo del clúster con `rke2 server --cluster-reset --cluster-reset-restore-path`.
- [ ] **Lab 12: CIS Benchmark Hardening y Auditoría (`12_rke2_cis_hardening`)**:
  - Activación de perfiles CIS (`profile: cis-1.23` / `cis-1.6`) en `config.yaml` y Pod Security Admissions (PSA).
  - Auditoría automatizada de seguridad ejecutando el job de `kube-bench` para RKE2.

---

### 🛠️ Mejoras de Infraestructura y Ergonomía (QoL en `shared/`)

- [ ] **Redundancia Supervisor 9345 (Lab 05)**: Exponer tanto el API (`6443`) como el Supervisor (`9345`) bajo la VIP `10.207.154.60` (HAProxy / VIP dual), eliminando el SPOF en el join de nodos.
- [ ] **Registry Empresarial TLS & Auth (Lab 06)**: Añadir variante con CA local (certificados autofirmados) y autenticación HTTP Basic (`ca_file` y `auth` en `registries.yaml`).
- [ ] **Pre-flight Validator ejecutable (Lab 01)**: Crear `01_preflight_check.yml` ejecutable que verifique sysctls, módulos del kernel, memoria libre y puertos antes de arrancar los labs.
- [ ] **QoL SSH Profile (`shared/`)**: Añadir en `/etc/profile.d/rke2.sh` el autocompletado bash para `kubectl` y `crictl`, el alias `alias k=kubectl` y la exportación automática del `KUBECONFIG`.
