# Laboratorios Base: Ejemplos de Ansible para Kubernetes en LXD

Este directorio contiene los 14 laboratorios numerados, cada uno autocontenido (su propio `run_all.sh`/`destroy_all.sh`, inventario y `group_vars`), de menor a mayor complejidad. Para una visión general de la estructura del repositorio (este directorio `base/` frente a `ansible/roles/`), consulta el [`README.md`](../README.md) de `ansible/`.

## 📋 Requisitos Previos en el Host

Antes de empezar, solo debes asegurar estos tres requisitos básicos en tu máquina física (host):

1. **Soporte de Virtualización (KVM):**
   - Dado que los playbooks están diseñados para usar **Máquinas Virtuales LXD (LXD VMs)** para garantizar el aislamiento absoluto, tu equipo debe soportar virtualización de hardware (KVM habilitado en la BIOS y cargado en el kernel).
2. **Ansible Instalado:**
   - Debes disponer de Ansible instalado en tu host para lanzar las automatizaciones.
   - La forma recomendada es vía **pipx**, que aísla Ansible del Python del sistema:
     ```bash
     sudo apt install -y pipx   # si no tienes pipx instalado todavía
     pipx install ansible       # instala el paquete "ansible" completo (no "ansible-core")
     pipx ensurepath
     ```
     > [!IMPORTANT]
     > Instala el paquete **`ansible`** (no `ansible-core`): solo el paquete completo trae
     > empaquetadas las colecciones `community.general` y `kubernetes.core`, que
     > `check_requisitos.yml` y `00_bootstrap_host_lxd.yml` necesitan para poder ejecutarse
     > la primera vez, antes de tener conexión a Internet para descargarlas por su cuenta.
     >
     > Tras `pipx ensurepath` puede que necesites abrir una terminal nueva (o hacer
     > `source ~/.bashrc`) para que `ansible-playbook` quede disponible en el `PATH`.

     También puedes usar el script [`00_instalar_ansible.sh`](00_instalar_ansible.sh) de este
     directorio: instala Ansible con pipx (inyectando ya `kubernetes`, `jsonpatch` y `pyyaml`
     en su venv), instala `kubectl` y `helm` (binarios oficiales), y a continuación lanza
     `check_requisitos.yml`. Si detecta que LXD todavía no está instalado, encadena
     automáticamente [`01_bootstrap_host.sh`](01_bootstrap_host.sh) (te pedirá la contraseña
     de `sudo`) antes de esa comprobación final — en un host completamente nuevo, este único
     script deja todo listo de principio a fin. Es **multidistribución**: probado en vivo en
     Ubuntu, Debian, Rocky Linux, Fedora y openSUSE (ver
     [`ansible/scripts/test_instalar_ansible_distros.sh`](../scripts/test_instalar_ansible_distros.sh)).
     ```bash
     chmod +x 00_instalar_ansible.sh
     ./00_instalar_ansible.sh
     ```
     
     > [!TIP]
     > **Validar `00_instalar_ansible.sh` en múltiples distros**: Para probar que el script
     > funciona correctamente en Ubuntu, Debian, Rocky, Fedora y openSUSE, usa el framework
     > de pruebas automatizado:
     > ```bash
     > ./test_matrix_runner.sh multidistro
     > ```
     > Esto ejecuta pruebas en 10 distros (5 × 2 versiones) y compila resultados en `MATRIX.md`.
     > Ver [`TEST_FRAMEWORK.md`](TEST_FRAMEWORK.md) para más detalles.
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

Es **multidistribución** (mismo alcance que [`00_instalar_ansible.sh`](00_instalar_ansible.sh): Ubuntu,
Debian, Rocky Linux 9/10, Fedora y openSUSE Leap/Tumbleweed), verificado en vivo — ver
[`ansible/scripts/test_lxd_host_bootstrap_distros.sh`](../scripts/test_lxd_host_bootstrap_distros.sh)
(la misma lógica, extraída como rol reutilizable en
[`lxd_host_bootstrap`](../roles/lxd_host_bootstrap/)).

