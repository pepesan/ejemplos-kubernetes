# 🧪 Framework de Pruebas Automatizadas

Conjunto de scripts parametrizados para automatizar:
- Validación de idempotencia en labs (2 pasadas consecutivas)
- Pruebas multidistro de `00_instalar_ansible.sh` (5 distros × 2 versiones)
- Compilación de resultados en `MATRIX.md`

## 📁 Estructura de Archivos

**Archivos principales**:
```
test_matrix_runner.sh       # Script maestro que ejecuta pruebas
test_config.sh              # Configuración parametrizada (distros, labs, cambios)
TEST_FRAMEWORK.md           # Este archivo
```

**Directorio de logs** (se crea automáticamente):
```
logs/                       # Directorio de logs (estructura similar a ejemplos)
├── multidistro/           # Logs de pruebas multidistro
│   ├── 20260809_121500_results.csv              # Resultados multidistro (timestamp)
│   ├── 20260809_121500_summary.log              # Resumen ejecución
│   ├── 20260809_121500_test_ubuntu_2404.log    # Log individual: ubuntu 24.04
│   ├── 20260809_121500_test_ubuntu_2604.log
│   ├── 20260809_121500_test_debian_12.log
│   └── ... (más distros)
│
├── labs/                   # Logs de revalidación de labs
│   ├── 20260809_121500_lab02_results.csv        # Resultados Lab 02 (timestamp)
│   ├── 20260809_121500_lab02_summary.log        # Resumen Lab 02
│   ├── 20260809_121500_lab02_pass1.log          # Ejecución 1: Lab 02
│   ├── 20260809_121500_lab02_pass2.log          # Ejecución 2 (idempotencia)
│   ├── 20260809_121500_lab03_results.csv
│   ├── 20260809_121500_lab03_summary.log
│   └── ... (más labs)
│
└── current_20260809_121500/  # Directorio de trabajo (compatibilidad)
    └── (archivos temporales)
```

**Convención de nombres**: `YYYYMMDD_HHMMSS_tipo_nombre.log`
- Incluye fecha/hora de inicio (sin ambigüedad)
- Tipo: `test_`, `lab`, `results`, `summary`
- Nombre: distro o número de lab


## 🚀 Uso Rápido

### Ejecutar todo (todas las pruebas)
```bash
./test_matrix_runner.sh all
```

### Pruebas específicas

#### Multidistro de `00_instalar_ansible.sh`
```bash
./test_matrix_runner.sh multidistro
# Prueba: ubuntu 24.04, 26.04 | debian 12, 13 | rocky 9, 10 | fedora 40, 41 | opensuse leap, tumbleweed
```

#### Revalidar Lab específico (2 pasadas idempotencia)
```bash
./test_matrix_runner.sh lab02   # Lab 02 HA
./test_matrix_runner.sh lab03   # Lab 03 Longhorn
./test_matrix_runner.sh lab04   # Lab 04 Rook Ceph
```

### Configurar salida
```bash
# Escribir resultados en archivo personalizado
OUTPUT_FILE=/tmp/mi_matrix.md ./test_matrix_runner.sh all

# Especificar directorio de logs
LOG_DIR=/tmp/mis_logs ./test_matrix_runner.sh multidistro
```

## 📋 Archivos Generados

```
/tmp/test_matrix_YYYYMMDD_HHMMSS/
├── multidistro_results.txt      # CSV con resultados multidistro
├── test_ubuntu_2404.log         # Log individual: ubuntu 24.04
├── test_ubuntu_2604.log         # Log individual: ubuntu 26.04
├── test_debian_12.log
├── ... (más distros)
├── lab02_results.txt            # CSV con resultados Lab 02
├── lab02_pass1.log              # Log: Lab 02 pasada 1
├── lab02_pass2.log              # Log: Lab 02 pasada 2
├── lab03_results.txt
└── ... (más labs)

MATRIX.md                         # Actualizado con resultados (archivo de salida)
```

## ⚙️ Configuración (test_config.sh)

Parametrización centralizada — **no necesitas editar los scripts principales**, solo la config:

```bash
source test_config.sh

# Ver distros y labs habilitados
./test_config.sh

# Modificar qué distros/labs probar
# (editar ENABLED_DISTROS, ENABLED_LABS en test_config.sh)
```

### Distros Disponibles (cambiar en `test_config.sh`)

```bash
ENABLED_DISTROS=(
  ubuntu_2404         # Ubuntu 24.04 LTS
  ubuntu_2604         # Ubuntu 26.04 (latest)
  debian_12           # Debian 12 (Bookworm)
  debian_13           # Debian 13 (Trixie)
  rocky_9             # Rocky Linux 9
  rocky_10            # Rocky Linux 10
  fedora_40           # Fedora 40
  fedora_41           # Fedora 41
  opensuse_leap       # openSUSE Leap 16.0
  opensuse_tumbleweed # openSUSE Tumbleweed
)
```

### Labs Disponibles (cambiar en `test_config.sh`)

```bash
ENABLED_LABS=(
  01  # Mono-nodo Base
  02  # Multi-nodo HA (recomendado)
  03  # Longhorn
  04  # Rook Ceph
  05  # Ceph Externo
  06  # MetalLB + Ingress
  07  # Observabilidad
  08  # Gateway API
  09  # Actualización HA
  10  # Percona MySQL
  11  # MariaDB
  12  # PostgreSQL
  13  # MongoDB
  14  # Vault
)
```

