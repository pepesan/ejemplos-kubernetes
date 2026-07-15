# Laboratorio K8s Single-Node sobre LXD

Este laboratorio contiene una serie de playbooks de Ansible para desplegar un nodo único de Kubernetes sobre contenedores LXD en la máquina local de manera automatizada.

## 📋 Estructura

*   **`ansible.cfg`**: Parámetros globales de Ansible (inventario por defecto, pipelining activo).
*   **`inventory.ini`**: Declaración de recursos del nodo (`k8s-single` con IP `10.207.154.50`).
*   **`group_vars/all.yml`**: Variables del sistema (red, imagen, versión de k8s).
*   **`01_check_requisitos.yml`**: Verificación de herramientas locales (LXD, red, imagen).
*   **`02_crear_nodo.yml`**: Creación del contenedor con privilegios especiales y nesting activado.
*   **`03_configurar_os.yml`**: Configuración de módulos y sysctl requeridos por Kubernetes.
*   **`04_instalar_containerd.yml`**: Instalación del Container Runtime Interface (CRI).
*   **`05_instalar_k8s_tools.yml`**: Instalación de `kubeadm`, `kubelet` y `kubectl` desde repositorios oficiales.
*   **`06_inicializar_cluster.yml`**: Inicialización del clúster con `kubeadm`, instalación de Flannel CNI y remoción de Taints para despliegue mono-nodo.
*   **`07_destroy.yml`**: Eliminación del contenedor para limpieza rápida.

## 🚀 Uso del Laboratorio

1.  Asegura permisos de ejecución para los scripts automatizados:
    ```bash
    chmod +x run_all.sh destroy_all.sh
    ```

2.  Ejecuta el despliegue del laboratorio:
    ```bash
    ./run_all.sh
    ```

3.  Conéctate por SSH al nodo creado para verificar el clúster:
    ```bash
    ssh root@10.207.154.50
    ```
    Una vez dentro, ejecuta:
    ```bash
    kubectl get nodes
    kubectl get pods -A
    ```

4.  Para eliminar y limpiar el entorno:
    ```bash
    ./destroy_all.sh
    ```
