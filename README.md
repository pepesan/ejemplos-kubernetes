# Ejemplos de Kubernetes

Repositorio de ejemplos y laboratorios prácticos de Kubernetes, con dos partes independientes:

*   **`src/`** — ejemplos puntuales de conceptos concretos (Deployments, Services, Ingress, Helm, HPA...), pensados para probarse rápido sobre un único clúster **Minikube** local.
*   **`ansible/`** — laboratorios completos y más realistas (HA multi-nodo, almacenamiento distribuido, operadores de bases de datos...), desplegados con Ansible sobre **máquinas virtuales LXD** propias, no sobre Minikube.

## Instalación de minikube y kubectl
```bash
./00_install_minikube_kubectl_helm.sh
```
## Lanzamiento del minukube
```bash
./01_minikube_start.sh
```
## Parada del minukube
```bash
./02_minikube_stop.sh
```
## Borrado del minukube
```bash
./03_minikube_delete.sh
```
## Arreglo del fallo de dns

Entrar al minikube por ssh

```bash
minikube ssh
```
Verificar que no resuelve el dns
```bash
nslookup google.com
```
Modificar el /etc/resolve.conf
```bash
sudo sh -c 'printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf'
```
Comprobar que ya resuelve correctamente
```bash
nslookup google.com
```

## Carpeta `src/` — Ejemplos puntuales sobre Minikube

Cada subcarpeta es un ejemplo autocontenido de un concepto concreto de Kubernetes, pensado para desplegarse manualmente (`kubectl apply -f ...`) sobre el Minikube levantado con los scripts de arriba:

*   **00_deployments**: Deployments básicos (ReplicaSets, rolling updates).
*   **01_services**: tipos de Service (ClusterIP, NodePort, LoadBalancer).
*   **02_volumes**: volúmenes y persistencia básica (`emptyDir`, `hostPath`, PVC).
*   **03_configmap**: configuración externa a los Pods vía ConfigMap.
*   **04_secret**: gestión de credenciales/secretos vía Secret.
*   **05_ingress**: enrutado HTTP básico con un Ingress Controller.
*   **06_helm** / **07_helm_rancher_install**: introducción a Helm y despliegue de Rancher con Helm.
*   **08_helm_advanced**: plantillas y funciones más avanzadas de Helm (charts propios).
*   **09_canary_rollout_a_b** / **10_ingress_dns**: despliegues Canary y A/B con NGINX Ingress Controller.
*   **11_istio**: malla de servicios con Istio.
*   **12_hashicorp_vault**: gestión de secretos con HashiCorp Vault.
*   **13_ejercicio_completo**: ejercicio integrador combinando varios de los conceptos anteriores.
*   **14_hpa**: autoescalado horizontal de Pods (HorizontalPodAutoscaler).
*   **15_health**: sondas de salud (liveness/readiness/startup probes).
*   **16_limits**: límites y peticiones de recursos (requests/limits) y cuotas de namespace.
*   **17_ns**: organización y aislamiento por Namespace.
*   **18_ingress_traefik**: Ingress con Traefik como controlador alternativo a NGINX.

## Carpeta `ansible/` — Laboratorios completos de Kubernetes en LXD

Serie de laboratorios prácticos de Kubernetes desplegados con Ansible sobre máquinas virtuales **LXD locales** (no Minikube). Cada laboratorio es autocontenido: su propio `run_all.sh`/`destroy_all.sh`, inventario y `group_vars`. El índice completo, con instrucciones de uso y detalles de cada uno, está en [`ansible/README.md`](ansible/README.md); el plan de ruta y el estado de validación de cada laboratorio están en [`ansible/PLAN.md`](ansible/PLAN.md).

Laboratorios disponibles:
*   **01 — Mono-Nodo Kubernetes Base**: un único nodo todo-en-uno.
*   **02 — Multi-Nodo Kubernetes Base HA**: 3 managers + 3 workers, kube-vip.
*   **03 — Almacenamiento Distribuido Longhorn**: persistencia HA sobre el clúster del 02.
*   **04 — Rook Ceph Hiperconvergente**: almacenamiento Ceph gestionado dentro del propio clúster.
*   **05 — Ceph Externo + K8s CSI**: clúster Ceph fuera de Kubernetes, integrado vía CSI.
*   **06 — Red e Ingress (MetalLB)**: LoadBalancer + Ingress NGINX.
*   **07 — Observabilidad (Loki/Prometheus/Grafana)**: stack de métricas y logs.
*   **08 — Gateway API con Cilium**: Cilium como CNI e implementación de Gateway API (HTTPRoute/GRPCRoute).
*   **09 — Actualización de Clúster HA**: upgrade de Kubernetes v1.35→v1.36 nodo a nodo.
*   **10 — Percona Operator for MySQL (PXC/Galera)**: clúster MySQL con replicación síncrona Galera.
*   **11 — MariaDB Galera (mariadb-operator)**: equivalente al 10 usando MariaDB real.
*   **12 — Percona Operator for PostgreSQL**: clúster PostgreSQL con alta disponibilidad vía Patroni.
