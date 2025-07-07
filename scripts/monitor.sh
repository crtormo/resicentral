#!/bin/bash

# Script de Monitoreo para ResiCentral
# Supervisa el estado de los servicios y envía alertas

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Función para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Configuración
COMPOSE_FILE="docker-compose.prod.yml"
ALERT_EMAIL=${ADMIN_EMAIL:-"admin@resicentral.com"}
WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}
LOG_FILE="/var/log/resicentral/monitor.log"

# Umbrales de alerta
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
RESPONSE_TIME_THRESHOLD=5000 # ms

# Crear directorio de logs si no existe
mkdir -p $(dirname $LOG_FILE)

# Función para registrar en log
log_to_file() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Función para enviar alerta por email
send_email_alert() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log_info "📧 Alerta enviada por email"
    fi
}

# Función para enviar alerta por Slack
send_slack_alert() {
    local message="$1"
    local color="$2"
    
    if [ -n "$WEBHOOK_URL" ]; then
        local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "ResiCentral - Alerta de Monitoreo",
            "text": "$message",
            "footer": "Monitor ResiCentral",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
        
        if curl -X POST -H 'Content-type: application/json' \
           --data "$payload" "$WEBHOOK_URL" &>/dev/null; then
            log_info "💬 Alerta enviada por Slack"
        else
            log_warn "⚠️ No se pudo enviar alerta por Slack"
        fi
    fi
}

# Función para verificar servicios Docker
check_docker_services() {
    log_step "Verificando servicios Docker"
    local issues=0
    
    # Lista de servicios críticos
    local services=("postgres" "redis" "minio" "backend" "frontend" "nginx")
    
    for service in "${services[@]}"; do
        if docker-compose -f $COMPOSE_FILE ps $service | grep -q "Up"; then
            log_info "✅ $service: Ejecutándose"
        else
            log_error "❌ $service: No está ejecutándose"
            issues=$((issues + 1))
            
            # Intentar reiniciar el servicio
            log_step "Intentando reiniciar $service"
            if docker-compose -f $COMPOSE_FILE restart $service; then
                log_info "✅ $service reiniciado exitosamente"
                send_slack_alert "Servicio $service reiniciado automáticamente" "warning"
            else
                log_error "❌ No se pudo reiniciar $service"
                send_email_alert "🚨 Error crítico en $service" "El servicio $service no pudo ser reiniciado automáticamente"
                send_slack_alert "Error crítico: $service no pudo ser reiniciado" "danger"
            fi
        fi
    done
    
    log_to_file "Docker Services Check - Issues: $issues"
    return $issues
}

