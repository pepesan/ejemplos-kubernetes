# 🗺️ Plan de Ruta: Módulo RKE2 (Rancher Kubernetes Engine 2)

Este documento contiene el plan de trabajo, estado de implementación y decisiones de diseño para la serie de ejemplos de RKE2.

---

## 📋 Lista de Laboratorios RKE2

- [x] **01. Requisitos: Hardware y Red** (`01_requisitos_hardware_red`): Documentación y playbooks de validación de hardware, puertos y kernel para RKE2.
- [ ] **02. Server Node Single** (`02_rke2_server_single_node`): Despliegue mono-nodo RKE2 Server en VM LXD.
- [ ] **03. Configuración de CNI** (`03_cni_configuration`): Selección y ajuste de Canal, Cilium o Calico vía `HelmChartConfig`.
- [ ] **04. Worker Node / Agent** (`04_worker_node_agent`): Aprovisionamiento de RKE2 Agents y unión al plano de control.
- [ ] **05. Alta Disponibilidad (HA)** (`05_ha_cluster_etcd`): 3 Server Nodes con etcd embebido y kube-vip / LB externo.
- [ ] **06. Registros Privados (Docker Registry)** (`06_docker_private_registry`): Configuración de `registries.yaml` para mirrors y credenciales.
- [ ] **07. Actualizaciones del Clúster** (`07_actualizaciones_cluster`): Rolling upgrades con Ansible y System Upgrade Controller.

---

## 📐 Decisiones de Diseño

1. **RKE2 sobre LXD VMs:** Se utilizan VMs LXD (`limits.cpu`, `limits.memory`) en lugar de contenedores LXD para garantizar compatibilidad total con `containerd`, `etcd`, `iptables`/`nftables` y módulos de CNI sin requerir privilegios o workarounds de kernel.
2. **Puerto Supervisor RKE2:** El puerto `9345` se utiliza para la unión de nodos (`rke2-server` y `rke2-agent`), mientras que `6443` expone la API de Kubernetes estándar.
3. **Idempotencia:** Todos los playbooks de RKE2 deben ser idempotentes; ejecutar `ansible-playbook` una segunda vez sobre un clúster en funcionamiento debe resultar en `changed=0` (salvo que varíen tokens o certificados dinámicos).