Para validar que tu bootstrap de LXD funciona correctamente, ejecuta:
```bash
# Validar idempotencia del lab base (2 pasadas)
./test_matrix_runner.sh lab02
```
Ver [`TEST_FRAMEWORK.md`](TEST_FRAMEWORK.md) para más opciones de testing.

Este playbook realiza las siguientes acciones críticas:
1.  **Instala utilidades base:** `snapd` (excepto en openSUSE, que no lo publica — ver más abajo) y `curl`.
2.  **Instala dependencias de Python para Ansible:** `python3-kubernetes`, `python3-jsonpatch` y `python3-yaml` (`python3-pyyaml` en Rocky/Fedora; `python3dist(kubernetes)`/`python3dist(jsonpatch)`/`python3dist(pyyaml)` en openSUSE, cuyos nombres de paquete van versionados con el Python del sistema). Estas bibliotecas son **imprescindibles** para que Ansible pueda usar sus módulos nativos de gestión de Kubernetes (`kubernetes.core.k8s`) y Helm (`kubernetes.core.helm`) sin depender de comandos de consola manuales.

    > [!WARNING]
    > Si instalaste Ansible con **pipx**, estos paquetes `apt` se instalan en el Python del
    > sistema, pero pipx ejecuta Ansible en un venv aislado que **no ve** ese Python del
    > sistema. El síntoma es un fallo como `Failed to import the required Python library
    > (kubernetes)` al llegar a una tarea `kubernetes.core.k8s` (por ejemplo, en
    > `07_desplegar_headlamp.yml`), aunque `check_requisitos.yml` no lo detecte de antemano
    > porque solo comprueba que la colección `kubernetes.core` esté presente, no que la
    > librería `kubernetes` sea importable desde el intérprete que usará Ansible.
    >
    > Si instalaste Ansible con [`00_instalar_ansible.sh`](00_instalar_ansible.sh) (opción
    > recomendada más arriba) esto **ya está resuelto**: el script inyecta `kubernetes`,
    > `jsonpatch` y `pyyaml` directamente en el venv de pipx (`pipx inject`) justo después de
    > instalar Ansible. Si instalaste Ansible a mano, inyecta la librería tú mismo:
    > ```bash
    > pipx inject ansible kubernetes jsonpatch pyyaml
    > ```
3.  **Habilita módulos de kernel:** Carga overlay y br_netfilter en el host para permitir la comunicación por puente de los contenedores de Kubernetes.
4.  **Instala LXD** (el hipervisor para las VMs del clúster) — vía Snap en Ubuntu/Debian/Rocky/Fedora, o
    vía su paquete nativo de zypper en openSUSE (que no publica `snapd`; ahí también se activa y arranca
    explícitamente `lxd.service`, que viene deshabilitado por defecto a diferencia del snap). `kubectl` y
    `helm` ya no se instalan aquí: los instala [`00_instalar_ansible.sh`](00_instalar_ansible.sh) a partir
    de sus binarios oficiales (mismo método en cualquier distro) — por eso ese script se ejecuta antes que
    este playbook.
5.  **Inicializa LXD de forma no interactiva:** Levanta el pool de almacenamiento y la red puente `lxdbr0` con la subred `10.207.154.1/24`.
6.  **Configura permisos:** Añade tu usuario al grupo `lxd`.

