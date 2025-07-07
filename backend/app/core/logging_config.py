import logging
import logging.config
import os
from datetime import datetime
from typing import Dict, Any


def setup_logging() -> None:
    """
    Configure logging for the application
    """
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    log_dir = os.getenv("LOG_DIR", "logs")
    
    # Create logs directory if it doesn't exist
    os.makedirs(log_dir, exist_ok=True)
    
    # Generate log filename with current date
    current_date = datetime.now().strftime("%Y-%m-%d")
    log_file = os.path.join(log_dir, f"resicentral_{current_date}.log")
    error_log_file = os.path.join(log_dir, f"resicentral_errors_{current_date}.log")
    
    logging_config: Dict[str, Any] = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "detailed": {
                "format": "%(asctime)s - %(name)s - %(levelname)s - %(module)s:%(lineno)d - %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S"
            },
            "simple": {
                "format": "%(levelname)s - %(message)s"
            },
            "json": {
                "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
                "format": "%(asctime)s %(name)s %(levelname)s %(module)s %(lineno)d %(message)s"
            }
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "level": "DEBUG",
                "formatter": "simple",
                "stream": "ext://sys.stdout"
            },
            "file": {
                "class": "logging.handlers.RotatingFileHandler",
                "level": log_level,
                "formatter": "detailed",
                "filename": log_file,
                "maxBytes": 10 * 1024 * 1024,  # 10MB
                "backupCount": 5,
                "encoding": "utf8"
            },
            "error_file": {
                "class": "logging.handlers.RotatingFileHandler",
                "level": "ERROR",
                "formatter": "detailed",
                "filename": error_log_file,
                "maxBytes": 10 * 1024 * 1024,  # 10MB
                "backupCount": 5,
                "encoding": "utf8"
            }
        },
        "loggers": {
            "": {  # root logger
                "level": log_level,
                "handlers": ["console", "file", "error_file"],
                "propagate": False
            },
            "uvicorn": {
                "level": "INFO",
                "handlers": ["console", "file"],
                "propagate": False
            },
            "uvicorn.error": {
                "level": "INFO",
                "handlers": ["console", "file", "error_file"],
                "propagate": False
            },
            "uvicorn.access": {
                "level": "INFO",
                "handlers": ["file"],
                "propagate": False
            },
            "sqlalchemy.engine": {
                "level": "WARNING",
                "handlers": ["file"],
                "propagate": False
            },
            "minio": {
                "level": "WARNING",
                "handlers": ["file"],
                "propagate": False
            }
        }
    }
    
    logging.config.dictConfig(logging_config)


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the given name
    
    Args:
        name: Logger name (usually __name__)
    
    Returns:
        Logger instance
    """
    return logging.getLogger(name)


class SecurityLogger:
    """Logger specifically for security events"""
    
    def __init__(self):
        self.logger = get_logger("security")
        
        # Add security-specific handler if in production
        if os.getenv("ENVIRONMENT") == "production":
            security_log_file = os.path.join(
                os.getenv("LOG_DIR", "logs"), 
                f"security_{datetime.now().strftime('%Y-%m-%d')}.log"
            )
            
            security_handler = logging.handlers.RotatingFileHandler(
                security_log_file,
                maxBytes=10 * 1024 * 1024,
                backupCount=10
            )
            
            security_formatter = logging.Formatter(
                "%(asctime)s - SECURITY - %(levelname)s - %(message)s",
                datefmt="%Y-%m-%d %H:%M:%S"
            )
            
            security_handler.setFormatter(security_formatter)
            self.logger.addHandler(security_handler)
    
    def log_login_attempt(self, email: str, success: bool, ip_address: str = None):
        """Log login attempts"""
        status = "SUCCESS" if success else "FAILED"
        message = f"Login {status} for user: {email}"
        if ip_address:
            message += f" from IP: {ip_address}"
        
        if success:
            self.logger.info(message)
        else:
            self.logger.warning(message)
    
    def log_file_upload(self, user_id: int, filename: str, file_size: int, success: bool):
        """Log file upload attempts"""
        status = "SUCCESS" if success else "FAILED"
        message = f"File upload {status} - User: {user_id}, File: {filename}, Size: {file_size}"
        
        if success:
            self.logger.info(message)
        else:
            self.logger.warning(message)
    
    def log_permission_denied(self, user_id: int, action: str, resource: str):
        """Log permission denied events"""
        message = f"Permission denied - User: {user_id}, Action: {action}, Resource: {resource}"
        self.logger.warning(message)
    
    def log_api_access(self, user_id: int, endpoint: str, method: str, status_code: int):
        """Log API access"""
        message = f"API access - User: {user_id}, Endpoint: {endpoint}, Method: {method}, Status: {status_code}"
        self.logger.info(message)
    
    def log_data_access(self, user_id: int, resource_type: str, resource_id: int):
        """Log sensitive data access"""
        message = f"Data access - User: {user_id}, Type: {resource_type}, ID: {resource_id}"
        self.logger.info(message)


class PerformanceLogger:
    """Logger for performance monitoring"""
    
    def __init__(self):
        self.logger = get_logger("performance")
    
    def log_slow_query(self, query: str, duration: float, threshold: float = 1.0):
        """Log slow database queries"""
        if duration > threshold:
            self.logger.warning(f"Slow query detected - Duration: {duration:.2f}s - Query: {query[:100]}...")
    
    def log_api_response_time(self, endpoint: str, method: str, duration: float, threshold: float = 2.0):
        """Log slow API responses"""
        if duration > threshold:
            self.logger.warning(f"Slow API response - Endpoint: {endpoint}, Method: {method}, Duration: {duration:.2f}s")
    
    def log_file_operation_time(self, operation: str, filename: str, duration: float):
        """Log file operation times"""
        self.logger.info(f"File operation - Operation: {operation}, File: {filename}, Duration: {duration:.2f}s")


# Global logger instances
security_logger = SecurityLogger()
performance_logger = PerformanceLogger()