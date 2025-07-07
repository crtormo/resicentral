#!/bin/bash

# Script de inicio para ResiCentral Backend
# Maneja la inicialización, migraciones y inicio del servidor

set -e  # Salir en cualquier error

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

# Configuración por defecto
ENVIRONMENT=${ENVIRONMENT:-production}
WORKERS=${WORKERS:-4}
MAX_WORKERS=${MAX_WORKERS:-8}
TIMEOUT=${TIMEOUT:-30}
KEEP_ALIVE=${KEEP_ALIVE:-2}
PORT=${PORT:-8000}
HOST=${HOST:-0.0.0.0}

log_info "🚀 Iniciando ResiCentral Backend"
log_info "Entorno: $ENVIRONMENT"
log_info "Workers: $WORKERS"
log_info "Puerto: $PORT"

# Crear directorios necesarios
log_step "Creando directorios necesarios"
mkdir -p /app/logs /app/uploads /app/temp /app/static

# Verificar conectividad a base de datos
log_step "Verificando conexión a base de datos"
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if python -c "
import psycopg2
import os
import sys
try:
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    conn.close()
    print('Conexión a base de datos exitosa')
    sys.exit(0)
except Exception as e:
    print(f'Error de conexión: {e}')
    sys.exit(1)
"; then
        log_info "✅ Conexión a base de datos establecida"
        break
    else
        log_warn "Intento $attempt/$max_attempts - Esperando base de datos..."
        sleep 2
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    log_error "❌ No se pudo conectar a la base de datos después de $max_attempts intentos"
    exit 1
fi

# Verificar conectividad a Redis
log_step "Verificando conexión a Redis"
if python -c "
import redis
import os
try:
    r = redis.Redis.from_url(os.environ.get('REDIS_URL', 'redis://redis:6379/0'))
    r.ping()
    print('Conexión a Redis exitosa')
except Exception as e:
    print(f'Error de conexión a Redis: {e}')
    exit(1)
"; then
    log_info "✅ Conexión a Redis establecida"
else
    log_warn "⚠️ No se pudo conectar a Redis, continuando sin cache"
fi

# Ejecutar migraciones de base de datos
log_step "Ejecutando migraciones de base de datos"
if python -c "
from app.database import engine, Base
from app.models import *
try:
    Base.metadata.create_all(bind=engine)
    print('Migraciones ejecutadas correctamente')
except Exception as e:
    print(f'Error en migraciones: {e}')
    exit(1)
"; then
    log_info "✅ Migraciones de base de datos completadas"
else
    log_error "❌ Error ejecutando migraciones"
    exit 1
fi

# Inicializar datos iniciales si es necesario
log_step "Verificando datos iniciales"
if [ "$ENVIRONMENT" = "production" ]; then
    python -c "
from app import crud
from app.database import get_db
from app.models import User
try:
    db = next(get_db())
    admin_count = db.query(User).filter(User.is_superuser == True).count()
    if admin_count == 0:
        print('Creando usuario administrador inicial...')
        # Crear usuario admin inicial aquí si es necesario
    db.close()
except Exception as e:
    print(f'Error verificando datos iniciales: {e}')
"
fi

# Verificar configuración de MinIO
log_step "Verificando configuración de MinIO"
python -c "
from app.minio_client import minio_client
try:
    if minio_client.bucket_exists('resicentral-prod'):
        print('Bucket de MinIO existe')
    else:
        print('Creando bucket de MinIO...')
        minio_client.make_bucket('resicentral-prod')
        print('Bucket creado correctamente')
except Exception as e:
    print(f'Error configurando MinIO: {e}')
"

# Configurar logs
log_step "Configurando sistema de logs"
cat > /app/logging.conf << EOF
[loggers]
keys=root,gunicorn.error,gunicorn.access,uvicorn.error,uvicorn.access

[handlers]
keys=console,error_file,access_file

[formatters]
keys=generic,access

[logger_root]
level=INFO
handlers=console

[logger_gunicorn.error]
level=INFO
handlers=error_file
propagate=1
qualname=gunicorn.error

[logger_gunicorn.access]
level=INFO
handlers=access_file
propagate=0
qualname=gunicorn.access

[logger_uvicorn.error]
level=INFO
handlers=error_file
propagate=1
qualname=uvicorn.error

[logger_uvicorn.access]
level=INFO
handlers=access_file
propagate=0
qualname=uvicorn.access

[handler_console]
class=StreamHandler
formatter=generic
args=(sys.stdout, )

[handler_error_file]
class=logging.handlers.RotatingFileHandler
formatter=generic
args=('/app/logs/error.log', 'a', 10485760, 5)

[handler_access_file]
class=logging.handlers.RotatingFileHandler
formatter=access
args=('/app/logs/access.log', 'a', 10485760, 5)

[formatter_generic]
format=%(asctime)s [%(process)d] [%(levelname)s] %(message)s
datefmt=%Y-%m-%d %H:%M:%S
class=logging.Formatter

[formatter_access]
format=%(message)s
class=logging.Formatter
EOF

# Configurar Prometheus para métricas (si está habilitado)
if [ "${ENABLE_METRICS:-false}" = "true" ]; then
    log_step "Configurando métricas de Prometheus"
    export PROMETHEUS_MULTIPROC_DIR=/app/temp/prometheus
    mkdir -p $PROMETHEUS_MULTIPROC_DIR
    rm -rf $PROMETHEUS_MULTIPROC_DIR/*
fi

# Verificar salud de la aplicación antes de inicio completo
log_step "Verificando configuración de la aplicación"
if python -c "
from app.main import app
from app.core.config import settings
try:
    print(f'Aplicación: {settings.app_name}')
    print(f'Versión: {settings.app_version}')
    print(f'Entorno: {settings.environment}')
    print('Configuración verificada correctamente')
except Exception as e:
    print(f'Error en configuración: {e}')
    exit(1)
"; then
    log_info "✅ Configuración de aplicación verificada"
else
    log_error "❌ Error en configuración de aplicación"
    exit 1
fi

# Configurar variables de entorno adicionales para Gunicorn
export PYTHONPATH="/app:$PYTHONPATH"

# Comando de inicio según el entorno
if [ "$ENVIRONMENT" = "development" ]; then
    log_step "Iniciando en modo desarrollo"
    exec uvicorn app.main:app \
        --host $HOST \
        --port $PORT \
        --reload \
        --log-level debug \
        --access-log \
        --log-config /app/logging.conf
elif [ "$ENVIRONMENT" = "testing" ]; then
    log_step "Iniciando en modo testing"
    exec uvicorn app.main:app \
        --host $HOST \
        --port $PORT \
        --log-level info \
        --log-config /app/logging.conf
else
    log_step "Iniciando en modo producción con Gunicorn"
    
    # Validar configuración de Gunicorn
    if [ ! -f "/app/gunicorn.conf.py" ]; then
        log_error "❌ Archivo de configuración de Gunicorn no encontrado"
        exit 1
    fi
    
    # Iniciar servidor de producción
    exec gunicorn app.main:app \
        --config /app/gunicorn.conf.py \
        --bind $HOST:$PORT \
        --workers $WORKERS \
        --worker-class uvicorn.workers.UvicornWorker \
        --timeout $TIMEOUT \
        --keep-alive $KEEP_ALIVE \
        --max-requests 1000 \
        --max-requests-jitter 100 \
        --preload \
        --log-config /app/logging.conf
fi