> [!NOTE]
> **Autoconfiguración de sudo no interactivo**: `00_instalar_ansible.sh` y `01_bootstrap_host.sh`
> comparten la lógica de [`lib_sudo.sh`](lib_sudo.sh), que comprueba `sudo -n` al inicio y, si
> falla, autoconfigura `/etc/sudoers.d/k8s-labs` (`usuario ALL=(ALL) NOPASSWD: ALL`). Detecta
> primero el escenario (sudo-rs vs. sudo tradicional, TTY disponible o no) antes de actuar:
> - **Con terminal real**: pide la contraseña de forma interactiva (`sudo -v`).
> - **Sin terminal** (agente/CI/IDE remoto): usa `K8S_LABS_SUDO_PASS='tu_contraseña'` con
>   `sudo -S`. Necesario en Ubuntu 24.10+ (sudo-rs) y en cualquier sudo tradicional sin
>   `requiretty` activo.
> - **Sudo tradicional con `requiretty` activo y sin terminal**: no hay forma fiable de saltárselo
>   sin acceso a una terminal real (probado y descartado el uso de pseudo-terminales vía `script`:
>   poco fiable entre versiones de `util-linux` y ausente en imágenes mínimas de Fedora). El script
>   informa el error con instrucciones claras.
> - **`/etc/sudoers` ausente por completo**: confirmado en vivo incluso en la imagen VM oficial de
>   openSUSE Tumbleweed (el paquete `sudo` no activa `/usr/etc/sudoers` en el primer arranque).
>   Requiere una intervención manual de root (el script indica el comando exacto).
>
> Se necesita **una sola contraseña de sudo** en la primera ejecución; a partir de entonces
> `sudo -n` funciona sin interacción.

### Ejecución del Playbook:

Ejecuta el playbook indicando la opción `--ask-become-pass` para que Ansible pueda solicitar privilegios de administrador (`sudo`) de forma segura en tu terminal para instalar las dependencias:

```bash
ansible-playbook 00_bootstrap_host_lxd.yml --ask-become-pass
```

### Validar el Setup Completo:

Una vez completado el bootstrap, valida que todo está listo ejecutando el lab base (3 managers + 3 workers, 2 pasadas consecutivas para verificar idempotencia):

```bash
# Validar que Lab 02 Base HA funciona correctamente
./test_matrix_runner.sh lab02

# O ejecutar todas las pruebas (labs + multidistro)
./test_matrix_runner.sh all
```

Los resultados se compilarán automáticamente en `./logs/` y en `MATRIX.md`. Ver [`TEST_FRAMEWORK.md`](TEST_FRAMEWORK.md) para el uso completo del framework de pruebas.

O usa el script equivalente [`01_bootstrap_host.sh`](01_bootstrap_host.sh) de este directorio:
```bash
chmod +x 01_bootstrap_host.sh
./01_bootstrap_host.sh
```

> [!IMPORTANT]
> Una vez completado este playbook, debes cerrar y abrir de nuevo tu sesión de terminal (o ejecutar `newgrp lxd`) en tu host para que tu usuario tome el grupo `lxd` y puedas lanzar comandos de `lxc` sin privilegios de root (`sudo`).

## 🎓 Lecciones Aprendidas (Bootstrap del Host Multidistribución)

Estas son las clases de error reales, confirmadas en vivo (nunca solo por documentación), encontradas al validar `00_instalar_ansible.sh` → `00_bootstrap_host_lxd.yml` → `check_requisitos.yml` contra las 10 distros de la matriz soportada (Ubuntu 24.04/26.04, Debian 12/13, Fedora 43/44, Rocky Linux 9/10, openSUSE Leap 16.0/Tumbleweed). Antes de tocar el bootstrap del host, revisar esta lista.

