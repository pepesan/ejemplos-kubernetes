# Ejemplos de Ansible para Kubernetes en LXD

Este directorio contiene recetas y automatizaciones de Ansible para desplegar clústeres de Kubernetes de prueba de forma local usando LXD.

## 📋 Requisitos de Instalación en el Host

Para ejecutar estos playbooks, debes asegurar los siguientes requisitos en tu máquina local:

1. **LXD Instalado y Configurado:**
   - Debe estar instalado (generalmente a través de `snap install lxd`).
   - Debe estar inicializado (`lxd init` con configuración por defecto).
   - El puente de red por defecto `lxdbr0` debe existir.

2. **Soporte de Virtualización (KVM):**
   - Dado que los playbooks están diseñados para usar **Máquinas Virtuales LXD (LXD VMs)** para garantizar el aislamiento absoluto y evitar conflictos con la sesión de X11/NVIDIA del host, tu equipo debe soportar virtualización de hardware (KVM habilitado en la BIOS y cargado en el kernel).

3. **Claves SSH:**
   - Debes disponer de una clave SSH pública en tu host (por ejemplo, `~/.ssh/id_ed25519.pub`). El script de creación inyectará automáticamente esta clave en la máquina virtual para permitir que Ansible se conecte sin contraseña por SSH.

4. **Imagen Base (Template):**
   - Debe existir una imagen de tipo `VIRTUAL-MACHINE` llamada `k8s-template` importada en LXD. Puedes verificar las imágenes existentes ejecutando:
     ```bash
     lxc image list
     ```

5. **Ansible y Colección General:**
   - Debes tener Ansible instalado en el host.
   - Instala la colección de LXD para Ansible ejecutando:
     ```bash
     ansible-galaxy collection install community.general
     ```

---

## 📂 Ejemplos Disponibles

### 1. Despliegue Mono-Nodo (`01_un_nodo`)
Ubicación: [01_un_nodo/](01_un_nodo/)

Este ejemplo levanta un nodo único de Kubernetes en una máquina virtual de LXD. Realiza los siguientes pasos de forma secuencial:
- **`01_check_requisitos.yml`**: Valida que LXD, la red y la imagen base estén listos en el host.
- **`02_crear_nodo.yml`**: Crea e inicia la máquina virtual (`k8s-single`) e inyecta la clave SSH pública del host.
- **`03_configurar_os.yml`**: Carga módulos de kernel (`overlay`, `br_netfilter`) y aplica los sysctls de red obligatorios para Kubernetes.
- **`04_instalar_containerd.yml`**: Instala y configura `containerd` como runtime (CRI), configurando el driver `systemd` para cgroups.
- **`05_instalar_k8s_tools.yml`**: Instala `kubeadm`, `kubelet` y `kubectl` bloqueando sus versiones para evitar actualizaciones inesperadas.
- **`06_inicializar_cluster.yml`**: Inicializa el plano de control con `kubeadm`, despliega el plugin de red (CNI Flannel) y quita el Taint de control-plane para permitir la ejecución de pods en un único nodo.
- **`07_desplegar_nginx.yml`**: Despliega un Pod de prueba de Nginx expuesto mediante NodePort para verificar el correcto funcionamiento del clúster.
- **`08_despliegue_helm.yml`**: Instala una aplicación Apache utilizando Helm.
- **`20_destroy.yml`**: Detiene y elimina la máquina virtual de LXD para limpiar todo el entorno.

Uso rápido:
```bash
cd 01_un_nodo
./run_all.sh       # Para desplegar el entorno completo
./destroy_all.sh   # Para limpiar y borrar todo
```
