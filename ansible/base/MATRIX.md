# 📊 Matriz de Revalidación de Laboratorios Base

Documento de seguimiento de revalidaciones post-cambios en versiones y parametrización de imágenes.
---

## ✅ Estado Verificado por Lab

| Lab | Estado | Pass 1 | Pass 2 | Notas |
|-----|--------|--------|--------|-------|
| 01 | ✅ Validado (VMs reales) | exit=0, 207s, failed=0 | exit=0, 60s, changed=0, failed=0 | Idempotencia real confirmada, revisado línea a línea |
| 02 | ✅ Validado (VMs reales) | exit=0, 536s, failed=0 | exit=0, changed>0 mínimo, failed=0 | Ver detalle abajo — changeds explicados, no son bugs |
| 03 | ⏳ Pendiente de re-test | — | — | Resultado previo era falso positivo (falló por falta de imagen base) |
| 04 | ⏳ Pendiente de re-test | — | — | Resultado previo era falso positivo (falló por falta de imagen base) |
| 05 | ⏳ Pendiente de re-test | — | — | Resultado previo era falso positivo (falló por falta de imagen base) |
| 06 | ⏳ Pendiente de re-test | — | — | Resultado previo era falso positivo (falló por falta de imagen base) |
| 07 | ✅ Validado (VMs reales) | exit=0, 598s, failed=0 | exit=0, 111s, changed=3 total, failed=0 | Ver detalle abajo — mismos patrones que Lab 02, no son bugs |
| 08 | ⏳ Pendiente de re-test | — | — | Resultado previo era falso positivo (falló por falta de imagen base) |
| 09 | ✅ Validado (VMs reales) | exit=0, 665s, failed=0 | exit=0, 204s, changed=55 real (no bug, ver detalle) | Upgrade kubeadm — changed alto es esperado por diseño |
| 10 | ✅ Validado (VMs reales) | exit=0, 873s, failed=0 | exit=0, 120s, changed=3 real, failed=0 | Patrón benigno estándar (token kubeadm + helm repo) |
| 11 | ✅ Validado (VMs reales) | exit=0, 644s, failed=0 | exit=0, 117s, changed=3 real, failed=0 | Patrón benigno estándar (token kubeadm + helm repo) |
| 12 | ✅ Validado (VMs reales) | exit=0, 573s, failed=0 | exit=0, 122s, changed=4 real, failed=0 | El runner reportó "❌ falló" por un bug transitorio propio (ver nota), no del lab |
| 13 | ❌ **FALLO REAL** | exit=0(*), 1711s, failed=1 | exit=0(*), 1362s, failed=1 | Clúster MongoDB nunca llega a "ready" — ver detalle abajo. (*) exit engañoso, ver bug del framework |
| 14 | ⏳ En ejecución | — | — | — |
| Multidistro | ❌ No implementado | — | — | `test_multidistro()` es una simulación hardcodeada, no ejecuta nada real |

---

## 📋 Lab 01 — Detalle Verificado

**Ejecución**: `logs/labs/20260809_123931_lab01_*` (post-bootstrap, VM real `k8s-single`)

- Pass 1: exit=0, 207s. Todos los plays con `failed=0`, `unreachable=0`. Los mensajes
  "FAILED - RETRYING" son reintentos normales esperando el agente LXD, no errores.
- Pass 2: exit=0, 60s. **`changed=0` en absolutamente todos los plays** — idempotencia real, no
  solo por debajo del umbral del script.

**Veredicto**: ✅ Correcto, sin problemas ocultos.

---

## 📋 Lab 02 — Detalle Verificado

**Ejecución**: `logs/labs/20260809_125813_lab02_*` (post-bootstrap, cluster HA real 3 managers + 3 workers)

- Pass 1: exit=0, 536s (8m56s). Todos los plays con `failed=0`, `unreachable=0`, `rescued=0`,
  `ignored=0`. Incluye una prueba deliberada de failover: se apaga `k8s-manager1` y se confirma que
  la API sigue respondiendo vía la VIP de kube-vip con los 6 nodos `Ready`.
