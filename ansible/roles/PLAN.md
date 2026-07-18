# 🧩 Plan de Ruta y Estado de los Roles

Backlog y estado de los roles de Ansible reutilizables en `ansible/roles/`. Para el plan de ruta de los
laboratorios base, ver [`../base/PLAN.md`](../base/PLAN.md); para la vista general del repositorio, ver
[`../PLAN.md`](../PLAN.md).

Tras completar los 14 laboratorios base (01-14), hay bastante lógica duplicada o casi idéntica entre
ellos que encajaría como roles de Ansible propios. Los laboratorios existentes NO se han migrado a
usar estos roles todavía (decisión explícita: primero crear los roles de forma autocontenida, migrar
más adelante).

## Estado

- ✅ **`lxd_machine_provision`** (implementado y validado con Molecule de verdad, 2026-07-18): aprovisionamiento de instancias LXD — **VMs o contenedores indistintamente** (`lxd_instance_type`, por grupo o por host) — con unos specs dados (CPU/RAM/disco), independiente de qué se instale luego dentro. Reproduce fielmente `02_crear_nodos.yml` (creación, espera del agente LXD, inyección de la clave SSH del host, espera de SSH), generalizando el tipo de instancia (el original solo creaba VMs). `molecule test` completo (sintaxis, converge, `idempotence` nativo, verify, destroy) pasa en los dos escenarios (`default`=VM, `container`), sin dejar residuos.
- 🟡 **`lxd_host_bootstrap`** (implementado, 2026-07-18): preparar el host físico (paquetes apt, colecciones Galaxy, módulos de kernel, LXD/kubectl/helm vía snap, `lxd init` de red+storage+perfil, imagen base). Reproduce fielmente `ansible/base/00_bootstrap_host_lxd.yml`, reorganizado en ficheros de tasks separados con las variables como `defaults/main.yml`. Corregido además un bug real de diseño: `lxd_host_user` y las tareas que dependían de "quien conecta" (`become: false`) asumían que el play se invoca como usuario normal escalando con `become: true` — al asumir en las pruebas que el proceso corre ya como root (`sudo -E molecule test`, sin pedir contraseña interactiva), esa asunción se rompía y la clave SSH/colecciones Galaxy acababan bajo `/root` en vez del usuario real; corregido resolviendo `lxd_host_user` desde `SUDO_USER` (con fallback al usuario conectado) y apuntando esas tareas a él explícitamente vía `become_user`. **Pendiente de la ejecución real de `molecule test`** (necesita `sudo`, que el usuario debe lanzar él mismo) — verificado hasta ahora por sintaxis e inspección.
- ⬜ **`k8s_ha_cluster`**: dado un conjunto de IPs/pools de máquinas, nº de managers/workers y requisitos por pool, monta el clúster HA completo (VIP de kube-vip) con opciones intercambiables de CNI (Cilium/Flannel), CSI/almacenamiento (Longhorn/Rook Ceph/externo) y Headlamp (activable o no, como una opción más de la instalación del clúster, no como role aparte).
- ⬜ **`percona_operator`**: patrón genérico "añadir repo Helm + instalar operador + esperar rollout", parametrizado por el nombre del operador (`pxc-operator`, `pg-operator`, `psmdb-operator`).
- ⬜ **`generated_secret`**: el patrón repetido de "generar una credencial si no existe ya, guardarla en archivo local con permisos `0600`, nunca en pantalla" (contraseñas de PXC, MongoDB, Vault, `vault_admin`...).
- ⬜ **`k8s_node_scale_cycle`**: añadir/unir un nodo nuevo al clúster y drenarlo con seguridad al retirarlo — en particular el workaround del PDB del `instance-manager` de Longhorn antes de un `kubectl drain`, la lección aprendida más repetida de todo el repositorio (escenarios 03, 10-13).

## Mejoras posibles (revisión de roles de la competencia)