## 📊 Criterios de Éxito

### Multidistro (`00_instalar_ansible.sh`)

Cada distro debe cumplir:
- ✅ `exit code: 0` (script termina sin error)
- ✅ `ansible-playbook` disponible en PATH
- ✅ `kubectl` instalado (binario oficial)
- ✅ `helm` instalado (binario oficial)
- ✅ Duración < 10 min (600s)

**Status**: `✅ PASS` si todos los criterios se cumplen

### Idempotencia de Labs (2 pasadas)

Para cada lab:
- ✅ **Pasada 1**: `exit 0` (cambios esperados)
- ✅ **Pasada 2**: `exit 0` + cambios ~= 0 (idempotencia confirmada)
- ✅ **Cleanup**: `exit 0` sin residuos en LXD

**Status**: `✅ VALIDATED` si ambas pasadas salen con exit 0 y cambios mínimos

## 🔄 Flujo de Ejecución Típico

```bash
# Día 1: Realizar cambios en labs (ej. actualizar versiones)
# ...cambios en group_vars/all.yml, playbooks, etc...

# Día 2: Ejecutar suite de pruebas
./test_matrix_runner.sh all

# Resultado: MATRIX.md se actualiza con:
# ✅ Resultados multidistro (tabla 10 distros)
# ✅ Resultados idempotencia (tabla N labs)
# ✅ Timeline de ejecución
# ✅ Problemas encontrados y soluciones

# Revisar MATRIX.md
cat MATRIX.md
```

## 📝 Agregar Nueva Prueba

### Agregar un lab nuevo

Editar `test_config.sh`:
```bash
LABS[15]="mi_nuevo_lab"
ENABLED_LABS+=(15)

# Marcar si tiene cambios en este ciclo
LABS_WITH_CHANGES[15]="variable1, variable2"
```

Luego ejecutar:
```bash
./test_matrix_runner.sh lab15
```

### Agregar una distro nueva

Editar `test_config.sh`:
```bash
DISTROS[debian_testing]="debian:testing"
ENABLED_DISTROS+=(debian_testing)
```

Luego ejecutar:
```bash
./test_matrix_runner.sh multidistro
```

### Agregar nuevas variables a trackear

Editar `test_config.sh`:
```bash
CHANGED_VARS[mi_nueva_variable]="valor"
```

## 🛠️ Troubleshooting

### Test se queda colgado
- Verificar timeouts en `test_matrix_runner.sh` (3600s para labs, 600s para distros)
- Revisar logs en `/tmp/test_matrix_*/`

### Distro X falla
- Verificar logs: `/tmp/test_matrix_*/test_DISTRO.log`
- Algunas distros pueden requerir setup adicional (ej. sudo, repos)

### Results no se escriben en MATRIX.md
- Verificar permisos: `chmod +w MATRIX.md`
- Verificar path: `ls -la MATRIX.md`
- Check OUTPUT_FILE variable: `echo $OUTPUT_FILE`

## 📚 Ejemplos Avanzados

### Ejecutar solo 2 distros para debug
```bash
# Editar test_config.sh
ENABLED_DISTROS=(ubuntu_2404 debian_12)

./test_matrix_runner.sh multidistro
```

### Revalidar solo los labs modificados en este ciclo
```bash
# En test_config.sh, cambios recientes están en LABS_WITH_CHANGES
# Ejecutar solo esos:
for lab in 02 03 04 06 08; do
  ./test_matrix_runner.sh lab$lab
done
```

### Guardar resultados con timestamp
```bash
OUTPUT_FILE="MATRIX_$(date +%Y%m%d_%H%M%S).md" ./test_matrix_runner.sh all
```

## 📌 Notas

- Los scripts son **idempotentes**: puedes ejecutarlos múltiples veces sin problemas
- Los logs se guardan automáticamente (no se pierden)
- MATRIX.md se actualiza (append), no se sobrescribe
- Requiere: bash, lxc, ansible-playbook, timeout
- Tiempo total estimado:
  - Multidistro (10 distros): ~50-60 min
  - Lab 02 (2 pasadas): ~60-90 min
  - Todo junto: ~120-150 min

---

## 📝 Changelog

### v2.0 (2026-08-09)
- **🔄 Cambio en estructura de logs**:
  - Antes: `/tmp/test_matrix_YYYYMMDD_HHMMSS/` (directorio temporal)
  - Ahora: `./logs/multidistro/` y `./logs/labs/` (persistent, similar a labs)
  - Nombres con timestamp: `YYYYMMDD_HHMMSS_tipo_nombre.log`
  - Evita sobrescrituras: cada ejecución es un archivo nuevo
  
- **➕ Nuevos archivos por ejecución**:
  - `YYYYMMDD_HHMMSS_results.csv` - Tabla de resultados
  - `YYYYMMDD_HHMMSS_summary.log` - Resumen rápido
  - `YYYYMMDD_HHMMSS_test_*.log` / `YYYYMMDD_HHMMSS_lab*_*.log` - Logs completos

### v1.0 (2026-08-09)
- Initial release: Framework parametrizado de pruebas

---

**Última actualización**: 2026-08-09
