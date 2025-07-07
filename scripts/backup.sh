#!/bin/bash

# Script de Backup para ResiCentral
# Realiza backup completo de base de datos y archivos

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
BACKUP_DIR="/backups/resicentral"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
S3_BUCKET=${BACKUP_S3_BUCKET:-""}
COMPOSE_FILE="docker-compose.prod.yml"

# Crear directorio de backup
mkdir -p $BACKUP_DIR

log_info "🗄️ Iniciando backup completo de ResiCentral"
log_info "📅 Fecha: $(date)"
log_info "📁 Directorio: $BACKUP_DIR"

# Función para verificar que los servicios están ejecutándose
check_services() {
    log_step "Verificando servicios"
    
    if ! docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        log_error "❌ Los servicios no están ejecutándose"
        return 1
    fi
    
    log_info "✅ Servicios verificados"
}

# Función para backup de base de datos
backup_database() {
    log_step "Respaldando base de datos PostgreSQL"
    
    local db_backup_file="$BACKUP_DIR/database_backup_$DATE.sql"
    local db_backup_compressed="$BACKUP_DIR/database_backup_$DATE.sql.gz"
    
    # Crear backup de la base de datos
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_dump -U resicentral resicentral_prod > $db_backup_file; then
        log_info "✅ Backup de base de datos creado: $db_backup_file"
        
        # Comprimir backup
        if gzip $db_backup_file; then
            log_info "✅ Backup comprimido: $db_backup_compressed"
        else
            log_warn "⚠️ No se pudo comprimir el backup de base de datos"
        fi
    else
        log_error "❌ Error creando backup de base de datos"
        return 1
    fi
}

# Función para backup de archivos MinIO
backup_minio() {
    log_step "Respaldando archivos de MinIO"
    
    local minio_backup_file="$BACKUP_DIR/minio_backup_$DATE.tar.gz"
    
    # Crear backup de archivos MinIO
    if docker-compose -f $COMPOSE_FILE exec -T minio sh -c "tar -czf /tmp/minio_backup.tar.gz -C /data ." && \
       docker-compose -f $COMPOSE_FILE exec -T minio sh -c "cat /tmp/minio_backup.tar.gz" > $minio_backup_file; then
        log_info "✅ Backup de archivos MinIO creado: $minio_backup_file"
        
        # Limpiar archivo temporal en contenedor
        docker-compose -f $COMPOSE_FILE exec -T minio rm -f /tmp/minio_backup.tar.gz
    else
        log_error "❌ Error creando backup de archivos MinIO"
        return 1
    fi
}

# Función para backup de configuración
backup_config() {
    log_step "Respaldando configuración"
    
    local config_backup_file="$BACKUP_DIR/config_backup_$DATE.tar.gz"
    
    # Crear backup de archivos de configuración
    if tar -czf $config_backup_file \
        --exclude='*.log' \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='build' \
        --exclude='dist' \
        .env.production nginx.conf docker-compose.prod.yml deploy.sh 2>/dev/null; then
        log_info "✅ Backup de configuración creado: $config_backup_file"
    else
        log_warn "⚠️ Algunos archivos de configuración no pudieron ser respaldados"
    fi
}

# Función para backup de logs
backup_logs() {
    log_step "Respaldando logs"
    
    local logs_backup_file="$BACKUP_DIR/logs_backup_$DATE.tar.gz"
    
    # Crear backup de logs
    if docker-compose -f $COMPOSE_FILE exec -T backend sh -c "tar -czf /tmp/logs_backup.tar.gz -C /app/logs ." && \
       docker-compose -f $COMPOSE_FILE exec -T backend sh -c "cat /tmp/logs_backup.tar.gz" > $logs_backup_file; then
        log_info "✅ Backup de logs creado: $logs_backup_file"
        
        # Limpiar archivo temporal en contenedor
        docker-compose -f $COMPOSE_FILE exec -T backend rm -f /tmp/logs_backup.tar.gz
    else
        log_warn "⚠️ No se pudo crear backup de logs"
    fi
}

