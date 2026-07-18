# 🐘 Escenario 12: Percona Operator for PostgreSQL

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (3 managers + 3 workers, kube-vip), en diseño **hiperconvergente** (como los escenarios 07, 10 y 11, no el 03: sin nodos de storage dedicados) con **Longhorn** como backend de almacenamiento persistente y **Cilium** como CNI con su LoadBalancer L2 nativo (igual que los escenarios 08, 10 y 11, sin Gateway API — aquí no hace falta). Sobre esa base se despliega un clúster **PostgreSQL** con alta disponibilidad gestionada por **Patroni** (un primario + réplicas de solo lectura vía streaming replication, no multi-máster como Galera), todo ello administrado íntegramente por el **Percona Operator for PostgreSQL**.

Tercero de una serie de 4 laboratorios centrados en operadores de bases de datos para Kubernetes (10-13); a diferencia del 11 (MariaDB), este vuelve a ser del fabricante Percona, como el 10.

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs, configurar el SO e instalar containerd/kubeadm/kubelet/kubectl.
*   **`06_inicializar_primer_manager.yml`**: instala **Cilium** vía Helm con `kubeProxyReplacement: true` y `l2announcements.enabled: true` (sin Gateway API), igual que en los escenarios 10 y 11.
*   **`07_unir_managers.yml`** y **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los del escenario 02 sin cambios.
*   **`09_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy`, para exponer la BBDD con un `Service` `LoadBalancer` normal.
*   **`10_desplegar_headlamp.yml`**: despliega Headlamp Dashboard **justo después de formar el clúster**, antes que Longhorn o PostgreSQL, para poder seguir el resto de despliegues desde su consola web.
*   **`11_desplegar_longhorn.yml`**: instala Longhorn de forma hiperconvergente (los 3 workers alojan tanto réplicas de Longhorn como Pods de PostgreSQL).
*   **`12_desplegar_pg_operator.yml`**: instala el **Percona Operator for PostgreSQL** (chart `percona/pg-operator`) en el namespace `postgres`.
*   **`13_desplegar_pg_cluster.yml`**: despliega el clúster PostgreSQL (chart `percona/pg-db`, CRD `PerconaPGCluster`) con 3 réplicas, persistencia en Longhorn, pgBouncer como *connection pooler*, backups locales con pgBackRest (repo PVC, sin S3), y expone pgBouncer con un `Service` `LoadBalancer` (`expose.type: LoadBalancer`). La contraseña del usuario (generada automáticamente por el operador) se guarda en `pg_password.txt`, nunca en pantalla.
*   **`14_verificar_pg.yml`**: identifica el Pod primario y una réplica (etiquetas `postgres-operator.crunchydata.com/role`), escribe en el primario y lee desde la réplica (confirma la replicación), y comprueba el acceso TCP externo vía pgBouncer.
*   **`15_add_nodes.yml`** / **`16_integrar_nodos_pg.yml`** / **`17_eliminar_nodos.yml`**: escalado del clúster (ver "Escalar el clúster PostgreSQL" más abajo).
*   **`18_actualizar_motor_pg.yml`**: actualiza la versión del motor PostgreSQL sin downtime (ver "Actualizar el motor de PostgreSQL" más abajo).
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 12_k8s_percona_postgresql
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso:
*   🔗 **PostgreSQL (vía pgBouncer):** IP propia asignada por el LB-IPAM de Cilium (mostrada al final de `run_all.sh`), usuario y base de datos `pg-cluster`, contraseña en `pg_password.txt`:
    ```bash
    psql -h <IP-DE-POSTGRESQL> -U pg-cluster -d pg-cluster
    ```
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`.

## 📈 Escalar el clúster PostgreSQL

Cada réplica de PostgreSQL necesita su **propio nodo de Kubernetes dedicado** (nunca comparte nodo con otra réplica) — así que escalar el clúster implica primero escalar el propio clúster de Kubernetes. A diferencia de los escenarios 10 y 11 (motores Galera multi-máster, que exigen tamaño IMPAR por quórum), **Patroni no impone esa restricción** (un solo primario + réplicas de solo lectura), así que aquí se escala de **una en una**:

```bash
# 1. Descomenta/añade una línea de nodo en [new_workers] en inventory.ini, luego:
ansible-playbook 15_add_nodes.yml       # crea la VM y la une al clúster de Kubernetes
ansible-playbook 16_integrar_nodos_pg.yml  # amplía el clúster PostgreSQL (+1 réplica); cae en el nodo nuevo

