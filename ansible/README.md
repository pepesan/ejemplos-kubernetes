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

### 2. Despliegue Multi-Nodo (k8s base) (`02_k8s_base_1_manager_2_workers`)
Ubicación: [02_k8s_base_1_manager_2_workers/](02_k8s_base_1_manager_2_workers/)

Este ejemplo levanta un clúster de Kubernetes de producción local completo con 3 máquinas virtuales LXD:
*   `k8s-manager` (`10.207.154.50`): Nodo del plano de control.
*   `k8s-worker1` (`10.207.154.51`): Nodo trabajador 1.
*   `k8s-worker2` (`10.207.154.52`): Nodo trabajador 2.

Automatiza:
*   La creación de las 3 VMs e inyección de claves SSH.
*   La configuración del sistema operativo y container runtime (`containerd`) en todos los nodos.
*   La inicialización de `kubeadm` en el Manager.
*   La compartición dinámica del token y la unión de los 2 workers.
*   El despliegue de una app web con 2 réplicas balanceándose entre workers.
*   El despliegue de Headlamp Dashboard en el puerto `32082` del Manager.

Uso rápido:
```bash
cd 02_k8s_base_1_manager_2_workers
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 3. Almacenamiento Compartido NFS (ReadWriteMany) (`03_k8s_almacenamiento_persistente_nfs`)
Ubicación: [03_k8s_almacenamiento_persistente_nfs/](03_k8s_almacenamiento_persistente_nfs/)

Este ejemplo levanta un clúster multi-nodo completo junto con un nodo de almacenamiento externo dedicado en LXD:
*   `k8s-manager` (`10.207.154.50`): Control Plane.
*   `k8s-worker1` (`10.207.154.51`): Nodo trabajador 1.
*   `k8s-worker2` (`10.207.154.52`): Nodo trabajador 2.
*   `k8s-storage` (`10.207.154.55`): Servidor NFS de almacenamiento externo compartido.

Automatiza:
*   La creación de las 4 VMs y su correspondiente configuración de SSH root.
*   Instalación y configuración del servidor `nfs-kernel-server` en `k8s-storage` y el cliente `nfs-common` en todos los nodos de K8s.
*   Despliegue del CSI driver de NFS (`nfs-subdir-external-provisioner`) vía Helm como la StorageClass por defecto (`nfs-client`).
*   Verificación de almacenamiento ReadWriteMany (RWX) mediante un deployment con 2 réplicas escribiendo de forma concurrente en un archivo compartido en el NFS.

Uso rápido:
```bash
cd 03_k8s_almacenamiento_persistente_nfs
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

---

## 📐 Decisiones de Diseño y Arquitectura

En este proyecto se han adoptado las siguientes directivas y decisiones técnicas:

### 1. Política de Distribución de Cargas de Trabajo (Workloads)
*   **Mono-Nodo (`01_k8s_base_un_nodo`):** Dado que solo existe una máquina (`k8s-single`), se elimina el "taint" del plano de control (`node-role.kubernetes.io/control-plane-`) para permitir que la máquina aloje tanto el control-plane como los pods de usuario.
*   **Multi-Nodo (`02_k8s_base_1_manager_2_workers`):** Se mantiene el diseño estándar de producción. **El nodo Manager (`k8s-manager`) está estrictamente dedicado al plano de control** y conserva su "taint" (`NoSchedule`) por defecto. **Todas las cargas de trabajo de usuario se despliegan y balancean obligatoriamente en los nodos trabajadores (`k8s-worker1` y `k8s-worker2`)**.

### 2. Idempotencia Rigurosa en Ansible
Todos los playbooks han sido optimizados para cumplir con el principio de idempotencia (volver a ejecutar un playbook en un clúster activo no realiza cambios ni reporta estados modificados falsos):
*   **Inyección SSH:** Los comandos preparatorios (`mkdir -p`, `chmod`, `lxc file push`) usan `changed_when: false` ya que no alteran el estado real si la clave ya está inyectada.
*   **Configuración del kernel (Sysctl):** La aplicación de parámetros sysctl (`sysctl --system`) solo se activa si el archivo de configuración correspondiente ha cambiado.
*   **Containerd:** La configuración `/etc/containerd/config.toml` se genera utilizando la directiva `creates` para no sobreescribir configuraciones activas, y el servicio sólo se reinicia si hay modificaciones reales.
*   **Token de Acceso:** El archivo de credenciales `headlamp_token.txt` se consulta mediante un paso previo de verificación `stat`. El token de Headlamp sólo se regenera si el archivo local ha sido eliminado.

### 3. Persistencia y Seguridad del Dashboard
*   **Dashboard Moderno (Headlamp):** Se despliega mediante Helm y se expone por `NodePort` (puerto `32082`).
*   **TokenRequest API:** Para garantizar compatibilidad con Kubernetes v1.36 y evitar errores de validación de emisor (`iss`), se generan tokens dinámicos con una duración de 1 año (8760 horas) asociados al ServiceAccount del dashboard.
*   **Seguridad de Git:** Tanto el token (`headlamp_token.txt`) como el archivo `kubeconfig.yaml` están excluidos del control de versiones mediante `.gitignore` en cada laboratorio.

### 4. Sistema Operativo de las Máquinas (Ubuntu 26.04)
*   **Decisión:** Todo el clúster (Manager y Workers) se despliega obligatoriamente sobre máquinas virtuales basadas en **Ubuntu 26.04**.
*   **Justificación:** Proporciona un entorno moderno compatible con las directivas de seguridad más recientes de `kubeadm` v1.36, `containerd`, e integra las versiones más recientes de systemd y kernel-modules idóneas para virtualización anidada sobre LXD.