- **Un error real puede no ser una condición de carrera aunque lo parezca**: `lxd init --preseed` fallaba de forma intermitente con "lxd: command not found" justo tras instalar el snap, y el diagnóstico inicial fue "condición de carrera de snapd reiniciándose". La causa real era otra, determinista: `lookup('env', 'PATH')` congela el PATH del PROPIO PROCESO `ansible-playbook` en el momento en que arrancó — en el flujo real (`00_instalar_ansible.sh` → `01_bootstrap_host.sh` → este playbook, todo en la misma sesión de shell), esa sesión se abrió ANTES de que la tarea 1b instalara `snapd` y su script `/etc/profile.d` que añade su directorio de binarios al PATH. Solo "parecía" una carrera porque las pruebas manuales de repetición (una sesión de shell nueva y posterior) sí tenían el PATH correcto por casualidad. **Fix**: rutas de snap explícitas y hardcodeadas (`/snap/bin`, `/var/lib/snapd/snap/bin`) en el `environment: PATH` del play, en vez de depender solo de `lookup('env','PATH')`.
- **`sudo` resetea el PATH a su propio `secure_path`, que varía mucho entre distros y puede no incluir `/usr/local/bin`**: confirmado en vivo en Rocky Linux 9, cuyo `secure_path` por defecto es `/sbin:/bin:/usr/sbin:/usr/bin` — sin `/usr/local/bin` ni `/usr/local/sbin`. El propio instalador oficial de Helm (`get-helm-4`, ejecutado vía `sudo`) fallaba su propia comprobación final `command -v helm` justo después de instalar el binario ahí, con el binario ya presente y ejecutable. **Fix**: `sudo env "PATH=$PATH" "$@"` en vez de `sudo "$@"` a secas (función `run_priv`), evitando depender del `secure_path` de cada distro.
- **Un módulo/CLI puede fallar de forma genuinamente intermitente por reinicios internos del propio gestor de paquetes**: confirmado en vivo (Debian 13) que, tras instalar `snapd` por primera vez, éste se autoactualiza a su propia snap interna y se reinicia (versión saltando de `2.68.3` a `2.76.2` en el journal) — si `snap info lxd` cae justo en esa ventana, `community.general.snap` lo malinterpreta como salida vacía y falla con una excepción interna ("list index out of range") que enmascara el error real (el módulo solo reconoce el string exacto `"warning: no snap found"`, cualquier otro fallo de `snap info` lo confunde igual). Verificado con sondeo directo: ~40% de fallos en llamadas cada 0.5s durante &gt;100s tras la instalación. **Fix**: `retries`/`until` generosos (hasta 3 min de margen total) en las tareas que dependen de un snap recién instalado.
- **No asumir que un paquete disponible en una distro lo está en todas las de la misma "familia"**: openSUSE Tumbleweed (rolling) retiró el paquete `lxd` de sus repos oficiales en favor de `incus` (el fork comunitario), pero openSUSE **Leap** 16.0 (estable) seguía publicando `lxd` nativo con normalidad — no puede tratarse "toda la familia Suse" por igual; hay que distinguir por `ansible_facts.distribution` exacto, no solo por `os_family`. Mismo patrón con `kernel-modules-extra`: existe con el mismo nombre en Fedora y en la familia RedHat, pero solo hace falta instalarlo explícitamente en Rocky Linux 10 (Fedora ya lo trae).
- **Migrar de una herramienta a su fork/sucesor compatible (LXD → incus) puede hacerse sin tocar el resto del código, si el fork mantiene compatibilidad real de API/CLI**: confirmado en vivo que symlinks simples (`/usr/local/bin/lxc` → `incus`, `/usr/local/bin/lxd` → `incusd`, y el socket por defecto `/var/lib/lxd/unix.socket` → `/run/incus/unix.socket`) bastan para que tanto el CLI (`lxc image copy`, `lxc network show`, `lxc launch --vm`) como los módulos nativos de Ansible (`community.general.lxd_container`, `lxd_storage_volume_info`, usados en los ~50 sitios de los 14 laboratorios) sigan funcionando sin ningún cambio adicional. Única excepción real: la inicialización del daemon (`incus admin init` es subcomando del binario cliente, distinto de `lxd init`, subcomando del propio daemon).
- **Al instalar un paquete de módulos de kernel versionado (p.ej. `kernel-modules-extra` en RHEL/Rocky), pedir la versión exacta del kernel en ejecución, no el nombre genérico del paquete**: confirmado en vivo (Rocky Linux 10) que `dnf install kernel-modules-extra` sin más instala la versión MÁS RECIENTE del repo, que puede no coincidir con el kernel realmente arrancado en la imagen base — los módulos de una versión no cargan en un kernel distinto (`modprobe` sigue fallando con "not found" aunque el paquete ya esté instalado). **Fix**: `kernel-modules-extra-{{ ansible_facts.kernel }}` (NEVRA exacta) en vez del nombre desnudo del paquete.
- **No asumir que una utilidad "básica" está presente en una imagen mínima**: `which` no viene instalado por defecto en la imagen mínima de Rocky Linux 10 (`ansible.builtin.command: which lxc` fallaba con `rc=2` y stdout/stderr vacíos, un fallo silencioso y confuso de "el propio `which` no existe", no "lxc no existe"). **Fix**: `command -v` (builtin de `/bin/sh`, vía `ansible.builtin.shell`) en vez de `which` (paquete externo), portable en cualquier sistema POSIX sin dependencias adicionales.
- **Un módulo de Ansible puede cambiar su propia superficie de parámetros entre versiones, y `pip`/`pipx` puede resolver una versión mucho más antigua sin avisar** si el Python del sistema es viejo: confirmado en vivo que Rocky Linux 9 (Python 3.9 de sistema) resuelve `ansible-core 2.15.13` + `community.general 7.5.2` vía `pipx install ansible` — una versión bastante más vieja que la que resuelven distros con Python 3.11+ — y esa versión de `community.general.ansible_galaxy_install` ni siquiera reconoce el parámetro `state` ("Unsupported parameters"). **Fix**: omitir el parámetro `state` por completo en vez de fijar `state: present` — el comportamiento por defecto (instalar si falta, sin tocar red/caché si ya está) es el mismo en ambas versiones, y así el playbook no depende de una versión mínima concreta del módulo.
- **Reproducir en vivo un fallo "intermitente" varias veces antes de dar por buena la primera hipótesis de causa raíz**: el fallo de PATH del primer punto de esta lista se diagnosticó inicialmente (de forma incorrecta) como una carrera de tiempo, y ese diagnóstico erróneo llevó a aplicar primero un parche de `retries`/reintentos que no atacaba la causa real — solo se corrigió de verdad al notar que el fallo era reproducible al 100% en el flujo real de una sola sesión, y nunca al probarlo a mano en una sesión nueva.

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

