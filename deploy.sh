#!/bin/bash

# ResiCentral Production Deployment Script
# This script automates the deployment process for ResiCentral on VPS
# Usage: ./deploy.sh [environment] [options]

set -e  # Exit on any error

# Configuration
PROJECT_NAME="resicentral"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/${PROJECT_NAME}/deploy.log"
BACKUP_DIR="/opt/backups/${PROJECT_NAME}"
DEPLOY_USER="resicentral"
DOMAIN="api.resicentral.com"
WEB_DOMAIN="resicentral.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
SKIP_BACKUP=false
SKIP_TESTS=false
FORCE_REBUILD=false
DRY_RUN=false
VERBOSE=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to show help
show_help() {
    cat << EOF
ResiCentral Deployment Script

Usage: $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    production      Deploy to production environment (default)
    staging         Deploy to staging environment
    development     Deploy to development environment

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -d, --dry-run       Show what would be done without executing
    -f, --force         Force rebuild of all containers
    --skip-backup       Skip database backup
    --skip-tests        Skip running tests before deployment
    --rollback          Rollback to previous version

EXAMPLES:
    $0                           # Deploy to production
    $0 staging                   # Deploy to staging
    $0 production --force        # Force rebuild in production
    $0 --dry-run                 # Show deployment steps without executing

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            production|staging|development)
                ENVIRONMENT="$1"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_REBUILD=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --rollback)
                rollback_deployment
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"
    
    # Check if running as correct user
    if [[ "$(whoami)" != "$DEPLOY_USER" && "$(whoami)" != "root" ]]; then
        print_error "This script must be run as $DEPLOY_USER or root"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("docker" "docker-compose" "git" "nginx" "certbot")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
        print_status "✓ $cmd is available"
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    print_status "✓ Docker daemon is running"
    
    # Check disk space (at least 2GB free)
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 2097152 ]]; then
        print_warning "Low disk space: $(( free_space / 1024 / 1024 ))GB free"
    fi
    
    print_status "Prerequisites check completed"
}

# Function to setup environment
setup_environment() {
    print_step "Setting Up Environment: $ENVIRONMENT"
    
    # Create necessary directories
    sudo mkdir -p /var/log/$PROJECT_NAME
    sudo mkdir -p $BACKUP_DIR
    sudo mkdir -p /opt/$PROJECT_NAME/ssl
    sudo mkdir -p /opt/$PROJECT_NAME/data
    
    # Set proper permissions
    sudo chown -R $DEPLOY_USER:$DEPLOY_USER /opt/$PROJECT_NAME
    sudo chown -R $DEPLOY_USER:$DEPLOY_USER /var/log/$PROJECT_NAME
    sudo chown -R $DEPLOY_USER:$DEPLOY_USER $BACKUP_DIR
    
    # Create environment file
    create_environment_file
    
    print_status "Environment setup completed"
}

# Function to create environment file
create_environment_file() {
    local env_file=".env.${ENVIRONMENT}"
    
    if [[ ! -f "$env_file" ]]; then
        print_status "Creating environment file: $env_file"
        
        case $ENVIRONMENT in
            production)
                cat > "$env_file" << EOF
# Production Environment Configuration
ENVIRONMENT=production
DEBUG=False

# Database Configuration
DATABASE_URL=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}
POSTGRES_DB=resicentral_prod
POSTGRES_USER=resicentral_prod
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# JWT Configuration
JWT_SECRET_KEY=${JWT_SECRET_KEY:-$(openssl rand -base64 64)}
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440

# CORS Configuration
CORS_ORIGINS=https://$WEB_DOMAIN,https://app.$WEB_DOMAIN

# MinIO Configuration
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-$(openssl rand -hex 20)}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-$(openssl rand -base64 32)}
MINIO_BUCKET_NAME=resicentral-prod
MINIO_SECURE=False
MINIO_DOCUMENTS_FOLDER=documents
MINIO_IMAGES_FOLDER=clinical-images
MINIO_MAX_FILE_SIZE=104857600

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=\${EMAIL_USER}
SMTP_PASSWORD=\${EMAIL_PASSWORD}
FROM_EMAIL=noreply@$DOMAIN

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Logging
LOG_LEVEL=INFO
LOG_DIR=/var/log/$PROJECT_NAME

# API Configuration
API_V1_STR=/api/v1
PROJECT_NAME=ResiCentral
PROJECT_VERSION=1.0.0

# Security
ALLOWED_HOSTS=$DOMAIN,$WEB_DOMAIN,localhost
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
EOF
                ;;
            staging)
                cat > "$env_file" << EOF
