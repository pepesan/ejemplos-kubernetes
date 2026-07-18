# 🔐 Escenario 14: HashiCorp Vault — Secretos Dinámicos de Base de Datos

Este laboratorio despliega un clúster de Kubernetes HA de **6 nodos** (3 managers + 3 workers, kube-vip), en diseño **hiperconvergente** (mismo patrón que el escenario 10) con **Longhorn** como backend de almacenamiento persistente y **Cilium** como CNI con su LoadBalancer L2 nativo (sin Gateway API). Sobre esa base se despliega un clúster **Percona XtraDB Cluster** (igual que el escenario 10, aquí como "base de datos objetivo") y, encima, **HashiCorp Vault en modo HA** para demostrar su caso de uso más representativo: **credenciales de base de datos dinámicas**, generadas bajo demanda para una aplicación y **revocadas automáticamente** al expirar, sin que ninguna contraseña estática se guarde nunca en un `Secret` de Kubernetes ni en `etcd`.

Último laboratorio del roadmap de la serie de operadores de bases de datos (10-13) y de los laboratorios de plataforma en general.

## 📋 Estructura de Playbooks

*   **`02_crear_nodos.yml`** a **`05_instalar_k8s_tools.yml`**, **`07_unir_managers.yml`**, **`08_unir_workers.yml`**: reutilizan (`import_playbook`) los playbooks del escenario 02.
*   **`06_inicializar_primer_manager.yml`**: instala **Cilium** vía Helm (`kubeProxyReplacement: true`, `l2announcements.enabled: true`, sin Gateway API), igual que el escenario 10.
*   **`09_configurar_cilium_lb.yml`**: crea el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy`.
*   **`10_desplegar_headlamp.yml`**: despliega Headlamp Dashboard nada más formar el clúster.
*   **`11_desplegar_longhorn.yml`**: instala Longhorn de forma hiperconvergente (los 3 workers alojan Longhorn, PXC Y Vault).
*   **`12_desplegar_percona_operator.yml`** / **`13_desplegar_pxc_cluster.yml`** / **`14_verificar_pxc.yml`**: despliegan y verifican el clúster PXC (idéntico al escenario 10) — es la base de datos sobre la que Vault generará credenciales dinámicas.
*   **`15_instalar_csi_driver.yml`**: instala el **Secrets Store CSI Driver** (`secrets-store-csi-driver/secrets-store-csi-driver`), el componente genérico e independiente de Vault del que depende el montaje de secretos como volumen.
*   **`16_desplegar_vault.yml`**: instala **HashiCorp Vault** (`hashicorp/vault`) en modo HA con almacenamiento **Raft integrado** (sin Consul), 3 réplicas, y el **CSI Provider** de Vault como DaemonSet (`csi.enabled: true` del propio chart — no hace falta ningún chart aparte). El "Vault Agent Injector" (patrón más antiguo, basado en sidecars) se desactiva explícitamente.
*   **`17_inicializar_vault.yml`**: `vault operator init` (claves Shamir) + `vault operator unseal` de los 3 Pods. Claves y token root guardados en `vault_credentials.json`, nunca en pantalla.
*   **`18_secretos_estaticos_kv.yml`**: habilita el motor **KV v2** y escribe/lee un secreto estático de ejemplo — el uso **más básico y habitual** de Vault en la práctica, deliberadamente el primer caso de uso tras inicializar Vault, antes de pasar a los más avanzados (ver "Los usos de Vault, de más básico a más avanzado" más abajo).
*   **`19_configurar_vault_k8s_auth.yml`**: habilita el método de autenticación Kubernetes de Vault (los Pods se autentican con el JWT de su propio `ServiceAccount`, sin credenciales hardcodeadas) y crea la policy que limita qué puede leer la app de ejemplo.
*   **`20_configurar_motor_secretos_bbdd.yml`**: habilita el **Database Secrets Engine** de Vault apuntando al clúster PXC, con un usuario MySQL dedicado (`vault_admin`, privilegios mínimos) y un role (`app-role`) que genera credenciales de solo lectura con TTL corto.
*   **`21_desplegar_app_demo.yml`**: despliega una app de ejemplo que consume la credencial dinámica vía CSI, y verifica el ciclo de vida completo: conexión real a MySQL, existencia del usuario efímero, y revocación automática al expirar el TTL (ver "El flujo del secreto dinámico" más abajo).
*   **`30_destroy.yml`**: destrucción completa del entorno (numerado con margen respecto al último paso funcional, por si se añaden más pasos intermedios en el futuro).

---

## 🚀 Despliegue

```bash
cd 14_k8s_vault_secretos_bbdd
chmod +x run_all.sh destroy_all.sh
./run_all.sh
```

A diferencia de los escenarios 10-13 (donde el flujo por defecto se detiene en el paso de "verificación" y deja el escalado/actualización como extras manuales), aquí `run_all.sh` llega **hasta el paso 20 inclusive** por defecto: la demostración completa del secreto dinámico es el objetivo pedagógico central de este laboratorio, no un extra opcional. Tarda unos minutos más de lo habitual porque el último paso espera activamente a que expire el TTL de la credencial (por defecto 2 minutos) para confirmar la revocación automática.

### Acceso:
*   🔗 **Vault:** sin exposición externa (uso interno del clúster). Desde el host:
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig.yaml
    kubectl -n vault exec -it vault-0 -- vault status
    ```
    Claves de unseal y token root en `vault_credentials.json` (permisos `0600`, nunca en pantalla).