Roles similares ya publicados revisados: [`juju4/ansible-lxd`](https://galaxy.ansible.com/juju4/lxd),
[`plumelo/ansible-role-lxd`](https://github.com/plumelo/ansible-role-lxd),
[`tideops/ansible-role-kubernetes`](https://github.com/tideops/ansible-role-kubernetes).

- **`lxd_host_bootstrap`/`lxd_machine_provision`**: ninguna mejora concreta identificada. `juju4/ansible-lxd`
  y `plumelo/ansible-role-lxd` son más limitados que nuestros dos roles (solo instalan LXD y la red, sin
  gestión de imagen base, sin selección VM/contenedor, sin inyección de clave SSH) — no aportan ningún
  patrón que valga la pena adoptar.
- **`k8s_ha_cluster` (futuro)**: `tideops/ansible-role-kubernetes` cubre un alcance similar (kubeadm HA +
  kube-vip + CNI/storage seleccionables), pero usa un patrón de simples booleans on/off por componente
  (`install_longhorn`, `install_nginx_ingress`...), no selección real intercambiable de implementación.
  Para `k8s_ha_cluster` se prefiere un patrón de ficheros de tasks condicionales indexados por el nombre
  del componente elegido (p. ej. `cni: cilium` vs `cni: flannel` cargando tasks distintas, no solo
  activar/desactivar uno fijo) — más flexible y más fiel al objetivo original de "opciones
  intercambiables" de CNI/CSI. Es la única mejora concreta que aporta la revisión de la competencia, y
  aplica a un role todavía no implementado, no a los dos ya construidos.

## Idioma

A diferencia de los 14 laboratorios base (en español), los roles de `ansible/roles/` se escriben
íntegramente en inglés (código, comentarios, documentación y pruebas) — instrucción explícita del
usuario, deliberadamente distinta a la convención del resto del repositorio.

## Namespace de Galaxy — pendiente de revisar antes de publicar

`meta/main.yml` de ambos roles usa `namespace: ejemplos_kubernetes` como placeholder
(Molecule/`ansible-compat` exige alguno para poder calcular el nombre completo del role, aunque no se
vaya a publicar). Si en algún momento se publican de verdad en Ansible Galaxy, hay que sustituirlo por
el namespace real de la cuenta que publique.

## Plan de pruebas — Molecule

Con el driver `default` (renombrado desde `delegated` en Molecule 26.x) apuntando al host real (ni
`lxd_host_bootstrap` ni `lxd_machine_provision` pueden probarse de forma representativa en un
contenedor Docker/Podman aislado, al depender de virtualización real). Cada role incluye el paso
`idempotence` nativo de Molecule en su `test_sequence` — no se acepta ningún paso "siempre changed"
como excepción; en `lxd_machine_provision` esto obligó a corregir la inyección de la clave SSH para
comprobar el contenido ya presente antes de empujarla, en vez de asumir el patrón "siempre changed" que
sí se acepta en otros sitios del repo (p. ej. `force_update` de Headlamp) — decisión explícita del
usuario de exigir idempotencia real y verificada en los roles nuevos. `lxd_machine_provision` tiene dos
escenarios Molecule (`default` para VM, `container` para contenedor, este último con su propio
`prepare.yml` para importar una imagen en formato contenedor — un alias LXD está ligado a un único
formato, VM o contenedor, no ambos).

**Molecule se instaló durante esta sesión** (`pipx install molecule` + `molecule-plugins[docker]`,
aunque el driver usado realmente es `default`/antiguo `delegated`, incluido en el core) y
`molecule test` corre de verdad — no una aproximación manual. Ajustes que hicieron falta para que
funcionase:
- `meta/main.yml` necesita `namespace` explícito.
- El `provisioner.env.ANSIBLE_ROLES_PATH` de cada `molecule.yml` debe apuntar a
  `${MOLECULE_PROJECT_DIRECTORY}/..` (el `ansible/roles/` padre) para que `roles: [...]` resuelva sin
  instalar el role como colección.
