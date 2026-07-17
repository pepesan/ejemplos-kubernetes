# 📊 Escenario 07: Observabilidad Completa (Prometheus + Grafana + Loki)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (idéntico al escenario 02: 3 managers + 3 workers, kube-vip), con **Longhorn** como backend de almacenamiento persistente (igual que el 03, sin la separación de nodos storage/workload, ya que aquí el foco es la observabilidad) y un stack completo de métricas y logs con persistencia real: **Prometheus Operator**, **Grafana** y **Loki + Promtail**.

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs y formar el clúster HA.
*   **`09_desplegar_headlamp.yml`**: despliega Headlamp Dashboard (NodePort, igual que en el resto de laboratorios) justo después de formar el clúster, para poder seguir el resto de despliegues desde su consola web.
*   **`10_desplegar_longhorn.yml`**: instala Longhorn vía Helm como `StorageClass` por defecto (réplica x3 en los 3 workers), sin taints de aislamiento — todos los workers pueden alojar tanto réplicas de datos como cargas de trabajo.
*   **`11_desplegar_prometheus_grafana.yml`**: instala `kube-prometheus-stack` (Prometheus Operator + Prometheus + Alertmanager + Grafana + node-exporter + kube-state-metrics) vía Helm, con Prometheus y Grafana persistiendo sus datos en volúmenes Longhorn.
*   **`12_desplegar_loki.yml`**: instala Loki (modo *single binary*, backend de almacenamiento en sistema de archivos sobre un volumen Longhorn) y Promtail (DaemonSet que envía los logs de todos los nodos a Loki), y registra automáticamente Loki como fuente de datos en Grafana.
*   **`13_verificar_observabilidad.yml`**: comprueba que Prometheus tiene métricas `up`, que Grafana responde, y que Loki ya ha recibido logs de al menos un `job`.
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 07_k8s_observabilidad_loki_grafana_prometheus
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso a los paneles:
*   🔗 **Prometheus:** `http://10.207.154.49:32090`
*   🔗 **Grafana:** `http://10.207.154.49:32091` — usuario `admin`, contraseña en `grafana_admin_password.txt`. Loki ya aparece configurado como fuente de datos (menú *Connections → Data sources*); explora los logs desde *Explore*.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Longhorn sin separación de roles:** a diferencia del escenario 03 (donde se aíslan físicamente los nodos de almacenamiento con taints), aquí todos los workers alojan tanto réplicas de Longhorn como las cargas de trabajo del propio stack de observabilidad — simplifica el laboratorio y mantiene el foco pedagógico en Prometheus/Grafana/Loki, no en el aislamiento de almacenamiento (ya cubierto en el 03).
*   **`kube-prometheus-stack` en vez de piezas sueltas:** es el chart de facto de la comunidad para desplegar el Operador de Prometheus junto con Grafana y los *exporters* estándar (`node-exporter`, `kube-state-metrics`) con una única instalación coherente, en vez de gestionar cada pieza por separado.
*   **Loki en modo *single binary*:** para un laboratorio de un solo clúster pequeño, el modo distribuido de Loki (componentes `read`/`write`/`backend` separados) es una complejidad innecesaria; el modo monolítico ofrece las mismas capacidades de consulta sobre un único Pod con persistencia en Longhorn.
*   **Todo con persistencia real:** a diferencia de un demo con almacenamiento efímero (`emptyDir`), Prometheus, Grafana y Loki guardan sus datos en `PersistentVolumeClaims` respaldados por Longhorn — si un Pod se reprograma a otro nodo, no se pierden ni las métricas históricas ni los dashboards guardados.
