from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.security import HTTPBearer
from sqlalchemy.orm import Session
from datetime import timedelta
import uvicorn
import os
import io
from typing import Optional
from dotenv import load_dotenv

# Importar módulos locales
from .core.config import settings
from .core.logging_config import setup_logging, get_logger, security_logger
from .database import get_db, create_tables, check_database_connection

# Configure logging
setup_logging()
logger = get_logger(__name__)
from .models import User, Document, ClinicalImage, Drug, Procedure, Algorithm, AlgorithmNode, AlgorithmEdge, Shift
from .schemas import (
    UserCreate, UserResponse, UserUpdate, UserChangePassword,
    LoginRequest, LoginResponse, Token, Message, ErrorResponse,
    DocumentCreate, DocumentResponse, DocumentWithOwnerResponse,
    DocumentUpdate, DocumentStats, DocumentSearchResponse,
    DocumentDownload, FileInfo, ClinicalImageCreate, ClinicalImageResponse,
    ClinicalImageWithOwnerResponse, ClinicalImageUpdate, ClinicalImageStats,
    ClinicalImageSearchResponse, ClinicalImageUrl, ClinicalImageUpload,
    DrugCreate, DrugResponse, DrugUpdate, DrugSearchResponse,
    CalculatorResult, CURB65Request, WellsPERequest, GlasgowComaRequest,
    CHADS2VAScRequest, CalculatorInfo
)
from .security import (
    authenticate_user, get_current_user, get_current_active_user,
    get_current_verified_user, get_current_superuser,
    create_access_token, get_password_hash, verify_password
)
from .minio_client import (
    upload_document, download_document, get_document_download_url,
    delete_document, document_exists, minio_client,
    upload_clinical_image, download_clinical_image, get_clinical_image_url,
    delete_clinical_image, clinical_image_exists
)
from . import crud
from .clinical_modules.calculators import (
    calculate_curb65, calculate_wells_pe, calculate_glasgow_coma_scale,
    calculate_chads2_vasc, get_available_calculators
)

# Cargar variables de entorno
load_dotenv()

# Crear instancia de FastAPI
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Sistema de gestión residencial integral",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Evento de inicio de la aplicación
@app.on_event("startup")
async def startup_event():
    """Crear tablas y verificar conexión en el inicio"""
    try:
        # Validate required environment variables
        settings.validate_required_env_vars()
        logger.info("Environment variables validated successfully")
        
        # Check database connection
        if not check_database_connection():
            logger.error("Failed to connect to database")
            raise Exception("No se pudo conectar a la base de datos")
        
        create_tables()
        logger.info("Database connected and tables created successfully")
        
    except Exception as e:
        logger.error(f"Startup failed: {str(e)}")
        raise

# Ruta de salud del servicio
@app.get("/")
async def root():
    return {
        "message": "¡Bienvenido a ResiCentral API!",
        "version": settings.app_version,
        "status": "active"
    }

# Ruta de health check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ResiCentral Backend",
        "version": settings.app_version,
        "database": "connected" if check_database_connection() else "disconnected"
    }

# === ENDPOINTS DE AUTENTICACIÓN ===

@app.post("/auth/login", response_model=LoginResponse)
async def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    """Iniciar sesión con email y contraseña"""
    user = authenticate_user(db, login_data.email, login_data.password)
    if not user:
        security_logger.log_login_attempt(login_data.email, False)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cuenta desactivada"
        )
    
    # Crear token de acceso
    access_token_expires = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    
    # Actualizar último login
    crud.update_user_last_login(db, user.id)
    
    # Log successful login
    security_logger.log_login_attempt(login_data.email, True)
    logger.info(f"User {user.id} logged in successfully")
    
    return LoginResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.from_orm(user)
    )

