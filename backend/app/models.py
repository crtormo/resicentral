from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, ForeignKey, Float
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from .database import Base
import uuid

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_superuser = Column(Boolean, default=False)
    phone = Column(String, nullable=True)
    avatar_url = Column(String, nullable=True)
    bio = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    # Relaciones
    documents = relationship("Document", back_populates="owner", cascade="all, delete-orphan")
    clinical_images = relationship("ClinicalImage", back_populates="owner", cascade="all, delete-orphan")
    shifts = relationship("Shift", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, username={self.username})>"
    
    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "email": self.email,
            "username": self.username,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "full_name": self.full_name,
            "is_active": self.is_active,
            "is_verified": self.is_verified,
            "is_superuser": self.is_superuser,
            "phone": self.phone,
            "avatar_url": self.avatar_url,
            "bio": self.bio,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "last_login": self.last_login
        }


class Drug(Base):
    __tablename__ = "drugs"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False, index=True)
    generic_name = Column(String, nullable=True, index=True)
    brand_names = Column(Text, nullable=True)  # JSON string con nombres comerciales
    therapeutic_class = Column(String, nullable=True, index=True)
    mechanism_of_action = Column(Text, nullable=True)
    indications = Column(Text, nullable=True)
    contraindications = Column(Text, nullable=True)
    dosage = Column(Text, nullable=True)
    side_effects = Column(Text, nullable=True)
    interactions = Column(Text, nullable=True)
    precautions = Column(Text, nullable=True)
    pregnancy_category = Column(String, nullable=True)
    pediatric_use = Column(Boolean, default=False)
    geriatric_use = Column(Boolean, default=False)
    route_of_administration = Column(String, nullable=True)
    strength = Column(String, nullable=True)
    presentation = Column(String, nullable=True)
    laboratory = Column(String, nullable=True)
    active_ingredient = Column(String, nullable=True)
    is_prescription_only = Column(Boolean, default=True)
    is_controlled_substance = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    def __repr__(self):
        return f"<Drug(id={self.id}, name={self.name}, generic_name={self.generic_name})>"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "name": self.name,
            "generic_name": self.generic_name,
            "brand_names": self.brand_names,
            "therapeutic_class": self.therapeutic_class,
            "mechanism_of_action": self.mechanism_of_action,
            "indications": self.indications,
            "contraindications": self.contraindications,
            "dosage": self.dosage,
            "side_effects": self.side_effects,
            "interactions": self.interactions,
            "precautions": self.precautions,
            "pregnancy_category": self.pregnancy_category,
            "pediatric_use": self.pediatric_use,
            "geriatric_use": self.geriatric_use,
            "route_of_administration": self.route_of_administration,
            "strength": self.strength,
            "presentation": self.presentation,
            "laboratory": self.laboratory,
            "active_ingredient": self.active_ingredient,
            "is_prescription_only": self.is_prescription_only,
            "is_controlled_substance": self.is_controlled_substance,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }


class Document(Base):
    __tablename__ = "documents"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    filename = Column(String, nullable=False)
    original_filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    file_size = Column(Float, nullable=False)  # Tamaño en bytes
    file_type = Column(String, nullable=False)  # MIME type
    file_extension = Column(String, nullable=False)
    category = Column(String, nullable=True)  # PDF, PPT, DOC, etc.
    tags = Column(Text, nullable=True)  # JSON string con tags
    is_public = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    download_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Clave foránea al usuario propietario
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relación con el usuario
    owner = relationship("User", back_populates="documents")
    
    def __repr__(self):
        return f"<Document(id={self.id}, title={self.title}, filename={self.filename})>"
    
    @property
    def file_size_mb(self):
        """Retorna el tamaño del archivo en MB"""
        return round(self.file_size / (1024 * 1024), 2)
    
    @property
    def file_size_human(self):
        """Retorna el tamaño del archivo en formato legible"""
        if self.file_size < 1024:
            return f"{self.file_size} B"
        elif self.file_size < 1024 * 1024:
            return f"{round(self.file_size / 1024, 2)} KB"
        elif self.file_size < 1024 * 1024 * 1024:
            return f"{round(self.file_size / (1024 * 1024), 2)} MB"
        else:
            return f"{round(self.file_size / (1024 * 1024 * 1024), 2)} GB"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "title": self.title,
            "description": self.description,
            "filename": self.filename,
            "original_filename": self.original_filename,
            "file_path": self.file_path,
            "file_size": self.file_size,
            "file_size_mb": self.file_size_mb,
            "file_size_human": self.file_size_human,
            "file_type": self.file_type,
            "file_extension": self.file_extension,
            "category": self.category,
            "tags": self.tags,
            "is_public": self.is_public,
            "is_active": self.is_active,
            "download_count": self.download_count,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "owner_id": self.owner_id,
            "owner": self.owner.to_dict() if self.owner else None
        }


