# Ejemplos de Ansible para Kubernetes en LXD

Este directorio contiene recetas y automatizaciones de Ansible para desplegar clústeres de Kubernetes de prueba de forma local usando LXD.

## 📋 Requisitos Previos en el Host

Antes de empezar, solo debes asegurar estos tres requisitos básicos en tu máquina física (host):

1. **Soporte de Virtualización (KVM):**
   - Dado que los playbooks están diseñados para usar **Máquinas Virtuales LXD (LXD VMs)** para garantizar el aislamiento absoluto, tu equipo debe soportar virtualización de hardware (KVM habilitado en la BIOS y cargado en el kernel).
2. **Ansible Instalado:**
   - Debes disponer de Ansible instalado en tu host para lanzar las automatizaciones.
3. **Claves SSH:**
   - Debes disponer de una clave SSH pública en tu host (por ejemplo, `~/.ssh/id_ed25519.pub`). Se inyectará automáticamente en las VMs para permitir que Ansible se conecte sin contraseña.
   - Si no tienes claves SSH creadas en tu host, puedes generarlas con el comando:
     ```bash
     ssh-keygen -t ed25519 -C "tu_nombre_o_correo"
     ```
     *(Presiona Enter para guardarla en la ruta por defecto `~/.ssh/id_ed25519`. Si no quieres que te pida contraseña en cada ejecución de Ansible, presiona Enter dos veces sin escribir passphrase).*

> [!NOTE]
> **¿Y LXD, las redes y la imagen base?** Ya no necesitas configurarlos a mano. El script de bootstrap de abajo se encarga de instalar LXD, configurar la red puente `lxdbr0` en la subred `10.207.154.1/24` e importar la imagen base de Ubuntu 26.04 de forma 100% automatizada.

---

## ⚡ Preparación Automatizada del Host (LXD Bootstrapping)

Para configurar tu máquina física (host) con el entorno de virtualización LXD y todas las dependencias requeridas para interactuar con los clústeres de Kubernetes, debes ejecutar el playbook principal de aprovisionamiento del host.

Este playbook realiza las siguientes acciones críticas:
1.  **Instala utilidades base:** `snapd` y `curl`.
2.  **Instala dependencias de Python para Ansible:** `python3-kubernetes`, `python3-jsonpatch` y `python3-yaml`. Estas bibliotecas son **imprescindibles** para que Ansible pueda usar sus módulos nativos de gestión de Kubernetes (`kubernetes.core.k8s`) y Helm (`kubernetes.core.helm`) sin depender de comandos de consola manuales.
3.  **Habilita módulos de kernel:** Carga overlay y br_netfilter en el host para permitir la comunicación por puente de los contenedores de Kubernetes.
4.  **Instala herramientas Snap (modo classic):**
    *   `lxd` (el hipervisor para las VMs del clúster).
    *   `kubectl` (CLI local de Kubernetes para control del clúster).
    *   `helm` (gestor de paquetes para desplegar Longhorn, Headlamp, etc.).
5.  **Inicializa LXD de forma no interactiva:** Levanta el pool de almacenamiento y la red puente `lxdbr0` con la subred `10.207.154.1/24`.
6.  **Configura permisos:** Añade tu usuario al grupo `lxd`.

### Ejecución del Playbook:

Ejecuta el playbook indicando la opción `--ask-become-pass` para que Ansible pueda solicitar privilegios de administrador (`sudo`) de forma segura en tu terminal para instalar las dependencias:

```bash
ansible-playbook 00_bootstrap_host_lxd.yml --ask-become-pass
```

> [!IMPORTANT]
> Una vez completado este playbook, debes cerrar y abrir de nuevo tu sesión de terminal (o ejecutar `newgrp lxd`) en tu host para que tu usuario tome el grupo `lxd` y puedas lanzar comandos de `lxc` sin privilegios de root (`sudo`).

---

## 📂 Ejemplos Disponibles

### 1. Despliegue Mono-Nodo (k8s base) (`01_k8s_base_un_nodo`)
Ubicación: [01_k8s_base_un_nodo/](01_k8s_base_un_nodo/)

