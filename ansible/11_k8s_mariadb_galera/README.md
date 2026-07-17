# 🦭 Escenario 11: MariaDB Galera (mariadb-operator)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (3 managers + 3 workers, kube-vip), en diseño **hiperconvergente** (como los escenarios 07 y 10, no el 03: sin nodos de storage dedicados) con **Longhorn** como backend de almacenamiento persistente y **Cilium** como CNI con su LoadBalancer L2 nativo (igual que los escenarios 08 y 10, sin Gateway API — aquí no hace falta). Sobre esa base se despliega un clúster **MariaDB** con replicación síncrona **Galera** (multi-maestro), gestionado íntegramente por el operador comunitario **mariadb-operator**.

Segundo de una serie de 4 laboratorios centrados en operadores de bases de datos para Kubernetes (10-13); a diferencia de los otros tres (todos del fabricante Percona), este usa MariaDB real vía `mariadb-operator`.

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs, configurar el SO e instalar containerd/kubeadm/kubelet/kubectl.
*   **`06_inicializar_primer_manager.yml`**: instala **Cilium** vía Helm con `kubeProxyReplacement: true` y `l2announcements.enabled: true` (sin Gateway API), igual que en el escenario 10.
*   **`07_unir_managers.yml`** y **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los del escenario 02 sin cambios.
*   **`09_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy`, para exponer la BBDD con `Service`s `LoadBalancer` normales.
*   **`10_desplegar_headlamp.yml`**: despliega Headlamp Dashboard **justo después de formar el clúster**, antes que Longhorn o MariaDB, para poder seguir el resto de despliegues desde su consola web.
*   **`11_desplegar_longhorn.yml`**: instala Longhorn de forma hiperconvergente (los 3 workers alojan tanto réplicas de Longhorn como Pods de MariaDB).
*   **`12_desplegar_mariadb_operator.yml`**: instala **mariadb-operator** vía Helm (charts `mariadb-operator-crds` y `mariadb-operator`) en el namespace `mariadb`.
*   **`13_desplegar_mariadb_cluster.yml`**: crea el recurso `MariaDB` (CRD `k8s.mariadb.com/v1alpha1`) con `galera.enabled: true`, 3 réplicas, persistencia en Longhorn, y expone tanto el Service general como el `primaryService` (solo escritura) como `LoadBalancer`. La contraseña root (generada automáticamente por el operador vía `rootPasswordSecretKeyRef.generate: true`) se guarda en `mariadb_root_password.txt`, nunca en pantalla.
*   **`14_verificar_mariadb.yml`**: escribe un dato en un nodo MariaDB y lo lee desde otro distinto (confirma la replicación síncrona Galera), y comprueba el acceso TCP externo vía la IP del `primaryService`.
*   **`15_add_nodes.yml`** / **`16_integrar_nodos_mariadb.yml`** / **`17_eliminar_nodos.yml`**: escalado del clúster (ver "Escalar el clúster MariaDB" más abajo).
*   **`18_actualizar_motor_mariadb.yml`**: actualiza la versión del motor MariaDB/Galera sin downtime (ver "Actualizar el motor de MariaDB" más abajo).
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 11_k8s_mariadb_galera
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso:
*   🔗 **MariaDB (vía el Service primario, solo escritura):** IP propia asignada por el LB-IPAM de Cilium (mostrada al final de `run_all.sh`), usuario `root`, contraseña en `mariadb_root_password.txt`:
    ```bash
    mysql -h <IP-DE-MARIADB> -u root -p
    ```
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`.

## 📈 Escalar el clúster MariaDB

Cada réplica de MariaDB/Galera necesita su **propio nodo de Kubernetes dedicado** (nunca comparte nodo con otra réplica) — así que escalar el clúster MariaDB implica primero escalar el propio clúster de Kubernetes. Al igual que en el escenario 10 (Percona), `mariadb-operator` exige en tiempo real que `spec.replicas` sea **IMPAR** (rechaza la operación con *"An odd number of MariaDB instances is required to avoid split brain situations for Galera"* si no — confirmado en vivo, no solo por la documentación), así que aquí también se escala siempre de **2 en 2**:

```bash
# 1. Descomenta/añade las dos líneas de nodo en [new_workers] en inventory.ini, luego:
ansible-playbook 15_add_nodes.yml               # crea las 2 VMs y las une al clúster de Kubernetes
ansible-playbook 16_integrar_nodos_mariadb.yml  # amplía el clúster MariaDB (+2 réplicas); caen en los 2 nodos nuevos

