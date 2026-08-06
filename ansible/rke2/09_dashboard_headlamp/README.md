# Laboratorio 09: Panel de Control Web Moderno con Headlamp

Este laboratorio demuestra cómo desplegar y configurar **Headlamp** (CNCF Sandbox), la interfaz de usuario web moderna e interactiva para Kubernetes, sobre un clúster RKE2.

---

## 📋 ¿Qué despliega este laboratorio?

1. **Clúster RKE2 (2 VMs LXD)**:
   - 1 Server Node (`rke2-server1` en `10.207.154.60`).
   - 1 Worker Node (`rke2-worker1` en `10.207.154.61`).
2. **Headlamp Web Dashboard (v0.44.0)**:
   - Despliegue automatizado vía Helm (`headlamp/headlamp`) en el namespace `headlamp`.
   - Exposición mediante servicio `NodePort` en el puerto `30090`.
3. **Autenticación Segura automatizada**:
   - Creación del `ServiceAccount` `headlamp-admin` con `ClusterRoleBinding` `cluster-admin`.
   - Generación de Secret con Token de servicio persistente (`headlamp-admin-token`).
   - Guardado automático del token Bearer en el fichero local `headlamp_token.txt`.

---

## 🚀 Uso

```bash
# Desplegar el clúster RKE2 + Headlamp + Generación de Token:
./run_all.sh

# El script mostrará al finalizar la URL de acceso y el Token listo para copiar:
# URL: http://10.207.154.60:30090
# Fichero de Token: $(pwd)/headlamp_token.txt

# Abrir en el navegador de la máquina host:
http://10.207.154.60:30090

# Copiar el token desde la consola o leerlo desde el fichero:
cat headlamp_token.txt

# Destruir el laboratorio:
./destroy_all.sh
```

---

## 🏗️ Ficheros del laboratorio

| Fichero | Descripción |
| --- | --- |
| `inventory.ini` | 1 Server (`rke2-server1`) + 1 Worker (`rke2-worker1`). |
| `group_vars/all.yml` | Variables del clúster RKE2 y Headlamp (NodePort 30090, versión 0.44.0). |
| `10_configurar_headlamp.yml` | Playbook lab-local: despliega Headlamp vía Helm, crea RBAC, genera el token y lo guarda en `headlamp_token.txt`. |
| `run_all.sh` / `destroy_all.sh` | Scripts de ciclo de vida del laboratorio. |

---

## ✅ Idempotencia

El laboratorio es **100% idempotente**: la reejecución de `./run_all.sh` valida que el release de Helm, el RBAC y el Secret de token están presentes sin provocar modificaciones no deseadas (`changed=0`).
