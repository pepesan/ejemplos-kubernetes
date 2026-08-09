#!/bin/bash

echo "╔════════════════════════════════════════════════╗"
echo "║        📊 MONITOR DE PROGRESO EN VIVO           ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Monitor por 120 minutos
for i in {1..120}; do
  clear
  
  echo "⏱️  PROGRESO - $(date '+%H:%M:%S')"
  echo "════════════════════════════════════════════════"
  echo ""
  
  # Lab 02
  echo "🧪 Lab 02 (Base HA - 2 pasadas):"
  if [ -f "logs/lab02_runner.log" ]; then
    lines=$(wc -l < logs/lab02_runner.log)
    
    if grep -q "exit code 0" logs/lab02_runner.log 2>/dev/null; then
      echo "   ✅ Pasada 1: COMPLETADA"
    elif grep -q "Exit: 0" logs/lab02_runner.log 2>/dev/null; then
      echo "   ⏳ Pasada 1: EN PROGRESO"
    else
      echo "   🔄 INICIANDO..."
    fi
    
    if grep -q "Exit code pasada 2" logs/lab02_runner.log 2>/dev/null; then
      echo "   ✅ Pasada 2: COMPLETADA"
    elif grep -q "Pasada 2:" logs/lab02_runner.log 2>/dev/null; then
      echo "   ⏳ Pasada 2: EN PROGRESO"
    fi
    
    if grep -q "RESULTADO FINAL\|IDEMPOTENCIA CONFIRMADA" logs/lab02_runner.log 2>/dev/null; then
      echo "   ✅ Estado: COMPLETADO"
    else
      echo "   Líneas de log: $lines"
    fi
  fi
  
  echo ""
  
  # Multidistro
  echo "🌍 Multidistro (5 distros × 2 versiones):"
  if [ -f "logs/multidistro_runner.log" ]; then
    lines=$(wc -l < logs/multidistro_runner.log)
    
    if grep -q "Resultados multidistro" logs/multidistro_runner.log 2>/dev/null; then
      echo "   ✅ Estado: COMPLETADO"
    elif [ "$lines" -gt 10 ]; then
      echo "   ⏳ EN PROGRESO (líneas: $lines)"
    else
      echo "   🔄 INICIANDO..."
    fi
  fi
  
  echo ""
  echo "════════════════════════════════════════════════"
  echo "Logs en vivo:"
  echo "  tail -f logs/lab02_runner.log"
  echo "  tail -f logs/multidistro_runner.log"
  echo ""
  echo "Presiona Ctrl+C para detener el monitor"
  echo "Próxima actualización en 30 segundos..."
  
  sleep 30
done

echo ""
echo "✅ Monitor completado. Revisar MATRIX.md para resultados finales."

