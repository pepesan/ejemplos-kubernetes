# db_operator

Installs a database operator into an already-running Kubernetes cluster via Helm. Faithfully
extracted from the near-identical `12_desplegar_*_operator.yml` step repeated across
`ansible/base/10_k8s_percona_mysql_pxc`, `base/11_k8s_mariadb_galera`,
`base/12_k8s_percona_postgresql` and `base/13_k8s_percona_mongodb`:

1. Adds the operator's Helm repository — `pxc`/`postgresql`/`mongodb` are all Percona operators
   sharing one repo; `mariadb` is a separate upstream (`mariadb-operator`) with its own repo.
2. Creates the operator's namespace if it doesn't already exist.
3. Installs the selected operator's chart(s) via Helm, pinned at a proven version.
4. Waits for the operator's Deployment(s) to finish rolling out. `mariadb` additionally installs
   a separate CRDs chart first and waits for its validating-webhook Deployment and Service
   endpoints too — its webhook becomes ready a few seconds after the main controller, and a
   `MariaDB` CRD created too early fails with "no route to host".

## Requirements

- An already-running Kubernetes cluster with a fetched admin kubeconfig (e.g. `k8s_ha_cluster`).
- Run against `hosts: localhost` (or equivalent) — every task talks to the cluster via
  `kubeconfig`, none of it runs on cluster nodes directly.

## Role Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `db_operator_name` | `pxc` | Which operator to install: `pxc`, `postgresql`, `mongodb` or `mariadb` |
| `db_operator_kubeconfig_path` | `{{ inventory_dir }}/kubeconfig.yaml` | Admin kubeconfig of the cluster to install into |
| `db_operator_namespace` | *(per-operator default: `pxc`/`postgres`/`mongodb`/`mariadb`)* | Namespace the operator is installed into |
| `db_operator_pxc_chart_version` | `1.20.0` | `pxc-operator` chart version |
| `db_operator_pg_chart_version` | `3.0.0` | `pg-operator` chart version |
| `db_operator_psmdb_chart_version` | `1.22.0` | `psmdb-operator` chart version |
| `db_operator_mariadb_chart_version` | `26.6.0` | `mariadb-operator` (and its CRDs chart) version |
| `db_operator_rollout_timeout` | `180s` | How long to wait for the operator Deployment(s)' rollout |

## Example Playbook

```yaml
- hosts: localhost
  roles:
    - role: db_operator
      vars:
        db_operator_name: postgresql
```

Call this role once per operator you need (e.g. `pxc` then `mariadb` in the same play) — each
selects its own task file (`tasks/{{ db_operator_name }}.yml`) and installs independently.

## Testing

One Molecule scenario, all four operators installed in sequence against the same cluster
(cheaper than one cluster per operator; each operator's install logic is independent, so testing
them together doesn't hide cross-operator issues):

```bash
cd ansible/roles/db_operator
molecule test
```

`prepare.yml` provisions one cheap k8s node via `lxd_machine_provision` + `k8s_ha_cluster`
(`csi: none`, Flannel, no Headlamp — no storage needed to just install operators). `converge.yml`
loops `db_operator_name` over `[pxc, postgresql, mongodb, mariadb]`, running this role once per
value. `verify.yml` checks, per operator: the namespace exists, the Helm release(s) are
`deployed`, and `kubectl rollout status` on the operator Deployment(s) succeeds. Includes
Molecule's native `idempotence` step.

```bash
./molecule/run_matrix.sh
```

Runs the same scenario once per operator (`pxc`, `postgresql`, `mongodb`, `mariadb`), each
installed **standalone** rather than bundled with the other 3 — proves no operator implicitly
depends on shared cluster state left behind by another. Full `molecule test` per operator
(including native `idempotence`). Resumable: results already recorded in
`../db_operator_matrix_results.csv` (at the `ansible/roles/` level, alongside every other role's
own matrix results) are skipped on a re-run.