@app.post("/auth/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario"""
    # Verificar si el email ya existe
    if crud.email_exists(db, user_data.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este email ya está registrado"
        )
    
    # Verificar si el username ya existe
    if crud.username_exists(db, user_data.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este nombre de usuario ya está en uso"
        )
    
    # Crear el usuario
    db_user = crud.create_user(db, user_data)
    
    return UserResponse.from_orm(db_user)

@app.get("/auth/me", response_model=UserResponse)
async def get_current_user_profile(current_user: User = Depends(get_current_active_user)):
    """Obtener información del usuario actual"""
    return UserResponse.from_orm(current_user)

# === ENDPOINTS DE USUARIOS ===

@app.get("/users/", response_model=list[UserResponse])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Obtener lista de usuarios (solo superusuarios)"""
    users = crud.get_users(db, skip=skip, limit=limit)
    return [UserResponse.from_orm(user) for user in users]

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de un usuario específico"""
    # Los usuarios pueden ver su propio perfil o los superusuarios pueden ver cualquier perfil
    if current_user.id != user_id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para ver este perfil"
        )
    
    db_user = crud.get_user_by_id(db, user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    return UserResponse.from_orm(db_user)

@app.put("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Actualizar información de un usuario"""
    # Los usuarios pueden actualizar su propio perfil o los superusuarios pueden actualizar cualquier perfil
    if current_user.id != user_id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para actualizar este perfil"
        )
    
    db_user = crud.get_user_by_id(db, user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # Verificar si el nuevo username ya existe (si se está actualizando)
    if user_update.username and user_update.username != db_user.username:
        if crud.username_exists(db, user_update.username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Este nombre de usuario ya está en uso"
            )
    
    updated_user = crud.update_user(db, user_id, user_update)
    return UserResponse.from_orm(updated_user)

@app.put("/users/{user_id}/change-password", response_model=Message)
async def change_password(
    user_id: int,
    password_data: UserChangePassword,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Cambiar contraseña de un usuario"""
    # Solo el propio usuario puede cambiar su contraseña
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo puedes cambiar tu propia contraseña"
        )
    
    # Verificar contraseña actual
    if not verify_password(password_data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contraseña actual incorrecta"
        )
    
    # Actualizar contraseña
    crud.update_user_password(db, user_id, password_data.new_password)
    
    return Message(message="Contraseña actualizada exitosamente")

@app.delete("/users/{user_id}", response_model=Message)
async def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Eliminar un usuario (solo superusuarios)"""
    db_user = crud.get_user_by_id(db, user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    if db_user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes eliminar tu propia cuenta"
        )
    
    crud.delete_user(db, user_id)
    return Message(message="Usuario eliminado exitosamente")


# === ENDPOINTS DE DOCUMENTOS ===

@app.post("/documents/upload", response_model=DocumentResponse)
async def upload_document_endpoint(
    file: UploadFile = File(...),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    is_public: bool = Form(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Subir un nuevo documento"""
    
    # Verificar tipo de archivo permitido
    allowed_types = [
        'application/pdf',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
    ]
    
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Tipo de archivo no permitido. Tipos permitidos: PDF, PPT, PPTX, DOC, DOCX, TXT"
        )
    
    # Verificar tamaño del archivo (50MB máximo)
    max_size = 50 * 1024 * 1024  # 50MB
    file_content = await file.read()
    if len(file_content) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo es demasiado grande. Tamaño máximo: 50MB"
        )
    
    # Subir archivo a MinIO
    file_io = io.BytesIO(file_content)
    upload_result = upload_document(file_io, file.filename, file.content_type)
    
    if not upload_result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error subiendo archivo: {upload_result.get('error', 'Error desconocido')}"
        )
    
    # Crear documento en la base de datos
    document_data = DocumentCreate(
        title=title,
        description=description,
        category=category,
        tags=tags,
        is_public=is_public
    )
    
    db_document = crud.create_document(db, document_data, current_user.id, upload_result)
    
    return DocumentResponse.from_orm(db_document)

@app.get("/documents/", response_model=list[DocumentResponse])
async def get_documents(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    is_public: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de documentos"""
    
    # Si no es superusuario, solo puede ver sus documentos o documentos públicos
    if not current_user.is_superuser:
        if is_public is not False:  # None o True
            # Mostrar documentos públicos o propios
            documents = crud.get_documents(
                db, skip=skip, limit=limit, category=category,
                is_public=True if is_public else None
            )
            if is_public is None:
                # Agregar documentos propios
                own_documents = crud.get_user_documents(db, current_user.id, skip=0, limit=limit)
                documents.extend(own_documents)
                # Remover duplicados si los hay
                seen = set()
                documents = [d for d in documents if not (d.id in seen or seen.add(d.id))]
        else:
            # Solo documentos propios
            documents = crud.get_user_documents(db, current_user.id, skip=skip, limit=limit)
    else:
        # Superusuario puede ver todos
        documents = crud.get_documents(
            db, skip=skip, limit=limit, category=category, is_public=is_public
        )
    
    return [DocumentResponse.from_orm(doc) for doc in documents]

@app.get("/documents/my", response_model=list[DocumentResponse])
async def get_my_documents(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener documentos del usuario actual"""
    documents = crud.get_documents(
        db, skip=skip, limit=limit, owner_id=current_user.id, category=category
    )
    return [DocumentResponse.from_orm(doc) for doc in documents]

@app.get("/documents/public", response_model=list[DocumentResponse])
async def get_public_documents(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Obtener documentos públicos (no requiere autenticación)"""
    documents = crud.get_documents(
        db, skip=skip, limit=limit, is_public=True, category=category
    )
    return [DocumentResponse.from_orm(doc) for doc in documents]

@app.get("/documents/{document_id}", response_model=DocumentWithOwnerResponse)
async def get_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de un documento específico"""
    db_document = crud.get_document_by_id(db, document_id)
    if not db_document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Documento no encontrado"
        )
    
    # Verificar permisos
    if not db_document.is_public and db_document.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para ver este documento"
        )
    
    return DocumentWithOwnerResponse.from_orm(db_document)

@app.put("/documents/{document_id}", response_model=DocumentResponse)
async def update_document(
    document_id: int,
    document_update: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Actualizar información de un documento"""
    db_document = crud.get_document_by_id(db, document_id)
    if not db_document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Documento no encontrado"
        )
    
    # Solo el propietario o superusuario pueden actualizar
    if db_document.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para actualizar este documento"
        )
    
    updated_document = crud.update_document(db, document_id, document_update)
    return DocumentResponse.from_orm(updated_document)

@app.delete("/documents/{document_id}", response_model=Message)
async def delete_document_endpoint(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Eliminar un documento"""
    db_document = crud.get_document_by_id(db, document_id)
    if not db_document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Documento no encontrado"
        )
    
    # Solo el propietario o superusuario pueden eliminar
    if db_document.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para eliminar este documento"
        )
    
    # Eliminar archivo de MinIO
    if not delete_document(db_document.file_path):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error eliminando archivo del almacenamiento"
        )
    
    # Eliminar registro de la base de datos
    crud.delete_document(db, document_id)
    return Message(message="Documento eliminado exitosamente")

@app.get("/documents/{document_id}/download")
async def download_document_endpoint(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Descargar un documento"""
    db_document = crud.get_document_by_id(db, document_id)
    if not db_document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Documento no encontrado"
        )
    
    # Verificar permisos
    if not db_document.is_public and db_document.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para descargar este documento"
        )
    
    # Incrementar contador de descargas
    crud.increment_download_count(db, document_id)
    
    # Descargar archivo de MinIO
    file_content = download_document(db_document.file_path)
    if not file_content:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error descargando archivo del almacenamiento"
        )
    
    # Retornar archivo como respuesta streaming
    return StreamingResponse(
        io.BytesIO(file_content),
        media_type=db_document.file_type,
        headers={
            "Content-Disposition": f"attachment; filename={db_document.original_filename}"
        }
    )

@app.get("/documents/{document_id}/download-url", response_model=DocumentDownload)
async def get_download_url(
    document_id: int,
    expires_hours: int = 1,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener URL de descarga presignada"""
    db_document = crud.get_document_by_id(db, document_id)
    if not db_document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Documento no encontrado"
        )
    
    # Verificar permisos
    if not db_document.is_public and db_document.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para acceder a este documento"
        )
    
    # Generar URL de descarga
    download_url = get_document_download_url(db_document.file_path, expires_hours)
    if not download_url:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error generando URL de descarga"
        )
    
    return DocumentDownload(
        download_url=download_url,
        expires_in=expires_hours * 3600  # Convertir a segundos
    )

@app.get("/documents/search", response_model=DocumentSearchResponse)
async def search_documents(
    q: str,
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    file_type: Optional[str] = None,
    my_documents_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Buscar documentos"""
    
    owner_id = current_user.id if my_documents_only else None
    is_public = None if my_documents_only or current_user.is_superuser else True
    
    documents = crud.search_documents(
        db, q, skip=skip, limit=limit, 
        owner_id=owner_id, is_public=is_public,
        category=category, file_type=file_type
    )
    
    total = len(documents)  # Para simplicidad, en producción debería ser una consulta separada
    
    return DocumentSearchResponse(
        documents=[DocumentResponse.from_orm(doc) for doc in documents],
        total=total,
        skip=skip,
        limit=limit
    )

@app.get("/documents/stats", response_model=DocumentStats)
async def get_documents_stats(
    my_stats_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener estadísticas de documentos"""
    
    owner_id = current_user.id if my_stats_only or not current_user.is_superuser else None
    stats = crud.get_documents_stats(db, owner_id)
    
    return DocumentStats(**stats)


# === ENDPOINTS DE IMÁGENES CLÍNICAS ===

@app.post("/clinical-images/upload", response_model=ClinicalImageResponse)
async def upload_clinical_image_endpoint(
    file: UploadFile = File(...),
    description: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    is_public: bool = Form(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Subir una nueva imagen clínica"""
    
    # Verificar tipo de archivo permitido
    allowed_types = [
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/gif',
        'image/webp',
        'image/bmp',
        'image/tiff'
    ]
    
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Tipo de archivo no permitido. Tipos permitidos: JPEG, PNG, GIF, WebP, BMP, TIFF"
        )
    
    # Verificar tamaño del archivo (20MB máximo)
    max_size = 20 * 1024 * 1024  # 20MB
    file_content = await file.read()
    if len(file_content) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo es demasiado grande. Tamaño máximo: 20MB"
        )
    
    # Subir imagen a MinIO
    file_io = io.BytesIO(file_content)
    upload_result = upload_clinical_image(file_io, file.filename, file.content_type)
    
    if not upload_result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error subiendo imagen: {upload_result.get('error', 'Error desconocido')}"
        )
    
    # Crear imagen clínica en la base de datos
    image_data = ClinicalImageCreate(
        description=description,
        tags=tags,
        is_public=is_public
    )
    
    # Generar clave única para la imagen (usando filename sin extensión + UUID)
    image_key = upload_result["filename"]
    upload_result["image_key"] = image_key
    
    db_image = crud.create_clinical_image(db, image_data, current_user.id, upload_result)
    
    return ClinicalImageResponse.from_orm(db_image)

@app.get("/clinical-images/", response_model=list[ClinicalImageResponse])
async def get_clinical_images(
    skip: int = 0,
    limit: int = 20,
    tags: Optional[str] = None,
    is_public: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de imágenes clínicas"""
    
    # Si no es superusuario, solo puede ver sus imágenes o imágenes públicas
    if not current_user.is_superuser:
        if is_public is not False:  # None o True
            # Mostrar imágenes públicas o propias
            images = crud.get_clinical_images(
                db, skip=skip, limit=limit, tags=tags,
                is_public=True if is_public else None
            )
            if is_public is None:
                # Agregar imágenes propias
                own_images = crud.get_user_clinical_images(db, current_user.id, skip=0, limit=limit)
                images.extend(own_images)
                # Remover duplicados si los hay
                seen = set()
                images = [img for img in images if not (img.id in seen or seen.add(img.id))]
        else:
            # Solo imágenes propias
            images = crud.get_user_clinical_images(db, current_user.id, skip=skip, limit=limit)
    else:
        # Superusuario puede ver todas
        images = crud.get_clinical_images(
            db, skip=skip, limit=limit, tags=tags, is_public=is_public
        )
    
    return [ClinicalImageResponse.from_orm(img) for img in images]

@app.get("/clinical-images/my", response_model=list[ClinicalImageResponse])
async def get_my_clinical_images(
    skip: int = 0,
    limit: int = 20,
    tags: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener imágenes clínicas del usuario actual"""
    images = crud.get_clinical_images(
        db, skip=skip, limit=limit, owner_id=current_user.id, tags=tags
    )
    return [ClinicalImageResponse.from_orm(img) for img in images]

@app.get("/clinical-images/public", response_model=list[ClinicalImageResponse])
async def get_public_clinical_images(
    skip: int = 0,
    limit: int = 20,
    tags: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Obtener imágenes clínicas públicas (no requiere autenticación)"""
    images = crud.get_clinical_images(
        db, skip=skip, limit=limit, is_public=True, tags=tags
    )
    return [ClinicalImageResponse.from_orm(img) for img in images]

@app.get("/clinical-images/{image_id}", response_model=ClinicalImageWithOwnerResponse)
async def get_clinical_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de una imagen clínica específica"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Verificar permisos
    if not db_image.is_public and db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para ver esta imagen"
        )
    
    # Incrementar contador de visualizaciones
    crud.increment_image_view_count(db, image_id)
    
    return ClinicalImageWithOwnerResponse.from_orm(db_image)

@app.put("/clinical-images/{image_id}", response_model=ClinicalImageResponse)
async def update_clinical_image(
    image_id: int,
    image_update: ClinicalImageUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Actualizar información de una imagen clínica"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Solo el propietario o superusuario pueden actualizar
    if db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para actualizar esta imagen"
        )
    
    updated_image = crud.update_clinical_image(db, image_id, image_update)
    return ClinicalImageResponse.from_orm(updated_image)

@app.delete("/clinical-images/{image_id}", response_model=Message)
async def delete_clinical_image_endpoint(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Eliminar una imagen clínica"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Solo el propietario o superusuario pueden eliminar
    if db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para eliminar esta imagen"
        )
    
    # Crear ruta del archivo en MinIO
    image_file_path = f"clinical-images/{db_image.image_key}"
    
    # Eliminar archivo de MinIO
    if not delete_clinical_image(image_file_path):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error eliminando imagen del almacenamiento"
        )
    
    # Eliminar registro de la base de datos
    crud.delete_clinical_image(db, image_id)
    return Message(message="Imagen clínica eliminada exitosamente")

@app.get("/clinical-images/{image_id}/view")
async def view_clinical_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Ver una imagen clínica"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Verificar permisos
    if not db_image.is_public and db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para ver esta imagen"
        )
    
    # Crear ruta del archivo en MinIO
    image_file_path = f"clinical-images/{db_image.image_key}"
    
    # Descargar imagen de MinIO
    image_content = download_clinical_image(image_file_path)
    if not image_content:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error cargando imagen del almacenamiento"
        )
    
    # Retornar imagen como respuesta streaming
    return StreamingResponse(
        io.BytesIO(image_content),
        media_type=db_image.file_type,
        headers={
            "Content-Disposition": f"inline; filename={db_image.original_filename}"
        }
    )

@app.get("/clinical-images/{image_id}/download")
async def download_clinical_image_endpoint(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Descargar una imagen clínica"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Verificar permisos
    if not db_image.is_public and db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para descargar esta imagen"
        )
    
    # Crear ruta del archivo en MinIO
    image_file_path = f"clinical-images/{db_image.image_key}"
    
    # Descargar imagen de MinIO
    image_content = download_clinical_image(image_file_path)
    if not image_content:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error descargando imagen del almacenamiento"
        )
    
    # Retornar imagen como descarga
    return StreamingResponse(
        io.BytesIO(image_content),
        media_type=db_image.file_type,
        headers={
            "Content-Disposition": f"attachment; filename={db_image.original_filename}"
        }
    )

@app.get("/clinical-images/{image_id}/url", response_model=ClinicalImageUrl)
async def get_clinical_image_url(
    image_id: int,
    expires_hours: int = 1,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener URL de imagen clínica presignada"""
    db_image = crud.get_clinical_image_by_id(db, image_id)
    if not db_image:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Imagen clínica no encontrada"
        )
    
    # Verificar permisos
    if not db_image.is_public and db_image.owner_id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para acceder a esta imagen"
        )
    
    # Crear ruta del archivo en MinIO
    image_file_path = f"clinical-images/{db_image.image_key}"
    
    # Generar URL de imagen
    image_url = get_clinical_image_url(image_file_path, expires_hours)
    if not image_url:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error generando URL de imagen"
        )
    
    return ClinicalImageUrl(
        image_url=image_url,
        expires_in=expires_hours * 3600  # Convertir a segundos
    )