*   🔗 **MySQL (PXC vía HAProxy):** IP propia asignada por el LB-IPAM de Cilium, usuario `root`, contraseña en `pxc_root_password.txt`.
*   🔗 **Headlamp:** `http://10.207.154.49:32082` — token en `headlamp_token.txt`.
*   🔗 **Longhorn:** `http://10.207.154.49:32085`.

## 📚 Los usos de Vault, de más básico a más avanzado

El laboratorio introduce Vault en orden creciente de complejidad, no al revés:

1.  **`18_secretos_estaticos_kv.yml` — motor KV (Key-Value):** el uso más habitual de Vault en la práctica. Un almacén cifrado de secretos **estáticos** (los eliges tú, con `vault kv put`/`vault kv get`), con control de acceso y auditoría, pero **sin rotación automática**. Es el punto de entrada típico para cualquiera que empieza con Vault, y el caso de uso correcto cuando el sistema al que apunta el secreto no tiene un motor dinámico propio (una API de terceros, una licencia, etc.).
2.  **`19`-`21` — Database Secrets Engine (credenciales dinámicas):** el caso de uso más avanzado y el que de verdad diferencia a Vault de "un simple cofre de contraseñas" — credenciales **generadas bajo demanda**, de corta duración, y **revocadas automáticamente** al expirar (ver más abajo).

## 🔑 El flujo del secreto dinámico

```
App (ServiceAccount) ──JWT──▶ Vault (auth Kubernetes) ──▶ policy app-db-policy
                                     │
                                     ▼
                     Database Secrets Engine (vault_admin en PXC)
                                     │
                                     ▼
                  usuario MySQL efímero (v-kubernet-app-role-...)
                                     │
                        CSI Provider ▼ (archivo montado, SIN Secret de K8s)
                              Pod de la app ──▶ conecta a PXC
                                     │
                       TTL expira (2m) ──▶ Vault revoca el lease
                                     │
                          usuario YA NO existe en PXC
```

`21_desplegar_app_demo.yml` no se limita a comprobar que el Pod arranca: lee la credencial montada, se conecta de verdad a PXC con ella, confirma que el usuario efímero existe en `mysql.user`, y luego **espera activamente a que expire su TTL** (sin forzar `vault lease revoke` a mano) para confirmar que Vault lo revoca por sí solo — y que una conexión con esa misma credencial ahora falla. Es la prueba más directa posible del caso de uso central de Vault.

