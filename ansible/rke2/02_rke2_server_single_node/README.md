# Laboratorio 02: Instalación de RKE2 Server Node (Mono-nodo)

Este laboratorio demuestra cómo instalar y configurar un **RKE2 Server Node** independiente en una máquina virtual LXD.

## 📌 Aspectos Clave

1. **Instalador Oficial:** Usa el script de instalación `https://get.rke2.io`.
2. **Archivo de Configuración:** `/etc/rancher/rke2/config.yaml`.
3. **Servicio Systemd:** `rke2-server.service`.
4. **Kubeconfig:** Generado en `/etc/rancher/rke2/rke2.yaml` (con permisos `0600`).
5. **Binarios y Symlinks:** `kubectl`, `crictl` y `ctr` se instalan en `/var/lib/rancher/rke2/bin/`.

## ⚙️ Ejemplo de `config.yaml` básico (`/etc/rancher/rke2/config.yaml`)

```yaml
token: "mi-token-secreto-rke2"
tls-san:
  - "10.207.154.60"
  - "rke2-server.local"
write-kubeconfig-mode: "0644"
cni: "canal"
```

## 🚀 Comandos Rápidos

```bash
# 1. Crear directorio de configuración
sudo mkdir -p /etc/rancher/rke2

# 2. Descargar e instalar RKE2 Server
curl -sfL https://get.rke2.io | sudo sh -

# 3. Habilitar y arrancar el servicio
sudo systemctl enable --now rke2-server.service

# 4. Configurar kubectl para el usuario local
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export PATH=$PATH:/var/lib/rancher/rke2/bin
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc

# 5. Comprobar estado del nodo
kubectl get nodes
```