- Pass 2: exit=0. `failed=0`/`unreachable=0` en todos los plays, pero **no `changed=0` puro**:
  - `/dev/kmsg` symlink recreado en `k8s-manager1` y `k8s-worker1` exclusivamente — son justo los 2
    nodos que las "PRUEBA 1/2" de caos paran y reinician; al rebotar la VM el kernel recrea
    `/dev/kmsg` como dispositivo real, pisando el symlink, y la tarea lo repara. Autocuración
    esperada, no un bug.
  - Token de `kubeadm join` y `certificate-key` reescritos localmente — regenerados por diseño en
    cada ejecución (caducan).
  - `helm repo add` de Headlamp reporta `changed` en cada pasada — quirk conocido/inofensivo del
    módulo, no afecta al resultado.
  - Las tareas "PRUEBA 1/2: Parar/Reiniciar VM" son el propio test de caos del lab — siempre
    `changed` por diseño, no es una tarea de configuración que deba ser idempotente.

**Veredicto**: ✅ Correcto, sin problemas ocultos. Todos los `changed` de Pass 2 están explicados y
son comportamiento esperado, no fallos de idempotencia real.

---

## 📋 Lab 07 — Detalle Verificado

**Ejecución**: `logs/labs/20260809_131154_lab07_*` (post-bootstrap, cluster HA real 3 managers + 3 workers, stack Loki/Grafana/Prometheus)

- Pass 1: exit=0, 598s (~10min). 30 plays, todos con `failed=0`, `unreachable=0`, `rescued=0`,
  `ignored=0`.
- Pass 2: exit=0, 111s. Los 30 plays con `failed=0`/`unreachable=0`. Solo 3 `changed` en total, los
  mismos patrones ya vistos en el Lab 02 (no hay test de caos en este lab, por lo que no aparece el
  patrón `/dev/kmsg`):
  - Token de `kubeadm join` y `certificate-key` reescritos localmente (caducan, se regeneran por
    diseño en cada ejecución).
  - `helm repo add` de Headlamp reporta `changed` (mismo quirk inofensivo del módulo).

**Veredicto**: ✅ Correcto, sin problemas ocultos.

---

## 📋 Lab 09 — Detalle Verificado (Actualización kubeadm v1.35→v1.36)

**Ejecución**: `logs/labs/20260809_132358_lab09_*` (post-bootstrap, cluster HA real, upgrade nodo a nodo)

- Pass 1: exit=0, 665s. Todos los plays con `failed=0`, `unreachable=0`, `rescued=0`, `ignored=0`.
- Pass 2: exit=0, 204s. `failed=0`/`unreachable=0` en todos los plays. El runner reportó
  "Cambios: 3" pero era un **subconteo del propio script** (ver corrección del framework más abajo)
  — la suma real es **55**, concentrados en el bloque de actualización (`changed=8` por nodo × 6
  nodos + extras). Verificado que **no es un bug del lab**: las tareas de `drain`/`uncordon` tienen
  `changed_when: true` puesto explícitamente por el autor (son acciones imperativas sobre el
  clúster, no estado declarativo), y `kubeadm upgrade apply`/`upgrade node` usan
  `changed_when: "'SUCCESS' in ... stdout"`, que refleja el comportamiento real de `kubeadm`
  (reaplica manifiestos del plano de control en cada invocación, incluso si el nodo ya está en la
  versión objetivo). Es el comportamiento esperado de un playbook de **procedimiento de upgrade**,
  no de un rol de configuración declarativo.

**Veredicto**: ✅ Correcto, sin problemas ocultos. `changed` alto en Pass 2 es por diseño, no un
fallo de idempotencia real.

---

## 📋 Labs 10 y 11 — Detalle Verificado

**Ejecución**: `logs/labs/20260809_133841_lab10_*` y `logs/labs/20260809_135530_lab11_*`
(post-bootstrap, clústeres HA reales hiperconvergentes con PXC/MariaDB + Longhorn + Cilium)

- Lab 10 — Pass 1: exit=0, 873s, `failed=0` en todos los plays. Pass 2: exit=0, 120s, `failed=0`
  en todos los plays, **3 cambios reales** (patrón benigno estándar: token `kubeadm join` +
  `certificate-key` regenerados + `helm repo add` de Headlamp).