Este ejemplo levanta un nodo único de Kubernetes en una máquina virtual de LXD. Realiza la instalación y configuración básica, despliega Apache y Nginx de prueba, y monta el dashboard Headlamp.

Uso rápido:
```bash
cd 01_k8s_base_un_nodo
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 2. Despliegue Multi-Nodo HA (k8s base) (`02_k8s_base_ha_3_managers_3_workers`)
Ubicación: [02_k8s_base_ha_3_managers_3_workers/](02_k8s_base_ha_3_managers_3_workers/)

Este ejemplo levanta un clúster de Kubernetes de alta disponibilidad (HA) con 6 máquinas virtuales LXD, sin punto único de fallo en el plano de control:
*   `k8s-manager1/2/3` (`10.207.154.50-52`): Plano de control (3 réplicas).
*   `k8s-worker1/2/3` (`10.207.154.53-55`): Nodos trabajadores.
*   **VIP `10.207.154.49:6443`**: dirección virtual gestionada por **kube-vip** (pod estático con ARP + leader-election en cada manager) que expone el API server de forma estable, sin importar qué manager esté activo.

Automatiza:
*   La creación de las 6 VMs e inyección de claves SSH.
*   La configuración del sistema operativo y container runtime (`containerd`) en todos los nodos.
*   La inicialización de `kubeadm` en el primer manager con `--control-plane-endpoint` apuntando al VIP y `--upload-certs`.
*   La unión de los 2 managers adicionales al plano de control vía `--certificate-key`.
*   La unión dinámica de los 3 workers vía el VIP.
*   El despliegue de una app web con 2 réplicas balanceándose entre workers.
*   Una **prueba de resiliencia HA** dedicada: parar y recuperar un worker, y parar y recuperar el manager que hizo el `kubeadm init` inicial, verificando que el VIP conmuta y que el clúster nunca deja de responder.
*   El despliegue de Headlamp Dashboard en el puerto `32082`, accesible vía el VIP.

Uso rápido:
```bash
cd 02_k8s_base_ha_3_managers_3_workers
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 3. Almacenamiento Distribuido Replicado con Longhorn (`03_k8s_ha_almacenamiento_persistente_longhorn`)
Ubicación: [03_k8s_ha_almacenamiento_persistente_longhorn/](03_k8s_ha_almacenamiento_persistente_longhorn/)

Este laboratorio despliega un clúster de Kubernetes HA avanzado de 8 nodos virtuales sobre LXD (basado en el 02: 3 managers, 2 workload workers, 3 storage dedicados), reutilizando vía `import_playbook` los pasos base de infraestructura y bootstrap del laboratorio 02.

Utiliza Longhorn como motor de almacenamiento de bloques y sistema de archivos distribuido nativo de Kubernetes para dar soporte a volúmenes persistentes multi-nodo (ReadWriteMany - RWX) y mono-nodo (ReadWriteOnce - RWO) con tolerancia a fallos mediante replicación en 3 vías.

Automatiza:
*   La creación de 8 VMs LXD (3 managers, 2 workload workers, 3 storage) e inyección de claves SSH.
*   Configuración del sistema operativo, container runtime (`containerd`), `open-iscsi` y `nfs-common` en todos los nodos de K8s.
*   Inicialización de kubeadm HA (kube-vip) y unión de los nodos del clúster.
*   Instalación de Longhorn vía Helm optimizando taints y tolerancias para restringir los datos replicados únicamente a los 3 nodos storage dedicados.
*   Verificación del almacenamiento ReadWriteMany (RWX) montando un archivo de logs compartido entre dos pods escritores que corren en los workers.
*   Exposición del panel de administración de Longhorn a través de NodePort (puerto `32085`, accesible vía la VIP).

