# Configuración de Gunicorn para ResiCentral Backend
# Optimizado para producción con alto rendimiento y seguridad

import multiprocessing
import os

# Configuración del servidor
bind = "0.0.0.0:8000"
backlog = 2048

# Configuración de workers
workers = int(os.environ.get("WORKERS", multiprocessing.cpu_count() * 2 + 1))
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
preload_app = True
timeout = int(os.environ.get("TIMEOUT", 30))
keepalive = int(os.environ.get("KEEP_ALIVE", 2))

# Configuración de memoria y recursos
worker_tmp_dir = "/dev/shm"
max_worker_memory = 1024 * 1024 * 512  # 512MB por worker

# Configuración de logs
accesslog = "/app/logs/gunicorn_access.log"
errorlog = "/app/logs/gunicorn_error.log"
loglevel = os.environ.get("LOG_LEVEL", "info").lower()
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Configuración de seguridad
limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190

# Configuración del proceso
user = "appuser"
group = "appgroup"
tmp_upload_dir = "/app/temp"
secure_scheme_headers = {
    'X-FORWARDED-PROTOCOL': 'ssl',
    'X-FORWARDED-PROTO': 'https',
    'X-FORWARDED-SSL': 'on'
}
forwarded_allow_ips = '*'

# Configuración de SSL (si se usa SSL termination en Gunicorn)
# keyfile = "/app/ssl/private.key"
# certfile = "/app/ssl/certificate.crt"

# Hooks del proceso
def on_starting(server):
    """Se ejecuta cuando Gunicorn inicia"""
    server.log.info("🚀 Iniciando ResiCentral API Backend")

def on_reload(server):
    """Se ejecuta cuando se recarga la configuración"""
    server.log.info("🔄 Recargando configuración del servidor")

def when_ready(server):
    """Se ejecuta cuando el servidor está listo"""
    server.log.info("✅ ResiCentral API Backend listo para recibir conexiones")

def worker_int(worker):
    """Se ejecuta cuando un worker recibe SIGINT o SIGQUIT"""
    worker.log.info("🛑 Worker %s interrumpido por usuario", worker.pid)

def pre_fork(server, worker):
    """Se ejecuta antes de hacer fork de un worker"""
    server.log.info("👷 Iniciando worker %s", worker.pid)

def post_fork(server, worker):
    """Se ejecuta después de hacer fork de un worker"""
    server.log.info("✅ Worker %s iniciado correctamente", worker.pid)

def post_worker_init(worker):
    """Se ejecuta después de inicializar un worker"""
    worker.log.info("🔧 Worker %s inicializado", worker.pid)

def worker_abort(worker):
    """Se ejecuta cuando un worker se aborta"""
    worker.log.error("💥 Worker %s abortado", worker.pid)

def pre_exec(server):
    """Se ejecuta antes de ejecutar la aplicación"""
    server.log.info("🎬 Ejecutando aplicación ResiCentral")

def pre_request(worker, req):
    """Se ejecuta antes de procesar cada request"""
    # Log para requests de alta prioridad o debug
    if req.path.startswith('/health'):
        return
    worker.log.debug("%s %s", req.method, req.path)

def post_request(worker, req, environ, resp):
    """Se ejecuta después de procesar cada request"""
    # Log de respuestas de error
    if resp.status_code >= 400:
        worker.log.warning("Error %s: %s %s", resp.status_code, req.method, req.path)

# Configuración adicional para desarrollo/debug
if os.environ.get("ENVIRONMENT") == "development":
    reload = True
    reload_extra_files = [
        "/app/app",
    ]
    loglevel = "debug"
    
# Configuración de Prometheus para métricas
if os.environ.get("ENABLE_METRICS", "false").lower() == "true":
    def child_exit(server, worker):
        """Se ejecuta cuando un worker termina"""
        from prometheus_client import CollectorRegistry, multiprocess, generate_latest
        registry = CollectorRegistry()
        multiprocess.MultiProcessCollector(registry)

# Configuración de memoria compartida para cache
if os.environ.get("ENABLE_SHARED_CACHE", "false").lower() == "true":
    def on_starting(server):
        import redis
        import pickle
        
        # Configurar cache compartido Redis
        redis_client = redis.Redis(
            host=os.environ.get("REDIS_HOST", "redis"),
            port=int(os.environ.get("REDIS_PORT", 6379)),
            db=int(os.environ.get("REDIS_DB", 0))
        )
        
        # Guardar cliente en memoria compartida
        server.redis_client = redis_client
        server.log.info("🔄 Cache Redis configurado")

# Configuración de rate limiting
def pre_request(worker, req):
    """Rate limiting por IP"""
    import time
    from collections import defaultdict
    
    # Simple rate limiting en memoria (para producción usar Redis)
    if not hasattr(worker, 'rate_limit_cache'):
        worker.rate_limit_cache = defaultdict(list)
    
    client_ip = req.environ.get('HTTP_X_FORWARDED_FOR', req.environ.get('REMOTE_ADDR'))
    current_time = time.time()
    
    # Limpiar entradas antiguas (últimos 60 segundos)
    worker.rate_limit_cache[client_ip] = [
        timestamp for timestamp in worker.rate_limit_cache[client_ip]
        if current_time - timestamp < 60
    ]
    
    # Verificar límite (100 requests por minuto por IP)
    if len(worker.rate_limit_cache[client_ip]) >= 100:
        worker.log.warning("Rate limit excedido para IP: %s", client_ip)
        # En producción, retornar 429 Too Many Requests
    
    # Agregar timestamp actual
    worker.rate_limit_cache[client_ip].append(current_time)