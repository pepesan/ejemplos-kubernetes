# 🍃 Escenario 13: Percona Operator for MongoDB (Sharding)

Este laboratorio despliega un clúster de Kubernetes HA de **9 nodos** (3 managers + 6 workers, kube-vip), en diseño **hiperconvergente** (como los escenarios 07, 10, 11 y 12, no el 03: sin nodos de storage dedicados) con **Longhorn** como backend de almacenamiento persistente y **Cilium** como CNI con su LoadBalancer L2 nativo (igual que los escenarios 08, 10, 11 y 12, sin Gateway API — aquí no hace falta). Sobre esa base se despliega un clúster **MongoDB con sharding**: **2 shards** de **3 réplicas** cada uno (6 Pods de datos), más 3 config servers y 3 routers `mongos`, todo ello administrado íntegramente por el **Percona Operator for MongoDB**.

Último de la serie de 4 laboratorios centrados en operadores de bases de datos para Kubernetes (10-13), de nuevo del fabricante Percona (como los escenarios 10 y 12).

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 9 VMs, configurar el SO e instalar containerd/kubeadm/kubelet/kubectl.
*   **`06_inicializar_primer_manager.yml`**: instala **Cilium** vía Helm con `kubeProxyReplacement: true` y `l2announcements.enabled: true` (sin Gateway API), igual que en los escenarios 10, 11 y 12.
*   **`07_unir_managers.yml`** y **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los del escenario 02 sin cambios.
*   **`09_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy`, para exponer la BBDD con un `Service` `LoadBalancer` normal.
*   **`10_desplegar_headlamp.yml`**: despliega Headlamp Dashboard **justo después de formar el clúster**, antes que Longhorn o MongoDB, para poder seguir el resto de despliegues desde su consola web.
*   **`11_desplegar_longhorn.yml`**: instala Longhorn de forma hiperconvergente (los 6 workers alojan tanto réplicas de Longhorn como Pods de MongoDB).
*   **`12_desplegar_mongodb_operator.yml`**: instala el **Percona Operator for MongoDB** (chart `percona/psmdb-operator`) en el namespace `mongodb`.
*   **`13_desplegar_mongodb_cluster.yml`**: despliega el clúster MongoDB (chart `percona/psmdb-db`, CRD `PerconaServerMongoDB`) con `sharding.enabled: true`, dos shards (`rs0`, `rs1`, 3 réplicas cada uno), 3 config servers y 3 `mongos`, persistencia en Longhorn, y expone `mongos` con un `Service` `LoadBalancer`. La contraseña de `databaseAdmin` (generada automáticamente por el operador) se guarda en `mongodb_password.txt`, nunca en pantalla.
*   **`14_verificar_mongodb.yml`**: comprueba que ambos shards están registrados y activos, crea una colección con sharding habilitado, inserta 200 documentos y confirma que quedan repartidos entre los dos shards (no todos en uno), y comprueba el acceso TCP externo vía `mongos`.
*   **`15_add_nodes.yml`** / **`16_integrar_shard.yml`** / **`17_eliminar_shard.yml`**: escalado del clúster añadiendo/quitando una shard COMPLETA (ver "Escalar el clúster MongoDB" más abajo).
*   **`18_actualizar_motor_mongodb.yml`**: actualiza la versión del motor MongoDB sin downtime (ver "Actualizar el motor de MongoDB" más abajo).
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 13_k8s_percona_mongodb
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso:
*   🔗 **MongoDB (vía mongos):** IP propia asignada por el LB-IPAM de Cilium (mostrada al final de `run_all.sh`), usuario `databaseAdmin`, contraseña en `mongodb_password.txt`:
    ```bash
    mongosh "mongodb://databaseAdmin:<password>@<IP-DE-MONGODB>:27017/admin"
    ```
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`.

## 📈 Escalar el clúster MongoDB (añadir/quitar una shard completa)

A diferencia de los escenarios 10, 11 y 12 (donde escalar significa añadir una réplica más a un único conjunto), en un clúster con sharding escalar significa añadir una **shard nueva completa** (su propio replica set de 3 nodos) para repartir más datos en paralelo. Cada réplica de cada shard necesita su propio nodo de Kubernetes dedicado — así que añadir una shard implica añadir 3 nodos de Kubernetes a la vez:

```bash
# 1. Descomenta/añade las TRES líneas de nodo en [new_workers] en inventory.ini, luego:
ansible-playbook 15_add_nodes.yml       # crea las 3 VMs y las une al clúster de Kubernetes
ansible-playbook 16_integrar_shard.yml  # añade la shard rs2 (3 réplicas); caen en los 3 nodos nuevos