@app.get("/clinical-images/search", response_model=ClinicalImageSearchResponse)
async def search_clinical_images(
    q: str,
    skip: int = 0,
    limit: int = 20,
    tags: Optional[str] = None,
    my_images_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Buscar imágenes clínicas"""
    
    owner_id = current_user.id if my_images_only else None
    is_public = None if my_images_only or current_user.is_superuser else True
    
    images = crud.search_clinical_images(
        db, q, skip=skip, limit=limit, 
        owner_id=owner_id, is_public=is_public, tags=tags
    )
    
    total = len(images)  # Para simplicidad, en producción debería ser una consulta separada
    
    return ClinicalImageSearchResponse(
        images=[ClinicalImageResponse.from_orm(img) for img in images],
        total=total,
        skip=skip,
        limit=limit
    )

@app.get("/clinical-images/stats", response_model=ClinicalImageStats)
async def get_clinical_images_stats(
    my_stats_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener estadísticas de imágenes clínicas"""
    
    owner_id = current_user.id if my_stats_only or not current_user.is_superuser else None
    stats = crud.get_clinical_images_stats(db, owner_id)
    
    return ClinicalImageStats(**stats)


# === ENDPOINTS DE FÁRMACOS (VADEMÉCUM) ===

@app.get("/drugs/", response_model=list[DrugResponse])
async def get_drugs(
    skip: int = 0,
    limit: int = 20,
    therapeutic_class: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de fármacos"""
    drugs = crud.get_drugs(db, skip=skip, limit=limit, therapeutic_class=therapeutic_class)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.get("/drugs/{drug_id}", response_model=DrugResponse)
async def get_drug(
    drug_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de un fármaco específico"""
    db_drug = crud.get_drug_by_id(db, drug_id)
    if not db_drug:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fármaco no encontrado"
        )
    
    return DrugResponse.from_orm(db_drug)

@app.get("/drugs/search", response_model=DrugSearchResponse)
async def search_drugs(
    q: str,
    skip: int = 0,
    limit: int = 20,
    therapeutic_class: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Buscar fármacos"""
    drugs = crud.search_drugs(
        db, q, skip=skip, limit=limit, therapeutic_class=therapeutic_class
    )
    
    total = len(drugs)  # Para simplicidad, en producción debería ser una consulta separada
    
    return DrugSearchResponse(
        drugs=[DrugResponse.from_orm(drug) for drug in drugs],
        total=total,
        skip=skip,
        limit=limit
    )

@app.get("/drugs/therapeutic-class/{therapeutic_class}", response_model=list[DrugResponse])
async def get_drugs_by_therapeutic_class(
    therapeutic_class: str,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener fármacos por clase terapéutica"""
    drugs = crud.get_drugs_by_therapeutic_class(db, therapeutic_class, skip=skip, limit=limit)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.get("/drugs/prescription-only", response_model=list[DrugResponse])
async def get_prescription_drugs(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener fármacos que requieren receta"""
    drugs = crud.get_prescription_drugs(db, skip=skip, limit=limit)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.get("/drugs/controlled-substances", response_model=list[DrugResponse])
async def get_controlled_substances(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener sustancias controladas"""
    drugs = crud.get_controlled_substances(db, skip=skip, limit=limit)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.get("/drugs/pediatric", response_model=list[DrugResponse])
async def get_pediatric_drugs(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener fármacos para uso pediátrico"""
    drugs = crud.get_pediatric_drugs(db, skip=skip, limit=limit)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.get("/drugs/geriatric", response_model=list[DrugResponse])
async def get_geriatric_drugs(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener fármacos para uso geriátrico"""
    drugs = crud.get_geriatric_drugs(db, skip=skip, limit=limit)
    return [DrugResponse.from_orm(drug) for drug in drugs]

@app.post("/drugs/seed", response_model=Message)
async def seed_drugs_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Poblar la tabla de fármacos con datos iniciales (solo superusuarios)"""
    if crud.seed_drugs(db):
        return Message(message="Tabla de fármacos poblada exitosamente")
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error poblando la tabla de fármacos"
        )


# === ENDPOINTS DE PROCEDIMIENTOS ===

@app.get("/procedures/", response_model=list)
async def get_procedures(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    difficulty_level: Optional[str] = None,
    is_featured: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de procedimientos"""
    procedures = crud.get_procedures(
        db, skip=skip, limit=limit, category=category, 
        specialty=specialty, difficulty_level=difficulty_level,
        is_featured=is_featured
    )
    return [procedure.to_dict() for procedure in procedures]

@app.get("/procedures/featured", response_model=list)
async def get_featured_procedures(
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener procedimientos destacados"""
    procedures = crud.get_featured_procedures(db, skip=skip, limit=limit)
    return [procedure.to_dict() for procedure in procedures]

@app.get("/procedures/category/{category}", response_model=list)
async def get_procedures_by_category(
    category: str,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener procedimientos por categoría"""
    procedures = crud.get_procedures_by_category(db, category, skip=skip, limit=limit)
    return [procedure.to_dict() for procedure in procedures]

@app.get("/procedures/specialty/{specialty}", response_model=list)
async def get_procedures_by_specialty(
    specialty: str,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener procedimientos por especialidad"""
    procedures = crud.get_procedures_by_specialty(db, specialty, skip=skip, limit=limit)
    return [procedure.to_dict() for procedure in procedures]

@app.get("/procedures/{procedure_id}")
async def get_procedure(
    procedure_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de un procedimiento específico"""
    db_procedure = crud.get_procedure_by_id(db, procedure_id)
    if not db_procedure:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Procedimiento no encontrado"
        )
    
    # Incrementar contador de visualizaciones
    crud.increment_procedure_view_count(db, procedure_id)
    
    return db_procedure.to_dict()

@app.get("/procedures/search", response_model=dict)
async def search_procedures(
    q: str,
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    difficulty_level: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Buscar procedimientos"""
    procedures = crud.search_procedures(
        db, q, skip=skip, limit=limit, category=category,
        specialty=specialty, difficulty_level=difficulty_level
    )
    
    total = len(procedures)  # Para simplicidad, en producción debería ser una consulta separada
    
    return {
        "procedures": [procedure.to_dict() for procedure in procedures],
        "total": total,
        "skip": skip,
        "limit": limit
    }

@app.post("/procedures/{procedure_id}/rate", response_model=Message)
async def rate_procedure(
    procedure_id: int,
    rating: float,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Calificar un procedimiento"""
    if not (1.0 <= rating <= 5.0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La calificación debe estar entre 1.0 y 5.0"
        )
    
    updated_procedure = crud.update_procedure_rating(db, procedure_id, rating)
    if not updated_procedure:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Procedimiento no encontrado"
        )
    
    return Message(message="Calificación registrada exitosamente")

@app.post("/procedures/seed", response_model=Message)
async def seed_procedures_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Poblar la tabla de procedimientos con datos de ejemplo (solo superusuarios)"""
    if crud.seed_sample_procedures(db):
        return Message(message="Tabla de procedimientos poblada exitosamente")
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error poblando la tabla de procedimientos"
        )


# === ENDPOINTS DE ALGORITMOS ===

@app.get("/algorithms/", response_model=list)
async def get_algorithms(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    algorithm_type: Optional[str] = None,
    is_featured: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de algoritmos"""
    algorithms = crud.get_algorithms(
        db, skip=skip, limit=limit, category=category,
        specialty=specialty, algorithm_type=algorithm_type,
        is_featured=is_featured
    )
    return [algorithm.to_dict() for algorithm in algorithms]

@app.get("/algorithms/featured", response_model=list)
async def get_featured_algorithms(
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener algoritmos destacados"""
    algorithms = crud.get_featured_algorithms(db, skip=skip, limit=limit)
    return [algorithm.to_dict() for algorithm in algorithms]

@app.get("/algorithms/type/{algorithm_type}", response_model=list)
async def get_algorithms_by_type(
    algorithm_type: str,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener algoritmos por tipo"""
    algorithms = crud.get_algorithms_by_type(db, algorithm_type, skip=skip, limit=limit)
    return [algorithm.to_dict() for algorithm in algorithms]

@app.get("/algorithms/{algorithm_id}")
async def get_algorithm(
    algorithm_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener información de un algoritmo específico"""
    db_algorithm = crud.get_algorithm_by_id(db, algorithm_id)
    if not db_algorithm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Algoritmo no encontrado"
        )
    
    # Incrementar contador de visualizaciones
    crud.increment_algorithm_view_count(db, algorithm_id)
    
    return db_algorithm.to_dict()

@app.get("/algorithms/{algorithm_id}/full")
async def get_algorithm_with_nodes_and_edges(
    algorithm_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener algoritmo completo con nodos y conexiones para ejecución"""
    algorithm = crud.get_algorithm_with_nodes_and_edges(db, algorithm_id)
    if not algorithm:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Algoritmo no encontrado"
        )
    
    # Incrementar contador de uso
    crud.increment_algorithm_usage_count(db, algorithm_id)
    
    # Preparar respuesta con estructura completa
    result = algorithm.to_dict()
    result["nodes"] = [node.to_dict() for node in algorithm.nodes]
    result["edges"] = [edge.to_dict() for edge in algorithm.edges]
    
    # Obtener nodo inicial
    start_node = crud.get_algorithm_start_node(db, algorithm_id)
    result["start_node"] = start_node.to_dict() if start_node else None
    
    return result

@app.get("/algorithms/{algorithm_id}/start-node")
async def get_algorithm_start_node(
    algorithm_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener el nodo inicial de un algoritmo"""
    start_node = crud.get_algorithm_start_node(db, algorithm_id)
    if not start_node:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nodo inicial no encontrado"
        )
    
    return start_node.to_dict()

@app.get("/algorithms/{algorithm_id}/nodes/{node_id}/edges")
async def get_outgoing_edges_from_node(
    algorithm_id: int,
    node_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Obtener conexiones salientes de un nodo específico"""
    # Verificar que el nodo pertenece al algoritmo
    node = crud.get_algorithm_node_by_id(db, node_id)
    if not node or node.algorithm_id != algorithm_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nodo no encontrado o no pertenece al algoritmo"
        )
    
    edges = crud.get_outgoing_edges_from_node(db, node_id)
    return [edge.to_dict() for edge in edges]

@app.get("/algorithms/search", response_model=dict)
async def search_algorithms(
    q: str,
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    algorithm_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Buscar algoritmos"""
    algorithms = crud.search_algorithms(
        db, q, skip=skip, limit=limit, category=category,
        specialty=specialty, algorithm_type=algorithm_type
    )
    
    total = len(algorithms)  # Para simplicidad, en producción debería ser una consulta separada
    
    return {
        "algorithms": [algorithm.to_dict() for algorithm in algorithms],
        "total": total,
        "skip": skip,
        "limit": limit
    }

@app.post("/algorithms/seed", response_model=Message)
async def seed_algorithms_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """Poblar la tabla de algoritmos con datos de ejemplo (solo superusuarios)"""
    if crud.seed_sample_algorithms(db):
        return Message(message="Tabla de algoritmos poblada exitosamente")
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error poblando la tabla de algoritmos"
        )


# === ENDPOINTS DE CALCULADORAS CLÍNICAS ===

@app.get("/calculators/", response_model=dict)
async def get_calculators(
    current_user: User = Depends(get_current_active_user)
):
    """Obtener lista de calculadoras clínicas disponibles"""
    return get_available_calculators()

@app.post("/calculators/curb65", response_model=CalculatorResult)
async def calculate_curb65_endpoint(
    request: CURB65Request,
    current_user: User = Depends(get_current_active_user)
):
    """Calcular score CURB-65 para neumonía"""
    try:
        result = calculate_curb65(
            confusion=request.confusion,
            urea=request.urea,
            respiratory_rate=request.respiratory_rate,
            blood_pressure_systolic=request.blood_pressure_systolic,
            blood_pressure_diastolic=request.blood_pressure_diastolic,
            age=request.age
        )
        return CalculatorResult(**result.to_dict())
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error calculando CURB-65: {str(e)}"
        )

@app.post("/calculators/wells-pe", response_model=CalculatorResult)
async def calculate_wells_pe_endpoint(
    request: WellsPERequest,
    current_user: User = Depends(get_current_active_user)
):
    """Calcular score de Wells para embolia pulmonar"""
    try:
        result = calculate_wells_pe(
            clinical_signs_dvt=request.clinical_signs_dvt,
            pe_likely=request.pe_likely,
            heart_rate_over_100=request.heart_rate_over_100,
            immobilization_surgery=request.immobilization_surgery,
            previous_pe_dvt=request.previous_pe_dvt,
            hemoptysis=request.hemoptysis,
            malignancy=request.malignancy
        )
        return CalculatorResult(**result.to_dict())
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error calculando Wells PE: {str(e)}"
        )

@app.post("/calculators/glasgow-coma", response_model=CalculatorResult)
async def calculate_glasgow_coma_endpoint(
    request: GlasgowComaRequest,
    current_user: User = Depends(get_current_active_user)
):
    """Calcular Escala de Coma de Glasgow"""
    try:
        result = calculate_glasgow_coma_scale(
            eye_opening=request.eye_opening,
            verbal_response=request.verbal_response,
            motor_response=request.motor_response
        )
        return CalculatorResult(**result.to_dict())
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error calculando Glasgow Coma Scale: {str(e)}"
        )

@app.post("/calculators/chads2-vasc", response_model=CalculatorResult)
async def calculate_chads2_vasc_endpoint(
    request: CHADS2VAScRequest,
    current_user: User = Depends(get_current_active_user)
):
    """Calcular score CHA2DS2-VASc"""
    try:
        result = calculate_chads2_vasc(
            congestive_heart_failure=request.congestive_heart_failure,
            hypertension=request.hypertension,
            age=request.age,
            diabetes=request.diabetes,
            stroke_tia_history=request.stroke_tia_history,
            vascular_disease=request.vascular_disease,
            sex_female=request.sex_female
        )
        return CalculatorResult(**result.to_dict())
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error calculando CHA2DS2-VASc: {str(e)}"
        )


# Manejador de excepciones global
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={
            "message": "Error interno del servidor",
            "detail": str(exc) if settings.debug else "Error interno"
        }
    )

# === ENDPOINTS DE TURNOS ===

@app.get("/shifts/", summary="Obtener turnos del usuario")
async def get_user_shifts(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener todos los turnos del usuario autenticado"""
    try:
        shifts = crud.get_user_shifts(db, current_user.id, skip, limit)
        return [shift.to_dict() for shift in shifts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo turnos: {str(e)}")

@app.get("/shifts/today", summary="Obtener turnos de hoy")
async def get_today_shifts(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener turnos del día actual"""
    try:
        shifts = crud.get_today_shifts(db, current_user.id)
        return [shift.to_dict() for shift in shifts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo turnos de hoy: {str(e)}")

@app.get("/shifts/upcoming", summary="Obtener próximos turnos")
async def get_upcoming_shifts(
    days: int = 7,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener próximos turnos en los siguientes días"""
    try:
        shifts = crud.get_upcoming_shifts(db, current_user.id, days)
        return [shift.to_dict() for shift in shifts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo próximos turnos: {str(e)}")

@app.get("/shifts/active", summary="Obtener turno activo")
async def get_active_shift(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener el turno actualmente activo"""
    try:
        shift = crud.get_active_shift(db, current_user.id)
        return shift.to_dict() if shift else None
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo turno activo: {str(e)}")

@app.get("/shifts/month/{year}/{month}", summary="Obtener turnos de un mes")
async def get_shifts_by_month(
    year: int,
    month: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener turnos de un mes específico"""
    try:
        if not (1 <= month <= 12):
            raise HTTPException(status_code=400, detail="Mes inválido")
        
        shifts = crud.get_shifts_by_month(db, current_user.id, year, month)
        return [shift.to_dict() for shift in shifts]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo turnos del mes: {str(e)}")

@app.get("/shifts/{shift_id}", summary="Obtener turno por ID")
async def get_shift(
    shift_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener un turno específico por ID"""
    try:
        shift = crud.get_shift_by_id(db, shift_id)
        if not shift:
            raise HTTPException(status_code=404, detail="Turno no encontrado")
        
        # Verificar que el turno pertenece al usuario
        if shift.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="No autorizado para ver este turno")
        
        return shift.to_dict()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo turno: {str(e)}")

@app.post("/shifts/", summary="Crear nuevo turno")
async def create_shift(
    shift_data: dict,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Crear un nuevo turno"""
    try:
        # Validar campos requeridos
        required_fields = ["title", "shift_type", "start_date", "end_date"]
        for field in required_fields:
            if field not in shift_data:
                raise HTTPException(status_code=400, detail=f"Campo requerido: {field}")
        
        from datetime import datetime
        # Convertir fechas string a datetime
        if isinstance(shift_data["start_date"], str):
            shift_data["start_date"] = datetime.fromisoformat(shift_data["start_date"].replace('Z', '+00:00'))
        if isinstance(shift_data["end_date"], str):
            shift_data["end_date"] = datetime.fromisoformat(shift_data["end_date"].replace('Z', '+00:00'))
        
        shift = crud.create_shift(db, shift_data, current_user.id)
        return shift.to_dict()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creando turno: {str(e)}")

@app.put("/shifts/{shift_id}", summary="Actualizar turno")
async def update_shift(
    shift_id: int,
    shift_data: dict,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Actualizar un turno existente"""
    try:
        # Verificar que el turno existe y pertenece al usuario
        existing_shift = crud.get_shift_by_id(db, shift_id)
        if not existing_shift:
            raise HTTPException(status_code=404, detail="Turno no encontrado")
        
        if existing_shift.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="No autorizado para actualizar este turno")
        
        # Convertir fechas string a datetime si es necesario
        from datetime import datetime
        for date_field in ["start_date", "end_date", "recurrence_end_date"]:
            if date_field in shift_data and isinstance(shift_data[date_field], str):
                shift_data[date_field] = datetime.fromisoformat(shift_data[date_field].replace('Z', '+00:00'))
        
        shift = crud.update_shift(db, shift_id, shift_data)
        return shift.to_dict()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error actualizando turno: {str(e)}")

@app.delete("/shifts/{shift_id}", summary="Eliminar turno")
async def delete_shift(
    shift_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Eliminar un turno"""
    try:
        # Verificar que el turno existe y pertenece al usuario
        shift = crud.get_shift_by_id(db, shift_id)
        if not shift:
            raise HTTPException(status_code=404, detail="Turno no encontrado")
        
        if shift.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="No autorizado para eliminar este turno")
        
        success = crud.delete_shift(db, shift_id)
        if success:
            return {"message": "Turno eliminado exitosamente"}
        else:
            raise HTTPException(status_code=500, detail="Error eliminando turno")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error eliminando turno: {str(e)}")

@app.get("/shifts/search/{query}", summary="Buscar turnos")
async def search_shifts(
    query: str,
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Buscar turnos por texto"""
    try:
        shifts = crud.search_shifts(db, current_user.id, query, skip, limit)
        return [shift.to_dict() for shift in shifts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error buscando turnos: {str(e)}")

@app.get("/shifts/statistics/user", summary="Obtener estadísticas de turnos")
async def get_shift_statistics(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener estadísticas de turnos del usuario"""
    try:
        stats = crud.get_shift_statistics(db, current_user.id)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo estadísticas: {str(e)}")

@app.post("/shifts/seed", summary="Poblar turnos de ejemplo")
async def seed_shifts(
    current_user: User = Depends(get_current_superuser),
    db: Session = Depends(get_db)
):
    """Poblar la base de datos con turnos de ejemplo (solo superusuarios)"""
    try:
        success = crud.seed_sample_shifts(db, current_user.id)
        if success:
            return {"message": "Turnos de ejemplo creados exitosamente"}
        else:
            raise HTTPException(status_code=500, detail="Error poblando turnos")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error poblando turnos: {str(e)}")

# === ENDPOINTS DE ASISTENTE IA ===

@app.post("/ai/chat", summary="Chat con asistente IA")
async def chat_with_ai(
    message_data: dict,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Enviar mensaje al asistente IA y recibir respuesta"""
    try:
        import openai
        import os
        
        # Obtener API key desde variables de entorno
        api_key = os.getenv("AI_API_KEY")
        if not api_key:
            raise HTTPException(status_code=500, detail="API key de IA no configurada")
        
        message = message_data.get("message", "")
        if not message:
            raise HTTPException(status_code=400, detail="Mensaje requerido")
        
        # Configurar contexto médico
        system_prompt = """Eres un asistente médico especializado que ayuda a residentes médicos.
        Puedes responder preguntas sobre:
        - Procedimientos médicos
        - Diagnósticos diferenciales
        - Cálculos clínicos
        - Tratamientos y medicamentos
        - Interpretación de estudios
        
        Siempre proporciona información basada en evidencia y recuerda que las respuestas son para fines educativos.
        No reemplazas el juicio clínico profesional. Responde en español."""
        
        # Hacer llamada a la API de OpenAI (o similar)
        try:
            openai.api_key = api_key
            response = openai.ChatCompletion.create(
                model=os.getenv("AI_MODEL", "gpt-3.5-turbo"),
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message}
                ],
                max_tokens=int(os.getenv("AI_MAX_TOKENS", "1000")),
                temperature=float(os.getenv("AI_TEMPERATURE", "0.7"))
            )
            
            ai_response = response.choices[0].message.content
            
            return {
                "message": message,
                "response": ai_response,
                "timestamp": datetime.utcnow(),
                "user_id": current_user.id
            }
            
        except Exception as ai_error:
            # Fallback response si la IA no está disponible
            return {
                "message": message,
                "response": "Lo siento, el asistente IA no está disponible en este momento. Por favor, intenta más tarde.",
                "timestamp": datetime.utcnow(),
                "user_id": current_user.id,
                "error": "AI_SERVICE_UNAVAILABLE"
            }
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en chat con IA: {str(e)}")

@app.get("/ai/suggestions", summary="Obtener sugerencias basadas en contexto")
async def get_ai_suggestions(
    context: str = "",
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener sugerencias del asistente IA basadas en contexto"""
    try:
        suggestions = []
        
        # Sugerencias predefinidas basadas en contexto
        if "turno" in context.lower() or "horario" in context.lower():
            suggestions = [
                "¿Cómo prepararse para un turno nocturno?",
                "Checklist pre-turno",
                "Manejo del cansancio durante guardias",
                "Protocolo de entrega de turno"
            ]
        elif "emergencia" in context.lower() or "urgencia" in context.lower():
            suggestions = [
                "Protocolo ABCDE en trauma",
                "Manejo inicial del paciente crítico",
                "Medicamentos de emergencia",
                "Escalas de triaje"
            ]
        elif "procedimiento" in context.lower():
            suggestions = [
                "Preparación de campo estéril",
                "Técnica de sutura",
                "Punción lumbar",
                "Intubación endotraqueal"
            ]
        else:
            suggestions = [
                "¿En qué puedo ayudarte hoy?",
                "Consultar procedimientos médicos",
                "Calcular scores clínicos",
                "Revisar protocolos de emergencia",
                "Buscar información de medicamentos"
            ]
        
        return {
            "suggestions": suggestions,
            "context": context,
            "timestamp": datetime.utcnow()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo sugerencias: {str(e)}")

@app.get("/ai/medical-info/{topic}", summary="Obtener información médica específica")
async def get_medical_info(
    topic: str,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Obtener información médica sobre un tema específico"""
    try:
        # Base de conocimiento básica (en una implementación real, esto vendría de una base de datos)
        medical_info = {
            "hipertension": {
                "definition": "Presión arterial sistólica ≥140 mmHg o diastólica ≥90 mmHg",
                "causes": ["Esencial (95%)", "Secundaria (5%): renal, endocrina, vascular"],
                "treatment": ["Cambios en estilo de vida", "Medicamentos: IECA, ARA-II, Diuréticos, Calcioantagonistas"],
                "complications": ["ACV", "Infarto", "Insuficiencia renal", "Retinopatía"]
            },
            "diabetes": {
                "definition": "Glucemia en ayunas ≥126 mg/dL o HbA1c ≥6.5%",
                "types": ["Tipo 1: autoinmune", "Tipo 2: resistencia a insulina", "Gestacional"],
                "treatment": ["Dieta", "Ejercicio", "Metformina", "Insulina según tipo"],
                "complications": ["Nefropatía", "Retinopatía", "Neuropatía", "Enfermedad cardiovascular"]
            },
            "asma": {
                "definition": "Enfermedad inflamatoria crónica de vías respiratorias",
                "symptoms": ["Disnea", "Sibilancias", "Tos", "Opresión torácica"],
                "treatment": ["Broncodilatadores de rescate", "Corticoides inhalados", "Evitar desencadenantes"],
                "emergency": ["Salbutamol nebulizado", "Corticoides sistémicos", "Oxígeno"]
            }
        }
        
        topic_lower = topic.lower()
        info = medical_info.get(topic_lower)
        
        if info:
            return {
                "topic": topic,
                "information": info,
                "timestamp": datetime.utcnow(),
                "source": "medical_database"
            }
        else:
            return {
                "topic": topic,
                "information": None,
                "message": f"No se encontró información específica sobre '{topic}'. Puedes usar el chat para hacer preguntas más específicas.",
                "timestamp": datetime.utcnow()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo información médica: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug
    )