# Función para verificar conectividad HTTP
check_http_endpoints() {
    log_step "Verificando endpoints HTTP"
    local issues=0
    
    # Endpoints a verificar
    local endpoints=(
        "https://resicentral.com:Frontend"
        "https://api.resicentral.com/health:API Backend"
        "https://api.resicentral.com/docs:API Documentation"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        local endpoint=$(echo $endpoint_info | cut -d: -f1)
        local name=$(echo $endpoint_info | cut -d: -f2)
        
        local start_time=$(date +%s%3N)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" || echo "000")
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        if [ "$http_code" = "200" ]; then
            log_info "✅ $name: HTTP $http_code (${response_time}ms)"
            
            # Verificar tiempo de respuesta
            if [ $response_time -gt $RESPONSE_TIME_THRESHOLD ]; then
                log_warn "⚠️ $name: Tiempo de respuesta alto (${response_time}ms)"
                send_slack_alert "$name tiene tiempo de respuesta alto: ${response_time}ms" "warning"
            fi
        else
            log_error "❌ $name: HTTP $http_code"
            issues=$((issues + 1))
            send_email_alert "🚨 Error HTTP en $name" "El endpoint $endpoint devolvió código $http_code"
            send_slack_alert "Error HTTP en $name: código $http_code" "danger"
        fi
    done
    
    log_to_file "HTTP Endpoints Check - Issues: $issues"
    return $issues
}

# Función para verificar base de datos
check_database() {
    log_step "Verificando base de datos"
    local issues=0
    
    # Verificar conectividad a PostgreSQL
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -U resicentral &>/dev/null; then
        log_info "✅ PostgreSQL: Conectividad OK"
        
        # Verificar número de conexiones
        local connections=$(docker-compose -f $COMPOSE_FILE exec -T postgres psql -U resicentral -d resicentral_prod -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
        
        if [ -n "$connections" ] && [ "$connections" -gt 0 ]; then
            log_info "✅ PostgreSQL: $connections conexiones activas"
            
            # Alerta si hay muchas conexiones
            if [ "$connections" -gt 50 ]; then
                log_warn "⚠️ PostgreSQL: Alto número de conexiones ($connections)"
                send_slack_alert "PostgreSQL tiene un alto número de conexiones: $connections" "warning"
            fi
        else
            log_warn "⚠️ PostgreSQL: No se pudieron obtener estadísticas de conexiones"
        fi
    else
        log_error "❌ PostgreSQL: No responde"
        issues=$((issues + 1))
        send_email_alert "🚨 Error en PostgreSQL" "La base de datos no responde"
        send_slack_alert "Error: PostgreSQL no responde" "danger"
    fi
    
    # Verificar Redis
    if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping &>/dev/null; then
        log_info "✅ Redis: Conectividad OK"
    else
        log_error "❌ Redis: No responde"
        issues=$((issues + 1))
        send_email_alert "🚨 Error en Redis" "Redis no responde"
        send_slack_alert "Error: Redis no responde" "danger"
    fi
    
    log_to_file "Database Check - Issues: $issues"
    return $issues
}

# Función para verificar uso de recursos
check_system_resources() {
    log_step "Verificando recursos del sistema"
    local issues=0
    
    # Verificar uso de CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        log_warn "⚠️ CPU: ${cpu_usage}% (umbral: ${CPU_THRESHOLD}%)"
        send_slack_alert "Alto uso de CPU: ${cpu_usage}%" "warning"
        issues=$((issues + 1))
    else
        log_info "✅ CPU: ${cpu_usage}%"
    fi
    
    # Verificar uso de memoria
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        log_warn "⚠️ Memoria: ${memory_usage}% (umbral: ${MEMORY_THRESHOLD}%)"
        send_slack_alert "Alto uso de memoria: ${memory_usage}%" "warning"
        issues=$((issues + 1))
    else
        log_info "✅ Memoria: ${memory_usage}%"
    fi
    
    # Verificar uso de disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        log_warn "⚠️ Disco: ${disk_usage}% (umbral: ${DISK_THRESHOLD}%)"
        send_slack_alert "Alto uso de disco: ${disk_usage}%" "warning"
        issues=$((issues + 1))
    else
        log_info "✅ Disco: ${disk_usage}%"
    fi
    
    # Verificar carga del sistema
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    local cpu_cores=$(nproc)
    local load_threshold=$((cpu_cores * 2))
    
    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        log_warn "⚠️ Carga del sistema: $load_avg (umbral: $load_threshold)"
        send_slack_alert "Alta carga del sistema: $load_avg" "warning"
        issues=$((issues + 1))
    else
        log_info "✅ Carga del sistema: $load_avg"
    fi
    
    log_to_file "System Resources Check - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%, Load: $load_avg"
    return $issues
}

# Función para verificar logs de errores
check_error_logs() {
    log_step "Verificando logs de errores"
    local issues=0
    
    # Verificar logs de aplicación (últimos 5 minutos)
    local recent_errors=$(docker-compose -f $COMPOSE_FILE logs --since="5m" 2>&1 | grep -i "error\|exception\|failed\|critical" | wc -l)
    
    if [ "$recent_errors" -gt 10 ]; then
        log_warn "⚠️ $recent_errors errores recientes en logs"
        send_slack_alert "Alto número de errores en logs: $recent_errors en los últimos 5 minutos" "warning"
        issues=$((issues + 1))
    else
        log_info "✅ Logs: $recent_errors errores recientes"
    fi
    
    # Verificar logs de Nginx
    if [ -f "/var/log/nginx/error.log" ]; then
        local nginx_errors=$(tail -100 /var/log/nginx/error.log | grep "$(date +%Y/%m/%d)" | wc -l)
        if [ "$nginx_errors" -gt 5 ]; then
            log_warn "⚠️ $nginx_errors errores de Nginx hoy"
            send_slack_alert "Errores de Nginx: $nginx_errors errores hoy" "warning"
            issues=$((issues + 1))
        else
            log_info "✅ Nginx: $nginx_errors errores hoy"
        fi
    fi
    
    log_to_file "Error Logs Check - App errors: $recent_errors, Nginx errors: ${nginx_errors:-0}"
    return $issues
}

# Función para verificar certificados SSL
check_ssl_certificates() {
    log_step "Verificando certificados SSL"
    local issues=0
    
    local domains=("resicentral.com" "api.resicentral.com" "www.resicentral.com")
    
    for domain in "${domains[@]}"; do
        local expiry_date=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        
        if [ -n "$expiry_date" ]; then
            local expiry_timestamp=$(date -d "$expiry_date" +%s)
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [ $days_until_expiry -lt 7 ]; then
                log_error "❌ $domain: Certificado expira en $days_until_expiry días"
                send_email_alert "🚨 Certificado SSL próximo a expirar" "El certificado de $domain expira en $days_until_expiry días"
                send_slack_alert "Certificado SSL de $domain expira en $days_until_expiry días" "danger"
                issues=$((issues + 1))
            elif [ $days_until_expiry -lt 30 ]; then
                log_warn "⚠️ $domain: Certificado expira en $days_until_expiry días"
                send_slack_alert "Certificado SSL de $domain expira en $days_until_expiry días" "warning"
            else
                log_info "✅ $domain: Certificado válido por $days_until_expiry días"
            fi
        else
            log_error "❌ $domain: No se pudo verificar certificado"
            issues=$((issues + 1))
        fi
    done
    
    log_to_file "SSL Certificates Check - Issues: $issues"
    return $issues
}

# Función para generar reporte de estado
generate_status_report() {
    log_step "Generando reporte de estado"
    
    local report_file="/tmp/resicentral_status_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > $report_file << EOF
REPORTE DE ESTADO - RESICENTRAL
===============================

Fecha: $(date)
Servidor: $(hostname)
Uptime: $(uptime)

SERVICIOS DOCKER:
$(docker-compose -f $COMPOSE_FILE ps 2>/dev/null || echo "No se pudo obtener estado")

RECURSOS DEL SISTEMA:
- CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)%
- Memoria: $(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')%
- Disco: $(df / | tail -1 | awk '{print $5}')
- Carga: $(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)

CONECTIVIDAD:
$(for endpoint in "https://resicentral.com" "https://api.resicentral.com/health"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" || echo "000")
    echo "- $endpoint: HTTP $code"
done)

LOGS RECIENTES:
$(docker-compose -f $COMPOSE_FILE logs --tail=10 2>/dev/null | tail -20 || echo "No se pudieron obtener logs")

EOF

    log_info "📊 Reporte generado: $report_file"
    
    # Enviar reporte por email si hay problemas críticos
    if [ -f "$report_file" ]; then
        # Contar líneas con errores
        local critical_issues=$(grep -c "❌\|Error\|Failed\|Critical" "$report_file" 2>/dev/null || echo "0")
        
        if [ "$critical_issues" -gt 0 ]; then
            send_email_alert "🚨 Reporte de Estado ResiCentral - $critical_issues problemas críticos" "$(cat $report_file)"
        fi
    fi
}

# Función para auto-reparación
auto_repair() {
    log_step "Intentando auto-reparación"
    
    # Limpiar logs grandes
    find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;
    
    # Limpiar archivos temporales de Docker
    docker system prune -f --volumes &>/dev/null || true
    
    # Reiniciar servicios que no responden
    local services=("postgres" "redis" "minio" "backend" "frontend")
    for service in "${services[@]}"; do
        if ! docker-compose -f $COMPOSE_FILE ps $service | grep -q "Up"; then
            log_step "Reiniciando $service"
            docker-compose -f $COMPOSE_FILE restart $service
        fi
    done
    
    log_info "✅ Auto-reparación completada"
}

# Función principal
main() {
    log_info "🔍 Iniciando monitoreo de ResiCentral"
    log_to_file "Monitor started"
    
    local total_issues=0
    
    # Ejecutar verificaciones
    check_docker_services || total_issues=$((total_issues + $?))
    check_http_endpoints || total_issues=$((total_issues + $?))
    check_database || total_issues=$((total_issues + $?))
    check_system_resources || total_issues=$((total_issues + $?))
    check_error_logs || total_issues=$((total_issues + $?))
    check_ssl_certificates || total_issues=$((total_issues + $?))
    
    # Generar reporte
    generate_status_report
    
    # Auto-reparación si hay problemas
    if [ $total_issues -gt 0 ]; then
        log_warn "⚠️ Detectados $total_issues problemas, iniciando auto-reparación"
        auto_repair
    fi
    
    # Resumen final
    if [ $total_issues -eq 0 ]; then
        log_info "✅ Monitoreo completado - Sistema saludable"
        log_to_file "Monitor completed - Status: OK"
    else
        log_warn "⚠️ Monitoreo completado - $total_issues problemas detectados"
        log_to_file "Monitor completed - Status: $total_issues issues"
    fi
}

# Manejo de argumentos
case "${1:-main}" in
    "main")
        main
        ;;
    "services")
        check_docker_services
        ;;
    "http")
        check_http_endpoints
        ;;
    "database")
        check_database
        ;;
    "resources")
        check_system_resources
        ;;
    "logs")
        check_error_logs
        ;;
    "ssl")
        check_ssl_certificates
        ;;
    "repair")
        auto_repair
        ;;
    "report")
        generate_status_report
        ;;
    "help")
        echo "Uso: $0 [main|services|http|database|resources|logs|ssl|repair|report|help]"
        echo ""
        echo "Opciones:"
        echo "  main      - Ejecutar monitoreo completo (por defecto)"
        echo "  services  - Verificar servicios Docker"
        echo "  http      - Verificar endpoints HTTP"
        echo "  database  - Verificar base de datos"
        echo "  resources - Verificar recursos del sistema"
        echo "  logs      - Verificar logs de errores"
        echo "  ssl       - Verificar certificados SSL"
        echo "  repair    - Ejecutar auto-reparación"
        echo "  report    - Generar reporte de estado"
        echo "  help      - Mostrar esta ayuda"
        ;;
    *)
        log_error "Argumento inválido: $1"
        echo "Usa '$0 help' para ver opciones disponibles"
        exit 1
        ;;
esac