class ClinicalImage(Base):
    __tablename__ = "clinical_images"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    description = Column(Text, nullable=True)
    tags = Column(Text, nullable=True)  # JSON string con tags/keywords
    image_key = Column(String, nullable=False, unique=True)  # Clave única para MinIO
    original_filename = Column(String, nullable=False)
    file_size = Column(Float, nullable=False)  # Tamaño en bytes
    file_type = Column(String, nullable=False)  # MIME type
    image_width = Column(Integer, nullable=True)  # Ancho de la imagen
    image_height = Column(Integer, nullable=True)  # Alto de la imagen
    is_public = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    view_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Clave foránea al usuario propietario
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relación con el usuario
    owner = relationship("User", back_populates="clinical_images")
    
    def __repr__(self):
        return f"<ClinicalImage(id={self.id}, image_key={self.image_key}, owner_id={self.owner_id})>"
    
    @property
    def file_size_mb(self):
        """Retorna el tamaño del archivo en MB"""
        return round(self.file_size / (1024 * 1024), 2)
    
    @property
    def file_size_human(self):
        """Retorna el tamaño del archivo en formato legible"""
        if self.file_size < 1024:
            return f"{self.file_size} B"
        elif self.file_size < 1024 * 1024:
            return f"{round(self.file_size / 1024, 2)} KB"
        elif self.file_size < 1024 * 1024 * 1024:
            return f"{round(self.file_size / (1024 * 1024), 2)} MB"
        else:
            return f"{round(self.file_size / (1024 * 1024 * 1024), 2)} GB"
    
    @property
    def image_dimensions(self):
        """Retorna las dimensiones de la imagen"""
        if self.image_width and self.image_height:
            return f"{self.image_width} x {self.image_height}"
        return "Desconocido"
    
    @property
    def aspect_ratio(self):
        """Calcula la relación de aspecto de la imagen"""
        if self.image_width and self.image_height:
            return round(self.image_width / self.image_height, 2)
        return None
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "description": self.description,
            "tags": self.tags,
            "image_key": self.image_key,
            "original_filename": self.original_filename,
            "file_size": self.file_size,
            "file_size_mb": self.file_size_mb,
            "file_size_human": self.file_size_human,
            "file_type": self.file_type,
            "image_width": self.image_width,
            "image_height": self.image_height,
            "image_dimensions": self.image_dimensions,
            "aspect_ratio": self.aspect_ratio,
            "is_public": self.is_public,
            "is_active": self.is_active,
            "view_count": self.view_count,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "owner_id": self.owner_id,
            "owner": self.owner.to_dict() if self.owner else None
        }


class Procedure(Base):
    __tablename__ = "procedures"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    category = Column(String, nullable=True, index=True)
    specialty = Column(String, nullable=True, index=True)
    difficulty_level = Column(String, nullable=True)  # Básico, Intermedio, Avanzado
    estimated_duration = Column(Integer, nullable=True)  # Minutos
    
    # Contenido estructurado
    objective = Column(Text, nullable=True)
    indications = Column(Text, nullable=True)
    contraindications = Column(Text, nullable=True)
    materials_needed = Column(Text, nullable=True)  # JSON string con lista de materiales
    preparation_steps = Column(Text, nullable=True)  # JSON string con pasos de preparación
    procedure_steps = Column(Text, nullable=True)  # JSON string con pasos del procedimiento
    post_procedure_care = Column(Text, nullable=True)  # JSON string con cuidados posteriores
    complications = Column(Text, nullable=True)  # JSON string con posibles complicaciones
    tips_and_tricks = Column(Text, nullable=True)  # JSON string con consejos
    
    # Multimedia
    video_url = Column(String, nullable=True)
    images = Column(Text, nullable=True)  # JSON string con URLs de imágenes
    references = Column(Text, nullable=True)  # JSON string con referencias bibliográficas
    
    # Metadatos
    tags = Column(Text, nullable=True)  # JSON string con tags
    is_published = Column(Boolean, default=False)
    is_featured = Column(Boolean, default=False)
    view_count = Column(Integer, default=0)
    rating_average = Column(Float, default=0.0)
    rating_count = Column(Integer, default=0)
    
    # Auditoría
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    updated_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Relaciones
    created_by = relationship("User", foreign_keys=[created_by_id])
    updated_by = relationship("User", foreign_keys=[updated_by_id])
    
    def __repr__(self):
        return f"<Procedure(id={self.id}, title={self.title}, category={self.category})>"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "title": self.title,
            "description": self.description,
            "category": self.category,
            "specialty": self.specialty,
            "difficulty_level": self.difficulty_level,
            "estimated_duration": self.estimated_duration,
            "objective": self.objective,
            "indications": self.indications,
            "contraindications": self.contraindications,
            "materials_needed": self.materials_needed,
            "preparation_steps": self.preparation_steps,
            "procedure_steps": self.procedure_steps,
            "post_procedure_care": self.post_procedure_care,
            "complications": self.complications,
            "tips_and_tricks": self.tips_and_tricks,
            "video_url": self.video_url,
            "images": self.images,
            "references": self.references,
            "tags": self.tags,
            "is_published": self.is_published,
            "is_featured": self.is_featured,
            "view_count": self.view_count,
            "rating_average": self.rating_average,
            "rating_count": self.rating_count,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "created_by_id": self.created_by_id,
            "updated_by_id": self.updated_by_id,
            "created_by": self.created_by.to_dict() if self.created_by else None,
            "updated_by": self.updated_by.to_dict() if self.updated_by else None,
        }


