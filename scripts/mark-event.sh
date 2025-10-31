#!/bin/bash

# Script para marcar eventos no sistema CRDT
# Uso: ./mark-event.sh "Texto do evento"

# Verificar se foi passado um argumento
if [ $# -eq 0 ]; then
    echo "❌ Uso: $0 \"Texto do evento\""
    exit 1
fi

EVENT_TEXT="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="event.log"

# Anexar timestamp + evento ao arquivo de log
echo "[$TIMESTAMP] $EVENT_TEXT" >> "$LOG_FILE"

# Enviar evento como métrica customizada para o dashboard (opcional)
# Isso cria uma métrica gauge temporária que pode ser útil para marcar eventos no Grafana
if command -v curl &> /dev/null; then
    # Enviar como métrica Prometheus customizada
    METRIC_DATA="# TYPE crdt_event gauge
crdt_event{event=\"$EVENT_TEXT\",timestamp=\"$TIMESTAMP\"} 1
"
    curl -X POST -H "Content-Type: text/plain" \
         --data "$METRIC_DATA" \
         http://localhost:3000/metrics 2>/dev/null || \
    echo "⚠️  Não foi possível enviar métrica para o dashboard (serviço pode não estar rodando)"
fi

echo "✅ Evento marcado: [$TIMESTAMP] $EVENT_TEXT"