Uso rápido:
```bash
cd 03_k8s_ha_almacenamiento_persistente_longhorn
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 4. Almacenamiento Rook Ceph Hiperconvergente (`04_k8s_ha_almacenamiento_persistente_rook_ceph`)
Ubicación: [04_k8s_ha_almacenamiento_persistente_rook_ceph/](04_k8s_ha_almacenamiento_persistente_rook_ceph/)

Este ejemplo levanta un clúster HA completo con 6 VMs (basado en el 02: 3 managers + 3 workers), reutilizando vía `import_playbook` los pasos base de infraestructura y bootstrap del laboratorio 02. Cada worker cuenta con un disco virtual secundario de 20GB. Despliega el operador Rook para autogestionar un clúster de Ceph directamente sobre Kubernetes.

Automatiza:
*   La creación de 6 VMs LXD, inyección de claves SSH y adición en caliente del disco secundario `ceph-disk` en los workers.
*   Instalación de las herramientas de K8s, inicialización HA (kube-vip) y unión del clúster.
*   Instalación del operador de Rook Ceph y configuración del clúster Ceph (`CephCluster`).
*   Creación de StorageClasses predeterminadas para RBD (RWO) y CephFS (RWX).
*   Verificación de almacenamiento RBD y CephFS compartidos mediante pods escritores de prueba.
*   Despliegue de Prometheus conectado al Ceph Dashboard.

Uso rápido:
```bash
cd 04_k8s_ha_almacenamiento_persistente_rook_ceph
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 5. Clúster Ceph Externo e Independiente (`05_k8s_ha_almacenamiento_persistente_externo_ceph`)
Ubicación: [05_k8s_ha_almacenamiento_persistente_externo_ceph/](05_k8s_ha_almacenamiento_persistente_externo_ceph/)

Este laboratorio despliega un clúster de Kubernetes HA (basado en el 02: 3 managers + 3 workers) y un clúster Ceph externo formado por 3 nodos de almacenamiento (OSDs) independientes sobre VMs LXD, gestionados de forma externa e integrados a través de drivers de Ceph CSI en Kubernetes.

### 6. Red y Acceso Externo con MetalLB e Ingress (`06_k8s_red_ingress_metallb`)
Ubicación: [06_k8s_red_ingress_metallb/](06_k8s_red_ingress_metallb/)

Este laboratorio despliega un clúster de Kubernetes HA (basado en el 02: 3 managers + 3 workers) y añade **MetalLB** (LoadBalancer L2 local sobre la red de LXD) y el **NGINX Ingress Controller**, exponiendo dos microservicios de prueba consolidados detrás de un único Ingress que enruta por nombre de host.

Automatiza:
*   Instalación de MetalLB vía Helm y configuración de un `IPAddressPool`/`L2Advertisement`.
*   Instalación del NGINX Ingress Controller vía Helm, expuesto como `Service` tipo `LoadBalancer`.
*   Despliegue de dos microservicios de prueba (`app-a`, `app-b`), cada uno con su propio `ConfigMap`, `Secret` e `initContainer` de espera de dependencias (DNS).
*   Verificación automática de que el enrutamiento por nombre de host (`app-a.k8s.local`, `app-b.k8s.local`) devuelve el contenido correcto de cada microservicio.

Uso rápido:
```bash
cd 06_k8s_red_ingress_metallb
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 7. Observabilidad Completa con Prometheus, Grafana y Loki (`07_k8s_observabilidad_loki_grafana_prometheus`)
Ubicación: [07_k8s_observabilidad_loki_grafana_prometheus/](07_k8s_observabilidad_loki_grafana_prometheus/)

Este laboratorio despliega un clúster de Kubernetes HA (basado en el 02: 3 managers + 3 workers) con **Longhorn** como backend de almacenamiento persistente y un stack completo de observabilidad: **Prometheus Operator** + **Grafana** (métricas) y **Loki** + **Promtail** (logs centralizados), todo con persistencia real en volúmenes Longhorn.

Automatiza:
*   Instalación de Longhorn como `StorageClass` por defecto.
*   Instalación de `kube-prometheus-stack` (Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics) vía Helm.
*   Instalación de Loki (modo *single binary*) y Promtail (DaemonSet), con Loki registrado automáticamente como fuente de datos en Grafana.
*   Verificación automática de que Prometheus tiene métricas activas, Grafana responde, y Loki está recibiendo logs de los distintos componentes del clúster.

Uso rápido:
```bash
cd 07_k8s_observabilidad_loki_grafana_prometheus
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 8. Gateway API con Cilium (`08_k8s_gateway_api`)
Ubicación: [08_k8s_gateway_api/](08_k8s_gateway_api/)