class Algorithm(Base):
    __tablename__ = "algorithms"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    category = Column(String, nullable=True, index=True)
    specialty = Column(String, nullable=True, index=True)
    
    # Configuración del algoritmo
    algorithm_type = Column(String, nullable=False)  # decision_tree, flowchart, checklist
    start_node_id = Column(Integer, nullable=True)  # ID del nodo inicial
    
    # Metadatos
    tags = Column(Text, nullable=True)  # JSON string con tags
    is_published = Column(Boolean, default=False)
    is_featured = Column(Boolean, default=False)
    view_count = Column(Integer, default=0)
    usage_count = Column(Integer, default=0)
    
    # Auditoría
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    updated_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Relaciones
    created_by = relationship("User", foreign_keys=[created_by_id])
    updated_by = relationship("User", foreign_keys=[updated_by_id])
    nodes = relationship("AlgorithmNode", back_populates="algorithm", cascade="all, delete-orphan")
    edges = relationship("AlgorithmEdge", back_populates="algorithm", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Algorithm(id={self.id}, title={self.title}, type={self.algorithm_type})>"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "title": self.title,
            "description": self.description,
            "category": self.category,
            "specialty": self.specialty,
            "algorithm_type": self.algorithm_type,
            "start_node_id": self.start_node_id,
            "tags": self.tags,
            "is_published": self.is_published,
            "is_featured": self.is_featured,
            "view_count": self.view_count,
            "usage_count": self.usage_count,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "created_by_id": self.created_by_id,
            "updated_by_id": self.updated_by_id,
            "created_by": self.created_by.to_dict() if self.created_by else None,
            "updated_by": self.updated_by.to_dict() if self.updated_by else None,
        }


class AlgorithmNode(Base):
    __tablename__ = "algorithm_nodes"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    algorithm_id = Column(Integer, ForeignKey("algorithms.id"), nullable=False)
    
    # Información del nodo
    node_type = Column(String, nullable=False)  # start, decision, action, end, input
    title = Column(String, nullable=False)
    content = Column(Text, nullable=True)
    
    # Configuración específica por tipo
    question = Column(Text, nullable=True)  # Para nodos de decisión
    action_description = Column(Text, nullable=True)  # Para nodos de acción
    input_type = Column(String, nullable=True)  # text, number, boolean, select
    input_options = Column(Text, nullable=True)  # JSON string con opciones para select
    validation_rules = Column(Text, nullable=True)  # JSON string con reglas de validación
    
    # Posición en el canvas (para editor visual)
    position_x = Column(Float, default=0.0)
    position_y = Column(Float, default=0.0)
    
    # Estilo visual
    color = Column(String, nullable=True)
    icon = Column(String, nullable=True)
    
    # Metadatos
    order_index = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relaciones
    algorithm = relationship("Algorithm", back_populates="nodes")
    outgoing_edges = relationship("AlgorithmEdge", foreign_keys="[AlgorithmEdge.from_node_id]", back_populates="from_node")
    incoming_edges = relationship("AlgorithmEdge", foreign_keys="[AlgorithmEdge.to_node_id]", back_populates="to_node")
    
    def __repr__(self):
        return f"<AlgorithmNode(id={self.id}, type={self.node_type}, title={self.title})>"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "algorithm_id": self.algorithm_id,
            "node_type": self.node_type,
            "title": self.title,
            "content": self.content,
            "question": self.question,
            "action_description": self.action_description,
            "input_type": self.input_type,
            "input_options": self.input_options,
            "validation_rules": self.validation_rules,
            "position_x": self.position_x,
            "position_y": self.position_y,
            "color": self.color,
            "icon": self.icon,
            "order_index": self.order_index,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


