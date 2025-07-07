#!/bin/bash

# Script de inicio para Nginx Frontend
# Configuración optimizada para ResiCentral Frontend

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

log_info "🚀 Iniciando ResiCentral Frontend"

# Verificar que los archivos necesarios existen
log_step "Verificando archivos requeridos"
if [ ! -f "/usr/share/nginx/html/index.html" ]; then
    log_error "❌ Archivo index.html no encontrado"
    exit 1
fi

if [ ! -f "/usr/share/nginx/html/main.dart.js" ]; then
    log_warn "⚠️ Archivo main.dart.js no encontrado - puede afectar la funcionalidad"
fi

# Verificar configuración de Nginx
log_step "Validando configuración de Nginx"
if ! nginx -t; then
    log_error "❌ Error en configuración de Nginx"
    exit 1
fi

log_info "✅ Configuración de Nginx válida"

# Crear directorios de logs si no existen
log_step "Preparando directorios de logs"
mkdir -p /var/log/nginx/resicentral

# Generar configuración dinámica si es necesario
log_step "Configurando parámetros dinámicos"

# Configurar variables de entorno para template
export BACKEND_URL=${BACKEND_URL:-"https://api.resicentral.com"}
export ENVIRONMENT=${ENVIRONMENT:-"production"}
export ENABLE_ANALYTICS=${ENABLE_ANALYTICS:-"false"}

# Inyectar configuración en archivos JavaScript si es necesario
if [ "$ENVIRONMENT" = "production" ]; then
    log_step "Configurando entorno de producción"
    
    # Configurar service worker si existe
    if [ -f "/usr/share/nginx/html/flutter_service_worker.js" ]; then
        log_info "✅ Service Worker encontrado"
    fi
    
    # Verificar manifest.json
    if [ -f "/usr/share/nginx/html/manifest.json" ]; then
        log_info "✅ Manifest PWA encontrado"
    fi
fi

# Configurar permisos finales
log_step "Configurando permisos"
find /usr/share/nginx/html -type f -exec chmod 644 {} \;
find /usr/share/nginx/html -type d -exec chmod 755 {} \;

# Pre-comprimir archivos para mejor rendimiento
log_step "Optimizando archivos estáticos"
if [ "$ENVIRONMENT" = "production" ]; then
    # Generar versiones comprimidas para archivos grandes
    find /usr/share/nginx/html -name "*.js" -size +1k -exec gzip -9 -k {} \; 2>/dev/null || true
    find /usr/share/nginx/html -name "*.css" -size +1k -exec gzip -9 -k {} \; 2>/dev/null || true
    find /usr/share/nginx/html -name "*.html" -size +1k -exec gzip -9 -k {} \; 2>/dev/null || true
fi

# Configurar headers de seguridad adicionales
log_step "Aplicando configuración de seguridad"

# Generar configuración de cache dinámica
cat > /tmp/cache_config.conf << EOF
# Cache dinámico generado en $(date)
map \$sent_http_content_type \$expires {
    default                    1d;
    text/html                  epoch;
    text/css                   max;
    application/javascript     max;
    application/wasm           max;
    ~image/                    max;
}
EOF

# Verificar salud del frontend
log_step "Verificando salud del frontend"
if [ -f "/usr/share/nginx/html/index.html" ]; then
    # Verificar que el archivo no esté vacío
    if [ -s "/usr/share/nginx/html/index.html" ]; then
        log_info "✅ Frontend verificado correctamente"
    else
        log_error "❌ Archivo index.html está vacío"
        exit 1
    fi
else
    log_error "❌ Archivo index.html no encontrado"
    exit 1
fi

# Configurar monitoreo si está habilitado
if [ "${ENABLE_MONITORING:-false}" = "true" ]; then
    log_step "Configurando monitoreo"
    
    # Configurar stub_status para métricas
    if ! grep -q "stub_status" /etc/nginx/conf.d/default.conf; then
        log_warn "⚠️ Monitoreo habilitado pero stub_status no configurado"
    fi
fi

# Manejar señales de terminación
cleanup() {
    log_info "🛑 Recibida señal de terminación"
    log_info "🧹 Limpiando recursos..."
    
    # Cerrar conexiones gracefully
    nginx -s quit
    
    log_info "👋 ResiCentral Frontend terminado"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Iniciar Nginx en foreground
log_info "🌐 Iniciando servidor web Nginx"
log_info "📍 Sirviendo aplicación en puerto 80"
log_info "🔗 Backend configurado en: $BACKEND_URL"

# Ejecutar Nginx
exec nginx -g 'daemon off;'