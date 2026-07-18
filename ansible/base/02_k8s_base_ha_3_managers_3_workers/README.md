# Laboratorio K8s Multi-Node (1 Manager + 2 Workers) sobre LXD

Este laboratorio contiene una serie de playbooks de Ansible para desplegar de forma automatizada un clúster multi-nodo completo de Kubernetes (1 nodo Control-Plane/Manager y 2 nodos Workers) sobre máquinas virtuales LXD en la máquina local.

## 📋 Estructura de Playbooks

*   **`ansible.cfg`**: Configuración de Ansible para este entorno.
*   **`inventory.ini`**: Definición de los nodos con sus IPs estáticas:
    *   `k8s-manager` (`10.207.154.50` - 3GB RAM, 2 CPUs)
    *   `k8s-worker1` (`10.207.154.51` - 2GB RAM, 2 CPUs)
    *   `k8s-worker2` (`10.207.154.52` - 2GB RAM, 2 CPUs)
*   **`group_vars/all.yml`**: Variables globales del sistema (red, versión de k8s, etc.).
*   **`../check_requisitos.yml`**: Playbook unificado en el directorio raíz. Se encarga de verificar las herramientas locales del host (LXD, red, imagen base) y asegurar la actualización de las colecciones de Ansible.
*   **`02_crear_nodos.yml`**: Creación de las 3 máquinas virtuales de LXD y la inyección de claves SSH.
*   **`03_configurar_os.yml`**: Ajustes de kernel y sysctl obligatorios para Kubernetes en todos los nodos.
*   **`04_instalar_containerd.yml`**: Instalación del Container Runtime Interface (CRI) en todo el clúster.
*   **`05_instalar_k8s_tools.yml`**: Instalación de `kubeadm`, `kubelet` y `kubectl` en todos los nodos.
*   **`06_inicializar_primer_manager.yml`**: Inicialización del primer manager (kube-vip + `kubeadm init` con `--control-plane-endpoint` y `--upload-certs`), configuración de CNI Flannel y generación/propagación del token de unión.
*   **`07_unir_managers.yml`**: Unión de los managers adicionales al plano de control HA vía `--certificate-key`.
*   **`08_unir_workers.yml`**: Ejecución de `kubeadm join` en los workers para conectarlos al clúster (vía la VIP).
*   **`09_desplegar_headlamp.yml`**: Despliegue del dashboard web Headlamp expuesto vía NodePort en el puerto `32082`, justo después de unir los workers para poder seguir el resto de despliegues desde su consola web.
*   **`10_despliegue_test.yml`**: Despliegue de una aplicación web de pruebas (Nginx) con 2 réplicas y verificación de que se balancea correctamente entre los workers.
*   **`11_prueba_resiliencia_ha.yml`**: Prueba de resiliencia HA dedicada — parar y recuperar un worker, y parar y recuperar el manager que hizo el `kubeadm init` inicial, verificando que la VIP conmuta y el clúster nunca deja de responder.
*   **`12_adicionar_nodo.yml`** / **`13_eliminar_nodo.yml`**: playbooks de escalado (añadir/quitar un worker de forma segura).
*   **`20_destroy.yml`**: Detención forzada y eliminación de las máquinas virtuales de LXD, además de la limpieza de archivos locales.

## 🚀 Uso del Laboratorio

1.  Otorga permisos de ejecución a los scripts:
    ```bash
    chmod +x run_all.sh destroy_all.sh
    ```

2.  Ejecuta el despliegue automático del clúster:
    ```bash
    ./run_all.sh
    ```

3.  Para interactuar con el clúster usando `kubectl` desde tu host, Ansible te dejará el archivo `kubeconfig.yaml` en esta carpeta. Puedes usarlo así:
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig.yaml
    kubectl get nodes -o wide
    ```

4.  **Acceso al Dashboard:**
    *   **URL:** [http://10.207.154.50:32082](http://10.207.154.50:32082)
    *   **Token:** Abre el archivo generado [headlamp_token.txt](headlamp_token.txt) para copiar el token de administrador e iniciar sesión.

5.  **Escalar el Clúster (Añadir/Quitar nodos):**
    *   **Añadir un nuevo nodo:**
        1. Abre el archivo `inventory.ini` y define el nuevo nodo dentro del grupo `[new_workers]`. Por ejemplo:
           ```ini
           [new_workers]
           k8s-worker3 ansible_host=10.207.154.53 lxd_cpu=2 lxd_mem=2GB lxd_disk=15GB
           ```
        2. Ejecuta el playbook de escalado:
           ```bash
           ansible-playbook 10_adicionar_nodo.yml
           ```
    *   **Quitar un nodo:**
        1. Ejecuta el playbook de eliminación especificando el nombre del nodo:
           ```bash
           ansible-playbook 11_eliminar_nodo.yml -e "node_name=k8s-worker3"
           ```

6.  Para limpiar todo el entorno y liberar recursos de tu máquina:
    ```bash
    ./destroy_all.sh
    ```
