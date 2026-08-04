# 🗺️ Plan de Ruta: Módulo RKE2 (Rancher Kubernetes Engine 2)

Este documento detalla el plan de trabajo, el estado de implementación de los ejemplos de RKE2 y el seguimiento de validación para el temario **"4.- RKE2 Despliegue de Kubernetes"**.

---

## 🏛️ Arquitectura Modular Reutilizable (`ansible/rke2/shared/`)

Para evitar duplicar código entre los laboratorios, toda la lógica de infraestructura vive en `shared/`:

- [x] **`shared/01_crear_vms.yml`**: Aprovisionamiento dinámico de VMs LXD en función del `inventory.ini`.
- [x] **`shared/02_configurar_os.yml`**: Ajuste de kernel (`overlay`, `br_netfilter`), sysctl (`ip_forward=1`), swap y paquetes base.
- [x] **`shared/03_instalar_rke2_server.yml`**: Instalación y configuración declarativa de RKE2 Server Node(s) (mono-nodo o HA) y extracción del `kubeconfig.yaml`.
- [x] **`shared/04_instalar_rke2_agent.yml`**: Instalación y conexión de RKE2 Agent / Worker Nodes al puerto `9345`.
- [x] **`shared/destroy_vms.yml`**: Limpieza automática de las VMs del inventario.
- [x] **`shared/run_lab.sh` & `shared/destroy_lab.sh`**: Scripts de orquestación común.

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
| **01** | **Requisitos: Hardware y Red** (`01_requisitos_hardware_red`) | ✅ Validado | `v1.35.6+rke2r1` | Documentación completa de vCPU/RAM/disco, sysctl y matriz de puertos (`6443`, `9345`, `2379-2380`, `8472`). |
| **02** | **Server Node Mono-nodo** (`02_rke2_server_single_node`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | VM LXD `rke2-server1` aprovisionada, `rke2-server.service` en ejecución, `kubeconfig.yaml` local ajustado y verificado en vivo. |
| **03** | **Configuración de CNI** (`03_cni_configuration`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | Probado en vivo con CNI **Cilium** (`cni: cilium`), pod `cilium-operator` y agentes `cilium-dt8bd` en estado `Running`. |
| **04** | **Worker Node (Agent)** (`04_worker_node_agent`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado para 1 Server + 2 Workers (`rke2-worker1/2`). Pendiente de prueba de carga y resiliencia. |
| **05** | **Alta Disponibilidad (HA)** (`05_ha_cluster_etcd`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | 3 Servers (etcd distribuido) + 2 Workers. VIP kube-vip `10.207.154.60` activa (ARP, `enp5s0`). Workers etiquetados `worker` via `kubernetes.core.k8s`. 2 ejecuciones consecutivas idempotentes. |
| **06** | **Docker Registry Privado** (`06_docker_private_registry`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado para inyectar `/etc/rancher/rke2/registries.yaml` (mirrors y auth). Pendiente de prueba con registry local. |
| **07** | **Actualizaciones del Clúster** (`07_actualizaciones_cluster`) | 🟡 Estructurado | `v1.35.6` -> `v1.36.2` | Estructurado para rolling upgrade de RKE2 `v1.35.6+rke2r1` a `v1.36.2+rke2r1` y System Upgrade Controller. |

---

## 🎯 Próximos Pasos (Backlog de Trabajo)

1. **Laboratorio 04 (Workers):** Ejecutar prueba en vivo de `04_worker_node_agent` verificando el registro de los 2 workers en el puerto `9345` y la distribución de pods de prueba.
2. **Laboratorio 05 — Lecciones aprendidas (ya aplicadas):**
   - **Interfaz kube-vip:** Las VMs LXD usan `enp5s0` (predictable naming), no `eth0`. Se autodetecta via `ansible_facts['default_ipv4']['interface']` con fallback a la variable `kube_vip_interface`.
   - **`serial: 1`:** Los servidores HA se despliegan uno a uno; el primero debe tener kube-vip + VIP levantada ANTES de que los demás intenten unirse al clúster.
   - **Etiqueta `worker`:** kubelet prohíbe `node-role.kubernetes.io/*` via `--node-labels` (namespace reservado). Se aplica vía `kubernetes.core.k8s` (patch del Node) desde el API server.
   - **`INJECT_FACTS_AS_VARS`:** Usar `ansible_facts['clave']` en vez de `ansible_clave` (deprecado a partir de ansible-core 2.24).
   - **Módulos sobre comandos:** Refactorizado para usar `kubernetes.core.k8s`, `kubernetes.core.k8s_info`, `ansible.posix.sysctl`, `ansible.builtin.get_url` y `community.general.lxd_container` (state: absent) en lugar de `kubectl`, `sysctl --system`, `curl | sh` y `lxc delete`.
3. **Laboratorio 06 (Registry):** Crear un registro local Docker de prueba e integrar el archivo `registries.yaml` para comprobar el pulling de imágenes privadas o espejadas.
4. **Laboratorio 07 (Actualizaciones):** Ejecutar la actualización en vivo de `v1.35.6+rke2r1` a `v1.36.2+rke2r1` sin pérdida de disponibilidad.