# Función para subir a S3 (opcional)
upload_to_s3() {
    if [ -z "$S3_BUCKET" ]; then
        log_info "ℹ️ S3 no configurado, saltando subida a la nube"
        return 0
    fi
    
    log_step "Subiendo backups a S3"
    
    # Verificar que aws cli está instalado
    if ! command -v aws &> /dev/null; then
        log_warn "⚠️ AWS CLI no está instalado, no se puede subir a S3"
        return 1
    fi
    
    # Subir archivos a S3
    for file in $BACKUP_DIR/*_$DATE.*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            if aws s3 cp "$file" "s3://$S3_BUCKET/resicentral/$filename"; then
                log_info "✅ Subido a S3: $filename"
            else
                log_error "❌ Error subiendo a S3: $filename"
            fi
        fi
    done
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log_step "Limpiando backups antiguos (>${RETENTION_DAYS} días)"
    
    # Limpiar backups locales antiguos
    find $BACKUP_DIR -name "*_backup_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Limpiar backups de S3 antiguos (si está configurado)
    if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
        log_step "Limpiando backups antiguos en S3"
        
        # Listar y eliminar archivos antiguos en S3
        local cutoff_date=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d)
        
        aws s3 ls "s3://$S3_BUCKET/resicentral/" | while read -r line; do
            local file_date=$(echo "$line" | grep -o '[0-9]\{8\}_[0-9]\{6\}' | head -1 | cut -d'_' -f1)
            if [ -n "$file_date" ] && [ "$file_date" -lt "$cutoff_date" ]; then
                local filename=$(echo "$line" | awk '{print $4}')
                if aws s3 rm "s3://$S3_BUCKET/resicentral/$filename"; then
                    log_info "🗑️ Eliminado de S3: $filename"
                fi
            fi
        done
    fi
    
    log_info "✅ Limpieza completada"
}

# Función para verificar integridad del backup
verify_backup() {
    log_step "Verificando integridad del backup"
    
    local errors=0
    
    # Verificar que los archivos existen y no están vacíos
    for file in $BACKUP_DIR/*_$DATE.*; do
        if [ -f "$file" ]; then
            if [ -s "$file" ]; then
                log_info "✅ Verificado: $(basename "$file")"
            else
                log_error "❌ Archivo vacío: $(basename "$file")"
                errors=$((errors + 1))
            fi
        fi
    done
    
    # Verificar backup de base de datos
    local db_backup=$(find $BACKUP_DIR -name "database_backup_$DATE.sql.gz" -o -name "database_backup_$DATE.sql")
    if [ -n "$db_backup" ]; then
        if file "$db_backup" | grep -q "gzip\|SQL"; then
            log_info "✅ Backup de base de datos verificado"
        else
            log_error "❌ Backup de base de datos corrupto"
            errors=$((errors + 1))
        fi
    fi
    
    return $errors
}

# Función para crear reporte de backup
create_backup_report() {
    log_step "Creando reporte de backup"
    
    local report_file="$BACKUP_DIR/backup_report_$DATE.txt"
    
    cat > $report_file << EOF
REPORTE DE BACKUP - RESICENTRAL
================================

Fecha: $(date)
Servidor: $(hostname)
Usuario: $(whoami)

ARCHIVOS CREADOS:
$(ls -lh $BACKUP_DIR/*_$DATE.* 2>/dev/null || echo "No se encontraron archivos de backup")

ESTADO DE SERVICIOS:
$(docker-compose -f $COMPOSE_FILE ps 2>/dev/null || echo "No se pudo obtener estado de servicios")

ESPACIO EN DISCO:
$(df -h | grep -E "(Filesystem|/)")

MEMORIA:
$(free -h)

CONFIGURACIÓN:
- Retención: $RETENTION_DAYS días
- S3 Bucket: ${S3_BUCKET:-"No configurado"}
- Directorio: $BACKUP_DIR

PRÓXIMO BACKUP PROGRAMADO:
$(crontab -l 2>/dev/null | grep backup || echo "No hay backup programado")

EOF

    log_info "✅ Reporte creado: $report_file"
}

# Función para enviar notificación (opcional)
send_notification() {
    local status=$1
    local message=$2
    
    # Enviar notificación por email si está configurado
    if [ -n "$SMTP_USERNAME" ] && [ -n "$SMTP_PASSWORD" ]; then
        log_step "Enviando notificación por email"
        
        local subject
        if [ "$status" = "success" ]; then
            subject="✅ Backup ResiCentral Exitoso - $(date)"
        else
            subject="❌ Backup ResiCentral Fallido - $(date)"
        fi
        
        # Usar sendmail o mail si está disponible
        if command -v mail &> /dev/null; then
            echo "$message" | mail -s "$subject" "${ADMIN_EMAIL:-admin@resicentral.com}"
            log_info "✅ Notificación enviada"
        else
            log_warn "⚠️ No se pudo enviar notificación (mail no disponible)"
        fi
    fi
}

# Función principal
main() {
    local start_time=$(date +%s)
    local errors=0
    
    log_info "🚀 Iniciando proceso de backup"
    
    # Verificar servicios
    if ! check_services; then
        log_error "❌ No se pueden realizar backups - servicios no disponibles"
        exit 1
    fi
    
    # Realizar backups
    backup_database || errors=$((errors + 1))
    backup_minio || errors=$((errors + 1))
    backup_config || errors=$((errors + 1))
    backup_logs || errors=$((errors + 1))
    
    # Verificar integridad
    verify_backup || errors=$((errors + 1))
    
    # Subir a S3 si está configurado
    upload_to_s3 || log_warn "⚠️ Error en subida a S3"
    
    # Limpiar backups antiguos
    cleanup_old_backups
    
    # Crear reporte
    create_backup_report
    
    # Calcular tiempo total
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $errors -eq 0 ]; then
        log_info "✅ Backup completado exitosamente en ${duration}s"
        log_info "📊 Archivos creados: $(ls -1 $BACKUP_DIR/*_$DATE.* | wc -l)"
        log_info "💾 Espacio utilizado: $(du -sh $BACKUP_DIR | cut -f1)"
        
        send_notification "success" "Backup completado exitosamente en ${duration}s"
    else
        log_error "❌ Backup completado con $errors errores en ${duration}s"
        send_notification "error" "Backup completado con $errors errores en ${duration}s"
        exit 1
    fi
}

# Manejo de argumentos
case "${1:-main}" in
    "main")
        main
        ;;
    "database")
        check_services && backup_database
        ;;
    "files")
        check_services && backup_minio
        ;;
    "config")
        backup_config
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "verify")
        verify_backup
        ;;
    "help")
        echo "Uso: $0 [main|database|files|config|cleanup|verify|help]"
        echo ""
        echo "Opciones:"
        echo "  main     - Ejecutar backup completo (por defecto)"
        echo "  database - Solo backup de base de datos"
        echo "  files    - Solo backup de archivos"
        echo "  config   - Solo backup de configuración"
        echo "  cleanup  - Limpiar backups antiguos"
        echo "  verify   - Verificar integridad del último backup"
        echo "  help     - Mostrar esta ayuda"
        ;;
    *)
        log_error "Argumento inválido: $1"
        echo "Usa '$0 help' para ver opciones disponibles"
        exit 1
        ;;
esac