# Ejemplos de Ansible para Kubernetes en LXD

Automatizaciones de Ansible para desplegar clústeres de Kubernetes de prueba de forma local usando LXD. El directorio se organiza en las siguientes secciones:

## 📂 Estructura

### [`base/`](base/) — Laboratorios Kubernetes (kubeadm)

Los 14 laboratorios numerados, de menor a mayor complejidad: desde un único nodo hasta clústeres HA con almacenamiento distribuido, red/Ingress, observabilidad, operadores de bases de datos y secretos dinámicos con Vault. Cada uno es autocontenido (su propio `run_all.sh`/`destroy_all.sh`, inventario y `group_vars`). Incluye también la preparación del host (LXD, `kubectl`, `helm`) y la validación de requisitos que todos comparten.

Ver [`base/README.md`](base/README.md) para el índice completo, requisitos previos, instrucciones de uso y las decisiones de diseño detrás de cada laboratorio.

### [`rke2/`](rke2/) — Módulo RKE2 (Rancher Kubernetes Engine 2)

Ejemplos y laboratorios dedicados a **RKE2 (Rancher Kubernetes Engine 2)** organizados según el temario oficial de despliegue de RKE2: requisitos de hardware/red, Server Node mono-nodo, configuración de CNI (Canal, Cilium, Calico), Worker Nodes (agents), clústeres HA con etcd distribuido, registros privados de Docker/Containerd y estrategias de actualización.

Ver [`rke2/README.md`](rke2/README.md) para la correspondencia detallada con el temario y guías de uso.

### [`roles/`](roles/) — Roles reutilizables

Roles de Ansible independientes, extraídos de la lógica duplicada entre los laboratorios de `base/`. No están (todavía) integrados en ningún laboratorio — son autocontenidos, con sus propias pruebas Molecule, y se escriben íntegramente en inglés (a diferencia de los laboratorios de `base/`, en español):

- [`lxd_host_bootstrap`](roles/lxd_host_bootstrap/): prepara un host para ejecutar los laboratorios de `base/` (LXD, `kubectl`, `helm`, red/storage/perfil de LXD, imagen base).
- [`lxd_machine_provision`](roles/lxd_machine_provision/): crea instancias LXD (VM o contenedor) para un grupo de inventario dado, y las deja accesibles por SSH.

Ver [`roles/README.md`](roles/README.md) para más detalle.

## 🗺️ Plan de Ruta y Estado

El roadmap completo, el estado de validación de cada laboratorio y el backlog de próximos roles están en [`PLAN.md`](PLAN.md).