# Para deshacerlo:
ansible-playbook 17_eliminar_nodos.yml -e 'node_name=k8s-worker4'
```

`17_eliminar_nodos.yml` reduce primero `spec.instances[0].replicas` (deja que el operador retire la réplica de forma ordenada) y solo cuando esa réplica ha desaparecido del todo destruye la VM — nunca al revés. Nunca reduce por debajo de 3 réplicas. Es idempotente incluso si una ejecución anterior quedó a medias.

## 🔄 Actualizar el motor de PostgreSQL

El laboratorio despliega deliberadamente una versión de PostgreSQL algo antigua (`percona_pg_image_tag`, no la última disponible) para poder simular una actualización real sin downtime:

```bash
ansible-playbook 18_actualizar_motor_pg.yml
```

Solo hace falta parchear `spec.image` con la nueva versión (`percona_pg_image_tag_upgrade` en `group_vars/all.yml`) — el propio operador se encarga de actualizar los Pods uno a uno (réplicas primero, primario al final con una conmutación de Patroni), sin perder disponibilidad. El playbook comprueba que todos los Pods siguen listos y la versión de PostgreSQL (`SHOW server_version`) antes y después.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Diseño hiperconvergente (3 managers + 3 workers), igual que los escenarios 10 y 11:** con 3 réplicas y 3 workers hiperconvergentes, cada réplica de PostgreSQL encaja uno por nodo sin necesitar VMs adicionales dedicadas solo a almacenamiento.
*   **Un nodo de Kubernetes dedicado por cada réplica, siempre:** igual que en los escenarios 10 y 11, se refuerza a nivel de proceso que escalar el clúster (`16_integrar_nodos_pg.yml`) siempre va precedido de añadir un nodo de Kubernetes dedicado (`15_add_nodes.yml`), y reducirlo (`17_eliminar_nodos.yml`) siempre retira también su nodo.
*   **Escalado de una en una réplica, no de dos en dos como en los escenarios 10 y 11:** Patroni gestiona la alta disponibilidad con un único primario elegido por consenso y réplicas de solo lectura (streaming replication), sin la restricción de paridad de los motores Galera multi-máster — no hay riesgo de "split brain" al añadir/quitar una sola réplica.
*   **Cilium (CNI + LB-IPAM), sin Gateway API:** mismo criterio que en los escenarios 10 y 11.
*   **Chart `percona/pg-db` en vez de un CR manual:** igual que con `pxc-db` en el escenario 10, el CR `PerconaPGCluster` tiene varios campos obligatorios (imagen, versión, instancias, proxy, backups) que el chart oficial genera de forma correcta y consistente con la versión del operador instalado.
*   **`percona_pg_image_tag` (motor de PostgreSQL) separado de `percona_pg_chart_version`/`percona_pg_db_chart_version` (operador/chart):** son versiones independientes, igual que en los escenarios 10 y 11. Se fija además una versión de motor deliberadamente algo antigua para poder demostrar una actualización real con `18_actualizar_motor_pg.yml`.
*   **`backups.enabled: true` con un repo local (PVC de Longhorn), no S3:** a diferencia de MySQL/MariaDB (donde se dejaron los backups desactivados por completo), el operador de PostgreSQL integra pgBackRest de forma más estrecha con el propio ciclo de vida del clúster — se mantiene activado con un repositorio local sencillo, sin necesitar credenciales de un backend externo.
*   **`expose.type: LoadBalancer` sobre pgBouncer, no directamente sobre las instancias:** pgBouncer actúa como *connection pooler* y punto de entrada único que Patroni mantiene siempre apuntando al primario actual, análogo al HAProxy del escenario 10 y al `primaryService` del escenario 11.
*   **Contraseña generada por el operador, no por Ansible:** al no definir un `Secret` de usuario explícito, el propio operador genera uno con contraseña aleatoria (`<cluster>-pguser-<cluster>`) la primera vez que no lo encuentra — Ansible solo lee el valor ya generado y lo guarda en `pg_password.txt` (permisos `0600`, excluido de git), sin imprimirlo nunca en la salida (`no_log: true` en las tareas que la usan).
*   **Identificación de Pods por etiqueta (`postgres-operator.crunchydata.com/role`), no por ordinal fijo:** a diferencia de PXC/MariaDB (donde los Pods siguen un patrón `-0`, `-1`, `-2` predecible), este operador no garantiza nombres de Pod deterministas para el *instance set* — localizar el primario/réplicas y sus PVC siempre se hace vía selectores de etiquetas, nunca asumiendo un sufijo numérico.
*   **Headlamp desplegado nada más formar el clúster:** mismo criterio ya aplicado en los escenarios 08, 09, 10 y 11.