### 12. Percona Operator for PostgreSQL (`12_k8s_percona_postgresql`)
Ubicación: [12_k8s_percona_postgresql/](12_k8s_percona_postgresql/)

Tercero de la serie de laboratorios de operadores de bases de datos, de nuevo del fabricante Percona (como el 10). Despliega PostgreSQL con alta disponibilidad vía **Patroni** (un primario + réplicas de solo lectura, no multi-máster como Galera). Mismo diseño hiperconvergente de 6 nodos + Cilium (CNI + LoadBalancer L2, sin Gateway API) que los escenarios 10 y 11.

Automatiza:
*   Instalación del Percona Operator for PostgreSQL (`percona/pg-operator`) y del clúster (`percona/pg-db`, CRD `PerconaPGCluster`) con 3 réplicas, pgBouncer como *connection pooler* y backups locales con pgBackRest.
*   Persistencia de los 3 nodos en volúmenes Longhorn, con anti-affinity obligatoria (un Pod de BBDD por nodo, forzada explícitamente).
*   Exposición externa vía el `Service` `LoadBalancer` `<cluster>-ha` (delante de pgBouncer).
*   Verificación de la replicación (escritura en el primario, lectura en una réplica) y del acceso TCP externo.
*   Escalado del clúster (de una en una réplica: Patroni no exige tamaño impar, a diferencia de Galera) y actualización del motor PostgreSQL sin downtime.
*   Contraseña del usuario generada automáticamente por el operador y guardada en `pg_password.txt`, nunca en pantalla.