Este laboratorio despliega un clúster de Kubernetes HA (basado en el 02: 3 managers + 3 workers) usando **Cilium** como CNI (sustituyendo a Flannel) y como implementación de **Gateway API**, con su LoadBalancer L2 nativo (LB-IPAM + L2Announcement) integrado en el mismo agente — sin MetalLB ni un controlador de Gateway aparte.

Automatiza:
*   Instalación de Cilium vía Helm con `kubeProxyReplacement: true` (y eliminación previa de `kube-proxy`) y `gatewayAPI.enabled: true`.
*   Creación de dos objetos `Gateway` separados (uno por protocolo, para evitar un bug conocido de Cilium con listeners de distintos `allowedRoutes.kinds` en un mismo `Gateway`): uno para `HTTPRoute` y otro para `GRPCRoute`.
*   Despliegue de dos versiones de una app demo (`stable`/`canary`) con reparto de tráfico ponderado 80/20 vía `HTTPRoute`, verificado estadísticamente con 100 peticiones.
*   Despliegue de un servicio gRPC de ejemplo (`kong/grpcbin`) expuesto vía `GRPCRoute`, verificado con una llamada real (`grpcurl`).
*   Despliegue de Headlamp justo después de formar el clúster, para poder seguir el resto de despliegues desde su consola web.

Uso rápido:
```bash
cd 08_k8s_gateway_api
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 9. Actualización de Clúster HA v1.35→v1.36 (`09_k8s_actualizacion_cluster_ha`)
Ubicación: [09_k8s_actualizacion_cluster_ha/](09_k8s_actualizacion_cluster_ha/)

Este laboratorio despliega un clúster de Kubernetes HA (basado en el 02: 3 managers + 3 workers) inicialmente en **Kubernetes v1.35**, y ejecuta a continuación el proceso oficial de actualización de `kubeadm` a **v1.36**, nodo a nodo, sin interrumpir la disponibilidad del API server.

Automatiza:
*   `kubeadm upgrade apply` en el primer manager (el único que aplica los cambios a nivel de clúster).
*   `kubeadm upgrade node` en el resto de managers y en los workers, uno a uno (`serial: 1`, para no perder nunca el quórum de etcd ni la VIP).
*   `kubectl drain`/actualización de `kubelet`+`kubectl` (liberando y volviendo a fijar el `apt hold` de versión)/`kubectl uncordon` en cada nodo.
*   Verificación final de que los 6 nodos reportan la versión objetivo y que la API y los Pods de `kube-system` siguen sanos.
*   Despliegue de Headlamp antes de empezar la actualización, para poder seguirla en directo desde su consola web.

Uso rápido:
```bash
cd 09_k8s_actualizacion_cluster_ha
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar en v1.35 y actualizar a v1.36
./destroy_all.sh   # Para limpiar y borrar todo
```

### 10. Percona Operator for MySQL — PXC/Galera (`10_k8s_percona_mysql_pxc`)
Ubicación: [10_k8s_percona_mysql_pxc/](10_k8s_percona_mysql_pxc/)

Primero de una serie de laboratorios centrados en operadores de bases de datos para Kubernetes. Despliega un clúster de Kubernetes HA de 6 nodos (3 managers + 3 workers) en diseño **hiperconvergente** (como el 07: sin nodos de storage dedicados) con **Longhorn** como almacenamiento persistente y **Cilium** como CNI + LoadBalancer L2 (sin Gateway API). Sobre esa base despliega un clúster **Percona XtraDB Cluster** (MySQL con replicación síncrona Galera) gestionado por el **Percona Operator for MySQL**.

Automatiza:
*   Instalación del Percona Operator for MySQL (`percona/pxc-operator`) y del clúster PXC (`percona/pxc-db`, CRD `PerconaXtraDBCluster`) con 3 réplicas Galera (una por worker, gracias al diseño hiperconvergente) + HAProxy.
*   Persistencia de los 3 nodos PXC en volúmenes Longhorn.
*   Exposición del endpoint de escritura (HAProxy) con un `Service` `LoadBalancer` estable (sin Gateway API: `TCPRoute` sigue siendo un recurso experimental, y no aporta nada frente a un `LoadBalancer` normal para este caso de uso).
*   Verificación de la replicación síncrona Galera (escritura en un nodo, lectura en otro distinto) y del acceso TCP externo.
*   Contraseña root generada automáticamente por el operador y guardada en `pxc_root_password.txt`, nunca en pantalla.

Uso rápido:
```bash
cd 10_k8s_percona_mysql_pxc
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 11. MariaDB Galera — mariadb-operator (`11_k8s_mariadb_galera`)
Ubicación: [11_k8s_mariadb_galera/](11_k8s_mariadb_galera/)

