from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc, func
from typing import Optional, List
from datetime import datetime, timedelta
from .models import User, Document, ClinicalImage, Drug, Procedure, Algorithm, AlgorithmNode, AlgorithmEdge, Shift
from .schemas import UserCreate, UserUpdate, DocumentCreate, DocumentUpdate, ClinicalImageCreate, ClinicalImageUpdate
from .security import get_password_hash

# CRUD operations for User model

def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    """Obtener un usuario por ID"""
    return db.query(User).filter(User.id == user_id).first()

def get_user_by_uuid(db: Session, uuid: str) -> Optional[User]:
    """Obtener un usuario por UUID"""
    return db.query(User).filter(User.uuid == uuid).first()

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Obtener un usuario por email"""
    return db.query(User).filter(User.email == email).first()

def get_user_by_username(db: Session, username: str) -> Optional[User]:
    """Obtener un usuario por nombre de usuario"""
    return db.query(User).filter(User.username == username).first()

def get_user_by_email_or_username(db: Session, email_or_username: str) -> Optional[User]:
    """Obtener un usuario por email o nombre de usuario"""
    return db.query(User).filter(
        or_(User.email == email_or_username, User.username == email_or_username)
    ).first()

def get_users(db: Session, skip: int = 0, limit: int = 100, is_active: Optional[bool] = None) -> List[User]:
    """Obtener lista de usuarios con paginación"""
    query = db.query(User)
    
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    
    return query.offset(skip).limit(limit).all()

def get_users_count(db: Session, is_active: Optional[bool] = None) -> int:
    """Obtener el número total de usuarios"""
    query = db.query(User)
    
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    
    return query.count()

def create_user(db: Session, user: UserCreate) -> User:
    """Crear un nuevo usuario"""
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        hashed_password=hashed_password,
        phone=user.phone,
        bio=user.bio,
        is_active=True,
        is_verified=False,
        is_superuser=False
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, user_id: int, user_update: UserUpdate) -> Optional[User]:
    """Actualizar un usuario existente"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    update_data = user_update.dict(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(db_user, field, value)
    
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user_password(db: Session, user_id: int, new_password: str) -> Optional[User]:
    """Actualizar la contraseña de un usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.hashed_password = get_password_hash(new_password)
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user_last_login(db: Session, user_id: int) -> Optional[User]:
    """Actualizar la fecha de último login del usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.last_login = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def activate_user(db: Session, user_id: int) -> Optional[User]:
    """Activar un usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.is_active = True
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def deactivate_user(db: Session, user_id: int) -> Optional[User]:
    """Desactivar un usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.is_active = False
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def verify_user(db: Session, user_id: int) -> Optional[User]:
    """Verificar un usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.is_verified = True
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def verify_user_by_email(db: Session, email: str) -> Optional[User]:
    """Verificar un usuario por email"""
    db_user = get_user_by_email(db, email)
    if not db_user:
        return None
    
    db_user.is_verified = True
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def make_superuser(db: Session, user_id: int) -> Optional[User]:
    """Hacer superusuario a un usuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.is_superuser = True
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def remove_superuser(db: Session, user_id: int) -> Optional[User]:
    """Remover permisos de superusuario"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return None
    
    db_user.is_superuser = False
    db_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_user)
    return db_user

def delete_user(db: Session, user_id: int) -> bool:
    """Eliminar un usuario (soft delete - solo desactivar)"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return False
    
    db_user.is_active = False
    db_user.updated_at = datetime.utcnow()
    db.commit()
    return True

def permanent_delete_user(db: Session, user_id: int) -> bool:
    """Eliminar permanentemente un usuario de la base de datos"""
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        return False
    
    db.delete(db_user)
    db.commit()
    return True

def search_users(db: Session, query: str, skip: int = 0, limit: int = 100) -> List[User]:
    """Buscar usuarios por nombre, email o username"""
    search_filter = or_(
        User.first_name.ilike(f"%{query}%"),
        User.last_name.ilike(f"%{query}%"),
        User.email.ilike(f"%{query}%"),
        User.username.ilike(f"%{query}%")
    )
    
    return db.query(User).filter(
        and_(User.is_active == True, search_filter)
    ).offset(skip).limit(limit).all()

def email_exists(db: Session, email: str) -> bool:
    """Verificar si un email ya existe"""
    return db.query(User).filter(User.email == email).first() is not None

def username_exists(db: Session, username: str) -> bool:
    """Verificar si un nombre de usuario ya existe"""
    return db.query(User).filter(User.username == username).first() is not None

def email_or_username_exists(db: Session, email: str, username: str) -> bool:
    """Verificar si un email o nombre de usuario ya existe"""
    return db.query(User).filter(
        or_(User.email == email, User.username == username)
    ).first() is not None


# === CRUD OPERATIONS FOR DOCUMENT MODEL ===

def get_document_by_id(db: Session, document_id: int) -> Optional[Document]:
    """Obtener un documento por ID"""
    return db.query(Document).filter(Document.id == document_id).first()

def get_document_by_uuid(db: Session, uuid: str) -> Optional[Document]:
    """Obtener un documento por UUID"""
    return db.query(Document).filter(Document.uuid == uuid).first()

def get_document_by_filename(db: Session, filename: str) -> Optional[Document]:
    """Obtener un documento por nombre de archivo"""
    return db.query(Document).filter(Document.filename == filename).first()

def get_documents(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    is_active: Optional[bool] = True,
    category: Optional[str] = None
) -> List[Document]:
    """Obtener lista de documentos con filtros"""
    query = db.query(Document)
    
    if owner_id is not None:
        query = query.filter(Document.owner_id == owner_id)
    
    if is_public is not None:
        query = query.filter(Document.is_public == is_public)
    
    if is_active is not None:
        query = query.filter(Document.is_active == is_active)
    
    if category:
        query = query.filter(Document.category.ilike(f"%{category}%"))
    
    return query.order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_documents_count(
    db: Session, 
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    is_active: Optional[bool] = True,
    category: Optional[str] = None
) -> int:
    """Obtener el número total de documentos con filtros"""
    query = db.query(Document)
    
    if owner_id is not None:
        query = query.filter(Document.owner_id == owner_id)
    
    if is_public is not None:
        query = query.filter(Document.is_public == is_public)
    
    if is_active is not None:
        query = query.filter(Document.is_active == is_active)
    
    if category:
        query = query.filter(Document.category.ilike(f"%{category}%"))
    
    return query.count()

def create_document(db: Session, document: DocumentCreate, owner_id: int, file_data: dict) -> Document:
    """Crear un nuevo documento"""
    db_document = Document(
        title=document.title,
        description=document.description,
        category=document.category,
        tags=document.tags,
        is_public=document.is_public,
        filename=file_data["filename"],
        original_filename=file_data["original_filename"],
        file_path=file_data["file_path"],
        file_size=file_data["file_size"],
        file_type=file_data["file_type"],
        file_extension=file_data["file_extension"],
        owner_id=owner_id
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    return db_document

def update_document(db: Session, document_id: int, document_update: DocumentUpdate) -> Optional[Document]:
    """Actualizar un documento existente"""
    db_document = get_document_by_id(db, document_id)
    if not db_document:
        return None
    
    update_data = document_update.dict(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(db_document, field, value)
    
    db_document.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_document)
    return db_document

def delete_document(db: Session, document_id: int) -> bool:
    """Eliminar un documento (soft delete)"""
    db_document = get_document_by_id(db, document_id)
    if not db_document:
        return False
    
    db_document.is_active = False
    db_document.updated_at = datetime.utcnow()
    db.commit()
    return True

def permanent_delete_document(db: Session, document_id: int) -> bool:
    """Eliminar permanentemente un documento de la base de datos"""
    db_document = get_document_by_id(db, document_id)
    if not db_document:
        return False
    
    db.delete(db_document)
    db.commit()
    return True

def increment_download_count(db: Session, document_id: int) -> Optional[Document]:
    """Incrementar el contador de descargas de un documento"""
    db_document = get_document_by_id(db, document_id)
    if not db_document:
        return None
    
    db_document.download_count += 1
    db_document.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_document)
    return db_document

