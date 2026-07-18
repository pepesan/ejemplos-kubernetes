# 🐬 Escenario 10: Percona Operator for MySQL (PXC/Galera)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (3 managers + 3 workers, kube-vip), en diseño **hiperconvergente** (como el escenario 07, no el 03: sin nodos de storage dedicados) con **Longhorn** como backend de almacenamiento persistente y **Cilium** como CNI con su LoadBalancer L2 nativo (igual que el escenario 08, pero sin Gateway API — aquí no hace falta). Sobre esa base se despliega un clúster **Percona XtraDB Cluster** (MySQL con replicación síncrona Galera, multi-maestro) gestionado íntegramente por el **Percona Operator for MySQL**.

Primero de una serie de 4 laboratorios centrados en operadores de bases de datos para Kubernetes (10-13), todos del fabricante Percona salvo el 11 (MariaDB real, vía el operador comunitario `mariadb-operator`).

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs, configurar el SO e instalar containerd/kubeadm/kubelet/kubectl.
*   **`06_inicializar_primer_manager.yml`**: **no** se reutiliza el del escenario 02 (que instala Flannel) — instala **Cilium** vía Helm con `kubeProxyReplacement: true` y `l2announcements.enabled: true` (sin `gatewayAPI`, a diferencia del escenario 08: aquí no se usa Gateway API en absoluto).
*   **`07_unir_managers.yml`** y **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los del escenario 02 sin cambios.
*   **`09_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy`, para poder exponer la BBDD con un `Service` `LoadBalancer` normal más adelante.
*   **`10_desplegar_headlamp.yml`**: despliega Headlamp Dashboard **justo después de formar el clúster**, antes que Longhorn o Percona, para poder seguir el resto de despliegues desde su consola web.
*   **`11_desplegar_longhorn.yml`**: instala Longhorn de forma hiperconvergente (sin taints ni separación de roles, igual que en el escenario 07): los 3 workers alojan tanto réplicas de Longhorn como Pods de PXC, con `StorageClass` por defecto a 3 réplicas.
*   **`12_desplegar_percona_operator.yml`**: instala el Percona Operator for MySQL (chart `percona/pxc-operator`) en el namespace `pxc`.
*   **`13_desplegar_pxc_cluster.yml`**: despliega el clúster PXC (chart `percona/pxc-db`, CRD `PerconaXtraDBCluster`) con 3 réplicas Galera + 2 HAProxy, persistencia en Longhorn, y expone HAProxy con un `Service` `LoadBalancer` (`haproxy.exposePrimary.type: LoadBalancer`). La contraseña root (generada automáticamente por el operador) se guarda en `pxc_root_password.txt`, nunca en pantalla.
*   **`14_verificar_pxc.yml`**: escribe un dato en un nodo PXC y lo lee desde otro distinto (confirma la replicación síncrona Galera), y comprueba el acceso TCP externo vía la IP del LoadBalancer.
*   **`15_add_nodes.yml`** / **`16_integrar_nodos_pxc.yml`** / **`17_eliminar_nodos.yml`**: escalado del clúster (ver "Escalar el clúster PXC" más abajo). A diferencia de otros laboratorios, aquí la unión al clúster de Kubernetes (`15`) y la integración en PXC (`16`) están separadas en dos playbooks distintos, mismo patrón que en los escenarios 03/04/05 con sus motores de almacenamiento.
*   **`18_actualizar_motor_pxc.yml`**: actualiza la versión del motor MySQL/Galera sin downtime (ver "Actualizar el motor de PXC" más abajo).
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 10_k8s_percona_mysql_pxc
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso:
*   🔗 **MySQL (PXC vía HAProxy):** IP propia asignada por el LB-IPAM de Cilium (mostrada al final de `run_all.sh`), usuario `root`, contraseña en `pxc_root_password.txt`:
    ```bash
    mysql -h <IP-DE-PXC> -u root -p
    ```
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`.

## 📈 Escalar el clúster PXC

Cada réplica de MySQL/Galera necesita su **propio nodo de Kubernetes dedicado** (nunca comparte nodo con otra réplica) — así que escalar el clúster PXC implica primero escalar el propio clúster de Kubernetes. Además, el operador exige que `spec.pxc.size` sea siempre **IMPAR** (quórum Galera), así que el escalado se hace siempre de **2 en 2** (nunca +1/-1), y por tanto siempre añadiendo/quitando **2 nodos de Kubernetes dedicados a la vez**. El flujo tiene tres pasos:

```bash
# 1. Descomenta/añade las dos líneas de nodo en [new_workers] en inventory.ini, luego:
ansible-playbook 15_add_nodes.yml            # crea las 2 VMs y las une al clúster de Kubernetes
ansible-playbook 16_integrar_nodos_pxc.yml   # amplía el clúster PXC (+2 réplicas); caen en los 2 nodos nuevos

