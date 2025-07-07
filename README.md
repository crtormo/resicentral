# 🏢 ResiCentral - Sistema de Gestión de Residencias

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.68+-green.svg)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13+-blue.svg)](https://postgresql.org)

ResiCentral es una solución completa para la gestión de residencias, condominios y complejos habitacionales. Permite administrar residentes, visitantes, pagos, mantenimiento y comunicación de manera eficiente y segura.

## 🚀 Características Principales

- **👥 Gestión de Residentes**: Administración completa de propietarios e inquilinos
- **🚪 Control de Acceso**: Registro y control de visitantes y entregas
- **💰 Gestión de Pagos**: Administración de cuotas, pagos y facturación
- **🔧 Mantenimiento**: Solicitudes de mantenimiento y seguimiento
- **📱 Aplicación Móvil**: Apps nativas para iOS y Android
- **🌐 Aplicación Web**: PWA con soporte offline
- **📊 Reportes**: Estadísticas y reportes detallados
- **🔐 Seguridad**: Autenticación JWT y roles de usuario
- **📧 Comunicación**: Sistema de notificaciones y mensajería

## 🛠️ Tecnologías Utilizadas

### Backend
- **FastAPI** - Framework web moderno y rápido
- **PostgreSQL** - Base de datos relacional
- **Redis** - Cache y sesiones
- **MinIO** - Almacenamiento de archivos
- **SQLAlchemy** - ORM para Python
- **Alembic** - Migraciones de base de datos

### Frontend
- **Flutter** - Framework multiplataforma
- **Dart** - Lenguaje de programación
- **Provider** - Gestión de estado
- **HTTP** - Cliente HTTP
- **SharedPreferences** - Almacenamiento local

### Infraestructura
- **Docker** - Contenedorización
- **Nginx** - Proxy reverso y servidor web
- **Let's Encrypt** - Certificados SSL
- **Prometheus** - Monitoreo y métricas
- **Grafana** - Visualización de datos

## 📋 Requisitos del Sistema

### Desarrollo
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.30+
- Flutter 3.0+ (para desarrollo móvil)
- Python 3.11+ (para desarrollo backend)

### Producción
- Ubuntu 22.04 LTS
- 4GB RAM mínimo (8GB recomendado)
- 50GB SSD mínimo
- 2 CPU cores mínimo (4 recomendado)

## 🚀 Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-usuario/resicentral.git
cd resicentral
```

### 2. Configurar Variables de Entorno

```bash
# Copiar archivo de ejemplo
cp .env.production.example .env.production

# Editar variables de entorno
nano .env.production
```

### 3. Desarrollo Local

```bash
# Iniciar servicios de desarrollo
docker-compose up -d

# La aplicación estará disponible en:
# - Frontend: http://localhost:3000
# - Backend API: http://localhost:8000
# - Documentación API: http://localhost:8000/docs
```

### 4. Despliegue a Producción

```bash
# Ejecutar script de despliegue
chmod +x deploy.sh
./deploy.sh

# Configurar dominio y SSL
sudo certbot --nginx -d tudominio.com -d api.tudominio.com
```

## 📁 Estructura del Proyecto

```
resicentral/
├── backend/                 # API Backend (FastAPI)
│   ├── app/                # Código de la aplicación
│   ├── migrations/         # Migraciones de base de datos
│   ├── tests/              # Pruebas unitarias
│   └── Dockerfile.prod     # Dockerfile de producción
├── frontend/               # Frontend Web (Flutter)
│   ├── lib/                # Código de la aplicación
│   ├── web/                # Archivos web
│   ├── assets/             # Recursos estáticos
│   └── Dockerfile.prod     # Dockerfile de producción
├── mobile_app/             # Aplicación móvil (Flutter)
│   ├── lib/                # Código de la aplicación
│   ├── android/            # Configuración Android
│   └── ios/                # Configuración iOS
├── scripts/                # Scripts de utilidades
│   ├── backup.sh           # Script de backup
│   └── monitor.sh          # Script de monitoreo
├── .github/                # Configuración GitHub Actions
│   └── workflows/          # Workflows de CI/CD
├── docker-compose.yml      # Configuración desarrollo
├── docker-compose.prod.yml # Configuración producción
├── nginx.conf              # Configuración Nginx
├── deploy.sh               # Script de despliegue
└── DEPLOYMENT_GUIDE.md     # Guía de despliegue
```

## 🔧 Comandos Útiles

### Desarrollo
```bash
# Construir y ejecutar contenedores
docker-compose up --build

# Ver logs
docker-compose logs -f

# Ejecutar migraciones
docker-compose exec backend alembic upgrade head

# Ejecutar pruebas
docker-compose exec backend pytest

# Construir app Flutter
cd frontend && flutter build web
```

### Producción
```bash
# Desplegar aplicación
./deploy.sh

# Monitorear sistema
./scripts/monitor.sh

# Crear backup
./scripts/backup.sh

# Ver estado de servicios
docker-compose -f docker-compose.prod.yml ps
```

## 📊 Monitoreo y Logs

### Métricas
- **Grafana**: http://tudominio.com:3001
- **Prometheus**: http://tudominio.com:9090

### Logs
```bash
# Logs de aplicación
docker-compose logs -f backend frontend

# Logs de Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Logs del sistema
journalctl -u docker -f
```

## 🔒 Seguridad

- Autenticación JWT con refresh tokens
- Encriptación de contraseñas con bcrypt
- Headers de seguridad HTTP
- Rate limiting por IP
- Validación de datos de entrada
- Certificados SSL/TLS automáticos

## 📱 Aplicaciones Móviles

### Android
1. Construir APK: `flutter build apk --release`
2. Generar AAB: `flutter build appbundle --release`
3. Publicar en Google Play Store

### iOS
1. Construir para iOS: `flutter build ios --release`
2. Abrir en Xcode y archivar
3. Publicar en App Store

## 🧪 Testing

```bash
# Ejecutar pruebas del backend
docker-compose exec backend pytest

# Ejecutar pruebas del frontend
cd frontend && flutter test

# Ejecutar pruebas de integración
docker-compose exec backend pytest tests/integration/
```

## 📈 CI/CD

El proyecto incluye workflows de GitHub Actions para:
- Pruebas automatizadas
- Construcción de imágenes Docker
- Despliegue automático
- Análisis de código

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama feature: `git checkout -b feature/nueva-funcionalidad`
3. Commit tus cambios: `git commit -m 'Agregar nueva funcionalidad'`
4. Push a la rama: `git push origin feature/nueva-funcionalidad`
5. Crea un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 📞 Soporte

- **Email**: dev@resicentral.com
- **Documentación**: [Guía de Despliegue](DEPLOYMENT_GUIDE.md)
- **Issues**: [GitHub Issues](https://github.com/tu-usuario/resicentral/issues)

## 🚀 Roadmap

- [ ] Integración con servicios de pago (Stripe, PayPal)
- [ ] Sistema de notificaciones push
- [ ] Aplicación para porteros/seguridad
- [ ] Integración con IoT y domótica
- [ ] Módulo de reservas de espacios comunes
- [ ] Sistema de encuestas y votaciones
- [ ] Integración con servicios de delivery

---

**Desarrollado con ❤️ para la gestión eficiente de residencias**