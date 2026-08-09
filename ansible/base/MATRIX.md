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
| 09 | ⏳ En ejecución | — | — | — |
| 10 | ⏳ En cola | — | — | — |
| 11 | ⏳ En cola | — | — | — |
| 12 | ⏳ En cola | — | — | — |
| 13 | ⏳ En cola | — | — | — |
| 14 | ⏳ En cola | — | — | — |
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

## 🔧 Correcciones Aplicadas al Framework de Test

- `test_matrix_runner.sh`: `cleanup_lab()` ahora usa `destroy_all.sh` de cada lab tras cada
  ejecución (antes no limpiaba VMs entre labs).
- `test_config.sh`: los 14 labs están habilitados en `ENABLED_LABS`.
- Pendiente: implementar `test_multidistro()` de verdad (o eliminarlo/marcarlo explícitamente como
  no disponible en la salida del script) — actualmente puede volver a generar una tabla de
  resultados ficticia si se invoca.

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

