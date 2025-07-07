import pytest
import tempfile
import os
from typing import Generator
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import User, Drug, Document, ClinicalImage, Procedure, Algorithm, Shift
from app.security import get_password_hash, create_access_token
from app import crud


# Test database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session")
def db_engine():
    """Create test database engine."""
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session(db_engine):
    """Create a fresh database session for each test."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session):
    """Create test client with dependency override."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()


@pytest.fixture
def test_user_data():
    """Test user data."""
    return {
        "email": "test@example.com",
        "username": "testuser",
        "first_name": "Test",
        "last_name": "User",
        "password": "testpassword123"
    }


@pytest.fixture
def test_superuser_data():
    """Test superuser data."""
    return {
        "email": "admin@example.com",
        "username": "admin",
        "first_name": "Admin",
        "last_name": "User",
        "password": "adminpassword123"
    }


@pytest.fixture
def test_user(db_session, test_user_data):
    """Create a test user in database."""
    user_data = test_user_data.copy()
    password = user_data.pop("password")
    
    user = User(
        **user_data,
        hashed_password=get_password_hash(password),
        is_active=True,
        is_verified=True
    )
    
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    
    return user


@pytest.fixture
def test_superuser(db_session, test_superuser_data):
    """Create a test superuser in database."""
    user_data = test_superuser_data.copy()
    password = user_data.pop("password")
    
    user = User(
        **user_data,
        hashed_password=get_password_hash(password),
        is_active=True,
        is_verified=True,
        is_superuser=True
    )
    
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    
    return user


@pytest.fixture
def user_token(test_user):
    """Generate JWT token for test user."""
    return create_access_token(data={"sub": str(test_user.id)})


@pytest.fixture
def superuser_token(test_superuser):
    """Generate JWT token for test superuser."""
    return create_access_token(data={"sub": str(test_superuser.id)})


@pytest.fixture
def auth_headers(user_token):
    """Authorization headers for test user."""
    return {"Authorization": f"Bearer {user_token}"}


@pytest.fixture
def superuser_headers(superuser_token):
    """Authorization headers for test superuser."""
    return {"Authorization": f"Bearer {superuser_token}"}


@pytest.fixture
def test_drug_data():
    """Test drug data."""
    return {
        "name": "Paracetamol",
        "generic_name": "Acetaminophen",
        "therapeutic_class": "Analgesic",
        "mechanism_of_action": "COX inhibitor",
        "indications": "Pain and fever",
        "contraindications": "Liver disease",
        "dosage": "500mg every 6 hours",
        "side_effects": "Hepatotoxicity at high doses",
        "interactions": "Warfarin",
        "precautions": "Monitor liver function",
        "pregnancy_category": "B",
        "pediatric_use": True,
        "geriatric_use": True,
        "route_of_administration": "Oral",
        "strength": "500mg",
        "presentation": "Tablets",
        "laboratory": "Generic Lab",
        "active_ingredient": "Acetaminophen",
        "is_prescription_only": False,
        "is_controlled_substance": False
    }


@pytest.fixture
def test_drug(db_session, test_drug_data):
    """Create a test drug in database."""
    drug = Drug(**test_drug_data)
    db_session.add(drug)
    db_session.commit()
    db_session.refresh(drug)
    return drug


@pytest.fixture
def test_shift_data():
    """Test shift data."""
    from datetime import datetime, timedelta
    
    start_time = datetime.utcnow() + timedelta(hours=1)
    end_time = start_time + timedelta(hours=8)
    
    return {
        "title": "Turno de Mañana",
        "description": "Turno regular de mañana",
        "shift_type": "mañana",
        "start_date": start_time,
        "end_date": end_time,
        "location": "Hospital Central",
        "department": "Medicina Interna",
        "status": "programado",
        "priority": "normal"
    }


@pytest.fixture
def test_shift(db_session, test_user, test_shift_data):
    """Create a test shift in database."""
    shift = Shift(**test_shift_data, user_id=test_user.id)
    db_session.add(shift)
    db_session.commit()
    db_session.refresh(shift)
    return shift


@pytest.fixture
def test_procedure_data():
    """Test procedure data."""
    return {
        "title": "Intubación Endotraqueal",
        "description": "Procedimiento de vía aérea avanzada",
        "category": "Vía Aérea",
        "specialty": "Anestesiología",
        "difficulty_level": "Avanzado",
        "estimated_duration": 15,
        "objective": "Establecer vía aérea definitiva",
        "indications": "Fallo respiratorio, protección de vía aérea",
        "contraindications": "Obstrucción total de vía aérea",
        "materials_needed": '["Laringoscopio", "Tubo endotraqueal", "Ambú"]',
        "procedure_steps": '["Preoxigenación", "Inducción", "Intubación", "Confirmación"]',
        "post_procedure_care": '["Ventilación mecánica", "Sedación"]',
        "complications": '["Traumatismo dental", "Aspiración", "Intubación esofágica"]',
        "is_published": True
    }


@pytest.fixture
def test_procedure(db_session, test_user, test_procedure_data):
    """Create a test procedure in database."""
    procedure = Procedure(**test_procedure_data, created_by_id=test_user.id)
    db_session.add(procedure)
    db_session.commit()
    db_session.refresh(procedure)
    return procedure


@pytest.fixture
def mock_minio():
    """Mock MinIO client for file operations."""
    class MockMinIOClient:
        def bucket_exists(self, bucket_name):
            return True
        
        def make_bucket(self, bucket_name):
            pass
        
        def put_object(self, bucket_name, object_name, data, length, content_type=None):
            return type('obj', (), {'object_name': object_name})
        
        def get_object(self, bucket_name, object_name):
            return type('obj', (), {'read': lambda: b'test_content'})
        
        def remove_object(self, bucket_name, object_name):
            pass
        
        def presigned_get_object(self, bucket_name, object_name, expires=None):
            return f"http://test-url/{object_name}"
    
    return MockMinIOClient()


@pytest.fixture
def temp_file():
    """Create a temporary file for testing file uploads."""
    with tempfile.NamedTemporaryFile(delete=False, suffix='.txt') as tmp:
        tmp.write(b'Test file content')
        tmp.flush()
        yield tmp.name
    
    # Cleanup
    try:
        os.unlink(tmp.name)
    except OSError:
        pass


@pytest.fixture
def sample_medical_data():
    """Sample medical calculation data."""
    return {
        "curb65": {
            "confusion": True,
            "urea": 8.0,
            "respiratory_rate": 32,
            "blood_pressure_systolic": 85,
            "blood_pressure_diastolic": 55,
            "age": 72
        },
        "wells_pe": {
            "clinical_signs_dvt": True,
            "pe_likely": False,
            "heart_rate_over_100": True,
            "immobilization_surgery": True,
            "previous_pe_dvt": False,
            "hemoptysis": False,
            "malignancy": False
        },
        "glasgow_coma": {
            "eye_opening": 4,
            "verbal_response": 5,
            "motor_response": 6
        },
        "chads2_vasc": {
            "congestive_heart_failure": True,
            "hypertension": True,
            "age": 75,
            "diabetes": False,
            "stroke_tia_history": False,
            "vascular_disease": True,
            "sex_female": False
        }
    }


@pytest.fixture(autouse=True)
def cleanup_test_files():
    """Automatically cleanup test files after each test."""
    yield
    # Cleanup any temporary files created during tests
    test_files = [
        "./test.db",
        "./test.db-journal",
        "./test.db-wal",
        "./test.db-shm"
    ]
    
    for file_path in test_files:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except OSError:
            pass