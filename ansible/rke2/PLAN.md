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
| **02** | **Server Node Mono-nodo** (`02_rke2_server_single_node`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | VM LXD `rke2-server1` aprovisionada, `rke2-server.service` en ejecución, `kubeconfig.yaml` local ajustado y verificado en vivo (2026-08-04). |
| **03** | **Configuración de CNI** (`03_cni_configuration`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | Probado en vivo con CNI **Cilium** (`cni: cilium`), pod `cilium-operator` y agentes `cilium` en estado `Running` (2026-08-04). |
| **04** | **Worker Node (Agent)** (`04_worker_node_agent`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | Probado en vivo con 1 Server + 2 Workers (`rke2-worker1/2`), registro en puerto `9345` y etiquetado `worker` (2026-08-04). |
| **05** | **Alta Disponibilidad (HA)** (`05_ha_cluster_etcd`) | ✅ Validado en Vivo | `v1.35.6+rke2r1` | 3 Servers (etcd distribuido) + 2 Workers. VIP kube-vip `10.207.154.60` activa (ARP, `enp5s0`). Workers etiquetados `worker` via `kubernetes.core.k8s`. 2 ejecuciones consecutivas idempotentes (2026-08-04). |
| **06** | **Docker Registry Privado** (`06_docker_private_registry`) | 🟡 Estructurado | `v1.35.6+rke2r1` | Estructurado para inyectar `/etc/rancher/rke2/registries.yaml` (mirrors y auth). Pendiente de prueba con registry local. |
| **07** | **Actualizaciones del Clúster** (`07_actualizaciones_cluster`) | 🟡 Estructurado | `v1.35.6` -> `v1.36.2` | Estructurado para rolling upgrade de RKE2 `v1.35.6+rke2r1` a `v1.36.2+rke2r1` y System Upgrade Controller. |

---

## 📝 Resumen del Trabajo Realizado Hasta Ahora (2026-08-04)

1. **Refactorización de la Arquitectura Modular (`shared/`):**
   - Extraída toda la lógica duplicada a `ansible/rke2/shared/` para hacer el temario 100% DRY.
   - Eliminados scripts hardcodeados y redundantes en el directorio raíz del módulo `rke2/`.
   - Creados los enlaces simbólicos `run_all.sh` -> `../shared/run_lab.sh` y `destroy_all.sh` -> `../shared/destroy_lab.sh` en cada subdirectorio de laboratorio.

2. **Validación del Lab 02 (Server Mono-nodo):**
   - Aprovisionada la VM `rke2-server1` en LXD.
   - Instalado RKE2 Server v1.35.6+rke2r1.
   - Extraído `kubeconfig.yaml` y verificado el acceso a `https://10.207.154.61:6443`.

3. **Validación del Lab 03 (CNI Cilium):**
   - Configurado `rke2_cni: cilium` en `group_vars/all.yml`.
   - Desplegados `cilium-operator` y `cilium-node` pods en estado `Running`.

4. **Validación del Lab 04 (Worker / Agent Nodes):**
   - Aprovisionadas 2 VMs de worker (`rke2-worker1`, `rke2-worker2`).
   - Conectadas al servidor a través del puerto supervisor `9345`.
   - Asignada la etiqueta de rol `worker` vía el módulo `kubernetes.core.k8s`.

5. **Validación del Lab 05 (Alta Disponibilidad con etcd + kube-vip):**
   - Desplegado un clúster de 3 Servers (quórum etcd distribuido) + 2 Workers.
   - Integrado `kube-vip` como DaemonSet para ofrecer VIP `10.207.154.60` en el puerto 6443 con ARP y leader election.
   - Despliegue secuencial (`serial: 1`) para garantizar que el primary server levante la VIP antes del join del resto de servidores.
   - Verificado con 2 ejecuciones consecutivas idempotentes (`changed=0`).

6. **Refactorización Completa a Módulos Nativos de Ansible:**
   - Sustituidos comandos de shell (`kubectl`, `sysctl`, `curl | sh`, `lxc delete`) por módulos Ansible nativos:
     - `kubernetes.core.k8s` y `kubernetes.core.k8s_info` (delegados a `localhost`).
     - `ansible.posix.sysctl`.
     - `community.general.lxd_container` (`state: absent`).
     - `ansible.builtin.get_url`.
   - Eliminado el paquete `incus` del host para evitar conflictos con LXD.

---

## 🎯 Próximos Pasos (Backlog de Trabajo)

1. **Laboratorio 06 (Registry):** Crear un registro local Docker de prueba e integrar el archivo `registries.yaml` para comprobar el pulling de imágenes privadas o espejadas.
2. **Laboratorio 07 (Actualizaciones):** Ejecutar la actualización en vivo de `v1.35.6+rke2r1` a `v1.36.2+rke2r1` sin pérdida de disponibilidad.
