from minio import Minio
from minio.error import S3Error
from urllib.parse import urljoin
import os
import uuid
import mimetypes
import logging
from typing import Optional, BinaryIO
from datetime import timedelta
from PIL import Image
from .core.config import settings

logger = logging.getLogger(__name__)

class MinIOClient:
    def __init__(self):
        """Inicializar cliente MinIO"""
        self.client = Minio(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure
        )
        self.bucket_name = settings.minio_bucket_name
        self.documents_folder = settings.minio_documents_folder
        self.images_folder = settings.minio_images_folder
        self.max_file_size = settings.minio_max_file_size
        self._ensure_bucket_exists()
    
    def _ensure_bucket_exists(self):
        """Asegurar que el bucket existe"""
        try:
            if not self.client.bucket_exists(self.bucket_name):
                self.client.make_bucket(self.bucket_name)
                logger.info(f"Bucket '{self.bucket_name}' creado en MinIO")
            else:
                logger.info(f"Bucket '{self.bucket_name}' ya existe en MinIO")
        except S3Error as e:
            logger.error(f"Error creando bucket: {e}")
            raise e
    
    def _generate_unique_filename(self, original_filename: str) -> str:
        """Generar un nombre de archivo único"""
        # Sanitizar el nombre del archivo
        name, ext = os.path.splitext(original_filename)
        # Remover caracteres peligrosos
        safe_name = "".join(c for c in name if c.isalnum() or c in (' ', '-', '_')).rstrip()
        unique_id = str(uuid.uuid4())
        return f"{safe_name}_{unique_id}{ext.lower()}"
    
    def _validate_file(self, file_data: BinaryIO, original_filename: str, content_type: str) -> dict:
        """Validar archivo antes de subirlo"""
        errors = []
        
        # Validar tamaño
        file_data.seek(0, 2)
        file_size = file_data.tell()
        file_data.seek(0)
        
        if file_size > self.max_file_size:
            errors.append(f"Archivo demasiado grande. Máximo permitido: {self.max_file_size / (1024*1024):.1f}MB")
        
        if file_size == 0:
            errors.append("El archivo está vacío")
        
        # Validar extensión
        _, ext = os.path.splitext(original_filename)
        ext = ext.lower()
        
        # Tipos de archivo permitidos
        allowed_document_types = {'.pdf', '.doc', '.docx', '.txt', '.ppt', '.pptx', '.xls', '.xlsx'}
        allowed_image_types = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'}
        
        if content_type.startswith('image/'):
            if ext not in allowed_image_types:
                errors.append(f"Tipo de imagen no permitido: {ext}")
        elif content_type.startswith('application/') or content_type.startswith('text/'):
            if ext not in allowed_document_types:
                errors.append(f"Tipo de documento no permitido: {ext}")
        else:
            errors.append(f"Tipo de archivo no permitido: {content_type}")
        
        return {
            "valid": len(errors) == 0,
            "errors": errors,
            "file_size": file_size
        }
    
    def _get_file_path(self, filename: str, folder: str = None) -> str:
        """Obtener la ruta completa del archivo en MinIO"""
        if folder is None:
            folder = self.documents_folder
        return f"{folder}/{filename}"
    
    def upload_file(
        self, 
        file_data: BinaryIO, 
        original_filename: str, 
        content_type: Optional[str] = None,
        folder: str = None
    ) -> dict:
        """
        Subir un archivo a MinIO
        
        Args:
            file_data: Datos binarios del archivo
            original_filename: Nombre original del archivo
            content_type: Tipo MIME del archivo
        
        Returns:
            dict: Información del archivo subido
        """
        try:
            # Detectar tipo MIME si no se proporciona
            if not content_type:
                content_type, _ = mimetypes.guess_type(original_filename)
                content_type = content_type or 'application/octet-stream'
            
            # Validar archivo
            validation = self._validate_file(file_data, original_filename, content_type)
            if not validation["valid"]:
                return {
                    "success": False,
                    "errors": validation["errors"]
                }
            
            # Generar nombre único para el archivo
            unique_filename = self._generate_unique_filename(original_filename)
            file_path = self._get_file_path(unique_filename, folder)
            
            file_size = validation["file_size"]
            
            # Subir archivo a MinIO
            self.client.put_object(
                bucket_name=self.bucket_name,
                object_name=file_path,
                data=file_data,
                length=file_size,
                content_type=content_type
            )
            
            # Obtener extensión del archivo
            _, file_extension = os.path.splitext(original_filename)
            
            result = {
                "filename": unique_filename,
                "original_filename": original_filename,
                "file_path": file_path,
                "file_size": file_size,
                "file_type": content_type,
                "file_extension": file_extension.lower(),
                "success": True
            }
            
            # Si es imagen, agregar dimensiones
            if folder == self.images_folder and content_type.startswith('image/'):
                try:
                    file_data.seek(0)
                    with Image.open(file_data) as img:
                        result["image_width"] = img.width
                        result["image_height"] = img.height
                except Exception as e:
                    logger.warning(f"Error obteniendo dimensiones de imagen: {e}")
                    result["image_width"] = None
                    result["image_height"] = None
            
            logger.info(f"Archivo subido exitosamente: {file_path}")
            return result
            
        except S3Error as e:
            logger.error(f"Error subiendo archivo a MinIO: {e}")
            return {
                "success": False,
                "error": str(e)
            }
        except Exception as e:
            logger.error(f"Error inesperado subiendo archivo: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def download_file(self, file_path: str) -> Optional[bytes]:
        """
        Descargar un archivo de MinIO
        
        Args:
            file_path: Ruta del archivo en MinIO
        
        Returns:
            bytes: Contenido del archivo o None si hay error
        """
        try:
            response = self.client.get_object(self.bucket_name, file_path)
            data = response.read()
            response.close()
            response.release_conn()
            return data
        except S3Error as e:
            print(f"❌ Error descargando archivo de MinIO: {e}")
            return None
        except Exception as e:
            print(f"❌ Error inesperado descargando archivo: {e}")
            return None
    
    def get_download_url(self, file_path: str, expires: timedelta = timedelta(hours=1)) -> Optional[str]:
        """
        Generar URL de descarga presignada
        
        Args:
            file_path: Ruta del archivo en MinIO
            expires: Tiempo de expiración de la URL
        
        Returns:
            str: URL de descarga presignada o None si hay error
        """
        try:
            url = self.client.presigned_get_object(
                bucket_name=self.bucket_name,
                object_name=file_path,
                expires=expires
            )
            return url
        except S3Error as e:
            print(f"❌ Error generando URL de descarga: {e}")
            return None
        except Exception as e:
            print(f"❌ Error inesperado generando URL: {e}")
            return None
    
    def delete_file(self, file_path: str) -> bool:
        """
        Eliminar un archivo de MinIO
        
        Args:
            file_path: Ruta del archivo en MinIO
        
        Returns:
            bool: True si se eliminó correctamente, False en caso contrario
        """
        try:
            self.client.remove_object(self.bucket_name, file_path)
            return True
        except S3Error as e:
            print(f"❌ Error eliminando archivo de MinIO: {e}")
            return False
        except Exception as e:
            print(f"❌ Error inesperado eliminando archivo: {e}")
            return False
    
    def file_exists(self, file_path: str) -> bool:
        """
        Verificar si un archivo existe en MinIO
        
        Args:
            file_path: Ruta del archivo en MinIO
        
        Returns:
            bool: True si el archivo existe, False en caso contrario
        """
        try:
            self.client.stat_object(self.bucket_name, file_path)
            return True
        except S3Error:
            return False
        except Exception:
            return False
    
    def get_file_info(self, file_path: str) -> Optional[dict]:
        """
        Obtener información de un archivo en MinIO
        
        Args:
            file_path: Ruta del archivo en MinIO
        
        Returns:
            dict: Información del archivo o None si hay error
        """
        try:
            stat = self.client.stat_object(self.bucket_name, file_path)
            return {
                "file_path": file_path,
                "size": stat.size,
                "content_type": stat.content_type,
                "etag": stat.etag,
                "last_modified": stat.last_modified,
                "metadata": stat.metadata
            }
        except S3Error as e:
            print(f"❌ Error obteniendo información del archivo: {e}")
            return None
        except Exception as e:
            print(f"❌ Error inesperado obteniendo información: {e}")
            return None
    
    def list_files(self, prefix: str = None) -> list:
        """
        Listar archivos en MinIO
        
        Args:
            prefix: Prefijo para filtrar archivos
        
        Returns:
            list: Lista de archivos
        """
        try:
            search_prefix = f"{self.documents_folder}/"
            if prefix:
                search_prefix += prefix
            
            objects = self.client.list_objects(
                bucket_name=self.bucket_name,
                prefix=search_prefix,
                recursive=True
            )
            
            files = []
            for obj in objects:
                files.append({
                    "name": obj.object_name,
                    "size": obj.size,
                    "last_modified": obj.last_modified,
                    "etag": obj.etag
                })
            
            return files
        except S3Error as e:
            print(f"❌ Error listando archivos: {e}")
            return []
        except Exception as e:
            print(f"❌ Error inesperado listando archivos: {e}")
            return []
    
    def get_bucket_info(self) -> dict:
        """
        Obtener información del bucket
        
        Returns:
            dict: Información del bucket
        """
        try:
            # Verificar si el bucket existe
            exists = self.client.bucket_exists(self.bucket_name)
            
            if not exists:
                return {
                    "bucket_name": self.bucket_name,
                    "exists": False,
                    "total_objects": 0,
                    "total_size": 0
                }
            
            # Contar objetos y calcular tamaño total
            objects = self.client.list_objects(
                bucket_name=self.bucket_name,
                prefix=f"{self.documents_folder}/",
                recursive=True
            )
            
            total_objects = 0
            total_size = 0
            
            for obj in objects:
                total_objects += 1
                total_size += obj.size
            
            return {
                "bucket_name": self.bucket_name,
                "exists": True,
                "total_objects": total_objects,
                "total_size": total_size,
                "total_size_mb": round(total_size / (1024 * 1024), 2)
            }
            
        except S3Error as e:
            print(f"❌ Error obteniendo información del bucket: {e}")
            return {
                "bucket_name": self.bucket_name,
                "exists": False,
                "error": str(e)
            }
        except Exception as e:
            print(f"❌ Error inesperado obteniendo información del bucket: {e}")
            return {
                "bucket_name": self.bucket_name,
                "exists": False,
                "error": str(e)
            }

# Instancia global del cliente MinIO
minio_client = MinIOClient()

# Funciones de conveniencia para documentos
def upload_document(file_data: BinaryIO, original_filename: str, content_type: Optional[str] = None) -> dict:
    """Función de conveniencia para subir documentos"""
    return minio_client.upload_file(file_data, original_filename, content_type, minio_client.documents_folder)

def download_document(file_path: str) -> Optional[bytes]:
    """Función de conveniencia para descargar documentos"""
    return minio_client.download_file(file_path)

def get_document_download_url(file_path: str, expires_hours: int = 1) -> Optional[str]:
    """Función de conveniencia para obtener URL de descarga"""
    return minio_client.get_download_url(file_path, timedelta(hours=expires_hours))

def delete_document(file_path: str) -> bool:
    """Función de conveniencia para eliminar documentos"""
    return minio_client.delete_file(file_path)

def document_exists(file_path: str) -> bool:
    """Función de conveniencia para verificar si un documento existe"""
    return minio_client.file_exists(file_path)

# Funciones de conveniencia para imágenes clínicas
def upload_clinical_image(file_data: BinaryIO, original_filename: str, content_type: Optional[str] = None) -> dict:
    """Función de conveniencia para subir imágenes clínicas"""
    return minio_client.upload_file(file_data, original_filename, content_type, minio_client.images_folder)

def download_clinical_image(file_path: str) -> Optional[bytes]:
    """Función de conveniencia para descargar imágenes clínicas"""
    return minio_client.download_file(file_path)

def get_clinical_image_url(file_path: str, expires_hours: int = 1) -> Optional[str]:
    """Función de conveniencia para obtener URL de imagen clínica"""
    return minio_client.get_download_url(file_path, timedelta(hours=expires_hours))

def delete_clinical_image(file_path: str) -> bool:
    """Función de conveniencia para eliminar imágenes clínicas"""
    return minio_client.delete_file(file_path)

def clinical_image_exists(file_path: str) -> bool:
    """Función de conveniencia para verificar si una imagen clínica existe"""
    return minio_client.file_exists(file_path)