# Para deshacerlo (hay que indicar los dos nodos a quitar):
ansible-playbook 17_eliminar_nodos.yml -e 'node_name=k8s-worker4 node_name2=k8s-worker5'
```

`17_eliminar_nodos.yml` reduce primero `spec.replicas` en 2 (deja que el operador expulse las 2 réplicas de Galera de forma ordenada) y solo cuando esas réplicas han desaparecido del todo destruye las VMs — nunca al revés, para no arriesgarse a perder un nodo Galera vivo de golpe. Nunca reduce por debajo de 3 réplicas (el quórum Galera mínimo). Tanto `16` como `17` comprueban, antes y después de escalar, que Galera realmente reconoce el tamaño correcto (`SHOW STATUS LIKE 'wsrep_cluster_size'`) y que todas las réplicas están `Synced` (`wsrep_local_state_comment`) — no solo que el Pod esté `Running`. Ambos son idempotentes incluso si una ejecución anterior quedó a medias.

## 🔄 Actualizar el motor de MariaDB

El laboratorio despliega deliberadamente una versión de MariaDB algo antigua (`mariadb_image_tag`, no la última disponible) para poder simular una actualización real sin downtime:

```bash
ansible-playbook 18_actualizar_motor_mariadb.yml
```

Solo hace falta parchear `spec.image` con la nueva versión (`mariadb_image_tag_upgrade` en `group_vars/all.yml`) — el propio operador se encarga de actualizar los Pods **uno a uno**, esperando a que cada uno vuelva a estar `Synced` en Galera antes de continuar con el siguiente. El playbook comprueba la salud del clúster y la versión de MariaDB (`SELECT VERSION()`) antes y después.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Diseño hiperconvergente (3 managers + 3 workers), igual que el escenario 10:** MariaDB Galera necesita 3 réplicas (quórum) y con exactamente 3 workers hiperconvergentes (cada uno alojando tanto Longhorn como un Pod de MariaDB) las 3 réplicas encajan perfectamente uno por nodo sin necesitar VMs adicionales dedicadas solo a almacenamiento.
*   **Un nodo de Kubernetes dedicado por cada réplica, siempre:** igual que en el escenario 10, se refuerza a nivel de proceso (no solo de configuración) que escalar el clúster MariaDB (`16_integrar_nodos_mariadb.yml`) siempre va precedido de añadir un nodo de Kubernetes dedicado (`15_add_nodes.yml`), y reducirlo (`17_eliminar_nodos.yml`) siempre retira también su nodo.
*   **Escalado de dos en dos réplicas, igual que en el escenario 10:** `mariadb-operator` también rechaza en tiempo de ejecución cualquier tamaño par de `spec.replicas` (mismo motivo que Percona: evitar split-brain en Galera) — se descubrió probándolo en vivo (la documentación pública no lo menciona explícitamente), así que el diseño de escalado es idéntico al del escenario 10: siempre de 2 en 2, con 2 nodos de Kubernetes dedicados a la vez.
*   **Cilium (CNI + LB-IPAM), sin Gateway API:** mismo criterio que en el escenario 10 — para exponer una base de datos, un `Service` `LoadBalancer` normal (API estable) es preferible a `TCPRoute` de Gateway API, que sigue siendo experimental y que Cilium ni siquiera implementa en su dataplane.
*   **CRD `MariaDB` aplicado directamente, sin el chart `mariadb-cluster`:** a diferencia de Percona (que requiere el chart `pxc-db` porque el CR tiene varios campos obligatorios difíciles de acertar a mano), el CRD `MariaDB` de `mariadb-operator` es lo bastante simple para aplicarlo directamente con `kubernetes.core.k8s`, evitando una capa de indirección de Helm innecesaria.
*   **`mariadb_image_tag` (motor de MariaDB/Galera) separado de `mariadb_operator_chart_version` (operador):** son dos versiones independientes, igual que en el escenario 10. Se fija además una versión de motor deliberadamente algo antigua para poder demostrar una actualización real con `18_actualizar_motor_mariadb.yml`.
*   **`rootPasswordSecretKeyRef` con `generate: true`, no un `Secret` creado por Ansible:** el propio operador genera un password aleatorio y lo guarda en el `Secret` indicado la primera vez que no lo encuentra — Ansible solo lee el valor ya generado y lo guarda en `mariadb_root_password.txt` (permisos `0600`, excluido de git), sin imprimirlo nunca en la salida (`no_log: true` en las tareas que la usan). Se referencia el `Secret` de forma explícita (con nombre predecible) en vez de dejar que el operador elija su propio nombre implícito, para no tener que adivinarlo después.
*   **`service`/`primaryService` de tipo `LoadBalancer`:** `mariadb-operator` crea automáticamente un Service general (reparte conexiones entre todos los nodos Galera) y, si se pide, un `primaryService` dedicado solo al nodo primario — se usa este último como endpoint de escritura recomendado, análogo al `haproxy.exposePrimary` del escenario 10.
*   **`tls.enabled` y `metrics.enabled` no activados:** fuera de alcance para un laboratorio didáctico (TLS añadiría gestión de certificados; `metrics` requiere los CRDs de `kube-prometheus-stack` instalados), igual criterio que se aplicó con los backups en el escenario 10.
*   **Headlamp desplegado nada más formar el clúster:** mismo criterio ya aplicado en los escenarios 08, 09 y 10.
