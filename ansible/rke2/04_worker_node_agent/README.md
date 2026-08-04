# Laboratorio 04: Adición de Worker Nodes (RKE2 Agent)

Este laboratorio explica cómo unir nodos de trabajo (**Worker / Agent Nodes**) a un clúster RKE2 existente.

## 📌 Requisitos Previos

1. Tener un **Server Node** en funcionamiento accesible en la IP (ejemplo `10.207.154.60`).
2. Obtener el **Token de unión** del Server Node ubicado en:
   `/var/lib/rancher/rke2/server/node-token`

## ⚙️ Configuración del Agent (`/etc/rancher/rke2/config.yaml` en el Worker)

```yaml
server: "https://10.207.154.60:9345"
token: "K10xxxxxx::server:abcdef1234567890..."
node-name: "rke2-worker1"
```

> [!NOTE]
> El puerto de unión es el **`9345`** (RKE2 Supervisor), NO el `6443` (API Server).

## 🚀 Comandos de Instalación en el Worker

```bash
# 1. Crear directorio de configuración
sudo mkdir -p /etc/rancher/rke2

# 2. Copiar/crear config.yaml con el servidor y token
sudo nano /etc/rancher/rke2/config.yaml

# 3. Instalar RKE2 en modo agent
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sudo sh -

# 4. Habilitar y arrancar el servicio rke2-agent
sudo systemctl enable --now rke2-agent.service

# 5. Comprobar desde el Server Node que el worker se ha unido
kubectl get nodes
```
