# 🧪 Lab 19: Backup & Disaster Recovery de etcd en RKE2

Este laboratorio demuestra la gestión completa de copias de seguridad (snapshots) y el procedimiento de recuperación ante desastres (**Disaster Recovery**) para el almacén de datos `etcd` en un clúster **RKE2**.

---

## 📑 Objetivos del Laboratorio

1. **Automatización de Snapshots (`config.yaml`)**:
   - Configurar la programación automática de snapshots mediante expresión cron (`etcd-snapshot-schedule-cron`).
   - Definir la política de retención de copias de seguridad (`etcd-snapshot-retention`).
   - Especificar el directorio local o destino S3 de almacenamiento de snapshots (`etcd-snapshot-dir`).

2. **Generación Manual de Snapshots vía RKE2 CLI**:
   - Tomar snapshots puntuales en caliente con `rke2 etcd-snapshot save --name <nombre>`.
   - Listar e inspeccionar los snapshots disponibles en el clúster con `rke2 etcd-snapshot ls`.

3. **Simulación de Desastre en Vivo**:
   - Desplegar una aplicación de prueba con datos críticos (Namespace `etcd-backup-demo`, ConfigMap y Deployment).
   - Generar la copia de seguridad `lab19-etcd-snapshot`.
   - Simular una pérdida catastrófica de datos eliminando por completo el namespace y sus recursos.

4. **Procedimiento de Disaster Recovery**:
   - Detener el servicio `rke2-server`.
   - Ejecutar la restitución del estado de `etcd` mediante el comando nativo de RKE2:
     ```bash
     rke2 server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/rke2/server/db/snapshots/<snapshot-file>
     ```
   - Reiniciar `rke2-server` y verificar que todos los namespaces, pods y datos del clúster se han restaurado a su estado original antes del desastre.

---

## 🛠️ Estructura del Laboratorio

```
19_etcd_backup_restore/
├── 10_etcd_backup_restore.yml  # Playbook principal de Backup & Disaster Recovery
├── group_vars/
│   └── all.yml                 # Variables del clúster RKE2 (v1.36.3+rke2r1)
├── inventory.ini               # Inventario de VMs (1 Server + 2 Workers)
├── run_all.sh                  # Aprovisionamiento dinámico + ejecución de laboratorio
├── destroy_all.sh              # Destrucción y limpieza de VMs LXD
├── ansible.cfg                 # Configuración de Ansible
└── README.md                   # Documentación en español del laboratorio
```

---

## 🚀 Guía de Ejecución

### 1. Despliegue y Validación Automática

Para ejecutar todo el laboratorio (aprovisionar VMs, configurar RKE2, tomar snapshot, simular desastre y restaurar etcd):

```bash
./run_all.sh
```

### 2. Prueba de Idempotencia

Ejecuta el playbook por segunda vez consecutiva para comprobar la idempotencia (`changed=0`):

```bash
ansible-playbook 10_etcd_backup_restore.yml
```

### 3. Limpieza del Laboratorio

Para destruir las máquinas virtuales LXD y limpiar el entorno:

```bash
./destroy_all.sh
```

---

## 🔍 Verificación Manual en las Máquinas

Si deseas realizar el proceso manualmente en la VM `rke2-server1`:

```bash
# SSH al servidor principal
ssh root@10.207.154.60

# 1. Tomar un snapshot manual de etcd
rke2 etcd-snapshot save --name manual-backup-demo

# 2. Listar los snapshots guardados
rke2 etcd-snapshot ls

# 3. Restaurar un snapshot de etcd (Disaster Recovery)
systemctl stop rke2-server
rke2 server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/rke2/server/db/snapshots/<snapshot-name>
systemctl start rke2-server

# 4. Verificar la recuperación del API
kubectl get nodes
kubectl get all -n etcd-backup-demo
```