class AlgorithmEdge(Base):
    __tablename__ = "algorithm_edges"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    algorithm_id = Column(Integer, ForeignKey("algorithms.id"), nullable=False)
    from_node_id = Column(Integer, ForeignKey("algorithm_nodes.id"), nullable=False)
    to_node_id = Column(Integer, ForeignKey("algorithm_nodes.id"), nullable=False)
    
    # Información de la conexión
    label = Column(String, nullable=True)  # Etiqueta de la conexión (ej: "Sí", "No", "Si >50")
    condition = Column(Text, nullable=True)  # Condición lógica para evaluar
    condition_type = Column(String, nullable=True)  # equals, greater_than, less_than, contains, etc.
    condition_value = Column(String, nullable=True)  # Valor a comparar
    
    # Estilo visual
    color = Column(String, nullable=True)
    line_style = Column(String, default="solid")  # solid, dashed, dotted
    thickness = Column(Integer, default=2)
    
    # Metadatos
    order_index = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relaciones
    algorithm = relationship("Algorithm", back_populates="edges")
    from_node = relationship("AlgorithmNode", foreign_keys=[from_node_id], back_populates="outgoing_edges")
    to_node = relationship("AlgorithmNode", foreign_keys=[to_node_id], back_populates="incoming_edges")
    
    def __repr__(self):
        return f"<AlgorithmEdge(id={self.id}, from={self.from_node_id}, to={self.to_node_id}, label={self.label})>"
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "algorithm_id": self.algorithm_id,
            "from_node_id": self.from_node_id,
            "to_node_id": self.to_node_id,
            "label": self.label,
            "condition": self.condition,
            "condition_type": self.condition_type,
            "condition_value": self.condition_value,
            "color": self.color,
            "line_style": self.line_style,
            "thickness": self.thickness,
            "order_index": self.order_index,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


class Shift(Base):
    __tablename__ = "shifts"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String, unique=True, index=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    
    # Información del turno
    shift_type = Column(String, nullable=False)  # mañana, tarde, noche, guardia
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    location = Column(String, nullable=True)  # Hospital, consultorio, etc.
    department = Column(String, nullable=True)  # Servicio médico
    
    # Estado del turno
    status = Column(String, default="programado")  # programado, confirmado, completado, cancelado
    is_recurring = Column(Boolean, default=False)
    recurrence_pattern = Column(String, nullable=True)  # semanal, mensual, etc.
    recurrence_end_date = Column(DateTime(timezone=True), nullable=True)
    
    # Información adicional
    notes = Column(Text, nullable=True)
    color = Column(String, nullable=True)  # Color para mostrar en el calendario
    priority = Column(String, default="normal")  # baja, normal, alta, urgente
    
    # Recordatorios
    reminder_enabled = Column(Boolean, default=True)
    reminder_minutes_before = Column(Integer, default=60)  # minutos antes del turno
    
    # Metadatos
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Clave foránea al usuario
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relación con el usuario
    user = relationship("User", back_populates="shifts")
    
    def __repr__(self):
        return f"<Shift(id={self.id}, title={self.title}, type={self.shift_type}, date={self.start_date})>"
    
    @property
    def duration_hours(self):
        """Calcula la duración del turno en horas"""
        if self.start_date and self.end_date:
            delta = self.end_date - self.start_date
            return round(delta.total_seconds() / 3600, 2)
        return 0
    
    @property
    def is_today(self):
        """Verifica si el turno es hoy"""
        from datetime import datetime, timezone
        today = datetime.now(timezone.utc).date()
        return self.start_date.date() == today
    
    @property
    def is_upcoming(self):
        """Verifica si el turno es futuro"""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        return self.start_date > now
    
    @property
    def is_active(self):
        """Verifica si el turno está actualmente activo"""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        return self.start_date <= now <= self.end_date
    
    def to_dict(self):
        return {
            "id": self.id,
            "uuid": self.uuid,
            "title": self.title,
            "description": self.description,
            "shift_type": self.shift_type,
            "start_date": self.start_date,
            "end_date": self.end_date,
            "location": self.location,
            "department": self.department,
            "status": self.status,
            "is_recurring": self.is_recurring,
            "recurrence_pattern": self.recurrence_pattern,
            "recurrence_end_date": self.recurrence_end_date,
            "notes": self.notes,
            "color": self.color,
            "priority": self.priority,
            "reminder_enabled": self.reminder_enabled,
            "reminder_minutes_before": self.reminder_minutes_before,
            "duration_hours": self.duration_hours,
            "is_today": self.is_today,
            "is_upcoming": self.is_upcoming,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "user_id": self.user_id,
            "user": self.user.to_dict() if self.user else None,
        }