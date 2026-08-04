# Laboratorio 06: Configuración de Registros Privados (Docker Registry / Mirrors)

RKE2 y Containerd permiten configurar registros de imágenes privados, espejos (mirrors) y autenticación sin modificar la configuración global de containerd directamente, mediante el archivo `/etc/rancher/rke2/registries.yaml`.

## 📄 Estructura de `/etc/rancher/rke2/registries.yaml`

El archivo se lee automáticamente durante el arranque o reinicio de `rke2-server` y `rke2-agent`.

```yaml
mirrors:
  "docker.io":
    endpoint:
      - "https://registry-mirror.local:5000"
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

## 🚀 Pasos para Aplicar Registros Privados

1. Crear el directorio y colocar el archivo `/etc/rancher/rke2/registries.yaml` en todos los nodos (Server y Worker).
2. Si se usan certificados autofirmados, colocarlos en la ruta especificada en `ca_file`.
3. Reiniciar el servicio de RKE2:
   ```bash
   # En Server Node:
   sudo systemctl restart rke2-server

   # En Worker Node:
   sudo systemctl restart rke2-agent
   ```
4. Probar la descarga de imágenes desde el registro privado:
   ```bash
   crictl pull registry.empresa.local:5000/mi-app:v1.0
   ```