# Para deshacerlo (hay que indicar los dos nodos a quitar):
ansible-playbook 17_eliminar_nodos.yml -e 'node_name=k8s-worker4 node_name2=k8s-worker5'
```

`17_eliminar_nodos.yml` reduce primero `spec.pxc.size` en 2 (deja que el operador expulse las 2 réplicas de Galera de forma ordenada) y solo cuando esas réplicas han desaparecido del todo destruye las VMs — nunca al revés, para no arriesgarse a perder un nodo Galera vivo de golpe. Nunca reduce por debajo de 3 réplicas (el quórum Galera mínimo). Tanto `16` como `17` comprueban, antes y después de escalar, que Galera realmente reconoce el tamaño correcto (`SHOW STATUS LIKE 'wsrep_cluster_size'`) y que todas las réplicas están `Synced` (`wsrep_local_state_comment`) — no solo que el Pod esté `Running`. Ambos son idempotentes incluso si una ejecución anterior quedó a medias (p.ej. interrumpida tras el escalado de PXC pero antes de terminar de limpiar los nodos).

## 🔄 Actualizar el motor de PXC

El laboratorio despliega deliberadamente una versión de Percona XtraDB Cluster algo antigua (`percona_pxc_image_tag`, no la última disponible) para poder simular una actualización real sin downtime:

```bash
ansible-playbook 18_actualizar_motor_pxc.yml
```

Solo hace falta parchear `spec.pxc.image` con la nueva versión (`percona_pxc_image_tag_upgrade` en `group_vars/all.yml`) — el propio operador, con `updateStrategy: SmartUpdate` (valor por defecto del chart), se encarga de actualizar los 3 Pods **uno a uno**, esperando a que cada uno vuelva a estar `Synced` en Galera antes de continuar con el siguiente. El playbook comprueba la salud del clúster y la versión de MySQL (`SELECT VERSION()`) antes y después.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Diseño hiperconvergente (3 managers + 3 workers), no separación storage/workload como en el escenario 03:** Percona XtraDB Cluster necesita 3 réplicas Galera (quórum) y el operador aplica anti-affinity por nodo (`pxc.affinity.antiAffinityTopologyKey: kubernetes.io/hostname`, preferente a nivel de Kubernetes) — con exactamente 3 workers hiperconvergentes (cada uno alojando tanto Longhorn como un Pod de PXC, igual que el escenario 07), las 3 réplicas encajan perfectamente uno por nodo sin necesitar VMs adicionales dedicadas solo a almacenamiento.
*   **Un nodo de Kubernetes dedicado por cada réplica, siempre, no solo "cuando el operador lo prefiera":** aunque la anti-affinity del operador es preferente (no bloquearía el despliegue si dos réplicas cayeran en el mismo nodo), este laboratorio refuerza la regla a nivel de proceso: escalar el clúster PXC (`16_integrar_nodos_pxc.yml`) siempre va precedido de añadir un nodo de Kubernetes dedicado (`15_add_nodes.yml`), y reducirlo (`17_eliminar_nodos.yml`) siempre retira también su nodo — así se refleja fielmente cómo se dimensionaría un clúster Galera en producción real.
*   **Cilium (CNI + LB-IPAM) en vez de MetalLB, y sin Gateway API:** se reutiliza el mismo Cilium ya validado en el escenario 08 para el CNI y el LoadBalancer L2, pero sin activar `gatewayAPI` — para exponer una base de datos, un `Service` `LoadBalancer` normal (API estable de Kubernetes) es la opción recomendada; `TCPRoute` de Gateway API sigue siendo un recurso experimental (spec inestable) y Cilium ni siquiera lo implementa todavía en su dataplane, así que no aporta nada frente a la alternativa estable para este caso de uso.
*   **Chart `percona/pxc-db` en vez de un CR manual:** escribir a mano un `PerconaXtraDBCluster` completo requiere conocer varios campos obligatorios (`secretsName`, `crVersion`, configuración de cada componente); el chart oficial de Percona genera un CR correcto y consistente con la versión del operador instalada.
*   **`percona_pxc_image_tag` (motor de MySQL/Galera) separado de `percona_pxc_chart_version` (operador/chart):** son dos versiones independientes — la del chart de Helm/operador y la de la propia imagen de base de datos que ese operador gestiona. Se fija además una versión de motor deliberadamente algo antigua (no la última disponible) para poder demostrar una actualización real con `18_actualizar_motor_pxc.yml`.
*   **`haproxy.exposePrimary.type: LoadBalancer`:** es el mecanismo que el propio chart ofrece para exponer el endpoint de escritura (a través de HAProxy, que ya hace de balanceador de conexiones entre los 3 nodos Galera) sin tener que crear un `Service` adicional a mano.
*   **Contraseña root generada por el operador, no por Ansible:** al no definir `secrets.passwords` en los values de Helm, el propio operador genera el `Secret` (`pxc-db-secrets`) con contraseñas aleatorias para todos los usuarios internos (root, xtrabackup, monitor, replicación...) la primera vez que no lo encuentra — Ansible solo lee el valor ya generado y lo guarda en `pxc_root_password.txt` (permisos `0600`, excluido de git), sin imprimirlo nunca en la salida (`no_log: true` en las tareas que la usan).
*   **`backup.enabled: false`:** sin un backend de almacenamiets (S3 o compatible) configurado, no tiene sentido activar el mecanismo de backups del operador para un laboratorio didáctico — se mantiene fuera de alcance, igual que se hizo con la persistencia de PostgreSQL en el escenario 08.
*   **Recursos de PXC/HAProxy reducidos frente a los valores por defecto del chart:** los valores por defecto (1 CPU/1GB por Pod de PXC y de HAProxy) están pensados para clústeres de producción; se reducen a un tamaño que cabe cómodamente en las VMs de este laboratorio (workers de 2 CPU/3GB) sin comprometer la demostración.
*   **`pxc_haproxy_size: 2`, no 1:** el propio operador de Percona rechaza (`state: error`, sin crear ningún Pod) una configuración con menos de 2 réplicas de HAProxy — es una comprobación de "safe defaults" pensada para no dejar sin balanceador de conexiones si cae una réplica. Con 2 HAProxy (repartidos en 2 de los 3 workers) se cumple el mínimo sin necesitar `spec.unsafeFlags.proxySize: true`.
*   **Verificación de replicación escribiendo en un nodo y leyendo en otro:** es la prueba más directa de que Galera realmente replica de forma síncrona entre los 3 nodos PXC, no solo que el clúster "está arriba".
*   **Headlamp desplegado nada más formar el clúster:** mismo criterio ya aplicado en los escenarios 08 y 09 — permite seguir desde la consola web cómo se despliegan Longhorn y el operador de Percona a medida que se ejecutan los siguientes pasos.
