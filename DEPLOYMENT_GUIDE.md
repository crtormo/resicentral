# 🚀 Guía Completa de Despliegue - ResiCentral

## Índice
1. [Requisitos del Sistema](#requisitos-del-sistema)
2. [Configuración del Servidor VPS](#configuración-del-servidor-vps)
3. [Despliegue Automatizado](#despliegue-automatizado)
4. [Configuración de Dominio y SSL](#configuración-de-dominio-y-ssl)
5. [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
6. [Publicación en Tiendas de Aplicaciones](#publicación-en-tiendas-de-aplicaciones)
7. [Solución de Problemas](#solución-de-problemas)

---

## 📋 Requisitos del Sistema

### Servidor VPS Mínimo
- **Sistema Operativo**: Ubuntu 22.04 LTS o superior
- **RAM**: 4GB mínimo, 8GB recomendado
- **Almacenamiento**: 50GB SSD mínimo
- **CPU**: 2 cores mínimo, 4 cores recomendado
- **Ancho de banda**: 1TB/mes mínimo

### Dependencias Requeridas
```bash
# Docker y Docker Compose
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker

# Nginx (proxy reverso)
sudo apt install -y nginx certbot python3-certbot-nginx

# Git
sudo apt install -y git curl wget

# Node.js (para herramientas de desarrollo)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

---

## 🛠️ Configuración del Servidor VPS

### 1. Configuración Inicial del Servidor

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Crear usuario para la aplicación
sudo useradd -m -s /bin/bash resicentral
sudo usermod -aG docker resicentral

# Configurar firewall
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Configurar swap (si es necesario)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. Configuración de Dominio

```bash
# Configurar DNS (en tu proveedor de dominio)
# Registro A: resicentral.com → IP_DEL_SERVIDOR
# Registro A: api.resicentral.com → IP_DEL_SERVIDOR
# Registro A: www.resicentral.com → IP_DEL_SERVIDOR
# Registro CNAME: *.resicentral.com → resicentral.com
```

### 3. Clonar Repositorio

```bash
# Cambiar al usuario de aplicación
sudo su - resicentral

# Clonar repositorio
git clone https://github.com/tu-usuario/resicentral.git
cd resicentral

# Configurar permisos
chmod +x deploy.sh
```

---

## 🚀 Despliegue Automatizado

### 1. Configuración de Variables de Entorno

Crear archivo `.env.production`:

```bash
# Base de datos
DATABASE_URL=postgresql://resicentral:tu_password_seguro@postgres:5432/resicentral_prod
POSTGRES_DB=resicentral_prod
POSTGRES_USER=resicentral
POSTGRES_PASSWORD=tu_password_seguro

# Redis
REDIS_URL=redis://redis:6379/0

# MinIO (almacenamiento de archivos)
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=tu_minio_password_seguro
MINIO_BUCKET_NAME=resicentral-prod

# API Backend
API_SECRET_KEY=tu_api_secret_key_muy_seguro
API_BASE_URL=https://api.resicentral.com
CORS_ORIGINS=https://resicentral.com,https://www.resicentral.com

# JWT
JWT_SECRET_KEY=tu_jwt_secret_key_muy_seguro
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30

# Email (configurar con tu proveedor)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=tu_email@gmail.com
SMTP_PASSWORD=tu_app_password

# Monitoreo
ENABLE_METRICS=true
ENABLE_MONITORING=true

# Ambiente
ENVIRONMENT=production
```

### 2. Ejecutar Despliegue

```bash
# Ejecutar script de despliegue
./deploy.sh

# El script automáticamente:
# - Hace backup de la base de datos
# - Actualiza el código desde Git
# - Construye las imágenes Docker
# - Ejecuta migraciones
# - Inicia los servicios
# - Verifica la salud de la aplicación
```

### 3. Verificar Despliegue

```bash
# Verificar servicios
docker-compose -f docker-compose.prod.yml ps

# Verificar logs
docker-compose -f docker-compose.prod.yml logs -f

# Verificar endpoints
curl -I https://api.resicentral.com/health
curl -I https://resicentral.com
```

---

## 🔐 Configuración de Dominio y SSL

### 1. Configurar Nginx como Proxy Reverso

```bash
# Copiar configuración de Nginx
sudo cp nginx.conf /etc/nginx/nginx.conf

# Crear configuración del sitio
sudo tee /etc/nginx/sites-available/resicentral << 'EOF'
server {
    listen 80;
    server_name resicentral.com www.resicentral.com api.resicentral.com;
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name resicentral.com www.resicentral.com;
    
    # Configuración SSL será agregada por Certbot
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl http2;
    server_name api.resicentral.com;
    
    # Configuración SSL será agregada por Certbot
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Habilitar sitio
sudo ln -s /etc/nginx/sites-available/resicentral /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 2. Configurar Certificados SSL

```bash
# Obtener certificados SSL con Let's Encrypt
sudo certbot --nginx -d resicentral.com -d www.resicentral.com -d api.resicentral.com

# Configurar renovación automática
sudo crontab -e
# Agregar línea:
0 12 * * * /usr/bin/certbot renew --quiet
```

---

## 📊 Monitoreo y Mantenimiento

### 1. Configurar Monitoreo

```bash
# Acceder a métricas
# Grafana: https://resicentral.com:3001
# Prometheus: https://resicentral.com:9090

# Credenciales por defecto:
# Usuario: admin
# Contraseña: admin (cambiar inmediatamente)
```

### 2. Backups Automáticos

```bash
# Crear script de backup
sudo tee /usr/local/bin/backup-resicentral.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backups/resicentral"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup base de datos
docker exec postgres pg_dump -U resicentral resicentral_prod > $BACKUP_DIR/db_backup_$DATE.sql

# Backup archivos
docker exec minio tar -czf /tmp/files_backup_$DATE.tar.gz /data
docker cp minio:/tmp/files_backup_$DATE.tar.gz $BACKUP_DIR/

# Limpiar backups antiguos (mantener 7 días)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/backup-resicentral.sh

# Configurar cron para backup diario
sudo crontab -e
# Agregar:
0 2 * * * /usr/local/bin/backup-resicentral.sh
```

### 3. Logs y Debugging

```bash
# Ver logs de aplicación
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f frontend

# Ver logs del sistema
sudo journalctl -u nginx -f
sudo journalctl -u docker -f

# Métricas del sistema
htop
df -h
free -h
```

---

## 📱 Publicación en Tiendas de Aplicaciones

### Google Play Store

#### 1. Preparación de la Aplicación

```bash
# Construir APK de release
cd mobile_app
flutter build apk --release

# Construir AAB (Android App Bundle) - recomendado
flutter build appbundle --release

# Los archivos se generan en:
# - build/app/outputs/flutter-apk/app-release.apk
# - build/app/outputs/bundle/release/app-release.aab
```

#### 2. Configuración de Firma Digital

```bash
# Generar keystore (hacer solo una vez)
keytool -genkey -v -keystore resicentral-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias resicentral

# Configurar android/key.properties
echo "storePassword=tu_password_seguro
keyPassword=tu_password_seguro
keyAlias=resicentral
storeFile=../resicentral-release-key.jks" > android/key.properties

# Configurar android/app/build.gradle
```

Agregar a `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### 3. Publicación en Google Play Console

1. **Crear cuenta de desarrollador**
   - Ir a [Google Play Console](https://play.google.com/console)
   - Pagar tarifa única de $25 USD
   - Completar información del desarrollador

2. **Crear nueva aplicación**
   - Nombre: "ResiCentral - Gestión de Residencias"
   - Categoría: "Productividad"
   - Idioma: Español

3. **Configurar información de la aplicación**
   ```
   Título: ResiCentral - Gestión de Residencias
   Descripción corta: Gestiona tu residencia de manera eficiente
   Descripción completa: 
   ResiCentral es la solución completa para la gestión de residencias y condominios. 
   Permite administrar residentes, visitantes, pagos, mantenimiento y comunicación 
   de manera eficiente y segura.
   
   Características:
   • Gestión de residentes y propiedades
   • Control de acceso y visitantes
   • Administración de pagos y cuotas
   • Mantenimiento y solicitudes
   • Comunicación con residentes
   • Reportes y estadísticas
   ```

4. **Subir assets gráficos**
   - Icono de aplicación: 512x512 px
   - Capturas de pantalla: 1080x1920 px (mínimo 2, máximo 8)
   - Gráfico de funciones: 1024x500 px
   - Icono de alta resolución: 512x512 px

5. **Configurar precios y distribución**
   - Aplicación gratuita
   - Países: México, España, Estados Unidos (expandir según necesidad)
   - Clasificación de contenido: Todos los públicos

6. **Subir APK/AAB**
   - Ir a "Administración de versiones" → "Versiones de la aplicación"
   - Crear nueva versión en "Producción"
   - Subir archivo AAB generado
   - Completar notas de la versión

### Apple App Store

#### 1. Preparación de la Aplicación iOS

```bash
# Construir para iOS
cd mobile_app
flutter build ios --release

# Abrir proyecto en Xcode
open ios/Runner.xcworkspace
```

#### 2. Configuración en Xcode

1. **Configurar equipo de desarrollo**
   - Seleccionar tu Apple Developer Account
   - Configurar Bundle Identifier: `com.resicentral.app`

2. **Configurar capacidades**
   - Push Notifications (si aplica)
   - In-App Purchase (si aplica)
   - Background Modes (si aplica)

3. **Configurar versión y build**
   - Version: 1.0.0
   - Build: 1

#### 3. Publicación en App Store Connect

1. **Crear cuenta de desarrollador**
   - Ir a [Apple Developer](https://developer.apple.com)
   - Pagar $99 USD anuales
   - Completar información del desarrollador

2. **Crear aplicación en App Store Connect**
   - Ir a [App Store Connect](https://appstoreconnect.apple.com)
   - Crear nueva aplicación
   - Bundle ID: com.resicentral.app
   - Nombre: "ResiCentral"

3. **Configurar información de la aplicación**
   ```
   Nombre: ResiCentral
   Subtítulo: Gestión de Residencias
   Descripción:
   ResiCentral es la solución completa para la gestión de residencias y condominios.
   
   Características principales:
   • Gestión eficiente de residentes
   • Control de acceso y visitantes
   • Administración de pagos
   • Mantenimiento y solicitudes
   • Comunicación integrada
   • Reportes detallados
   
   Ideal para administradores de condominios, residencias privadas y complejos habitacionales.
   ```

4. **Subir assets gráficos**
   - Icono de aplicación: 1024x1024 px
   - Capturas de pantalla iPhone: 1242x2688 px
   - Capturas de pantalla iPad: 2048x2732 px (si aplica)

5. **Configurar precios y disponibilidad**
   - Precio: Gratuito
   - Disponibilidad: México, España, Estados Unidos

6. **Subir build desde Xcode**
   - En Xcode: Product → Archive
   - Subir a App Store Connect
   - Esperar procesamiento (1-2 horas)

7. **Enviar para revisión**
   - Completar información para revisión
   - Notas para revisión de Apple
   - Enviar para revisión (proceso: 1-7 días)

### Progressive Web App (PWA)

#### 1. Configuración PWA

```bash
# Verificar que el manifest.json está configurado
# Archivo: frontend/web/manifest.json
{
  "name": "ResiCentral - Gestión de Residencias",
  "short_name": "ResiCentral",
  "description": "Gestiona tu residencia de manera eficiente",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#2196F3",
  "icons": [
    {
      "src": "icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

#### 2. Validar PWA

```bash
# Usar herramientas de validación
# 1. Chrome DevTools → Lighthouse → PWA
# 2. PWA Builder: https://www.pwabuilder.com
# 3. Verificar service worker y manifest
```

---

## 🔧 Solución de Problemas

### Problemas Comunes

#### 1. Error de Conexión a Base de Datos

```bash
# Verificar estado de PostgreSQL
docker-compose -f docker-compose.prod.yml ps postgres

# Ver logs
docker-compose -f docker-compose.prod.yml logs postgres

# Reiniciar servicio
docker-compose -f docker-compose.prod.yml restart postgres
```

#### 2. Certificado SSL Expirado

```bash
# Verificar certificados
sudo certbot certificates

# Renovar manualmente
sudo certbot renew --dry-run
sudo certbot renew

# Recargar Nginx
sudo systemctl reload nginx
```

#### 3. Aplicación No Responde

```bash
# Verificar estado de contenedores
docker-compose -f docker-compose.prod.yml ps

# Reiniciar aplicación
docker-compose -f docker-compose.prod.yml restart backend frontend

# Verificar recursos del sistema
htop
df -h
```

#### 4. Error en Despliegue

```bash
# Verificar logs de despliegue
tail -f /var/log/resicentral/deploy.log

# Hacer rollback
./deploy.sh rollback

# Verificar configuración
./deploy.sh check-config
```

### Comandos Útiles

```bash
# Monitoreo en tiempo real
watch -n 1 'docker-compose -f docker-compose.prod.yml ps'

# Backup manual
docker exec postgres pg_dump -U resicentral resicentral_prod > backup_$(date +%Y%m%d).sql

# Restaurar backup
docker exec -i postgres psql -U resicentral -d resicentral_prod < backup_20231215.sql

# Limpiar espacio en disco
docker system prune -a
docker volume prune

# Verificar configuración SSL
openssl s_client -connect resicentral.com:443

# Verificar rendimiento
curl -w "@curl-format.txt" -o /dev/null -s "https://resicentral.com"
```

---

## 📞 Soporte y Contacto

### Información de Contacto
- **Email**: dev@resicentral.com
- **Documentación**: https://docs.resicentral.com
- **Repository**: https://github.com/tu-usuario/resicentral

### Recursos Adicionales
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Flutter Documentation](https://flutter.dev/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

## 📝 Notas Importantes

1. **Seguridad**: Cambia todas las contraseñas por defecto antes de desplegar
2. **Backups**: Configura backups automáticos desde el primer día
3. **Monitoreo**: Configura alertas para eventos críticos
4. **Actualizaciones**: Mantén el sistema actualizado regularmente
5. **Documentación**: Mantén esta guía actualizada con cambios en el sistema

---

*Última actualización: $(date)*
*Versión: 1.0.0*