# Laboratorio K8s Multi-Node (1 Manager + 2 Workers) sobre LXD

Este laboratorio contiene una serie de playbooks de Ansible para desplegar de forma automatizada un clúster multi-nodo completo de Kubernetes (1 nodo Control-Plane/Manager y 2 nodos Workers) sobre máquinas virtuales LXD en la máquina local.

## 📋 Estructura de Playbooks

*   **`ansible.cfg`**: Configuración de Ansible para este entorno.
*   **`inventory.ini`**: Definición de los nodos con sus IPs estáticas:
    *   `k8s-manager` (`10.207.154.50` - 3GB RAM, 2 CPUs)
    *   `k8s-worker1` (`10.207.154.51` - 2GB RAM, 2 CPUs)
    *   `k8s-worker2` (`10.207.154.52` - 2GB RAM, 2 CPUs)
*   **`group_vars/all.yml`**: Variables globales del sistema (red, versión de k8s, etc.).
*   **`01_check_requisitos.yml`**: Verificación de herramientas locales (LXD, red, imagen).
*   **`02_crear_nodos.yml`**: Creación de las 3 máquinas virtuales de LXD y la inyección de claves SSH.
*   **`03_configurar_os.yml`**: Ajustes de kernel y sysctl obligatorios para Kubernetes en todos los nodos.
*   **`04_instalar_containerd.yml`**: Instalación del Container Runtime Interface (CRI) en todo el clúster.
*   **`05_instalar_k8s_tools.yml`**: Instalación de `kubeadm`, `kubelet` y `kubectl` en todos los nodos.
*   **`06_inicializar_manager.yml`**: Inicialización del plano de control en el Manager, configuración de CNI Flannel y generación/propagación del token de unión.
*   **`07_unir_workers.yml`**: Ejecución de `kubeadm join` en los workers para conectarlos al Manager de forma automatizada.
*   **`08_despliegue_test.yml`**: Despliegue de una aplicación web de pruebas (Nginx) con 2 réplicas y verificación de que se balancea correctamente entre los workers.
*   **`09_desplegar_headlamp.yml`**: Despliegue del dashboard web Headlamp expuesto vía NodePort en el puerto `32082` del Manager.
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

5.  Para limpiar todo el entorno y liberar recursos de tu máquina:
    ```bash
    ./destroy_all.sh
    ```