# Para deshacerlo (hay que indicar los tres nodos a quitar):
ansible-playbook 17_eliminar_shard.yml -e 'node_name=k8s-worker7 node_name2=k8s-worker8 node_name3=k8s-worker9'
```

`17_eliminar_shard.yml` retira la shard del CR (JSON Patch) y espera: el propio operador se encarga de **drenarla** con seguridad (`removeShard`, con reintentos hasta `state: completed`, migrando sus chunks a las shards restantes) y de borrar su `StatefulSet` una vez terminado — no hace falta llamar a `removeShard` a mano (ver "Decisiones de Diseño" más abajo). Solo cuando sus Pods han desaparecido del todo se destruyen las 3 VMs. Es idempotente incluso si una ejecución anterior quedó a medias.

## 🔄 Actualizar el motor de MongoDB

El laboratorio despliega deliberadamente una versión de MongoDB algo antigua (`mongodb_image_tag`, no la última disponible) para poder simular una actualización real sin downtime:

```bash
ansible-playbook 18_actualizar_motor_mongodb.yml
```

Solo hace falta parchear `spec.image` con la nueva versión (`mongodb_image_tag_upgrade` en `group_vars/all.yml`) — el propio operador se encarga de actualizar los Pods de todos los shards y config servers uno a uno, sin perder disponibilidad. El playbook comprueba que todos los shards siguen activos y la versión de MongoDB (`db.version()`) antes y después.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **9 nodos (3 managers + 6 workers), no 6 como en los escenarios 10-12:** con 2 shards de 3 réplicas cada uno (6 Pods de datos en total) y la política de "un Pod de BBDD por nodo" de los escenarios anteriores, hacen falta 6 workers dedicados a shards. Los 3 config servers y los `mongos` (sin estado, sin necesidad de nodo dedicado) comparten esos mismos 6 workers sin restricción, ya que no forman parte de la prueba de escalado (que solo añade/quita shards completos).
*   **Anti-affinity OBLIGATORIA por shard, no la preferente por defecto del chart (`antiAffinityTopologyKey`):** el campo simple `antiAffinityTopologyKey` del chart es solo PREFERENTE (lección aprendida en el escenario 12) — en un clúster pequeño puede acabar con varias réplicas del MISMO shard en el mismo nodo, de modo que si ese nodo cae se pierde el shard entero (no solo una réplica), rompiendo la tolerancia a fallos que el sharding pretende dar. Se usa en su lugar `affinity.advanced` (que el operador SÍ soporta, y permite anti-affinity de Kubernetes nativa y obligatoria), limitada a los Pods de CADA shard en concreto vía `labelSelector` — para repartir cada shard entre 3 nodos distintos sin forzar también reparto entre shards diferentes entre sí.
*   **Escalado añadiendo/quitando una shard COMPLETA (3 nodos a la vez), no una réplica suelta:** en un clúster con sharding, la unidad natural de escalado horizontal es la shard (un replica set completo), no una réplica individual dentro de una shard ya existente — así se demuestra el caso de uso real de MongoDB (repartir más datos en paralelo), no solo añadir más redundancia a los mismos datos.
*   **`spec.replsets` es una LISTA: se usa JSON Patch (`add`/`remove`), no un merge patch:** igual que en el escenario 12 (`spec.instances[0].replicas`), pero aquí el cambio es más simple porque se añade/quita el ELEMENTO ENTERO de la lista (no un campo dentro de un elemento existente) — encaja de forma natural con las operaciones `add`/`remove` de un JSON Patch (RFC 6902), sin arriesgarse a perder campos de otros elementos.
*   **Dejar que el propio operador llame a `removeShard`, no duplicarlo a mano:** el operador, al ver que una réplica desaparece de `spec.replsets`, ya llama él solo a `removeShard` (con reintentos hasta `state: completed`) y borra el `StatefulSet` una vez migrados los chunks — MongoDB no permite eliminar una shard sin drenarla antes, y esa garantía la da el operador. Se probó primero llamando a `removeShard` manualmente antes de tocar el CR, pero esto choca con el propio operador: al ver la réplica retirada del CR, intenta drenarla también él, y como para entonces el shard ya no existe en Mongo, esa llamada falla con `(ShardNotFound)` y deja el `Reconcile` permanentemente en error sin borrar el `StatefulSet` (confirmado en vivo). Dejar que sea el operador el único que llama a `removeShard` evita el problema.
*   **El usuario `databaseAdmin` no puede gestionar shards:** sus roles (`readWriteAnyDatabase`, `readAnyDatabase`, `dbAdminAnyDatabase`, `clusterMonitor`, `backup`, `restore`) no cubren `enableSharding`/`shardCollection`. Para eso hay que usar el usuario `clusterAdmin` (rol `clusterAdmin` + `directShardOperations`), generado automáticamente en el mismo Secret.
*   **El campo real del CRD es `persistentVolumeClaim`, no `pvc`:** al parchear el CR crudo directamente (p. ej. al añadir un shard nuevo vía JSON Patch), hay que usar el nombre real del campo — `pvc` es solo el nombre abreviado que usa el `values.yaml` del chart Helm, que el propio chart traduce internamente al aplicar el CR.
*   **Chart `percona/psmdb-db` en vez de un CR manual:** igual que con `pxc-db`/`pg-db` en los escenarios 10/12, el CR `PerconaServerMongoDB` tiene varios campos obligatorios que el chart oficial genera de forma correcta y consistente con la versión del operador instalado.
*   **`mongodb_image_tag` (motor de MongoDB) separado de `percona_psmdb_chart_version`/`percona_psmdb_db_chart_version` (operador/chart):** son versiones independientes, igual que en los escenarios 10, 11 y 12. Se fija además una versión de motor deliberadamente algo antigua para poder demostrar una actualización real con `18_actualizar_motor_mongodb.yml`.
*   **`expose.type: LoadBalancer` sobre `mongos`, no directamente sobre las shards:** `mongos` actúa como router y punto de entrada único para el cliente (enruta cada consulta a la shard correcta según su clave de partición), análogo al HAProxy del escenario 10, al `primaryService` del 11 y al pgBouncer del 12.
*   **Contraseña de `databaseAdmin` generada por el operador, no por Ansible:** al referenciar un nombre de `Secret` explícito (`secrets.users`) sin crearlo de antemano, el propio operador genera uno con contraseñas aleatorias para todos los usuarios de sistema (incluido `databaseAdmin`) la primera vez que no lo encuentra — Ansible solo lee el valor ya generado y lo guarda en `mongodb_password.txt` (permisos `0600`, excluido de git), sin imprimirlo nunca en la salida (`no_log: true` en las tareas que la usan).
*   **Verificación de sharding escribiendo 200 documentos y comprobando su reparto real entre shards:** es la prueba más directa de que el sharding realmente distribuye datos entre los dos `replsets`, no solo que el clúster "está arriba" y ambos shards aparecen registrados.
*   **Headlamp desplegado nada más formar el clúster:** mismo criterio ya aplicado en los escenarios 08, 09, 10, 11 y 12.
*   **`GLIBC_TUNABLES=glibc.pthread.rseq=1` en todos los contenedores `mongod`/`mongos`:** workaround de una incompatibilidad de plataforma (no del operador ni del laboratorio en sí) entre "restartable sequences" de glibc y kernels recientes de Linux, que hacía morir los Pods de MongoDB 8.x con SIGSEGV segundos después de arrancar en este entorno concreto. Se aplica vía `kubectl patch --type=json` sobre el CR justo después del `helm install`, porque el chart no propaga el campo `env` de sus propios `values` hasta el CR real (ver `PLAN.md` para el detalle completo del diagnóstico).
