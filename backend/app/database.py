from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import os
from dotenv import load_dotenv

load_dotenv()

# URL de la base de datos
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://resicentral_user:resicentral_password@localhost:5432/resicentral")

# Crear el motor de la base de datos
engine = create_engine(
    DATABASE_URL,
    poolclass=StaticPool,
    pool_pre_ping=True,
    pool_recycle=300,
    echo=os.getenv("DEBUG", "False").lower() == "true"
)

# Crear la clase SessionLocal
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Crear la clase Base para los modelos
Base = declarative_base()

# Dependencia para obtener la sesión de la base de datos
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Función para crear las tablas
def create_tables():
    """Crear todas las tablas en la base de datos"""
    Base.metadata.create_all(bind=engine)

# Función para verificar la conexión
def check_database_connection():
    """Verificar que la conexión a la base de datos funciona"""
    try:
        with engine.connect() as connection:
            connection.execute("SELECT 1")
            return True
    except Exception as e:
        print(f"Error conectando a la base de datos: {e}")
        return False