- Lab 11 — Pass 1: exit=0, 644s, `failed=0` en todos los plays. Pass 2: exit=0, 117s, `failed=0`
  en todos los plays, **3 cambios reales**, exactamente el mismo patrón que Lab 10.

**Veredicto**: ✅ Ambos correctos, sin problemas ocultos.

---

## 📋 Lab 12 — Detalle Verificado (y nota de incidente)

**Ejecución**: `logs/labs/20260809_140826_lab12_*` (post-bootstrap, cluster HA real, PostgreSQL vía Percona Operator/Patroni)

> ⚠️ **Incidente durante la sesión**: el commit `3aa2dd2` (fix del contador `sum_recap_field`) se
> guardó en disco a las 14:12:11, pero el proceso `./test_matrix_runner.sh lab12` ya llevaba
> corriendo desde las 14:08:26 — se editó el script mientras estaba en pleno vuelo. El proceso en
> curso quedó leyendo offsets desincronizados del fichero tras la edición y perdió la definición de
> `sum_recap_field`, causando `orden no encontrada` y, en cascada, que `run_sequence.sh` reportase
> **"❌ Lab 12 falló"** aunque Ansible nunca falló realmente. Verificado leyendo los logs crudos
> directamente (bypasseando el contador roto):

- Pass 1: exit=0, 573s. Todos los plays con `failed=0`, `unreachable=0`, `rescued=0`, `ignored=0`.
- Pass 2: exit=0, 122s. Todos los plays con `failed=0`/`unreachable=0`. **4 cambios reales**, mismo
  patrón benigno de siempre (token `kubeadm join` + `certificate-key` + `helm repo add`, esta vez
  del repositorio de Percona en vez de Headlamp).

**Veredicto**: ✅ Correcto, sin problemas ocultos. El "❌ falló" que aparece en
`logs/sequence_remaining_progress.log` para este lab es un falso negativo del framework de test
(editado mientras ejecutaba), no un fallo real del laboratorio. Confirmado que Lab 13 (arrancado a
las 14:20:13, después de que la edición ya estuviera guardada) no sufre este problema.

---

## ❌ Lab 13 — FALLO REAL (Percona MongoDB, Sharding)

**Ejecución**: `logs/labs/20260809_142013_lab13_*` (post-bootstrap, cluster HA real 3 managers + 6 workers)

**El clúster MongoDB (2 shards de 3 réplicas + config servers + mongos) nunca alcanza el estado
`ready`**, en ninguna de las dos pasadas:

- Pass 1 (1711s): tras 80 reintentos × 15s (20 min) esperando, `perconaservermongodb` reporta
  `status.state = "error"`. El play falla (`failed=1`) y **`run_all.sh` se detiene ahí mismo** — el
  log termina justo después del fallo, no llega a ejecutar el resto de tareas de ese playbook.
- Pass 2 (1362s): mismo timeout agotado, esta vez con `status.state = "initializing"` (no llega a
  progresar más allá de esa fase tampoco). Reproducible, no parece un fallo puntual/transitorio.

El propio `inventory.ini` de este lab ya documenta que es el más exigente de recursos de toda la
serie (`lxd_cpu=3`, `lxd_disk=32GB` por worker, subidos deliberadamente tras observar en vivo Pods
en `Pending` por CPU insuficiente y volúmenes Longhorn en `faulted`). Con los valores actuales del
`inventory.ini` **el problema persiste** — sugiere que el ajuste de recursos hecho en su momento no
fue suficiente, o hay una causa distinta (posible carrera entre los 2 shards arrancando a la vez,
límites de recursos del propio Percona Operator, etc.). **Pendiente de investigación dedicada.**

### 🔎 Además: esto reveló dos bugs adicionales del framework de test

1. **`exit_1`/`exit_2` no reflejan el resultado real**: `(cmd) || true; local exit_N=$?` hace que
   `$?` sea **siempre 0** (el `|| true` absorbe cualquier fallo de la subshell). El runner mostró
   "Exit: 0" en ambas pasadas de Lab 13 pese a que `run_all.sh` abortó por un fallo real. Este bug
   afecta a **todos** los labs testeados en esta sesión — en el resto no importó porque se verificó
   `failed=0` a mano en cada log completo, pero el campo "exit_code" de `results.csv` y el summary
   nunca ha sido fiable como señal de éxito/fracaso.
