# Laboratorio 06: Configuración de Registros Privados (Docker Registry / Mirrors)

Este laboratorio demuestra cómo configurar un **espejo (mirror) de registro de imágenes** para RKE2 usando `/etc/rancher/rke2/registries.yaml` y un registry local `registry:2` como pull-through cache de `docker.io`.

---

## 📋 ¿Qué despliega este laboratorio?

1. **VM LXD `rke2-server1`** con RKE2 Server mono-nodo.
2. **Contenedor Docker `rke2-registry-mirror`** en el host LXD, corriendo `registry:2` como pull-through cache de `docker.io` (HTTP, sin TLS, host networking en `0.0.0.0:5000`).
3. **`/etc/rancher/rke2/registries.yaml`** en el nodo RKE2, redirigiendo los pulls de `docker.io` al mirror local en `http://10.207.154.1:5000`.
4. **Verificación automática**: un Pod de prueba `busybox:1.36` que confirma que containerd descarga la imagen a través del mirror (assert contra el catálogo del registry).

---

## 📄 Estructura de `/etc/rancher/rke2/registries.yaml`

RKE2 y Containerd leen este archivo al arrancar/reiniciar `rke2-server` o `rke2-agent`:

```yaml
# /etc/rancher/rke2/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "http://10.207.154.1:5000"
configs:
  "10.207.154.1:5000":
    tls:
      insecure_skip_verify: true
```

### Autenticación y TLS (ejemplo extendido)

Para registries privados con autenticación y certificados autofirmados:

```yaml
mirrors:
  "registry.empresa.local":
    endpoint:
      - "https://registry.empresa.local:5000"
configs:
  "registry.empresa.local:5000":
    auth:
      username: "usuario_registry"
      password: "password_secreto"
    tls:
      ca_file: "/etc/rancher/rke2/certs/custom-ca.crt"
      insecure_skip_verify: false
```

---

## 🚀 Uso

```bash
# Desplegar el lab completo (VMs + RKE2 + registry mirror + verificación):
./run_all.sh

# Verificar el acceso al clúster:
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes -o wide
kubectl get pod registry-mirror-probe

# Comprobar el catálogo del mirror:
curl http://10.207.154.1:5000/v2/_catalog

# Destruir el lab (VMs + contenedor registry):
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`). |
| `group_vars/all.yml` | Variables del clúster + registry mirror (host, puerto, nombre contenedor). |
| `10_configurar_registry.yml` | Playbook lab-local: despliega el registry, empuja `registries.yaml`, reinicia RKE2 y verifica el pull. |
| `templates/registries.yaml.j2` | Template Jinja2 del fichero `registries.yaml`. |
| `destroy_registry.yml` | Teardown lab-local: elimina el contenedor Docker del registry. |

---

## ✅ Validación

- **2026-08-05**: Validado en vivo con 2 ejecuciones consecutivas idempotentes (`changed=0` en el step lab-specific). Pod `busybox:1.36` en estado `Running`, mirror catalog confirma `library/busybox` cacheado.