def search_documents(
    db: Session, 
    query: str, 
    skip: int = 0, 
    limit: int = 100,
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    category: Optional[str] = None,
    file_type: Optional[str] = None
) -> List[Document]:
    """Buscar documentos por título, descripción o tags"""
    search_filter = or_(
        Document.title.ilike(f"%{query}%"),
        Document.description.ilike(f"%{query}%"),
        Document.tags.ilike(f"%{query}%"),
        Document.original_filename.ilike(f"%{query}%")
    )
    
    base_query = db.query(Document).filter(
        and_(Document.is_active == True, search_filter)
    )
    
    if owner_id is not None:
        base_query = base_query.filter(Document.owner_id == owner_id)
    
    if is_public is not None:
        base_query = base_query.filter(Document.is_public == is_public)
    
    if category:
        base_query = base_query.filter(Document.category.ilike(f"%{category}%"))
    
    if file_type:
        base_query = base_query.filter(Document.file_type.ilike(f"%{file_type}%"))
    
    return base_query.order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_documents_by_category(db: Session, category: str, skip: int = 0, limit: int = 100) -> List[Document]:
    """Obtener documentos por categoría"""
    return db.query(Document).filter(
        and_(
            Document.is_active == True,
            Document.category.ilike(f"%{category}%")
        )
    ).order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_public_documents(db: Session, skip: int = 0, limit: int = 100) -> List[Document]:
    """Obtener documentos públicos"""
    return db.query(Document).filter(
        and_(
            Document.is_active == True,
            Document.is_public == True
        )
    ).order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_user_documents(db: Session, user_id: int, skip: int = 0, limit: int = 100) -> List[Document]:
    """Obtener documentos de un usuario específico"""
    return db.query(Document).filter(
        and_(
            Document.owner_id == user_id,
            Document.is_active == True
        )
    ).order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_recent_documents(db: Session, days: int = 7, skip: int = 0, limit: int = 100) -> List[Document]:
    """Obtener documentos recientes (últimos N días)"""
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    return db.query(Document).filter(
        and_(
            Document.is_active == True,
            Document.created_at >= cutoff_date
        )
    ).order_by(desc(Document.created_at)).offset(skip).limit(limit).all()

def get_popular_documents(db: Session, skip: int = 0, limit: int = 100) -> List[Document]:
    """Obtener documentos más descargados"""
    return db.query(Document).filter(
        Document.is_active == True
    ).order_by(desc(Document.download_count)).offset(skip).limit(limit).all()

def get_documents_stats(db: Session, owner_id: Optional[int] = None) -> dict:
    """Obtener estadísticas de documentos"""
    base_query = db.query(Document).filter(Document.is_active == True)
    
    if owner_id:
        base_query = base_query.filter(Document.owner_id == owner_id)
    
    # Total de documentos
    total_documents = base_query.count()
    
    # Tamaño total en MB
    total_size_result = base_query.with_entities(func.sum(Document.file_size)).scalar()
    total_size_mb = round((total_size_result or 0) / (1024 * 1024), 2)
    
    # Documentos por categoría
    category_stats = db.query(
        Document.category,
        func.count(Document.id).label('count')
    ).filter(Document.is_active == True)
    
    if owner_id:
        category_stats = category_stats.filter(Document.owner_id == owner_id)
    
    category_stats = category_stats.group_by(Document.category).all()
    documents_by_category = {cat or 'Sin categoría': count for cat, count in category_stats}
    
    # Documentos recientes (últimos 7 días)
    cutoff_date = datetime.utcnow() - timedelta(days=7)
    recent_query = base_query.filter(Document.created_at >= cutoff_date)
    recent_uploads = recent_query.count()
    
    return {
        "total_documents": total_documents,
        "total_size_mb": total_size_mb,
        "documents_by_category": documents_by_category,
        "recent_uploads": recent_uploads
    }

def filename_exists(db: Session, filename: str) -> bool:
    """Verificar si un nombre de archivo ya existe"""
    return db.query(Document).filter(Document.filename == filename).first() is not None


# === CRUD OPERATIONS FOR CLINICAL IMAGE MODEL ===

def get_clinical_image_by_id(db: Session, image_id: int) -> Optional[ClinicalImage]:
    """Obtener una imagen clínica por ID"""
    return db.query(ClinicalImage).filter(ClinicalImage.id == image_id).first()

def get_clinical_image_by_uuid(db: Session, uuid: str) -> Optional[ClinicalImage]:
    """Obtener una imagen clínica por UUID"""
    return db.query(ClinicalImage).filter(ClinicalImage.uuid == uuid).first()

def get_clinical_image_by_key(db: Session, image_key: str) -> Optional[ClinicalImage]:
    """Obtener una imagen clínica por image_key"""
    return db.query(ClinicalImage).filter(ClinicalImage.image_key == image_key).first()

def get_clinical_images(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    is_active: Optional[bool] = True,
    tags: Optional[str] = None
) -> List[ClinicalImage]:
    """Obtener lista de imágenes clínicas con filtros"""
    query = db.query(ClinicalImage)
    
    if owner_id is not None:
        query = query.filter(ClinicalImage.owner_id == owner_id)
    
    if is_public is not None:
        query = query.filter(ClinicalImage.is_public == is_public)
    
    if is_active is not None:
        query = query.filter(ClinicalImage.is_active == is_active)
    
    if tags:
        query = query.filter(ClinicalImage.tags.ilike(f"%{tags}%"))
    
    return query.order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_clinical_images_count(
    db: Session, 
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    is_active: Optional[bool] = True,
    tags: Optional[str] = None
) -> int:
    """Obtener el número total de imágenes clínicas con filtros"""
    query = db.query(ClinicalImage)
    
    if owner_id is not None:
        query = query.filter(ClinicalImage.owner_id == owner_id)
    
    if is_public is not None:
        query = query.filter(ClinicalImage.is_public == is_public)
    
    if is_active is not None:
        query = query.filter(ClinicalImage.is_active == is_active)
    
    if tags:
        query = query.filter(ClinicalImage.tags.ilike(f"%{tags}%"))
    
    return query.count()

def create_clinical_image(db: Session, image: ClinicalImageCreate, owner_id: int, image_data: dict) -> ClinicalImage:
    """Crear una nueva imagen clínica"""
    db_image = ClinicalImage(
        description=image.description,
        tags=image.tags,
        is_public=image.is_public,
        image_key=image_data["image_key"],
        original_filename=image_data["original_filename"],
        file_size=image_data["file_size"],
        file_type=image_data["file_type"],
        image_width=image_data.get("image_width"),
        image_height=image_data.get("image_height"),
        owner_id=owner_id
    )
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image

def update_clinical_image(db: Session, image_id: int, image_update: ClinicalImageUpdate) -> Optional[ClinicalImage]:
    """Actualizar una imagen clínica existente"""
    db_image = get_clinical_image_by_id(db, image_id)
    if not db_image:
        return None
    
    update_data = image_update.dict(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(db_image, field, value)
    
    db_image.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_image)
    return db_image

def delete_clinical_image(db: Session, image_id: int) -> bool:
    """Eliminar una imagen clínica (soft delete)"""
    db_image = get_clinical_image_by_id(db, image_id)
    if not db_image:
        return False
    
    db_image.is_active = False
    db_image.updated_at = datetime.utcnow()
    db.commit()
    return True

def permanent_delete_clinical_image(db: Session, image_id: int) -> bool:
    """Eliminar permanentemente una imagen clínica de la base de datos"""
    db_image = get_clinical_image_by_id(db, image_id)
    if not db_image:
        return False
    
    db.delete(db_image)
    db.commit()
    return True

def increment_image_view_count(db: Session, image_id: int) -> Optional[ClinicalImage]:
    """Incrementar el contador de visualizaciones de una imagen"""
    db_image = get_clinical_image_by_id(db, image_id)
    if not db_image:
        return None
    
    db_image.view_count += 1
    db_image.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_image)
    return db_image