2. **La condición de "IDEMPOTENCIA CONFIRMADA" no comprueba `failed_2`**: solo mira
   `[ "$changed_2" -lt 5 ]`. En Lab 13 el aviso de "incompleta" salió por pura coincidencia (el
   `changed_2=5` no pasaba el umbral) — con un `changed_2` menor, el script habría anunciado
   "IDEMPOTENCIA CONFIRMADA ✅" a pesar de un fallo real (`failed_2=1`).

**Corrección pendiente** (se aplicará tras terminar la cola actual, para no repetir el incidente de
edición en pleno vuelo que afectó a Lab 12): capturar el exit code real de `run_all.sh` sin `|| true`,
y exigir `failed_N -eq 0` además de `changed_N < 5` para declarar idempotencia confirmada.

---

## 🔧 Correcciones Aplicadas al Framework de Test

- `test_matrix_runner.sh`: `cleanup_lab()` ahora usa `destroy_all.sh` de cada lab tras cada
  ejecución (antes no limpiaba VMs entre labs).
- `test_config.sh`: los 14 labs están habilitados en `ENABLED_LABS`.
- Pendiente: implementar `test_multidistro()` de verdad (o eliminarlo/marcarlo explícitamente como
  no disponible en la salida del script) — actualmente puede volver a generar una tabla de
  resultados ficticia si se invoca.
- **Bug de conteo corregido**: `changed_1`/`changed_2`/`failed_1`/`failed_2` usaban
  `grep -c "changed=1"`, que solo cuenta líneas que **empiezan** literalmente por `changed=1`
  (pierde `changed=2`, `changed=4`, `changed=8`... por completo). Sustituido por `sum_recap_field()`,
  que suma con `awk` todos los valores reales de cada `PLAY RECAP`. Descubierto al auditar Lab 09:
  el script reportaba "Cambios: 3" cuando la suma real era 55. Este bug afectaba a los números
  "Cambios: N" mostrados/loggeados para **todos** los labs probados hasta ahora (01, 02, 07, 09,
  10, 11) — no invalida los veredictos de esta tabla (verificados leyendo cada log completo a
  mano, no confiando en ese contador), pero si alguien miró solo el CSV/summary sin leer el log
  crudo, esos números de "Cambios" no eran fiables antes de este fix.

---

## 📝 Variables Parametrizadas por Lab (auditoría 2026-08-09)

**Lab 01 / 02**: `test_nginx_image`, `test_alpine_image`
**Lab 03 / 05**: `test_alpine_image`
**Lab 04**: `rook_ceph_chart_version`, `test_alpine_image`
**Lab 06**: `test_nginx_image`, `test_busybox_image`
**Lab 07**: `loki_chart_version`, `promtail_chart_version`, `kube_vip_image`
**Lab 08**: `test_nginx_image`, `grpc_demo_image`, `grpcurl_version`
**Lab 09**: `k8s_upgrade_target_version`
**Lab 10**: `percona_pxc_image_tag`, `percona_pxc_haproxy_image_tag`
**Lab 11**: `mariadb_image_tag`
**Lab 12**: `percona_pg_image_tag`
**Lab 13**: `mongodb_image_tag`
**Lab 14**: `vault_image_tag`, `percona_pxc_image_tag`

Todas confirmadas correctamente referenciadas en sus playbooks vía `{{ variable }}`
(no hay hardcodes pendientes).

---

## 🖥️ Versión de Kubernetes

Verificado contra la fuente oficial (kubernetes.io/releases, 2026-08-09): **v1.36** (parche 1.36.2,
2026-06-09) es la línea estable más reciente en producción. v1.37 aún no se ha publicado (previsto
26/08/2026). Los labs que usan `k8s_major_version: "v1.36"` están en la última versión disponible;
el Lab 09 (upgrade v1.35→v1.36) también es coherente con esto.

---

**Última actualización**: 2026-08-09 13:15 CEST

## 🔬 Resultados de Pruebas Automatizadas

### Multidistro: 00_instalar_ansible.sh