# Staging Environment Configuration
ENVIRONMENT=staging
DEBUG=True

# Database Configuration
DATABASE_URL=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}
POSTGRES_DB=resicentral_staging
POSTGRES_USER=resicentral_staging
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}

# JWT Configuration
JWT_SECRET_KEY=${JWT_SECRET_KEY:-$(openssl rand -base64 64)}
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=120

# CORS Configuration
CORS_ORIGINS=https://staging.$WEB_DOMAIN,http://localhost:3000

# Other configurations similar to production but with staging values
EOF
                ;;
        esac
        
        print_status "Environment file created"
    else
        print_status "Environment file already exists"
    fi
}

# Function to backup database
backup_database() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        print_warning "Skipping database backup"
        return 0
    fi
    
    print_step "Creating Database Backup"
    
    local backup_file="$BACKUP_DIR/db_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would create backup at $backup_file"
        return 0
    fi
    
    # Create backup using docker-compose
    if docker-compose -f docker-compose.prod.yml exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_file"; then
        print_status "Database backup created: $backup_file"
        
        # Compress backup
        gzip "$backup_file"
        print_status "Backup compressed: ${backup_file}.gz"
        
        # Keep only last 7 days of backups
        find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime +7 -delete
        
        log_message "Database backup created successfully"
    else
        print_error "Failed to create database backup"
        exit 1
    fi
}

# Function to update source code
update_source_code() {
    print_step "Updating Source Code"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would pull latest code from git"
        return 0
    fi
    
    # Stash any local changes
    if git status --porcelain | grep -q .; then
        print_warning "Local changes detected, stashing them"
        git stash
    fi
    
    # Pull latest code
    print_status "Pulling latest code from repository"
    if git pull origin main; then
        print_status "Source code updated successfully"
        log_message "Source code updated from git"
    else
        print_error "Failed to update source code"
        exit 1
    fi
    
    # Update submodules if any
    if [[ -f ".gitmodules" ]]; then
        print_status "Updating git submodules"
        git submodule update --init --recursive
    fi
}

# Function to run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        print_warning "Skipping tests"
        return 0
    fi
    
    print_step "Running Tests"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would run test suites"
        return 0
    fi
    
    # Run backend tests
    print_status "Running backend tests"
    cd backend
    if python -m pytest tests/ --tb=short -q; then
        print_status "✓ Backend tests passed"
    else
        print_error "Backend tests failed"
        exit 1
    fi
    cd ..
    
    # Build and test containers
    print_status "Testing container builds"
    if docker-compose -f docker-compose.prod.yml build --no-cache backend; then
        print_status "✓ Backend container builds successfully"
    else
        print_error "Backend container build failed"
        exit 1
    fi
    
    log_message "All tests passed"
}

# Function to build and deploy containers
deploy_containers() {
    print_step "Deploying Containers"
    
    local compose_file="docker-compose.prod.yml"
    local compose_command="docker-compose -f $compose_file"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would build and deploy containers"
        return 0
    fi
    
    # Load environment variables
    export $(cat .env.${ENVIRONMENT} | xargs)
    
    # Pull latest images
    print_status "Pulling latest base images"
    $compose_command pull
    
    # Build containers
    if [[ "$FORCE_REBUILD" == "true" ]]; then
        print_status "Force rebuilding all containers"
        $compose_command build --no-cache
    else
        print_status "Building containers"
        $compose_command build
    fi
    
    # Stop existing containers gracefully
    print_status "Stopping existing containers"
    $compose_command down --timeout 30
    
    # Start new containers
    print_status "Starting new containers"
    $compose_command up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready"
    sleep 30
    
    # Health check
    if health_check; then
        print_status "✓ Deployment successful"
        log_message "Deployment completed successfully"
    else
        print_error "Health check failed"
        rollback_deployment
        exit 1
    fi
}

# Function to run health checks
health_check() {
    print_step "Running Health Checks"
    
    local retries=0
    local max_retries=10
    
    while [[ $retries -lt $max_retries ]]; do
        # Check backend API
        if curl -f -s "http://localhost:8000/health" > /dev/null; then
            print_status "✓ Backend API is healthy"
            break
        else
            print_warning "Backend API not ready, retrying... ($((retries + 1))/$max_retries)"
            sleep 10
            retries=$((retries + 1))
        fi
    done
    
    if [[ $retries -eq $max_retries ]]; then
        print_error "Backend API health check failed"
        return 1
    fi
    
    # Check database connection
    if docker-compose -f docker-compose.prod.yml exec -T postgres pg_isready -U "$POSTGRES_USER" > /dev/null; then
        print_status "✓ Database is healthy"
    else
        print_error "Database health check failed"
        return 1
    fi
    
    # Check MinIO
    if curl -f -s "http://localhost:9000/minio/health/live" > /dev/null; then
        print_status "✓ MinIO is healthy"
    else
        print_error "MinIO health check failed"
        return 1
    fi
    
    return 0
}