Segundo de la serie de laboratorios de operadores de bases de datos; a diferencia de los otros tres (todos Percona), usa MariaDB real vía el operador comunitario `mariadb-operator`. Mismo diseño hiperconvergente de 6 nodos + Cilium (CNI + LoadBalancer L2, sin Gateway API) que el 10.

Automatiza:
*   Instalación de `mariadb-operator` (charts `mariadb-operator-crds` + `mariadb-operator`) y del CRD `MariaDB` con `galera.enabled: true`, 3 réplicas (una por worker).
*   Persistencia de los 3 nodos en volúmenes Longhorn.
*   Exposición del endpoint de escritura (`primaryService`) con un `Service` `LoadBalancer` estable.
*   Verificación de la replicación síncrona Galera y del acceso TCP externo.
*   Escalado del clúster (2 en 2 réplicas, igual que el 10: el operador también exige un tamaño impar) y actualización del motor MariaDB sin downtime.
*   Contraseña root generada automáticamente por el operador y guardada en `mariadb_root_password.txt`, nunca en pantalla.

Uso rápido:
```bash
cd 11_k8s_mariadb_galera
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

---

## 📐 Decisiones de Diseño y Arquitectura

En este proyecto se han adoptado las siguientes directivas y decisiones técnicas:

### 1. Política de Distribución de Cargas de Trabajo (Workloads)
*   **Mono-Nodo (`01_k8s_base_un_nodo`):** Dado que solo existe una máquina (`k8s-single`), se elimina el "taint" del plano de control (`node-role.kubernetes.io/control-plane-`) para permitir que la máquina aloje tanto el control-plane como los pods de usuario.
*   **Multi-Nodo HA (`02_k8s_base_ha_3_managers_3_workers`):** Se mantiene el diseño estándar de producción. **Los 3 nodos Manager están estrictamente dedicados al plano de control** y conservan su "taint" (`NoSchedule`) por defecto. **Todas las cargas de trabajo de usuario se despliegan y balancean obligatoriamente en los 3 nodos trabajadores**.

### 1.1. Alta Disponibilidad del Plano de Control (kube-vip)
*   **Decisión:** El plano de control se expone tras una VIP (`10.207.154.49:6443`) gestionada por **kube-vip**, ejecutado como pod estático en cada uno de los 3 managers (ARP + leader-election), en vez de un balanceador externo tipo HAProxy/Keepalived en VMs dedicadas.
*   **Justificación:** Es el patrón más extendido hoy en día para HA de `kubeadm` en entornos on-prem/bare-metal (guías oficiales de `kubeadm`, Cluster API bare-metal, Talos, k3s/RKE2), y evita levantar infraestructura de balanceo adicional: la VIP la gestionan los propios managers. El primer manager inicializa el clúster con `kubeadm init --control-plane-endpoint --upload-certs`; los managers adicionales se unen con `kubeadm join --control-plane --certificate-key`. El laboratorio `02` incluye una prueba de resiliencia dedicada que para y recupera un worker y el manager que hizo el `kubeadm init` inicial, verificando que el VIP conmuta y el clúster nunca deja de responder.
*   **Reutilización:** Los laboratorios 03, 04 y 05 se basan en este clúster HA reutilizando sus playbooks de infraestructura y bootstrap vía `import_playbook`, en vez de duplicarlos.

### 2. Idempotencia Rigurosa en Ansible
Todos los playbooks han sido optimizados para cumplir con el principio de idempotencia (volver a ejecutar un playbook en un clúster activo no realiza cambios ni reporta estados modificados falsos):
*   **Inyección SSH:** Los comandos preparatorios (`mkdir -p`, `chmod`, `lxc file push`) usan `changed_when: false` ya que no alteran el estado real si la clave ya está inyectada.
*   **Configuración del kernel (Sysctl):** La aplicación de parámetros sysctl (`sysctl --system`) solo se activa si el archivo de configuración correspondiente ha cambiado.
*   **Containerd:** La configuración `/etc/containerd/config.toml` se genera utilizando la directiva `creates` para no sobreescribir configuraciones activas, y el servicio sólo se reinicia si hay modificaciones reales.
*   **Token de Acceso:** El archivo de credenciales `headlamp_token.txt` se consulta mediante un paso previo de verificación `stat`. El token de Headlamp sólo se regenera si el archivo local ha sido eliminado.

### 3. Persistencia y Seguridad del Dashboard
*   **Dashboard Moderno (Headlamp):** Se despliega mediante Helm y se expone por `NodePort` (puerto `32082`).
*   **TokenRequest API:** Para garantizar compatibilidad con Kubernetes v1.36 y evitar errores de validación de emisor (`iss`), se generan tokens dinámicos con una duración de 1 año (8760 horas) asociados al ServiceAccount del dashboard.
*   **Seguridad de Git:** El token (`headlamp_token.txt`), el `kubeconfig.yaml`, la `certificate_key.txt` de kubeadm y la contraseña del Ceph Dashboard (`ceph_dashboard_password.txt`) están excluidos del control de versiones mediante `.gitignore` en cada laboratorio.

### 4. Sistema Operativo de las Máquinas (Ubuntu 26.04)
*   **Decisión:** Todo el clúster (Manager y Workers) se despliega obligatoriamente sobre máquinas virtuales basadas en **Ubuntu 26.04**.
*   **Justificación:** Proporciona un entorno moderno compatible con las directivas de seguridad más recientes de `kubeadm` v1.36, `containerd`, e integra las versiones más recientes de systemd y kernel-modules idóneas para virtualización anidada sobre LXD.

### 5. Verificación de Requisitos Unificada (DRY)
*   **Decisión:** Las comprobaciones previas del entorno y la instalación de dependencias se han desacoplado de los escenarios individuales.
*   **Justificación:** Al unificar los chequeos en el playbook raíz `check_requisitos.yml`, se elimina la duplicación de código (DRY) en cada escenario. Los recursos pesados como la descarga de la imagen base de VM `k8s-template` y la instalación de colecciones de Ansible Galaxy se ejecutan durante el bootstrap inicial del host (`00_bootstrap_host_lxd.yml`), dejando al validador como un chequeo rápido e independiente de pre-vuelo que cada clúster reutiliza.

### 6. Escalado Dinámico de Nodos (Adición y Eliminación Segura)
*   **Decisión:** Todos los laboratorios multi-nodo cuentan con playbooks de escalado específicos para crear/unir un nodo al clúster y para eliminarlo (`add_node.yml`/`adicionar_nodo.yml` y `eliminar_nodo.yml`, con el prefijo numérico correspondiente a cada escenario). En los laboratorios con un sistema de almacenamiento distribuido propio (03 Longhorn, 04 Rook Ceph, 05 Ceph Externo), la unión al clúster de Kubernetes está deliberadamente separada en un playbook aparte de integración específica en el almacenamiento (p. ej. `12_integrar_nodo_longhorn.yml`), para poder razonar cada paso por separado.
*   **Justificación:** Esto permite simular entornos de nube elásticos de forma real. En los clústeres de almacenamiento (Longhorn, Rook Ceph y Ceph Externo), los playbooks distinguen entre añadir/eliminar capacidad de computación pura (workload) o capacidad de almacenamiento (storage), gestionando de forma segura la evacuación de cargas de trabajo (`kubectl drain`) y la migración de réplicas de datos antes de la destrucción física de las VMs.
*   **Alcance:** El escalado dinámico cubre nodos worker/storage. Escalar el número de managers del plano de control HA no está automatizado (requeriría repetir el flujo de `07_unir_managers.yml` para un nodo nuevo) y queda fuera del alcance actual.