Uso rápido:
```bash
cd 12_k8s_percona_postgresql
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 13. Percona Operator for MongoDB — PSMDB (`13_k8s_percona_mongodb`)
Ubicación: [13_k8s_percona_mongodb/](13_k8s_percona_mongodb/)

Cuarto y último laboratorio de la serie de operadores de bases de datos, de nuevo del fabricante Percona (como el 10 y el 12). Despliega un clúster MongoDB con **sharding real**: 2 shards de 3 réplicas cada uno, más config servers y routers `mongos`. Diseño hiperconvergente de **9 nodos** (3 managers + 6 workers, uno por réplica de shard) + Cilium (CNI + LoadBalancer L2, sin Gateway API).

Automatiza:
*   Instalación del Percona Operator for MongoDB (`percona/psmdb-operator`) y del clúster (`percona/psmdb-db`, CRD `PerconaServerMongoDB`) con 2 shards de 3 réplicas, 3 config servers y 3 routers `mongos`.
*   Anti-affinity **obligatoria** por shard (`affinity.advanced`, no la preferente por defecto del chart): las réplicas de un mismo shard nunca comparten nodo Kubernetes, para que la caída de un nodo nunca tumbe un shard entero.
*   Persistencia de todos los nodos en volúmenes Longhorn.
*   Verificación del sharding (creación de una colección shardeada, reparto de datos comprobado entre shards) y del acceso TCP externo vía el `Service` `LoadBalancer` de `mongos`.
*   Escalado en caliente: añadir un shard nuevo con sus 3 nodos dedicados (`15_add_nodes.yml` + `16_integrar_shard.yml`), y retirarlo de forma segura con `removeShard` (`17_eliminar_shard.yml`) — el propio operador se encarga de drenar los chunks a los shards restantes antes de borrar sus Pods.
*   Actualización del motor MongoDB sin downtime (rolling upgrade Pod a Pod gestionado por el operador).
*   Contraseñas generadas automáticamente por el operador (`databaseAdmin` para uso normal, `clusterAdmin` para gestión de shards) y guardadas en `mongodb_password.txt`, nunca en pantalla.

Uso rápido:
```bash
cd 13_k8s_percona_mongodb
chmod +x run_all.sh destroy_all.sh
./run_all.sh       # Para desplegar
./destroy_all.sh   # Para limpiar y borrar todo
```

### 14. HashiCorp Vault — Secretos Dinámicos de Base de Datos (`14_k8s_vault_secretos_bbdd`)
Ubicación: [14_k8s_vault_secretos_bbdd/](14_k8s_vault_secretos_bbdd/)

Último laboratorio del repositorio. Sobre el mismo diseño hiperconvergente de 6 nodos del escenario 10 (Cilium + Longhorn + Percona XtraDB Cluster), instala **HashiCorp Vault** en modo HA (Raft integrado, 3 réplicas) para demostrar sus usos en orden creciente de complejidad: primero el motor **KV** de secretos estáticos (el más básico y habitual), luego **secretos dinámicos de base de datos** — credenciales MySQL generadas bajo demanda, de corta duración, revocadas automáticamente al expirar.

Automatiza:
*   Vault HA con almacenamiento Raft integrado (sin Consul) y unseal manual con claves Shamir.
*   Motor KV v2 de secretos estáticos, verificado con una escritura/lectura real.
*   Autenticación Kubernetes (los Pods se autentican con el JWT de su propio `ServiceAccount`, sin credenciales hardcodeadas) y una policy que limita qué puede leer la app de ejemplo.
*   Database Secrets Engine apuntando al clúster PXC, con un usuario MySQL dedicado de privilegios mínimos (nunca root) para la gestión de credenciales dinámicas.
*   Vault CSI Provider (Secrets Store CSI Driver) para montar la credencial dinámica directamente como archivo en el Pod de una app de ejemplo, sin pasar nunca por un `Secret` nativo de Kubernetes.
*   Verificación real de extremo a extremo: conexión a MySQL con la credencial generada, confirmación del usuario efímero en la base de datos, y comprobación de que Vault lo revoca automáticamente al expirar su TTL.

Uso rápido:
```bash
cd 14_k8s_vault_secretos_bbdd
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
