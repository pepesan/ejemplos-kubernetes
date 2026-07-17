# 🌐 Escenario 06: Red y Acceso Externo (MetalLB + NGINX Ingress)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (idéntico al escenario 02: 3 managers + 3 workers, kube-vip), reutilizando vía `import_playbook` sus playbooks de infraestructura y bootstrap. Sobre él instala **MetalLB** para exponer servicios de tipo `LoadBalancer` en una red local sin balanceador de nube, y el **NGINX Ingress Controller** para enrutar tráfico HTTP a varios microservicios según el nombre de host.

## 📋 Estructura de Playbooks

*   **`ansible.cfg`** / **`inventory.ini`** / **`group_vars/all.yml`**: configuración del entorno, incluyendo el rango de IPs reservado para MetalLB (`metallb_ip_range`) y el dominio local de pruebas (`ingress_base_domain`).
*   **`../check_requisitos.yml`**: validación unificada de requisitos del host (LXD, red, imagen base).
*   **`02_crear_nodos.yml`** a **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs y formar el clúster HA.
*   **`09_desplegar_headlamp.yml`**: despliega Headlamp Dashboard (NodePort, igual que en el resto de laboratorios) justo después de formar el clúster, para poder seguir el resto de despliegues desde su consola web.
*   **`10_desplegar_metallb.yml`**: instala MetalLB vía Helm y configura un `IPAddressPool` + `L2Advertisement` para anunciar el rango de IPs por ARP en la red de LXD.
*   **`11_desplegar_ingress_nginx.yml`**: instala el NGINX Ingress Controller vía Helm con `service.type=LoadBalancer`, y espera a que MetalLB le asigne una IP externa.
*   **`12_desplegar_apps_demo.yml`**: despliega dos microservicios de prueba (`app-a`, `app-b`), cada uno con su propio `ConfigMap`, `Secret` e `initContainer` (que espera a que el DNS del clúster esté listo antes de arrancar el contenedor principal), consolidados detrás de un único `Ingress` que enruta por nombre de host.
*   **`13_verificar_ingress.yml`**: comprueba que cada host (`app-a.k8s.local`, `app-b.k8s.local`) devuelve el contenido correspondiente a su propio microservicio.
*   **`14_add_node.yml`** / **`15_eliminar_nodo.yml`**: escalado de nodos worker (ver más abajo).
*   **`20_destroy.yml`**: destrucción completa del entorno.

---

## 🚀 Despliegue

```bash
cd 06_k8s_red_ingress_metallb
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

### Acceso a las apps de prueba (por nombre de host):

Al terminar, `run_all.sh` muestra la IP que MetalLB asignó al Ingress Controller. Añádela a tu `/etc/hosts`:

```
<IP-LOADBALANCER> app-a.k8s.local app-b.k8s.local
```

Y accede desde el navegador o `curl`:

```bash
curl http://app-a.k8s.local/
curl http://app-b.k8s.local/
```

Cada host devuelve el saludo (`ConfigMap`) y la clave (`Secret`) de su propio microservicio — la misma IP y el mismo puerto (80) sirven contenido distinto según la cabecera `Host`, demostrando la consolidación de varios servicios detrás de un único punto de entrada.

### Acceso al Dashboard (Headlamp):
*   **URL:** `http://<VIP>:32082` (VIP: `10.207.154.49`)
*   **Token:** guardado en `headlamp_token.txt`. Para consultarlo o regenerarlo:
    ```bash
    kubectl --kubeconfig=kubeconfig.yaml create token headlamp-admin -n headlamp --duration=8760h
    ```

### Escalar el Clúster (Añadir/Quitar nodos worker):
*   **Añadir un nuevo worker:**
    1. Descomenta/añade una línea en `[new_workers]` de `inventory.ini`.
    2. `ansible-playbook 14_add_node.yml`
*   **Quitar un worker:**
    ```bash
    ansible-playbook 15_eliminar_nodo.yml -e "node_name=k8s-worker3"
    ```

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **MetalLB en modo L2 (ARP), no BGP:** para un laboratorio local de una sola subred plana en `lxdbr0`, el modo L2 (un nodo asume la IP vía ARP/NDP, sin necesidad de un router BGP) es el patrón estándar y no requiere infraestructura de red adicional. El rango `metallb_ip_range` está fuera del rango de IPs de nodos/VIP para evitar colisiones.
*   **Un único Ingress Controller compartido:** en vez de un `Service` `LoadBalancer` por cada microservicio (que consumiría una IP de MetalLB por servicio), se usa un solo Ingress Controller con una única IP LoadBalancer, y el enrutamiento por nombre de host (`Ingress` con múltiples `rules.host`) hacia los `Service` internos (`ClusterIP`) de cada app. Este es el patrón real de "consolidación de microservicios" en clústeres de producción.
*   **`initContainers` como patrón de espera de dependencias:** cada microservicio de prueba usa un `initContainer` (`busybox` con `nslookup` en bucle) que bloquea el arranque del contenedor principal hasta que el DNS del clúster responde — un patrón común para esperar a que una dependencia (DNS, base de datos, etc.) esté lista antes de arrancar la aplicación.
*   **`ConfigMap`/`Secret` vía `envFrom`:** los dos microservicios inyectan su configuración (`ConfigMap`) y credenciales (`Secret`) como variables de entorno, y las usan al generar su página de inicio en el arranque del contenedor — patrón de parametrización de aplicaciones sin necesidad de reconstruir la imagen.
