from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
import re

# Esquemas base para User
class UserBase(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    first_name: str = Field(..., min_length=1, max_length=50)
    last_name: str = Field(..., min_length=1, max_length=50)
    phone: Optional[str] = Field(None, max_length=20)
    bio: Optional[str] = Field(None, max_length=500)
    
    @validator('username')
    def validate_username(cls, v):
        if not re.match(r'^[a-zA-Z0-9_]+$', v):
            raise ValueError('El nombre de usuario solo puede contener letras, números y guiones bajos')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and not re.match(r'^[\+]?[1-9][\d]{0,15}$', v):
            raise ValueError('Formato de teléfono inválido')
        return v

# Esquema para crear un usuario
class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=128)
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('La contraseña debe tener al menos 8 caracteres')
        if not re.search(r'[A-Z]', v):
            raise ValueError('La contraseña debe contener al menos una letra mayúscula')
        if not re.search(r'[a-z]', v):
            raise ValueError('La contraseña debe contener al menos una letra minúscula')
        if not re.search(r'[0-9]', v):
            raise ValueError('La contraseña debe contener al menos un número')
        return v

# Esquema para actualizar un usuario
class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    first_name: Optional[str] = Field(None, min_length=1, max_length=50)
    last_name: Optional[str] = Field(None, min_length=1, max_length=50)
    phone: Optional[str] = Field(None, max_length=20)
    bio: Optional[str] = Field(None, max_length=500)
    avatar_url: Optional[str] = None
    
    @validator('username')
    def validate_username(cls, v):
        if v and not re.match(r'^[a-zA-Z0-9_]+$', v):
            raise ValueError('El nombre de usuario solo puede contener letras, números y guiones bajos')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and not re.match(r'^[\+]?[1-9][\d]{0,15}$', v):
            raise ValueError('Formato de teléfono inválido')
        return v

# Esquema para cambiar contraseña
class UserChangePassword(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=128)
    
    @validator('new_password')
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError('La contraseña debe tener al menos 8 caracteres')
        if not re.search(r'[A-Z]', v):
            raise ValueError('La contraseña debe contener al menos una letra mayúscula')
        if not re.search(r'[a-z]', v):
            raise ValueError('La contraseña debe contener al menos una letra minúscula')
        if not re.search(r'[0-9]', v):
            raise ValueError('La contraseña debe contener al menos un número')
        return v

# Esquema para respuesta de usuario (sin datos sensibles)
class UserResponse(UserBase):
    id: int
    uuid: str
    is_active: bool
    is_verified: bool
    is_superuser: bool
    avatar_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# Esquema para usuario en base de datos (con contraseña hasheada)
class UserInDB(UserResponse):
    hashed_password: str

# Esquemas para autenticación
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

# Esquema para token
class Token(BaseModel):
    access_token: str
    token_type: str

# Esquema para datos del token
class TokenData(BaseModel):
    user_id: Optional[int] = None
    email: Optional[str] = None

# Esquemas para respuestas de la API
class Message(BaseModel):
    message: str

class ErrorResponse(BaseModel):
    detail: str
    error_code: Optional[str] = None

# Esquema para verificación de email
class EmailVerification(BaseModel):
    email: EmailStr
    verification_code: str