# Function to update Nginx configuration
update_nginx() {
    print_step "Updating Nginx Configuration"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would update Nginx configuration"
        return 0
    fi
    
    # Copy Nginx configuration
    sudo cp nginx.conf /etc/nginx/sites-available/$PROJECT_NAME
    sudo ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
    
    # Test Nginx configuration
    if sudo nginx -t; then
        print_status "✓ Nginx configuration is valid"
        
        # Reload Nginx
        sudo systemctl reload nginx
        print_status "✓ Nginx reloaded"
        log_message "Nginx configuration updated"
    else
        print_error "Invalid Nginx configuration"
        exit 1
    fi
}

# Function to setup SSL certificates
setup_ssl() {
    print_step "Setting Up SSL Certificates"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would setup SSL certificates"
        return 0
    fi
    
    # Check if certificates already exist
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        print_status "SSL certificates already exist"
        
        # Try to renew certificates
        if sudo certbot renew --quiet; then
            print_status "SSL certificates renewed"
        fi
    else
        print_status "Obtaining new SSL certificates"
        
        # Stop Nginx temporarily
        sudo systemctl stop nginx
        
        # Obtain certificates
        if sudo certbot certonly --standalone -d "$DOMAIN" -d "$WEB_DOMAIN" --email "admin@$DOMAIN" --agree-tos --non-interactive; then
            print_status "✓ SSL certificates obtained"
        else
            print_error "Failed to obtain SSL certificates"
            sudo systemctl start nginx
            exit 1
        fi
        
        # Start Nginx
        sudo systemctl start nginx
    fi
    
    log_message "SSL certificates setup completed"
}

# Function to cleanup old resources
cleanup() {
    print_step "Cleaning Up"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would cleanup old resources"
        return 0
    fi
    
    # Remove unused Docker images
    print_status "Removing unused Docker images"
    docker image prune -f
    
    # Remove old log files
    print_status "Rotating log files"
    find /var/log/$PROJECT_NAME -name "*.log" -mtime +30 -delete
    
    # Remove old backups (keep last 30 days)
    print_status "Cleaning old backups"
    find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete
    
    log_message "Cleanup completed"
}

# Function to rollback deployment
rollback_deployment() {
    print_step "Rolling Back Deployment"
    
    print_warning "Rolling back to previous version"
    
    # Get previous git commit
    local previous_commit=$(git log --oneline -n 2 | tail -1 | cut -d' ' -f1)
    
    if [[ -n "$previous_commit" ]]; then
        print_status "Rolling back to commit: $previous_commit"
        git checkout "$previous_commit"
        
        # Rebuild and restart containers
        docker-compose -f docker-compose.prod.yml down
        docker-compose -f docker-compose.prod.yml up -d --build
        
        print_status "Rollback completed"
        log_message "Rollback to $previous_commit completed"
    else
        print_error "Could not find previous commit for rollback"
        exit 1
    fi
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚀 ResiCentral Deployment [$ENVIRONMENT]: $status - $message\"}" \
            "$SLACK_WEBHOOK_URL" 2>/dev/null || true
    fi
    
    # Log notification
    log_message "Notification sent: $status - $message"
}

# Main deployment function
main() {
    print_step "Starting ResiCentral Deployment"
    print_status "Environment: $ENVIRONMENT"
    print_status "Timestamp: $(date)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    # Create log entry
    log_message "Deployment started for environment: $ENVIRONMENT"
    
    # Send start notification
    send_notification "STARTED" "Deployment process initiated"
    
    # Execute deployment steps
    check_prerequisites
    setup_environment
    update_source_code
    run_tests
    backup_database
    deploy_containers
    update_nginx
    setup_ssl
    cleanup
    
    # Final health check
    if health_check; then
        print_step "Deployment Completed Successfully"
        print_status "🎉 ResiCentral is now running on $ENVIRONMENT environment"
        print_status "API URL: https://$DOMAIN"
        print_status "Web URL: https://$WEB_DOMAIN"
        
        send_notification "SUCCESS" "Deployment completed successfully"
        log_message "Deployment completed successfully"
    else
        print_error "Final health check failed"
        send_notification "FAILED" "Deployment health check failed"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi