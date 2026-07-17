# 🔄 Escenario 09: Actualización de Clúster HA (v1.35 → v1.36)

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (idéntico al escenario 02: 3 managers + 3 workers, kube-vip), pero inicialmente en **Kubernetes v1.35**, y a continuación ejecuta el proceso oficial de actualización de `kubeadm` a **v1.36**, nodo a nodo, sin interrumpir la disponibilidad del API server (gracias a la VIP de kube-vip y al `drain`/`uncordon` de cada nodo por turnos).

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02 para crear las 6 VMs y formar el clúster HA — con `k8s_major_version: "v1.35"` en `group_vars/all.yml`, así que el clúster arranca en esa versión.
*   **`09_desplegar_headlamp.yml`**: despliega Headlamp Dashboard **justo después de formar el clúster**, antes de empezar la actualización — así se puede seguir en tiempo real desde su consola web cómo van cambiando de versión los nodos.
*   **`10_actualizar_primer_manager.yml`**: en `k8s-manager1` (el que hizo el `kubeadm init` inicial) — apunta el repositorio APT a la nueva versión, actualiza el paquete `kubeadm`, ejecuta `kubeadm upgrade plan`/`apply`, hace `drain` del nodo, actualiza `kubelet`/`kubectl`, reinicia `kubelet` y hace `uncordon`.
*   **`11_actualizar_managers_adicionales.yml`**: mismo proceso en `k8s-manager2` y `k8s-manager3`, pero con `kubeadm upgrade node` (no `apply`, reservado al primer nodo) — **uno a uno** (`serial: 1`) para no perder nunca el quórum de etcd ni la disponibilidad de la VIP.
*   **`12_actualizar_workers.yml`**: mismo proceso en los 3 workers (`kubeadm upgrade node` + `drain`/actualizar/`uncordon`), también uno a uno.
*   **`13_verificar_actualizacion.yml`**: comprueba que los 6 nodos reportan la versión objetivo, que la API sigue respondiendo vía la VIP y que todos los Pods de `kube-system` están sanos.
*   **`20_destroy.yml`**: destrucción completa del entorno.

No se incluyen playbooks de escalado (`add_node`/`eliminar_nodo`): el foco pedagógico de este laboratorio es el proceso de actualización de versión, ya cubierto el escalado de nodos en los escenarios 02-06.

---

## 🚀 Despliegue

```bash
cd 09_k8s_actualizacion_cluster_ha
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

Para desplegar solo el clúster en v1.35 sin actualizar todavía (por ejemplo, para observar el "antes" desde Headlamp):
```bash
./run_all.sh --hasta 09
```
Y para completar la actualización después:
```bash
./run_all.sh --hasta 13
```
(Los pasos ya completados no se repiten: cada tarea de creación/inicialización comprueba el estado existente antes de actuar.)

### Acceso:
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`. Desplegado antes de la actualización para poder observarla en directo.
*   🔗 **kubectl:**
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig.yaml
    kubectl get nodes -o wide
    ```

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Clúster inicial en v1.35, no en la versión estándar del resto de laboratorios (v1.36):** es el único laboratorio que fija una versión de Kubernetes distinta a la del resto (`k8s_major_version` propio en su `group_vars/all.yml`), precisamente porque su objetivo es demostrar el salto entre dos versiones consecutivas.
*   **`kubeadm upgrade apply` solo en el primer manager, `kubeadm upgrade node` en el resto:** es el flujo oficial documentado por Kubernetes — el primer nodo del plano de control aplica los cambios a nivel de clúster (nueva versión del `ClusterConfiguration`, certificados, etc.), y el resto de nodos (managers adicionales y workers) solo necesitan sincronizar su configuración local de kubelet con `kubeadm upgrade node`.
*   **`serial: 1` en managers adicionales y en workers:** actualizar los nodos de uno en uno (nunca en paralelo) es lo que garantiza que la VIP de kube-vip y el quórum de etcd nunca se pierdan durante el proceso — con `serial` sin especificar, Ansible intentaría hacer `drain` de varios nodos a la vez, arriesgando quedarse sin capacidad para reprogramar Pods o incluso perder el quórum si caen 2 de 3 managers a la vez.
*   **`dpkg_selections` para quitar/poner el "hold" de versión:** los paquetes `kubeadm`/`kubelet`/`kubectl` se marcan con `apt-mark hold` nada más instalarse (ver escenario 02) para evitar actualizaciones automáticas accidentales; hay que liberarlos explícitamente antes de instalar la nueva versión y volver a fijarlos después, o `apt` se negaría a actualizarlos.
*   **`drain`/`uncordon` delegado a `localhost`:** los comandos `kubectl drain`/`uncordon` se ejecutan contra el nodo desde la máquina de control (con el `kubeconfig.yaml` local), igual que el resto de operaciones `kubectl` de este repositorio — no hace falta que el propio nodo tenga configurado `kubectl` para actuar sobre sí mismo.
*   **Verificación de versión y salud en `13_verificar_actualizacion.yml`, no una prueba de caída de nodos como en el escenario 02:** el objetivo aquí es demostrar que la actualización en sí no interrumpe el servicio (verificado indirectamente en cada paso, comprobando que la API sigue respondiendo vía la VIP mientras cada nodo está en `drain`), no repetir la prueba de resiliencia ante fallos ya cubierta en el escenario 02.
*   **Headlamp desplegado antes de la actualización:** mismo criterio ya aplicado en el escenario 08 — desplegarlo nada más formar el clúster permite observar en directo, desde la consola web, cómo cada nodo pasa por `drain`→actualización→`uncordon` durante el resto del laboratorio.