def search_clinical_images(
    db: Session, 
    query: str, 
    skip: int = 0, 
    limit: int = 100,
    owner_id: Optional[int] = None,
    is_public: Optional[bool] = None,
    tags: Optional[str] = None
) -> List[ClinicalImage]:
    """Buscar imágenes clínicas por descripción o tags"""
    search_filter = or_(
        ClinicalImage.description.ilike(f"%{query}%"),
        ClinicalImage.tags.ilike(f"%{query}%"),
        ClinicalImage.original_filename.ilike(f"%{query}%")
    )
    
    base_query = db.query(ClinicalImage).filter(
        and_(ClinicalImage.is_active == True, search_filter)
    )
    
    if owner_id is not None:
        base_query = base_query.filter(ClinicalImage.owner_id == owner_id)
    
    if is_public is not None:
        base_query = base_query.filter(ClinicalImage.is_public == is_public)
    
    if tags:
        base_query = base_query.filter(ClinicalImage.tags.ilike(f"%{tags}%"))
    
    return base_query.order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_clinical_images_by_tags(db: Session, tags: str, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas por tags"""
    return db.query(ClinicalImage).filter(
        and_(
            ClinicalImage.is_active == True,
            ClinicalImage.tags.ilike(f"%{tags}%")
        )
    ).order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_public_clinical_images(db: Session, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas públicas"""
    return db.query(ClinicalImage).filter(
        and_(
            ClinicalImage.is_active == True,
            ClinicalImage.is_public == True
        )
    ).order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_user_clinical_images(db: Session, user_id: int, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas de un usuario específico"""
    return db.query(ClinicalImage).filter(
        and_(
            ClinicalImage.owner_id == user_id,
            ClinicalImage.is_active == True
        )
    ).order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_recent_clinical_images(db: Session, days: int = 7, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas recientes (últimos N días)"""
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    return db.query(ClinicalImage).filter(
        and_(
            ClinicalImage.is_active == True,
            ClinicalImage.created_at >= cutoff_date
        )
    ).order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()

def get_popular_clinical_images(db: Session, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas más vistas"""
    return db.query(ClinicalImage).filter(
        ClinicalImage.is_active == True
    ).order_by(desc(ClinicalImage.view_count)).offset(skip).limit(limit).all()

def get_clinical_images_stats(db: Session, owner_id: Optional[int] = None) -> dict:
    """Obtener estadísticas de imágenes clínicas"""
    base_query = db.query(ClinicalImage).filter(ClinicalImage.is_active == True)
    
    if owner_id:
        base_query = base_query.filter(ClinicalImage.owner_id == owner_id)
    
    # Total de imágenes
    total_images = base_query.count()
    
    # Tamaño total en MB
    total_size_result = base_query.with_entities(func.sum(ClinicalImage.file_size)).scalar()
    total_size_mb = round((total_size_result or 0) / (1024 * 1024), 2)
    
    # Total de visualizaciones
    total_views_result = base_query.with_entities(func.sum(ClinicalImage.view_count)).scalar()
    total_views = total_views_result or 0
    
    # Imágenes por tipo de archivo
    type_stats = db.query(
        ClinicalImage.file_type,
        func.count(ClinicalImage.id).label('count')
    ).filter(ClinicalImage.is_active == True)
    
    if owner_id:
        type_stats = type_stats.filter(ClinicalImage.owner_id == owner_id)
    
    type_stats = type_stats.group_by(ClinicalImage.file_type).all()
    images_by_type = {file_type or 'Desconocido': count for file_type, count in type_stats}
    
    # Imágenes recientes (últimos 7 días)
    cutoff_date = datetime.utcnow() - timedelta(days=7)
    recent_query = base_query.filter(ClinicalImage.created_at >= cutoff_date)
    recent_uploads = recent_query.count()
    
    return {
        "total_images": total_images,
        "total_size_mb": total_size_mb,
        "images_by_type": images_by_type,
        "recent_uploads": recent_uploads,
        "total_views": total_views
    }

def image_key_exists(db: Session, image_key: str) -> bool:
    """Verificar si una clave de imagen ya existe"""
    return db.query(ClinicalImage).filter(ClinicalImage.image_key == image_key).first() is not None

def get_clinical_images_by_file_type(db: Session, file_type: str, skip: int = 0, limit: int = 100) -> List[ClinicalImage]:
    """Obtener imágenes clínicas por tipo de archivo"""
    return db.query(ClinicalImage).filter(
        and_(
            ClinicalImage.is_active == True,
            ClinicalImage.file_type.ilike(f"%{file_type}%")
        )
    ).order_by(desc(ClinicalImage.created_at)).offset(skip).limit(limit).all()


# === CRUD OPERATIONS FOR DRUG MODEL ===

def get_drug_by_id(db: Session, drug_id: int) -> Optional[Drug]:
    """Obtener un fármaco por ID"""
    return db.query(Drug).filter(Drug.id == drug_id).first()

def get_drug_by_uuid(db: Session, uuid: str) -> Optional[Drug]:
    """Obtener un fármaco por UUID"""
    return db.query(Drug).filter(Drug.uuid == uuid).first()

def get_drug_by_name(db: Session, name: str) -> Optional[Drug]:
    """Obtener un fármaco por nombre"""
    return db.query(Drug).filter(Drug.name == name).first()

def get_drugs(
    db: Session, 
    skip: int = 0, 
    limit: int = 100,
    therapeutic_class: Optional[str] = None,
    is_active: Optional[bool] = True
) -> List[Drug]:
    """Obtener lista de fármacos con filtros"""
    query = db.query(Drug)
    
    if is_active is not None:
        query = query.filter(Drug.is_active == is_active)
    
    if therapeutic_class:
        query = query.filter(Drug.therapeutic_class.ilike(f"%{therapeutic_class}%"))
    
    return query.order_by(Drug.name).offset(skip).limit(limit).all()

def get_drugs_count(
    db: Session, 
    therapeutic_class: Optional[str] = None,
    is_active: Optional[bool] = True
) -> int:
    """Obtener el número total de fármacos con filtros"""
    query = db.query(Drug)
    
    if is_active is not None:
        query = query.filter(Drug.is_active == is_active)
    
    if therapeutic_class:
        query = query.filter(Drug.therapeutic_class.ilike(f"%{therapeutic_class}%"))
    
    return query.count()

def search_drugs(
    db: Session, 
    query: str, 
    skip: int = 0, 
    limit: int = 100,
    therapeutic_class: Optional[str] = None
) -> List[Drug]:
    """Buscar fármacos por nombre, nombre genérico o clase terapéutica"""
    search_filter = or_(
        Drug.name.ilike(f"%{query}%"),
        Drug.generic_name.ilike(f"%{query}%"),
        Drug.brand_names.ilike(f"%{query}%"),
        Drug.therapeutic_class.ilike(f"%{query}%"),
        Drug.active_ingredient.ilike(f"%{query}%")
    )
    
    base_query = db.query(Drug).filter(
        and_(Drug.is_active == True, search_filter)
    )
    
    if therapeutic_class:
        base_query = base_query.filter(Drug.therapeutic_class.ilike(f"%{therapeutic_class}%"))
    
    return base_query.order_by(Drug.name).offset(skip).limit(limit).all()

def get_drugs_by_therapeutic_class(db: Session, therapeutic_class: str, skip: int = 0, limit: int = 100) -> List[Drug]:
    """Obtener fármacos por clase terapéutica"""
    return db.query(Drug).filter(
        and_(
            Drug.is_active == True,
            Drug.therapeutic_class.ilike(f"%{therapeutic_class}%")
        )
    ).order_by(Drug.name).offset(skip).limit(limit).all()

def get_prescription_drugs(db: Session, skip: int = 0, limit: int = 100) -> List[Drug]:
    """Obtener fármacos que requieren receta"""
    return db.query(Drug).filter(
        and_(
            Drug.is_active == True,
            Drug.is_prescription_only == True
        )
    ).order_by(Drug.name).offset(skip).limit(limit).all()

def get_controlled_substances(db: Session, skip: int = 0, limit: int = 100) -> List[Drug]:
    """Obtener sustancias controladas"""
    return db.query(Drug).filter(
        and_(
            Drug.is_active == True,
            Drug.is_controlled_substance == True
        )
    ).order_by(Drug.name).offset(skip).limit(limit).all()

def get_pediatric_drugs(db: Session, skip: int = 0, limit: int = 100) -> List[Drug]:
    """Obtener fármacos para uso pediátrico"""
    return db.query(Drug).filter(
        and_(
            Drug.is_active == True,
            Drug.pediatric_use == True
        )
    ).order_by(Drug.name).offset(skip).limit(limit).all()

def get_geriatric_drugs(db: Session, skip: int = 0, limit: int = 100) -> List[Drug]:
    """Obtener fármacos para uso geriátrico"""
    return db.query(Drug).filter(
        and_(
            Drug.is_active == True,
            Drug.geriatric_use == True
        )
    ).order_by(Drug.name).offset(skip).limit(limit).all()

def seed_drugs(db: Session) -> bool:
    """Poblar la tabla de fármacos con datos iniciales"""
    try:
        # Verificar si ya existen fármacos
        if db.query(Drug).count() > 0:
            print("La tabla de fármacos ya contiene datos. Saltando seeder.")
            return True
        
        # Datos iniciales de fármacos comunes
        drugs_data = [
            {
                "name": "Paracetamol",
                "generic_name": "Acetaminofén",
                "brand_names": '["Tylenol", "Tempra", "Dolex"]',
                "therapeutic_class": "Analgésico no opiáceo",
                "mechanism_of_action": "Inhibición de la síntesis de prostaglandinas en el sistema nervioso central",
                "indications": "Dolor leve a moderado, fiebre",
                "contraindications": "Hipersensibilidad al paracetamol, insuficiencia hepática severa",
                "dosage": "Adultos: 500-1000mg cada 6-8 horas. Máximo 4g/día",
                "side_effects": "Náuseas, vómitos, hepatotoxicidad en sobredosis",
                "interactions": "Warfarina, alcohol, carbamazepina",
                "precautions": "Uso cuidadoso en enfermedad hepática",
                "pregnancy_category": "B",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Oral, IV",
                "strength": "500mg",
                "presentation": "Tabletas, jarabe, inyectable",
                "laboratory": "Varios",
                "active_ingredient": "Acetaminofén",
                "is_prescription_only": False,
                "is_controlled_substance": False
            },
            {
                "name": "Ibuprofeno",
                "generic_name": "Ibuprofeno",
                "brand_names": '["Advil", "Motrin", "Nurofen"]',
                "therapeutic_class": "AINE",
                "mechanism_of_action": "Inhibición de la ciclooxigenasa (COX-1 y COX-2)",
                "indications": "Dolor, inflamación, fiebre, artritis",
                "contraindications": "Úlcera péptica activa, insuficiencia renal severa, embarazo tercer trimestre",
                "dosage": "Adultos: 400-600mg cada 6-8 horas. Máximo 2.4g/día",
                "side_effects": "Dispepsia, úlcera péptica, insuficiencia renal",
                "interactions": "Warfarina, ACE inhibidores, litio",
                "precautions": "Uso cuidadoso en enfermedad cardiovascular y renal",
                "pregnancy_category": "C",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Oral",
                "strength": "400mg",
                "presentation": "Tabletas, cápsulas, jarabe",
                "laboratory": "Varios",
                "active_ingredient": "Ibuprofeno",
                "is_prescription_only": False,
                "is_controlled_substance": False
            },
            {
                "name": "Amoxicilina",
                "generic_name": "Amoxicilina",
                "brand_names": '["Amoxil", "Trimox"]',
                "therapeutic_class": "Antibiótico beta-lactámico",
                "mechanism_of_action": "Inhibición de la síntesis de la pared celular bacteriana",
                "indications": "Infecciones bacterianas del tracto respiratorio, urinario, piel",
                "contraindications": "Hipersensibilidad a penicilinas",
                "dosage": "Adultos: 500mg cada 8 horas o 875mg cada 12 horas",
                "side_effects": "Diarrea, náuseas, erupción cutánea",
                "interactions": "Warfarina, metotrexato",
                "precautions": "Historial de alergias, enfermedad renal",
                "pregnancy_category": "B",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Oral",
                "strength": "500mg",
                "presentation": "Cápsulas, tabletas, suspensión",
                "laboratory": "Varios",
                "active_ingredient": "Amoxicilina",
                "is_prescription_only": True,
                "is_controlled_substance": False
            },
            {
                "name": "Omeprazol",
                "generic_name": "Omeprazol",
                "brand_names": '["Prilosec", "Losec"]',
                "therapeutic_class": "Inhibidor de la bomba de protones",
                "mechanism_of_action": "Inhibición de la H+/K+-ATPasa gástrica",
                "indications": "Úlcera péptica, ERGE, síndrome de Zollinger-Ellison",
                "contraindications": "Hipersensibilidad al omeprazol",
                "dosage": "Adultos: 20-40mg una vez al día antes del desayuno",
                "side_effects": "Cefalea, diarrea, náuseas, dolor abdominal",
                "interactions": "Warfarina, clopidogrel, diazepam",
                "precautions": "Uso prolongado puede causar deficiencia de B12 y magnesio",
                "pregnancy_category": "C",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Oral",
                "strength": "20mg",
                "presentation": "Cápsulas, tabletas",
                "laboratory": "Varios",
                "active_ingredient": "Omeprazol",
                "is_prescription_only": True,
                "is_controlled_substance": False
            },
            {
                "name": "Metformina",
                "generic_name": "Metformina",
                "brand_names": '["Glucophage", "Fortamet"]',
                "therapeutic_class": "Antidiabético biguanida",
                "mechanism_of_action": "Disminución de la producción hepática de glucosa",
                "indications": "Diabetes mellitus tipo 2",
                "contraindications": "Insuficiencia renal, acidosis metabólica",
                "dosage": "Adultos: 500-850mg 2-3 veces al día con comidas",
                "side_effects": "Diarrea, náuseas, acidosis láctica (rara)",
                "interactions": "Alcohol, contrastes yodados",
                "precautions": "Función renal, función hepática",
                "pregnancy_category": "B",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Oral",
                "strength": "500mg",
                "presentation": "Tabletas, tabletas de liberación prolongada",
                "laboratory": "Varios",
                "active_ingredient": "Metformina",
                "is_prescription_only": True,
                "is_controlled_substance": False
            },
            {
                "name": "Atorvastatina",
                "generic_name": "Atorvastatina",
                "brand_names": '["Lipitor"]',
                "therapeutic_class": "Estatina",
                "mechanism_of_action": "Inhibición de la HMG-CoA reductasa",
                "indications": "Hipercolesterolemia, prevención cardiovascular",
                "contraindications": "Enfermedad hepática activa, embarazo",
                "dosage": "Adultos: 10-80mg una vez al día",
                "side_effects": "Mialgia, hepatotoxicidad, rabdomiólisis",
                "interactions": "Warfarina, digoxina, ciclosporina",
                "precautions": "Función hepática, función renal",
                "pregnancy_category": "X",
                "pediatric_use": False,
                "geriatric_use": True,
                "route_of_administration": "Oral",
                "strength": "20mg",
                "presentation": "Tabletas",
                "laboratory": "Varios",
                "active_ingredient": "Atorvastatina",
                "is_prescription_only": True,
                "is_controlled_substance": False
            },
            {
                "name": "Lorazepam",
                "generic_name": "Lorazepam",
                "brand_names": '["Ativan"]',
                "therapeutic_class": "Benzodiacepina",
                "mechanism_of_action": "Potenciación del GABA",
                "indications": "Ansiedad, insomnio, convulsiones",
                "contraindications": "Hipersensibilidad, glaucoma de ángulo cerrado",
                "dosage": "Adultos: 0.5-2mg 2-3 veces al día",
                "side_effects": "Sedación, mareos, dependencia",
                "interactions": "Alcohol, opiáceos, antidepresivos",
                "precautions": "Dependencia, síndrome de abstinencia",
                "pregnancy_category": "D",
                "pediatric_use": False,
                "geriatric_use": True,
                "route_of_administration": "Oral, IV",
                "strength": "1mg",
                "presentation": "Tabletas, inyectable",
                "laboratory": "Varios",
                "active_ingredient": "Lorazepam",
                "is_prescription_only": True,
                "is_controlled_substance": True
            },
            {
                "name": "Salbutamol",
                "generic_name": "Salbutamol",
                "brand_names": '["Ventolin", "ProAir"]',
                "therapeutic_class": "Broncodilatador beta-2 agonista",
                "mechanism_of_action": "Estimulación de receptores beta-2 adrenérgicos",
                "indications": "Asma, EPOC, broncoespasmo",
                "contraindications": "Hipersensibilidad",
                "dosage": "Adultos: 2-4 puffs cada 4-6 horas según necesidad",
                "side_effects": "Taquicardia, temblor, nerviosismo",
                "interactions": "Beta-bloqueadores, diuréticos",
                "precautions": "Enfermedad cardiovascular, diabetes",
                "pregnancy_category": "C",
                "pediatric_use": True,
                "geriatric_use": True,
                "route_of_administration": "Inhalado",
                "strength": "100mcg/puff",
                "presentation": "Inhalador, nebulizador",
                "laboratory": "Varios",
                "active_ingredient": "Salbutamol",
                "is_prescription_only": True,
                "is_controlled_substance": False
            }
        ]
        
        # Insertar los datos
        for drug_data in drugs_data:
            db_drug = Drug(**drug_data)
            db.add(db_drug)
        
        db.commit()
        print(f"Se han insertado {len(drugs_data)} fármacos en la base de datos.")
        return True
        
    except Exception as e:
        db.rollback()
        print(f"Error al poblar la tabla de fármacos: {str(e)}")
        return False


# === CRUD OPERATIONS FOR PROCEDURE MODEL ===

def get_procedure_by_id(db: Session, procedure_id: int) -> Optional[Procedure]:
    """Obtener un procedimiento por ID"""
    return db.query(Procedure).filter(Procedure.id == procedure_id).first()

def get_procedure_by_uuid(db: Session, uuid: str) -> Optional[Procedure]:
    """Obtener un procedimiento por UUID"""
    return db.query(Procedure).filter(Procedure.uuid == uuid).first()

def get_procedures(
    db: Session, 
    skip: int = 0, 
    limit: int = 100,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    difficulty_level: Optional[str] = None,
    is_published: Optional[bool] = True,
    is_featured: Optional[bool] = None,
    created_by_id: Optional[int] = None
) -> List[Procedure]:
    """Obtener lista de procedimientos con filtros"""
    query = db.query(Procedure)
    
    if category:
        query = query.filter(Procedure.category.ilike(f"%{category}%"))
    
    if specialty:
        query = query.filter(Procedure.specialty.ilike(f"%{specialty}%"))
    
    if difficulty_level:
        query = query.filter(Procedure.difficulty_level == difficulty_level)
    
    if is_published is not None:
        query = query.filter(Procedure.is_published == is_published)
    
    if is_featured is not None:
        query = query.filter(Procedure.is_featured == is_featured)
    
    if created_by_id is not None:
        query = query.filter(Procedure.created_by_id == created_by_id)
    
    return query.order_by(desc(Procedure.created_at)).offset(skip).limit(limit).all()

def get_procedures_count(
    db: Session, 
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    difficulty_level: Optional[str] = None,
    is_published: Optional[bool] = True,
    is_featured: Optional[bool] = None,
    created_by_id: Optional[int] = None
) -> int:
    """Obtener el número total de procedimientos con filtros"""
    query = db.query(Procedure)
    
    if category:
        query = query.filter(Procedure.category.ilike(f"%{category}%"))
    
    if specialty:
        query = query.filter(Procedure.specialty.ilike(f"%{specialty}%"))
    
    if difficulty_level:
        query = query.filter(Procedure.difficulty_level == difficulty_level)
    
    if is_published is not None:
        query = query.filter(Procedure.is_published == is_published)
    
    if is_featured is not None:
        query = query.filter(Procedure.is_featured == is_featured)
    
    if created_by_id is not None:
        query = query.filter(Procedure.created_by_id == created_by_id)
    
    return query.count()

def search_procedures(
    db: Session, 
    query: str, 
    skip: int = 0, 
    limit: int = 100,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    difficulty_level: Optional[str] = None,
    is_published: Optional[bool] = True
) -> List[Procedure]:
    """Buscar procedimientos por título, descripción o tags"""
    search_filter = or_(
        Procedure.title.ilike(f"%{query}%"),
        Procedure.description.ilike(f"%{query}%"),
        Procedure.tags.ilike(f"%{query}%"),
        Procedure.objective.ilike(f"%{query}%")
    )
    
    base_query = db.query(Procedure).filter(search_filter)
    
    if category:
        base_query = base_query.filter(Procedure.category.ilike(f"%{category}%"))
    
    if specialty:
        base_query = base_query.filter(Procedure.specialty.ilike(f"%{specialty}%"))
    
    if difficulty_level:
        base_query = base_query.filter(Procedure.difficulty_level == difficulty_level)
    
    if is_published is not None:
        base_query = base_query.filter(Procedure.is_published == is_published)
    
    return base_query.order_by(desc(Procedure.created_at)).offset(skip).limit(limit).all()

def get_featured_procedures(db: Session, skip: int = 0, limit: int = 10) -> List[Procedure]:
    """Obtener procedimientos destacados"""
    return db.query(Procedure).filter(
        and_(
            Procedure.is_published == True,
            Procedure.is_featured == True
        )
    ).order_by(desc(Procedure.view_count)).offset(skip).limit(limit).all()

def get_procedures_by_category(db: Session, category: str, skip: int = 0, limit: int = 100) -> List[Procedure]:
    """Obtener procedimientos por categoría"""
    return db.query(Procedure).filter(
        and_(
            Procedure.is_published == True,
            Procedure.category.ilike(f"%{category}%")
        )
    ).order_by(desc(Procedure.created_at)).offset(skip).limit(limit).all()

def get_procedures_by_specialty(db: Session, specialty: str, skip: int = 0, limit: int = 100) -> List[Procedure]:
    """Obtener procedimientos por especialidad"""
    return db.query(Procedure).filter(
        and_(
            Procedure.is_published == True,
            Procedure.specialty.ilike(f"%{specialty}%")
        )
    ).order_by(desc(Procedure.created_at)).offset(skip).limit(limit).all()

def increment_procedure_view_count(db: Session, procedure_id: int) -> Optional[Procedure]:
    """Incrementar el contador de visualizaciones de un procedimiento"""
    db_procedure = get_procedure_by_id(db, procedure_id)
    if not db_procedure:
        return None
    
    db_procedure.view_count += 1
    db_procedure.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_procedure)
    return db_procedure

def update_procedure_rating(db: Session, procedure_id: int, new_rating: float) -> Optional[Procedure]:
    """Actualizar la calificación de un procedimiento"""
    db_procedure = get_procedure_by_id(db, procedure_id)
    if not db_procedure:
        return None
    
    # Calcular nueva calificación promedio
    total_rating = db_procedure.rating_average * db_procedure.rating_count
    db_procedure.rating_count += 1
    db_procedure.rating_average = (total_rating + new_rating) / db_procedure.rating_count
    
    db_procedure.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_procedure)
    return db_procedure


# === CRUD OPERATIONS FOR ALGORITHM MODEL ===

def get_algorithm_by_id(db: Session, algorithm_id: int) -> Optional[Algorithm]:
    """Obtener un algoritmo por ID"""
    return db.query(Algorithm).filter(Algorithm.id == algorithm_id).first()

def get_algorithm_by_uuid(db: Session, uuid: str) -> Optional[Algorithm]:
    """Obtener un algoritmo por UUID"""
    return db.query(Algorithm).filter(Algorithm.uuid == uuid).first()

def get_algorithms(
    db: Session, 
    skip: int = 0, 
    limit: int = 100,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    algorithm_type: Optional[str] = None,
    is_published: Optional[bool] = True,
    is_featured: Optional[bool] = None,
    created_by_id: Optional[int] = None
) -> List[Algorithm]:
    """Obtener lista de algoritmos con filtros"""
    query = db.query(Algorithm)
    
    if category:
        query = query.filter(Algorithm.category.ilike(f"%{category}%"))
    
    if specialty:
        query = query.filter(Algorithm.specialty.ilike(f"%{specialty}%"))
    
    if algorithm_type:
        query = query.filter(Algorithm.algorithm_type == algorithm_type)
    
    if is_published is not None:
        query = query.filter(Algorithm.is_published == is_published)
    
    if is_featured is not None:
        query = query.filter(Algorithm.is_featured == is_featured)
    
    if created_by_id is not None:
        query = query.filter(Algorithm.created_by_id == created_by_id)
    
    return query.order_by(desc(Algorithm.created_at)).offset(skip).limit(limit).all()

def get_algorithms_count(
    db: Session, 
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    algorithm_type: Optional[str] = None,
    is_published: Optional[bool] = True,
    is_featured: Optional[bool] = None,
    created_by_id: Optional[int] = None
) -> int:
    """Obtener el número total de algoritmos con filtros"""
    query = db.query(Algorithm)
    
    if category:
        query = query.filter(Algorithm.category.ilike(f"%{category}%"))
    
    if specialty:
        query = query.filter(Algorithm.specialty.ilike(f"%{specialty}%"))
    
    if algorithm_type:
        query = query.filter(Algorithm.algorithm_type == algorithm_type)
    
    if is_published is not None:
        query = query.filter(Algorithm.is_published == is_published)
    
    if is_featured is not None:
        query = query.filter(Algorithm.is_featured == is_featured)
    
    if created_by_id is not None:
        query = query.filter(Algorithm.created_by_id == created_by_id)
    
    return query.count()

def search_algorithms(
    db: Session, 
    query: str, 
    skip: int = 0, 
    limit: int = 100,
    category: Optional[str] = None,
    specialty: Optional[str] = None,
    algorithm_type: Optional[str] = None,
    is_published: Optional[bool] = True
) -> List[Algorithm]:
    """Buscar algoritmos por título, descripción o tags"""
    search_filter = or_(
        Algorithm.title.ilike(f"%{query}%"),
        Algorithm.description.ilike(f"%{query}%"),
        Algorithm.tags.ilike(f"%{query}%")
    )
    
    base_query = db.query(Algorithm).filter(search_filter)
    
    if category:
        base_query = base_query.filter(Algorithm.category.ilike(f"%{category}%"))
    
    if specialty:
        base_query = base_query.filter(Algorithm.specialty.ilike(f"%{specialty}%"))
    
    if algorithm_type:
        base_query = base_query.filter(Algorithm.algorithm_type == algorithm_type)
    
    if is_published is not None:
        base_query = base_query.filter(Algorithm.is_published == is_published)
    
    return base_query.order_by(desc(Algorithm.created_at)).offset(skip).limit(limit).all()

def get_featured_algorithms(db: Session, skip: int = 0, limit: int = 10) -> List[Algorithm]:
    """Obtener algoritmos destacados"""
    return db.query(Algorithm).filter(
        and_(
            Algorithm.is_published == True,
            Algorithm.is_featured == True
        )
    ).order_by(desc(Algorithm.usage_count)).offset(skip).limit(limit).all()

def get_algorithms_by_type(db: Session, algorithm_type: str, skip: int = 0, limit: int = 100) -> List[Algorithm]:
    """Obtener algoritmos por tipo"""
    return db.query(Algorithm).filter(
        and_(
            Algorithm.is_published == True,
            Algorithm.algorithm_type == algorithm_type
        )
    ).order_by(desc(Algorithm.created_at)).offset(skip).limit(limit).all()

def increment_algorithm_view_count(db: Session, algorithm_id: int) -> Optional[Algorithm]:
    """Incrementar el contador de visualizaciones de un algoritmo"""
    db_algorithm = get_algorithm_by_id(db, algorithm_id)
    if not db_algorithm:
        return None
    
    db_algorithm.view_count += 1
    db_algorithm.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_algorithm)
    return db_algorithm

def increment_algorithm_usage_count(db: Session, algorithm_id: int) -> Optional[Algorithm]:
    """Incrementar el contador de uso de un algoritmo"""
    db_algorithm = get_algorithm_by_id(db, algorithm_id)
    if not db_algorithm:
        return None
    
    db_algorithm.usage_count += 1
    db_algorithm.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_algorithm)
    return db_algorithm


# === CRUD OPERATIONS FOR ALGORITHM NODE MODEL ===

def get_algorithm_node_by_id(db: Session, node_id: int) -> Optional[AlgorithmNode]:
    """Obtener un nodo de algoritmo por ID"""
    return db.query(AlgorithmNode).filter(AlgorithmNode.id == node_id).first()

def get_algorithm_nodes_by_algorithm(db: Session, algorithm_id: int) -> List[AlgorithmNode]:
    """Obtener todos los nodos de un algoritmo"""
    return db.query(AlgorithmNode).filter(
        and_(
            AlgorithmNode.algorithm_id == algorithm_id,
            AlgorithmNode.is_active == True
        )
    ).order_by(AlgorithmNode.order_index).all()

def get_algorithm_start_node(db: Session, algorithm_id: int) -> Optional[AlgorithmNode]:
    """Obtener el nodo inicial de un algoritmo"""
    algorithm = get_algorithm_by_id(db, algorithm_id)
    if not algorithm or not algorithm.start_node_id:
        # Si no hay nodo inicial definido, buscar el primer nodo de tipo 'start'
        return db.query(AlgorithmNode).filter(
            and_(
                AlgorithmNode.algorithm_id == algorithm_id,
                AlgorithmNode.node_type == "start",
                AlgorithmNode.is_active == True
            )
        ).first()
    
    return get_algorithm_node_by_id(db, algorithm.start_node_id)


# === CRUD OPERATIONS FOR ALGORITHM EDGE MODEL ===

def get_algorithm_edge_by_id(db: Session, edge_id: int) -> Optional[AlgorithmEdge]:
    """Obtener una conexión de algoritmo por ID"""
    return db.query(AlgorithmEdge).filter(AlgorithmEdge.id == edge_id).first()

def get_algorithm_edges_by_algorithm(db: Session, algorithm_id: int) -> List[AlgorithmEdge]:
    """Obtener todas las conexiones de un algoritmo"""
    return db.query(AlgorithmEdge).filter(
        and_(
            AlgorithmEdge.algorithm_id == algorithm_id,
            AlgorithmEdge.is_active == True
        )
    ).order_by(AlgorithmEdge.order_index).all()

def get_outgoing_edges_from_node(db: Session, node_id: int) -> List[AlgorithmEdge]:
    """Obtener todas las conexiones salientes de un nodo"""
    return db.query(AlgorithmEdge).filter(
        and_(
            AlgorithmEdge.from_node_id == node_id,
            AlgorithmEdge.is_active == True
        )
    ).order_by(AlgorithmEdge.order_index).all()

def get_incoming_edges_to_node(db: Session, node_id: int) -> List[AlgorithmEdge]:
    """Obtener todas las conexiones entrantes a un nodo"""
    return db.query(AlgorithmEdge).filter(
        and_(
            AlgorithmEdge.to_node_id == node_id,
            AlgorithmEdge.is_active == True
        )
    ).order_by(AlgorithmEdge.order_index).all()

def get_algorithm_with_nodes_and_edges(db: Session, algorithm_id: int) -> Optional[Algorithm]:
    """Obtener un algoritmo completo con sus nodos y conexiones"""
    algorithm = get_algorithm_by_id(db, algorithm_id)
    if not algorithm:
        return None
    
    # Cargar nodos y conexiones
    algorithm.nodes = get_algorithm_nodes_by_algorithm(db, algorithm_id)
    algorithm.edges = get_algorithm_edges_by_algorithm(db, algorithm_id)
    
    return algorithm


# === SEEDER FUNCTIONS ===

def seed_sample_procedures(db: Session) -> bool:
    """Poblar la tabla de procedimientos con datos de ejemplo"""
    try:
        # Verificar si ya existen procedimientos
        if db.query(Procedure).count() > 0:
            print("La tabla de procedimientos ya contiene datos. Saltando seeder.")
            return True
        
        # Obtener el primer usuario (admin) para asignar como creador
        admin_user = db.query(User).filter(User.is_superuser == True).first()
        if not admin_user:
            admin_user = db.query(User).first()
        
        if not admin_user:
            print("No hay usuarios en la base de datos. No se pueden crear procedimientos.")
            return False
        
        # Datos de ejemplo de procedimientos
        procedures_data = [
            {
                "title": "Punción Lumbar",
                "description": "Procedimiento para obtención de líquido cefalorraquídeo",
                "category": "Neurología",
                "specialty": "Neurología",
                "difficulty_level": "Intermedio",
                "estimated_duration": 30,
                "objective": "Obtener muestra de líquido cefalorraquídeo para análisis diagnóstico",
                "indications": '["Sospecha de meningitis", "Hemorragia subaracnoidea", "Síndrome de hipertensión intracraneal"]',
                "contraindications": '["Hipertensión intracraneal", "Infección en sitio de punción", "Coagulopatía severa"]',
                "materials_needed": '["Aguja espinal", "Jeringas", "Anestésico local", "Antiséptico", "Gasas estériles"]',
                "procedure_steps": '["Posición del paciente", "Asepsia y antisepsia", "Anestesia local", "Inserción de aguja", "Obtención de muestra"]',
                "tags": '["punción", "lumbar", "LCR", "diagnóstico"]',
                "is_published": True,
                "is_featured": True,
                "created_by_id": admin_user.id,
            },
            {
                "title": "Intubación Endotraqueal",
                "description": "Procedimiento de manejo avanzado de vía aérea",
                "category": "Urgencias",
                "specialty": "Medicina de Emergencias",
                "difficulty_level": "Avanzado",
                "estimated_duration": 15,
                "objective": "Asegurar vía aérea permeable en paciente crítico",
                "indications": '["Paro cardiorrespiratorio", "Insuficiencia respiratoria severa", "Protección de vía aérea"]',
                "contraindications": '["Trauma cervical inestable", "Obstrucción completa de vía aérea superior"]',
                "materials_needed": '["Laringoscopio", "Tubo endotraqueal", "Guía", "Jeringa", "Estetoscopio"]',
                "procedure_steps": '["Preoxigenación", "Posición del paciente", "Laringoscopia", "Inserción del tubo", "Verificación"]',
                "tags": '["intubación", "vía aérea", "emergencia", "crítico"]',
                "is_published": True,
                "is_featured": True,
                "created_by_id": admin_user.id,
            },
            {
                "title": "Venopunción",
                "description": "Técnica básica para acceso venoso periférico",
                "category": "Enfermería",
                "specialty": "General",
                "difficulty_level": "Básico",
                "estimated_duration": 10,
                "objective": "Obtener acceso venoso para administración de medicamentos o extracción de muestras",
                "indications": '["Administración de medicamentos IV", "Extracción de muestras", "Hidratación parenteral"]',
                "contraindications": '["Infección en sitio de punción", "Tromboflebitis", "Fístula arteriovenosa"]',
                "materials_needed": '["Catéter venoso", "Tourniquet", "Alcohol", "Gasas", "Esparadrapo"]',
                "procedure_steps": '["Selección del sitio", "Asepsia", "Colocación de tourniquet", "Punción venosa", "Fijación"]',
                "tags": '["venopunción", "acceso venoso", "básico"]',
                "is_published": True,
                "is_featured": False,
                "created_by_id": admin_user.id,
            }
        ]
        
        # Insertar los datos
        for procedure_data in procedures_data:
            db_procedure = Procedure(**procedure_data)
            db.add(db_procedure)
        
        db.commit()
        print(f"Se han insertado {len(procedures_data)} procedimientos en la base de datos.")
        return True
        
    except Exception as e:
        db.rollback()
        print(f"Error al poblar la tabla de procedimientos: {str(e)}")
        return False

def seed_sample_algorithms(db: Session) -> bool:
    """Poblar la tabla de algoritmos con datos de ejemplo"""
    try:
        # Verificar si ya existen algoritmos
        if db.query(Algorithm).count() > 0:
            print("La tabla de algoritmos ya contiene datos. Saltando seeder.")
            return True
        
        # Obtener el primer usuario (admin) para asignar como creador
        admin_user = db.query(User).filter(User.is_superuser == True).first()
        if not admin_user:
            admin_user = db.query(User).first()
        
        if not admin_user:
            print("No hay usuarios en la base de datos. No se pueden crear algoritmos.")
            return False
        
        # Crear algoritmo de ejemplo: Manejo de Dolor Torácico
        algorithm_data = {
            "title": "Manejo de Dolor Torácico",
            "description": "Algoritmo para evaluación y manejo inicial del dolor torácico en urgencias",
            "category": "Cardiología",
            "specialty": "Medicina de Emergencias",
            "algorithm_type": "decision_tree",
            "tags": '["dolor torácico", "emergencia", "cardiología"]',
            "is_published": True,
            "is_featured": True,
            "created_by_id": admin_user.id,
        }
        
        db_algorithm = Algorithm(**algorithm_data)
        db.add(db_algorithm)
        db.commit()
        db.refresh(db_algorithm)
        
        # Crear nodos del algoritmo
        nodes_data = [
            {
                "algorithm_id": db_algorithm.id,
                "node_type": "start",
                "title": "Paciente con dolor torácico",
                "content": "Evaluación inicial del paciente con dolor torácico",
                "order_index": 1,
                "position_x": 100.0,
                "position_y": 50.0,
                "color": "#4CAF50",
                "icon": "start"
            },
            {
                "algorithm_id": db_algorithm.id,
                "node_type": "decision",
                "title": "¿Signos de alarma?",
                "content": "Evaluar signos vitales y síntomas de alarma",
                "question": "¿Presenta el paciente signos de alarma como hipotensión, disnea severa, sudoración profusa?",
                "order_index": 2,
                "position_x": 100.0,
                "position_y": 150.0,
                "color": "#FF9800",
                "icon": "help"
            },
            {
                "algorithm_id": db_algorithm.id,
                "node_type": "action",
                "title": "Manejo urgente",
                "content": "Estabilización inmediata del paciente",
                "action_description": "Oxígeno, acceso venoso, monitoreo cardíaco, ECG urgente",
                "order_index": 3,
                "position_x": 50.0,
                "position_y": 250.0,
                "color": "#F44336",
                "icon": "emergency"
            },
            {
                "algorithm_id": db_algorithm.id,
                "node_type": "action",
                "title": "Evaluación sistemática",
                "content": "Evaluación completa del dolor torácico",
                "action_description": "Historia clínica detallada, ECG, radiografía de tórax",
                "order_index": 4,
                "position_x": 150.0,
                "position_y": 250.0,
                "color": "#2196F3",
                "icon": "assessment"
            }
        ]
        
        nodes = []
        for node_data in nodes_data:
            db_node = AlgorithmNode(**node_data)
            db.add(db_node)
            nodes.append(db_node)
        
        db.commit()
        
        # Actualizar el nodo inicial del algoritmo
        db_algorithm.start_node_id = nodes[0].id
        db.commit()
        
        # Crear conexiones entre nodos
        edges_data = [
            {
                "algorithm_id": db_algorithm.id,
                "from_node_id": nodes[0].id,
                "to_node_id": nodes[1].id,
                "label": "Iniciar evaluación",
                "order_index": 1
            },
            {
                "algorithm_id": db_algorithm.id,
                "from_node_id": nodes[1].id,
                "to_node_id": nodes[2].id,
                "label": "Sí",
                "condition_type": "equals",
                "condition_value": "true",
                "order_index": 2,
                "color": "#F44336"
            },
            {
                "algorithm_id": db_algorithm.id,
                "from_node_id": nodes[1].id,
                "to_node_id": nodes[3].id,
                "label": "No",
                "condition_type": "equals",
                "condition_value": "false",
                "order_index": 3,
                "color": "#4CAF50"
            }
        ]
        
        for edge_data in edges_data:
            db_edge = AlgorithmEdge(**edge_data)
            db.add(db_edge)
        
        db.commit()
        print(f"Se ha creado el algoritmo '{db_algorithm.title}' con {len(nodes)} nodos y {len(edges_data)} conexiones.")
        return True
        
    except Exception as e:
        db.rollback()
        print(f"Error al poblar la tabla de algoritmos: {str(e)}")
        return False


# CRUD operations for Shift model

def get_shift_by_id(db: Session, shift_id: int) -> Optional[Shift]:
    """Obtener un turno por ID"""
    return db.query(Shift).filter(Shift.id == shift_id).first()

def get_shift_by_uuid(db: Session, uuid: str) -> Optional[Shift]:
    """Obtener un turno por UUID"""
    return db.query(Shift).filter(Shift.uuid == uuid).first()

def get_user_shifts(db: Session, user_id: int, skip: int = 0, limit: int = 100) -> List[Shift]:
    """Obtener turnos de un usuario"""
    return db.query(Shift).filter(Shift.user_id == user_id).offset(skip).limit(limit).all()

def get_shifts_by_date_range(
    db: Session, 
    user_id: int, 
    start_date: datetime, 
    end_date: datetime,
    skip: int = 0, 
    limit: int = 100
) -> List[Shift]:
    """Obtener turnos en un rango de fechas"""
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date >= start_date,
            Shift.start_date <= end_date
        )
    ).offset(skip).limit(limit).all()

def get_shifts_by_month(db: Session, user_id: int, year: int, month: int) -> List[Shift]:
    """Obtener turnos de un mes específico"""
    from calendar import monthrange
    start_date = datetime(year, month, 1)
    _, last_day = monthrange(year, month)
    end_date = datetime(year, month, last_day, 23, 59, 59)
    
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date >= start_date,
            Shift.start_date <= end_date
        )
    ).order_by(Shift.start_date).all()

def get_today_shifts(db: Session, user_id: int) -> List[Shift]:
    """Obtener turnos de hoy"""
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())
    end_of_day = datetime.combine(today, datetime.max.time())
    
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date >= start_of_day,
            Shift.start_date <= end_of_day
        )
    ).order_by(Shift.start_date).all()

def get_upcoming_shifts(db: Session, user_id: int, days: int = 7) -> List[Shift]:
    """Obtener próximos turnos"""
    now = datetime.now()
    future_date = now + timedelta(days=days)
    
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date >= now,
            Shift.start_date <= future_date
        )
    ).order_by(Shift.start_date).all()

def get_active_shift(db: Session, user_id: int) -> Optional[Shift]:
    """Obtener turno actualmente activo"""
    now = datetime.now()
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date <= now,
            Shift.end_date >= now
        )
    ).first()

def create_shift(db: Session, shift_data: dict, user_id: int) -> Shift:
    """Crear un nuevo turno"""
    db_shift = Shift(
        title=shift_data["title"],
        description=shift_data.get("description"),
        shift_type=shift_data["shift_type"],
        start_date=shift_data["start_date"],
        end_date=shift_data["end_date"],
        location=shift_data.get("location"),
        department=shift_data.get("department"),
        status=shift_data.get("status", "programado"),
        is_recurring=shift_data.get("is_recurring", False),
        recurrence_pattern=shift_data.get("recurrence_pattern"),
        recurrence_end_date=shift_data.get("recurrence_end_date"),
        notes=shift_data.get("notes"),
        color=shift_data.get("color"),
        priority=shift_data.get("priority", "normal"),
        reminder_enabled=shift_data.get("reminder_enabled", True),
        reminder_minutes_before=shift_data.get("reminder_minutes_before", 60),
        user_id=user_id
    )
    db.add(db_shift)
    db.commit()
    db.refresh(db_shift)
    return db_shift

def update_shift(db: Session, shift_id: int, shift_data: dict) -> Optional[Shift]:
    """Actualizar un turno existente"""
    db_shift = get_shift_by_id(db, shift_id)
    if not db_shift:
        return None
    
    for field, value in shift_data.items():
        if hasattr(db_shift, field):
            setattr(db_shift, field, value)
    
    db_shift.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_shift)
    return db_shift

def delete_shift(db: Session, shift_id: int) -> bool:
    """Eliminar un turno"""
    db_shift = get_shift_by_id(db, shift_id)
    if not db_shift:
        return False
    
    db.delete(db_shift)
    db.commit()
    return True

def get_shifts_by_type(db: Session, user_id: int, shift_type: str) -> List[Shift]:
    """Obtener turnos por tipo"""
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.shift_type == shift_type
        )
    ).order_by(Shift.start_date).all()

def get_shifts_by_status(db: Session, user_id: int, status: str) -> List[Shift]:
    """Obtener turnos por estado"""
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.status == status
        )
    ).order_by(Shift.start_date).all()

def get_shifts_by_priority(db: Session, user_id: int, priority: str) -> List[Shift]:
    """Obtener turnos por prioridad"""
    return db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.priority == priority
        )
    ).order_by(Shift.start_date).all()

def search_shifts(
    db: Session, 
    user_id: int, 
    query: str, 
    skip: int = 0, 
    limit: int = 100
) -> List[Shift]:
    """Buscar turnos por título, descripción o notas"""
    search_filter = or_(
        Shift.title.ilike(f"%{query}%"),
        Shift.description.ilike(f"%{query}%"),
        Shift.notes.ilike(f"%{query}%"),
        Shift.location.ilike(f"%{query}%"),
        Shift.department.ilike(f"%{query}%")
    )
    
    return db.query(Shift).filter(
        and_(Shift.user_id == user_id, search_filter)
    ).offset(skip).limit(limit).all()

def get_shift_statistics(db: Session, user_id: int) -> dict:
    """Obtener estadísticas de turnos del usuario"""
    total_shifts = db.query(Shift).filter(Shift.user_id == user_id).count()
    
    # Turnos por estado
    shifts_by_status = db.query(
        Shift.status, func.count(Shift.id)
    ).filter(Shift.user_id == user_id).group_by(Shift.status).all()
    
    # Turnos por tipo
    shifts_by_type = db.query(
        Shift.shift_type, func.count(Shift.id)
    ).filter(Shift.user_id == user_id).group_by(Shift.shift_type).all()
    
    # Turnos este mes
    now = datetime.now()
    start_of_month = datetime(now.year, now.month, 1)
    shifts_this_month = db.query(Shift).filter(
        and_(
            Shift.user_id == user_id,
            Shift.start_date >= start_of_month
        )
    ).count()
    
    # Próximos turnos (7 días)
    upcoming_shifts = len(get_upcoming_shifts(db, user_id, 7))
    
    return {
        "total_shifts": total_shifts,
        "shifts_by_status": dict(shifts_by_status),
        "shifts_by_type": dict(shifts_by_type),
        "shifts_this_month": shifts_this_month,
        "upcoming_shifts": upcoming_shifts
    }

def seed_sample_shifts(db: Session, user_id: int) -> bool:
    """Poblar la tabla con turnos de ejemplo"""
    try:
        # Verificar si ya existen turnos para este usuario
        existing_shifts = db.query(Shift).filter(Shift.user_id == user_id).first()
        if existing_shifts:
            print("Ya existen turnos para este usuario.")
            return True
        
        from datetime import datetime, timedelta
        base_date = datetime.now()
        
        sample_shifts = [
            {
                "title": "Turno Mañana - Urgencias",
                "description": "Turno de mañana en el servicio de urgencias",
                "shift_type": "mañana",
                "start_date": base_date + timedelta(days=1, hours=7),
                "end_date": base_date + timedelta(days=1, hours=15),
                "location": "Hospital Central",
                "department": "Urgencias",
                "status": "programado",
                "color": "#4CAF50",
                "priority": "alta",
                "notes": "Revisión de pacientes críticos"
            },
            {
                "title": "Guardia Nocturna - UCI",
                "description": "Guardia nocturna en unidad de cuidados intensivos",
                "shift_type": "noche",
                "start_date": base_date + timedelta(days=2, hours=22),
                "end_date": base_date + timedelta(days=3, hours=6),
                "location": "Hospital Central",
                "department": "UCI",
                "status": "confirmado",
                "color": "#2196F3",
                "priority": "urgente",
                "notes": "Pacientes post-operatorios"
            },
            {
                "title": "Consulta Externa - Cardiología",
                "description": "Consultas de cardiología ambulatoria",
                "shift_type": "tarde",
                "start_date": base_date + timedelta(days=3, hours=14),
                "end_date": base_date + timedelta(days=3, hours=18),
                "location": "Consultorio Médico",
                "department": "Cardiología",
                "status": "programado",
                "color": "#FF9800",
                "priority": "normal",
                "notes": "Seguimiento de pacientes crónicos"
            },
            {
                "title": "Cirugía General",
                "description": "Asistencia en cirugías programadas",
                "shift_type": "mañana",
                "start_date": base_date + timedelta(days=5, hours=8),
                "end_date": base_date + timedelta(days=5, hours=16),
                "location": "Hospital Central",
                "department": "Cirugía General",
                "status": "programado",
                "color": "#9C27B0",
                "priority": "alta",
                "notes": "3 cirugías programadas"
            },
            {
                "title": "Pediatría - Emergencias",
                "description": "Atención pediátrica de emergencia",
                "shift_type": "tarde",
                "start_date": base_date + timedelta(days=7, hours=16),
                "end_date": base_date + timedelta(days=8, hours=0),
                "location": "Hospital Pediátrico",
                "department": "Pediatría",
                "status": "programado",
                "color": "#F44336",
                "priority": "alta",
                "notes": "Temporada alta de infecciones respiratorias"
            }
        ]
        
        for shift_data in sample_shifts:
            shift_data["user_id"] = user_id
            db_shift = Shift(**shift_data)
            db.add(db_shift)
        
        db.commit()
        print(f"Se han creado {len(sample_shifts)} turnos de ejemplo.")
        return True
        
    except Exception as e:
        db.rollback()
        print(f"Error al poblar la tabla de turnos: {str(e)}")
        return False