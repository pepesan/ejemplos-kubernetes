#!/bin/bash
cd /home/pepesan/IdeaProjects/ejemplos-kubernetes/ansible/base

labs=(01 03 04 05 06 08)

cleanup_lab() {
  local lab_num="$1"
  echo ""
  echo "🧹 Limpiando Lab $lab_num..."

  lab_dir=$(ls -d ${lab_num}_* 2>/dev/null | head -1)

  if [ -z "$lab_dir" ]; then
    return 0
  fi

  if [ -f "$lab_dir/destroy_all.sh" ]; then
    (cd "$lab_dir" && timeout 300 ./destroy_all.sh > /dev/null 2>&1) || true
    echo "✅ Lab $lab_num limpiado"
  else
    # Fallback para Lab 01: limpiar manualmente
    for vm in $(lxc list -cn --format=json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4); do
      lxc stop "$vm" 2>/dev/null || true
      lxc delete "$vm" 2>/dev/null || true
    done
    echo "✅ Lab $lab_num limpiado (manual)"
  fi
}

for lab in "${labs[@]}"; do
  echo ""
  echo "════════════════════════════════════"
  echo "Iniciando Lab $lab - $(date)"
  echo "════════════════════════════════════"

  ./test_matrix_runner.sh lab$lab > logs/lab${lab}_runner.log 2>&1

  if [ $? -eq 0 ]; then
    echo "✅ Lab $lab completado exitosamente"
  else
    echo "❌ Lab $lab falló"
  fi

  echo "Completado: $(date)"

  # Limpiar VMs después de cada lab
  cleanup_lab "$lab"
done

echo ""
echo "════════════════════════════════════"
echo "✅ TODAS LAS REVALIDACIONES COMPLETADAS"
echo "════════════════════════════════════"
