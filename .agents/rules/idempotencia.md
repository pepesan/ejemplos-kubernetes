# Regla de Idempotencia para Escenarios Ansible

Para garantizar que todas las recetas de automatización de Ansible en este repositorio sean robustas y seguras frente a múltiples ejecuciones:

## 1. Verificación en Dos Fases
- **Regla:** Siempre que definas o modifiques un escenario o laboratorio, debes probar su ejecución completa **al menos dos veces consecutivas**.
- **Acción:**
  1. **Primera ejecución:** Debe completarse con éxito (creando y configurando los recursos desde cero).
  2. **Segunda ejecución:** Debe completarse con éxito sin reportar cambios innecesarios (`changed: 0` o el mínimo imprescindible como tokens efímeros) y sin dar fallos de "el recurso ya existe".

## 2. Idempotencia en LXD y Kubernetes
- **LXD:** Las tareas de adición de dispositivos, volumenes o interfaces de red deben tolerar que el dispositivo ya exista (usando `failed_when` adecuado o comprobaciones previas).
- **Helm/Kubernetes:** Utiliza siempre módulos idempotentes (`kubernetes.core.k8s` o `kubernetes.core.helm` en lugar de comandos `kubectl` crudos) o gestiona el control de errores (ej. tolerar que un *taint* ya esté aplicado).
- En el resto de tareas usa siempre que peudas un módulo idempotente o un comportamiento idempotente