# Esquema para resetear contraseña
class PasswordReset(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    email: EmailStr
    reset_token: str
    new_password: str = Field(..., min_length=8, max_length=128)
    
    @validator('new_password')
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError('La contraseña debe tener al menos 8 caracteres')
        if not re.search(r'[A-Z]', v):
            raise ValueError('La contraseña debe contener al menos una letra mayúscula')
        if not re.search(r'[a-z]', v):
            raise ValueError('La contraseña debe contener al menos una letra minúscula')
        if not re.search(r'[0-9]', v):
            raise ValueError('La contraseña debe contener al menos un número')
        return v


# === ESQUEMAS PARA DOCUMENTOS ===

# Esquemas base para Document
class DocumentBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = Field(None, max_length=50)
    tags: Optional[str] = Field(None, max_length=500)  # JSON string
    is_public: bool = False

# Esquema para crear un documento
class DocumentCreate(DocumentBase):
    pass

# Esquema para actualizar un documento
class DocumentUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = Field(None, max_length=50)
    tags: Optional[str] = Field(None, max_length=500)
    is_public: Optional[bool] = None

# Esquema para respuesta de documento (sin datos sensibles)
class DocumentResponse(DocumentBase):
    id: int
    uuid: str
    filename: str
    original_filename: str
    file_size: float
    file_size_mb: float
    file_size_human: str
    file_type: str
    file_extension: str
    is_active: bool
    download_count: int
    created_at: datetime
    updated_at: datetime
    owner_id: int
    
    class Config:
        from_attributes = True

# Esquema para respuesta de documento con información del propietario
class DocumentWithOwnerResponse(DocumentResponse):
    owner: Optional['UserResponse'] = None

# Esquema para subida de archivo
class FileUpload(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = Field(None, max_length=50)
    tags: Optional[str] = Field(None, max_length=500)
    is_public: bool = False

# Esquema para URL de descarga
class DocumentDownload(BaseModel):
    download_url: str
    expires_in: int  # Segundos hasta que expire la URL

# Esquema para estadísticas de documentos
class DocumentStats(BaseModel):
    total_documents: int
    total_size_mb: float
    documents_by_category: dict
    recent_uploads: int  # Últimos 7 días

# Esquema para búsqueda de documentos
class DocumentSearch(BaseModel):
    query: Optional[str] = None
    category: Optional[str] = None
    file_type: Optional[str] = None
    owner_id: Optional[int] = None
    is_public: Optional[bool] = None
    skip: int = 0
    limit: int = 20

# Esquema para respuesta de búsqueda
class DocumentSearchResponse(BaseModel):
    documents: List[DocumentResponse]
    total: int
    skip: int
    limit: int

# Esquema para información de archivo
class FileInfo(BaseModel):
    filename: str
    size: int
    content_type: str

# === ESQUEMAS PARA IMÁGENES CLÍNICAS ===

# Esquemas base para ClinicalImage
class ClinicalImageBase(BaseModel):
    description: Optional[str] = Field(None, max_length=1000)
    tags: Optional[str] = Field(None, max_length=500)  # JSON string
    is_public: bool = False

# Esquema para crear una imagen clínica
class ClinicalImageCreate(ClinicalImageBase):
    pass

# Esquema para actualizar una imagen clínica
class ClinicalImageUpdate(BaseModel):
    description: Optional[str] = Field(None, max_length=1000)
    tags: Optional[str] = Field(None, max_length=500)
    is_public: Optional[bool] = None

# Esquema para respuesta de imagen clínica
class ClinicalImageResponse(ClinicalImageBase):
    id: int
    uuid: str
    image_key: str
    original_filename: str
    file_size: float
    file_size_mb: float
    file_size_human: str
    file_type: str
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    image_dimensions: str
    aspect_ratio: Optional[float] = None
    is_active: bool
    view_count: int
    created_at: datetime
    updated_at: datetime
    owner_id: int
    
    class Config:
        from_attributes = True

# Esquema para respuesta de imagen clínica con información del propietario
class ClinicalImageWithOwnerResponse(ClinicalImageResponse):
    owner: Optional['UserResponse'] = None

# Esquema para subida de imagen clínica
class ClinicalImageUpload(BaseModel):
    description: Optional[str] = Field(None, max_length=1000)
    tags: Optional[str] = Field(None, max_length=500)
    is_public: bool = False

# Esquema para URL de imagen
class ClinicalImageUrl(BaseModel):
    image_url: str
    thumbnail_url: Optional[str] = None
    expires_in: int  # Segundos hasta que expire la URL

# Esquema para estadísticas de imágenes clínicas
class ClinicalImageStats(BaseModel):
    total_images: int
    total_size_mb: float
    images_by_type: dict
    recent_uploads: int  # Últimas 7 días
    total_views: int

# Esquema para búsqueda de imágenes clínicas
class ClinicalImageSearch(BaseModel):
    query: Optional[str] = None
    tags: Optional[str] = None
    owner_id: Optional[int] = None
    is_public: Optional[bool] = None
    skip: int = 0
    limit: int = 20

# Esquema para respuesta de búsqueda de imágenes
class ClinicalImageSearchResponse(BaseModel):
    images: List[ClinicalImageResponse]
    total: int
    skip: int
    limit: int

# Esquema para metadatos de imagen
class ImageMetadata(BaseModel):
    width: int
    height: int
    format: str
    mode: Optional[str] = None
    size_bytes: int

# === ESQUEMAS PARA FÁRMACOS ===

# Esquemas base para Drug
class DrugBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    generic_name: Optional[str] = Field(None, max_length=200)
    brand_names: Optional[str] = Field(None, max_length=1000)  # JSON string
    therapeutic_class: Optional[str] = Field(None, max_length=100)
    mechanism_of_action: Optional[str] = Field(None, max_length=2000)
    indications: Optional[str] = Field(None, max_length=2000)
    contraindications: Optional[str] = Field(None, max_length=2000)
    dosage: Optional[str] = Field(None, max_length=1000)
    side_effects: Optional[str] = Field(None, max_length=2000)
    interactions: Optional[str] = Field(None, max_length=2000)
    precautions: Optional[str] = Field(None, max_length=2000)
    pregnancy_category: Optional[str] = Field(None, max_length=10)
    pediatric_use: bool = False
    geriatric_use: bool = False
    route_of_administration: Optional[str] = Field(None, max_length=100)
    strength: Optional[str] = Field(None, max_length=100)
    presentation: Optional[str] = Field(None, max_length=200)
    laboratory: Optional[str] = Field(None, max_length=100)
    active_ingredient: Optional[str] = Field(None, max_length=200)
    is_prescription_only: bool = True
    is_controlled_substance: bool = False

# Esquema para crear un fármaco
class DrugCreate(DrugBase):
    pass

# Esquema para actualizar un fármaco
class DrugUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    generic_name: Optional[str] = Field(None, max_length=200)
    brand_names: Optional[str] = Field(None, max_length=1000)
    therapeutic_class: Optional[str] = Field(None, max_length=100)
    mechanism_of_action: Optional[str] = Field(None, max_length=2000)
    indications: Optional[str] = Field(None, max_length=2000)
    contraindications: Optional[str] = Field(None, max_length=2000)
    dosage: Optional[str] = Field(None, max_length=1000)
    side_effects: Optional[str] = Field(None, max_length=2000)
    interactions: Optional[str] = Field(None, max_length=2000)
    precautions: Optional[str] = Field(None, max_length=2000)
    pregnancy_category: Optional[str] = Field(None, max_length=10)
    pediatric_use: Optional[bool] = None
    geriatric_use: Optional[bool] = None
    route_of_administration: Optional[str] = Field(None, max_length=100)
    strength: Optional[str] = Field(None, max_length=100)
    presentation: Optional[str] = Field(None, max_length=200)
    laboratory: Optional[str] = Field(None, max_length=100)
    active_ingredient: Optional[str] = Field(None, max_length=200)
    is_prescription_only: Optional[bool] = None
    is_controlled_substance: Optional[bool] = None
    is_active: Optional[bool] = None

# Esquema para respuesta de fármaco
class DrugResponse(DrugBase):
    id: int
    uuid: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# Esquema para búsqueda de fármacos
class DrugSearch(BaseModel):
    query: Optional[str] = None
    therapeutic_class: Optional[str] = None
    is_prescription_only: Optional[bool] = None
    is_controlled_substance: Optional[bool] = None
    pediatric_use: Optional[bool] = None
    geriatric_use: Optional[bool] = None
    skip: int = 0
    limit: int = 20

# Esquema para respuesta de búsqueda de fármacos
class DrugSearchResponse(BaseModel):
    drugs: List[DrugResponse]
    total: int
    skip: int
    limit: int

# === ESQUEMAS PARA CALCULADORAS CLÍNICAS ===

# Esquema para resultado de calculadora
class CalculatorResult(BaseModel):
    score: float
    risk_level: str
    interpretation: str
    recommendations: str

# Esquema para CURB-65
class CURB65Request(BaseModel):
    confusion: bool
    urea: float = Field(..., ge=0)
    respiratory_rate: int = Field(..., ge=0, le=100)
    blood_pressure_systolic: int = Field(..., ge=0, le=300)
    blood_pressure_diastolic: int = Field(..., ge=0, le=200)
    age: int = Field(..., ge=0, le=150)

# Esquema para Wells PE
class WellsPERequest(BaseModel):
    clinical_signs_dvt: bool
    pe_likely: bool
    heart_rate_over_100: bool
    immobilization_surgery: bool
    previous_pe_dvt: bool
    hemoptysis: bool
    malignancy: bool

# Esquema para Glasgow Coma Scale
class GlasgowComaRequest(BaseModel):
    eye_opening: int = Field(..., ge=1, le=4)
    verbal_response: int = Field(..., ge=1, le=5)
    motor_response: int = Field(..., ge=1, le=6)

# Esquema para CHA2DS2-VASc
class CHADS2VAScRequest(BaseModel):
    congestive_heart_failure: bool
    hypertension: bool
    age: int = Field(..., ge=0, le=150)
    diabetes: bool
    stroke_tia_history: bool
    vascular_disease: bool
    sex_female: bool

# Esquema para lista de calculadoras
class CalculatorInfo(BaseModel):
    name: str
    description: str
    category: str
    parameters: List[dict]

# Importar esquemas de usuario para evitar errores de referencia circular
DocumentWithOwnerResponse.model_rebuild()
ClinicalImageWithOwnerResponse.model_rebuild()