### Destruir el Entorno:
```bash
./destroy_all.sh
```

---

## 📐 Decisiones de Diseño

*   **Vault Agent Injector y External Secrets Operator, descartados a propósito:** el Agent Injector (patrón más antiguo, basado en sidecars) y el External Secrets Operator (sincroniza a un `Secret` de Kubernetes, más simple pero no demuestra tan bien el modelo de "secreto efímero, nunca persistido en `etcd`") se descartaron en favor del **CSI Provider**, más representativo de cómo se hace hoy en producción y coherente con el objetivo de que el secreto nunca pase por un `Secret` nativo.
*   **`syncSecret.enabled: false` en el CSI Driver (valor por defecto, pero se fija explícito):** si se activara, el secreto acabaría materializado en un `Secret` de Kubernetes de todos modos, justo lo que este laboratorio quiere evitar.
*   **Raft integrado, no Consul:** el propio Vault puede ser su propio backend de almacenamiento HA (`ha.raft.enabled: true`) desde hace varias versiones — añadir Consul solo para esto sería una dependencia extra sin aportar nada al objetivo pedagógico del laboratorio.
*   **Unseal manual con claves Shamir, no auto-unseal:** para producción, lo representativo es el auto-unseal vía KMS de un proveedor cloud (AWS KMS/GCP Cloud KMS/Azure Key Vault) — no implementado aquí porque requeriría credenciales cloud reales, fuera del alcance de un laboratorio local en LXD. Se documenta la limitación en vez de simularla.
*   **`vault_admin`, no `root`, para el Database Secrets Engine:** Vault necesita privilegios para crear/borrar usuarios y conceder permisos, pero NUNCA los privilegios completos de `root` — se crea un usuario MySQL dedicado con exactamente los privilegios que necesita (`CREATE USER`, `GRANT OPTION`, `DROP`), ni uno más.
*   **TTL deliberadamente corto (`vault_db_role_default_ttl: 2m`):** para poder demostrar la expiración y revocación automática del lease en minutos, no en horas, sin que el laboratorio deje de ser representativo del mecanismo real.
*   **Conexión de Vault a PXC vía el `Service` interno de HAProxy, no la IP LoadBalancer externa:** Vault vive dentro del propio clúster, así que no tiene sentido salir y volver a entrar por la IP pública — usa la resolución DNS interna (`pxc-db-haproxy.pxc.svc`), igual de válido y sin depender del LB-IPAM de Cilium para una comunicación puramente interna.
*   **Anti-affinity obligatoria "gratis":** a diferencia de las charts de Percona (escenarios 10-13, donde hay que forzar `affinity.advanced`/`requiredDuringSchedulingIgnoredDuringExecution` a mano), el chart oficial de Vault ya trae esa anti-affinity **obligatoria** por defecto para los Pods `server` — un contraste útil frente a la lección aprendida en el resto de la serie.
*   **`global.tlsDisable: true`:** simplificación deliberada para el laboratorio — gestionar certificados TLS entre los Pods de Vault y el listener del cliente no añade valor pedagógico aquí, mismo criterio que otras simplificaciones ya aplicadas en la serie (p. ej. backups deshabilitados en los laboratorios de bases de datos).
*   **Vault chart 0.32.0 (imagen Vault 1.21.2), no 0.34.0 (Vault 2.0.x):** la serie 2.0 se publicó el mismo mes en que se construyó este laboratorio — un salto de versión MAYOR recién publicado es justo el tipo de "bleeding edge" que ya ha dado sorpresas en esta serie (incompatibilidad kernel/glibc con MongoDB 8.x en el escenario 13, Kubernetes 1.36 recién publicado). Se prefiere la última versión 1.x madura, comprobada en vivo con `helm search repo --versions`, no de memoria.
*   **Reutiliza la imagen de PXC para el Pod de demostración:** ya está en caché en el clúster y trae el cliente `mysql` incluido — evita descargar una imagen nueva solo para verificar la conexión.
