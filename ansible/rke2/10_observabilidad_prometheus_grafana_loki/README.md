# Laboratorio 10: Módulo Completo de Monitorización y Logging

Este laboratorio implementa el temario completo del módulo **"8.- Monitorización y Logging"**, desplegando un stack de observabilidad unificado nativo de Kubernetes sobre RKE2 con **Prometheus Operator**, **Grafana**, **Loki** y recolector de logs de contenedores (**Promtail / FluentBit**).

---

## 📋 Mapeo con el Temario "8.- Monitorización y Logging"

| Punto del Temario | Implementación / Ejemplo en el Lab | Estado / Fichero |
| --- | --- | --- |
| **• Introducción** | Conceptos de observabilidad unificada (Métricas + Logs + Trazas) en clústeres Kubernetes. | Documentado en `README.md` |
| **• Soluciones** | Comparativa de arquitecturas (Prometheus Operator + Grafana + Loki/Promtail vs FluentBit / Fluentd + Elasticsearch). | Documentado en `README.md` |
| **• Monitorización** | Recolección de métricas de nodos (`node-exporter`), componentes K8s (`kube-state-metrics`) y workloads. | `10_instalar_observabilidad.yml` (Play 3) |
| **• Prometheus** | Despliegue de `kube-prometheus-stack` (Prometheus Operator) expuesto en NodePort `30090`. | `10_instalar_observabilidad.yml` (Play 3) |
| **• Grafana** | Panel de control visual expuesto en NodePort `30080` (usuario `admin`, password `admin`) con dashboards de K8s. | `10_instalar_observabilidad.yml` (Play 3) |
| **• Logging** | Agregación centralizada de logs de contenedores en `/var/log/containers/*.log` mediante `loki-stack`. | `10_instalar_observabilidad.yml` (Play 4) |
| **• FluentBit / Promtail / Fluentd** | Agente recolector DaemonSet (`promtail` / `fluentbit`) capturando stdout/stderr de todos los pods. | `10_instalar_observabilidad.yml` (Play 4) |
| **• Acceso a Logs** | Consulta y filtrado de logs mediante LogQL desde Grafana (Loki Datasource) y vía CLI `kubectl logs`. | `10_instalar_observabilidad.yml` (Play 5 y 6) |

---

## ⚙️ Arquitectura del Stack de Observabilidad

```mermaid
graph TD
    subgraph Clúster RKE2 (Nodes & Workloads)
        NE["node-exporter (Métricas Host)"]
        KSM["kube-state-metrics (Métricas K8s)"]
        PT["Promtail / FluentBit DaemonSet (Logs stdout/stderr)"]
        PROBE["log-producer-pod (Pod de Prueba JSON Logs)"]
    end

    subgraph Monitoring Namespace
        PROM["Prometheus Operator (NodePort 30090)"]
        GRAF["Grafana Web UI (NodePort 30080)"]
    end

    subgraph Logging Namespace
        LOKI["Loki Log Aggregator (Port 3100)"]
    end

    NE --> PROM
    KSM --> PROM
    PROBE --> PT
    PT --> LOKI

    PROM --> GRAF
    LOKI --> GRAF
```

---

## 🚀 Uso del Laboratorio

```bash
# Desplegar el clúster RKE2 + Longhorn + Stack Observabilidad (Prometheus, Grafana, Loki):
./run_all.sh

# Exportar el kubeconfig local:
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# 📊 Acceder al Dashboard de Grafana (Métricas + Logs):
# URL: http://10.207.154.60:30080
# Usuario: admin  |  Contraseña: admin

# 📈 Acceder a la Consola de Prometheus:
# URL: http://10.207.154.60:30090

# 📜 Consultar logs del pod de prueba vía kubectl:
kubectl logs -n default log-producer-pod -f

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`) + 2 Workers (`rke2-worker1/2`). |
| `group_vars/all.yml` | Variables del clúster RKE2, Longhorn, NodePorts de Grafana (30080) y Prometheus (30090). |
| `10_instalar_observabilidad.yml` | Playbook Ansible: iSCSI, Longhorn, kube-prometheus-stack, loki-stack, datasource de Loki y pod de prueba de logs. |
| `run_all.sh` / `destroy_all.sh` | Scripts de ciclo de vida del laboratorio. |

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` confirma que las releases de Helm, los DaemonSets recolectores y las fuentes de datos están presentes sin provocar cambios no deseados (`changed=0`).
