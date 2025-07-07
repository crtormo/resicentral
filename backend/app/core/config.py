from pydantic_settings import BaseSettings
from typing import List
import os
import secrets
from dotenv import load_dotenv

load_dotenv()

def generate_secure_key() -> str:
    """Generate a secure random key for JWT if none is provided"""
    return secrets.token_urlsafe(32)

class Settings(BaseSettings):
    # Configuración de la aplicación
    app_name: str = os.getenv("APP_NAME", "ResiCentral")
    app_version: str = os.getenv("APP_VERSION", "1.0.0")
    debug: bool = os.getenv("DEBUG", "False").lower() == "true"
    
    # Configuración de la base de datos
    database_url: str = os.getenv("DATABASE_URL")
    
    # Configuración JWT
    jwt_secret_key: str = os.getenv("JWT_SECRET_KEY") or generate_secure_key()
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    jwt_access_token_expire_minutes: int = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    
    # Configuración de CORS
    cors_origins: List[str] = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")
    
    # Configuración de MinIO
    minio_endpoint: str = os.getenv("MINIO_ENDPOINT", "localhost:9000")
    minio_access_key: str = os.getenv("MINIO_ACCESS_KEY")
    minio_secret_key: str = os.getenv("MINIO_SECRET_KEY")
    minio_bucket_name: str = os.getenv("MINIO_BUCKET_NAME", "resicentral-files")
    minio_secure: bool = os.getenv("MINIO_SECURE", "False").lower() == "true"
    minio_documents_folder: str = os.getenv("MINIO_DOCUMENTS_FOLDER", "documents")
    minio_images_folder: str = os.getenv("MINIO_IMAGES_FOLDER", "clinical-images")
    minio_max_file_size: int = int(os.getenv("MINIO_MAX_FILE_SIZE", "104857600"))  # 100MB
    
    # Configuración de PostgreSQL
    postgres_db: str = os.getenv("POSTGRES_DB", "resicentral")
    postgres_user: str = os.getenv("POSTGRES_USER")
    postgres_password: str = os.getenv("POSTGRES_PASSWORD")
    postgres_host: str = os.getenv("POSTGRES_HOST", "localhost")
    postgres_port: int = int(os.getenv("POSTGRES_PORT", "5432"))
    
    # Configuración de AI
    ai_api_key: str = os.getenv("AI_API_KEY", "")
    ai_model: str = os.getenv("AI_MODEL", "gpt-3.5-turbo")
    ai_max_tokens: int = int(os.getenv("AI_MAX_TOKENS", "1000"))
    ai_temperature: float = float(os.getenv("AI_TEMPERATURE", "0.7"))
    
    def validate_required_env_vars(self):
        """Validate that required environment variables are set"""
        required_vars = {
            "DATABASE_URL": self.database_url,
            "MINIO_ACCESS_KEY": self.minio_access_key,
            "MINIO_SECRET_KEY": self.minio_secret_key,
            "POSTGRES_USER": self.postgres_user,
            "POSTGRES_PASSWORD": self.postgres_password,
        }
        
        missing_vars = [var for var, value in required_vars.items() if not value]
        if missing_vars:
            raise ValueError(f"Required environment variables are missing: {', '.join(missing_vars)}")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

# Instancia global de configuración
settings = Settings()

# Función para obtener la configuración
def get_settings() -> Settings:
    return settings