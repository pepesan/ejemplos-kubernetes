# Reglas para Nodos Kubernetes en LXD/LXC

Al desplegar clústeres de Kubernetes en entornos LXD/LXC, la estabilidad del host (especialmente en equipos de desarrollo con entornos gráficos X11/NVIDIA y múltiples dispositivos USB) depende del aislamiento de los recursos.

## 1. Estrategia Principal: Usar Máquinas Virtuales LXD (Recomendado)
- **Regla:** Siempre que sea posible, prefiere Máquinas Virtuales LXD (`type: virtual-machine` en Ansible) frente a contenedores privilegiados.
- **Razón:** Las VMs cuentan con su propio kernel virtualizado independiente y aislamiento por hardware (QEMU/KVM). Esto elimina por completo cualquier riesgo de interferencia con el hardware, los controladores de video (X11/NVIDIA) o los buses USB del host. Además, no requieren desactivar AppArmor ni realizar hacks de cgroups en el host.
- **Configuración básica en Ansible:**
  ```yaml
  community.general.lxd_container:
    name: k8s-node
    type: virtual-machine
    state: started
    # limits.cpu y limits.memory son totalmente soportados
  ```

## 2. Estrategia Secundaria: Contenedores Privilegiados (Fallback)
Si por restricciones extremas de hardware o recursos (RAM/CPU) se requiere obligatoriamente el uso de contenedores privilegiados (`security.privileged: "true"` con `/sys` montado en modo lectura/escritura):

- **Conflicto Crítico:** El servicio `systemd-udevd` interno del contenedor intentará gestionar el hardware real del host en el arranque, tirando la sesión gráfica (X11) y desconectando buses USB.
- **Acción Obligatoria:**
  1. Crear el contenedor apagado (`state: present`).
  2. Enmascarar preventivamente udev copiando archivos vacíos (`/dev/null`) a los paths de systemd internos antes de iniciar el contenedor:
     - `/etc/systemd/system/systemd-udevd.service`
     - `/etc/systemd/system/systemd-udevd-kernel.socket`
     - `/etc/systemd/system/systemd-udevd-control.socket`
  3. Iniciar el contenedor (`state: started`).

