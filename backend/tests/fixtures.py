"""
Test fixtures and mock data for ResiCentral tests.
"""
import pytest
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models import User, Document, ClinicalImage, Drug, Procedure, Algorithm, AlgorithmNode, AlgorithmEdge, Shift
from app.security import get_password_hash
from app.main import app


# Test Database Configuration
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session")
def test_db():
    """Create test database."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def db_session(test_db):
    """Create a fresh database session for each test."""
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture(scope="function")
def override_get_db(db_session):
    """Override the get_db dependency for testing."""
    def _override_get_db():
        yield db_session
    
    app.dependency_overrides[get_db] = _override_get_db
    yield
    app.dependency_overrides.clear()


# User Fixtures
@pytest.fixture
def test_user_data():
    """Basic user data for testing."""
    return {
        "email": "test@example.com",
        "username": "testuser",
        "first_name": "Test",
        "last_name": "User",
        "password": "TestPassword123",
        "phone": "+1234567890",
        "bio": "Test user biography"
    }


@pytest.fixture
def test_superuser_data():
    """Superuser data for testing."""
    return {
        "email": "admin@example.com",
        "username": "admin",
        "first_name": "Admin",
        "last_name": "User",
        "password": "AdminPassword123",
        "is_superuser": True
    }


@pytest.fixture
def test_user(db_session, test_user_data):
    """Create a test user in the database."""
    user = User(
        email=test_user_data["email"],
        username=test_user_data["username"],
        first_name=test_user_data["first_name"],
        last_name=test_user_data["last_name"],
        hashed_password=get_password_hash(test_user_data["password"]),
        phone=test_user_data.get("phone"),
        bio=test_user_data.get("bio"),
        is_active=True,
        is_verified=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def test_superuser(db_session, test_superuser_data):
    """Create a test superuser in the database."""
    user = User(
        email=test_superuser_data["email"],
        username=test_superuser_data["username"],
        first_name=test_superuser_data["first_name"],
        last_name=test_superuser_data["last_name"],
        hashed_password=get_password_hash(test_superuser_data["password"]),
        is_active=True,
        is_verified=True,
        is_superuser=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def test_inactive_user(db_session):
    """Create an inactive test user."""
    user = User(
        email="inactive@example.com",
        username="inactive",
        first_name="Inactive",
        last_name="User",
        hashed_password=get_password_hash("password123"),
        is_active=False,
        is_verified=False
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


# Document Fixtures
@pytest.fixture
def test_document_data():
    """Document data for testing."""
    return {
        "title": "Test Document",
        "description": "This is a test document",
        "category": "medical",
        "tags": "test,document,medical",
        "is_public": False
    }


@pytest.fixture
def test_document(db_session, test_user, test_document_data):
    """Create a test document in the database."""
    document = Document(
        title=test_document_data["title"],
        description=test_document_data["description"],
        filename="test_document.pdf",
        original_filename="test_document.pdf",
        file_path="documents/test_document.pdf",
        file_size=1024.0,
        file_type="application/pdf",
        file_extension=".pdf",
        category=test_document_data["category"],
        tags=test_document_data["tags"],
        is_public=test_document_data["is_public"],
        owner_id=test_user.id
    )
    db_session.add(document)
    db_session.commit()
    db_session.refresh(document)
    return document


@pytest.fixture
def test_public_document(db_session, test_user):
    """Create a public test document."""
    document = Document(
        title="Public Document",
        description="This is a public document",
        filename="public_document.pdf",
        original_filename="public_document.pdf",
        file_path="documents/public_document.pdf",
        file_size=2048.0,
        file_type="application/pdf",
        file_extension=".pdf",
        category="public",
        is_public=True,
        owner_id=test_user.id
    )
    db_session.add(document)
    db_session.commit()
    db_session.refresh(document)
    return document


# Clinical Image Fixtures
@pytest.fixture
def test_clinical_image_data():
    """Clinical image data for testing."""
    return {
        "description": "Test clinical image",
        "tags": "test,clinical,image",
        "is_public": False
    }


@pytest.fixture
def test_clinical_image(db_session, test_user, test_clinical_image_data):
    """Create a test clinical image in the database."""
    image = ClinicalImage(
        description=test_clinical_image_data["description"],
        tags=test_clinical_image_data["tags"],
        image_key="test_image_key_123",
        original_filename="test_image.jpg",
        file_size=1024.0,
        file_type="image/jpeg",
        image_width=800,
        image_height=600,
        is_public=test_clinical_image_data["is_public"],
        owner_id=test_user.id
    )
    db_session.add(image)
    db_session.commit()
    db_session.refresh(image)
    return image


# Drug Fixtures
@pytest.fixture
def test_drug_data():
    """Drug data for testing."""
    return {
        "name": "Acetaminophen",
        "generic_name": "acetaminophen",
        "brand_names": '["Tylenol", "Panadol"]',
        "therapeutic_class": "Analgesics",
        "mechanism_of_action": "COX inhibition",
        "indications": "Pain relief, fever reduction",
        "contraindications": "Liver disease",
        "dosage": "500-1000mg every 4-6 hours",
        "side_effects": "Hepatotoxicity with overdose",
        "route_of_administration": "Oral",
        "strength": "500mg",
        "presentation": "Tablets",
        "is_prescription_only": False
    }


@pytest.fixture
def test_drug(db_session, test_drug_data):
    """Create a test drug in the database."""
    drug = Drug(**test_drug_data)
    db_session.add(drug)
    db_session.commit()
    db_session.refresh(drug)
    return drug


# Procedure Fixtures
@pytest.fixture
def test_procedure_data():
    """Procedure data for testing."""
    return {
        "title": "Central Venous Line Insertion",
        "description": "Insertion of central venous catheter",
        "category": "Vascular Access",
        "specialty": "Internal Medicine",
        "difficulty_level": "Intermediate",
        "estimated_duration": 30,
        "objective": "Establish central venous access",
        "indications": "Need for central access, frequent blood draws",
        "contraindications": "Infection at insertion site",
        "materials_needed": '["Central line kit", "Ultrasound", "Sterile drapes"]',
        "procedure_steps": '["Prepare patient", "Sterile technique", "Insert needle"]',
        "is_published": True,
        "is_featured": False
    }


@pytest.fixture
def test_procedure(db_session, test_user, test_procedure_data):
    """Create a test procedure in the database."""
    procedure = Procedure(
        **test_procedure_data,
        created_by_id=test_user.id
    )
    db_session.add(procedure)
    db_session.commit()
    db_session.refresh(procedure)
    return procedure


# Algorithm Fixtures
@pytest.fixture
def test_algorithm_data():
    """Algorithm data for testing."""
    return {
        "title": "ACLS Algorithm",
        "description": "Advanced Cardiac Life Support algorithm",
        "category": "Emergency",
        "specialty": "Emergency Medicine",
        "algorithm_type": "decision_tree",
        "is_published": True,
        "is_featured": True
    }


@pytest.fixture
def test_algorithm(db_session, test_user, test_algorithm_data):
    """Create a test algorithm in the database."""
    algorithm = Algorithm(
        **test_algorithm_data,
        created_by_id=test_user.id
    )
    db_session.add(algorithm)
    db_session.commit()
    db_session.refresh(algorithm)
    return algorithm


@pytest.fixture
def test_algorithm_node(db_session, test_algorithm):
    """Create a test algorithm node."""
    node = AlgorithmNode(
        algorithm_id=test_algorithm.id,
        node_type="start",
        title="Start CPR",
        content="Begin chest compressions",
        position_x=100.0,
        position_y=100.0
    )
    db_session.add(node)
    db_session.commit()
    db_session.refresh(node)
    return node


@pytest.fixture
def test_algorithm_edge(db_session, test_algorithm_node):
    """Create a test algorithm edge."""
    # Create a second node for the edge
    node2 = AlgorithmNode(
        algorithm_id=test_algorithm_node.algorithm_id,
        node_type="decision",
        title="Check Pulse",
        content="Check for pulse",
        position_x=200.0,
        position_y=200.0
    )
    db_session.add(node2)
    db_session.commit()
    db_session.refresh(node2)
    
    edge = AlgorithmEdge(
        algorithm_id=test_algorithm_node.algorithm_id,
        from_node_id=test_algorithm_node.id,
        to_node_id=node2.id,
        label="Next",
        condition="continue"
    )
    db_session.add(edge)
    db_session.commit()
    db_session.refresh(edge)
    return edge


# Shift Fixtures
@pytest.fixture
def test_shift_data():
    """Shift data for testing."""
    now = datetime.utcnow()
    return {
        "title": "Night Shift",
        "description": "Emergency department night shift",
        "shift_type": "noche",
        "start_date": now + timedelta(hours=1),
        "end_date": now + timedelta(hours=9),
        "location": "Emergency Department",
        "department": "Emergency Medicine",
        "status": "programado",
        "is_recurring": False,
        "notes": "Regular night shift",
        "color": "#FF5722",
        "priority": "normal"
    }


@pytest.fixture
def test_shift(db_session, test_user, test_shift_data):
    """Create a test shift in the database."""
    shift = Shift(
        **test_shift_data,
        user_id=test_user.id
    )
    db_session.add(shift)
    db_session.commit()
    db_session.refresh(shift)
    return shift


# Calculator Test Data
@pytest.fixture
def curb65_test_data():
    """CURB-65 test data."""
    return {
        "low_risk": {
            "confusion": False,
            "urea": 5.0,
            "respiratory_rate": 18,
            "blood_pressure_systolic": 130,
            "blood_pressure_diastolic": 80,
            "age": 45,
            "expected_score": 0,
            "expected_risk": "Bajo"
        },
        "high_risk": {
            "confusion": True,
            "urea": 25.0,
            "respiratory_rate": 35,
            "blood_pressure_systolic": 85,
            "blood_pressure_diastolic": 50,
            "age": 75,
            "expected_score": 5,
            "expected_risk": "Severo"
        }
    }


@pytest.fixture
def wells_pe_test_data():
    """Wells PE test data."""
    return {
        "low_risk": {
            "clinical_signs_dvt": False,
            "pe_likely": False,
            "heart_rate_over_100": False,
            "immobilization_surgery": False,
            "previous_pe_dvt": False,
            "hemoptysis": False,
            "malignancy": False,
            "expected_score": 0.0,
            "expected_risk": "Bajo"
        },
        "high_risk": {
            "clinical_signs_dvt": True,
            "pe_likely": True,
            "heart_rate_over_100": True,
            "immobilization_surgery": True,
            "previous_pe_dvt": True,
            "hemoptysis": True,
            "malignancy": True,
            "expected_score": 12.5,
            "expected_risk": "Alto"
        }
    }


@pytest.fixture
def glasgow_test_data():
    """Glasgow Coma Scale test data."""
    return {
        "severe": {
            "eye_opening": 1,
            "verbal_response": 1,
            "motor_response": 1,
            "expected_score": 3,
            "expected_risk": "Severo"
        },
        "mild": {
            "eye_opening": 4,
            "verbal_response": 5,
            "motor_response": 6,
            "expected_score": 15,
            "expected_risk": "Bajo"
        }
    }


@pytest.fixture
def chads2_vasc_test_data():
    """CHA2DS2-VASc test data."""
    return {
        "low_risk": {
            "congestive_heart_failure": False,
            "hypertension": False,
            "age": 45,
            "diabetes": False,
            "stroke_tia_history": False,
            "vascular_disease": False,
            "sex_female": False,
            "expected_score": 0,
            "expected_risk": "Bajo"
        },
        "high_risk": {
            "congestive_heart_failure": True,
            "hypertension": True,
            "age": 80,
            "diabetes": True,
            "stroke_tia_history": True,
            "vascular_disease": True,
            "sex_female": True,
            "expected_score": 8,
            "expected_risk": "Alto"
        }
    }


# API Test Utilities
@pytest.fixture
def authenticated_headers(test_user):
    """Headers for authenticated requests."""
    from app.security import create_access_token
    from datetime import timedelta
    
    access_token = create_access_token(
        data={"sub": str(test_user.id)},
        expires_delta=timedelta(minutes=30)
    )
    
    return {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }


@pytest.fixture
def superuser_headers(test_superuser):
    """Headers for superuser authenticated requests."""
    from app.security import create_access_token
    from datetime import timedelta
    
    access_token = create_access_token(
        data={"sub": str(test_superuser.id)},
        expires_delta=timedelta(minutes=30)
    )
    
    return {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }


# Mock Data for File Operations
@pytest.fixture
def mock_file_upload():
    """Mock file upload data."""
    import io
    
    file_content = b"Mock PDF content for testing"
    file_io = io.BytesIO(file_content)
    
    return {
        "file": file_io,
        "filename": "test_document.pdf",
        "content_type": "application/pdf",
        "size": len(file_content)
    }


@pytest.fixture
def mock_image_upload():
    """Mock image upload data."""
    import io
    
    # Simple mock image content
    image_content = b"Mock JPEG content for testing"
    image_io = io.BytesIO(image_content)
    
    return {
        "file": image_io,
        "filename": "test_image.jpg",
        "content_type": "image/jpeg",
        "size": len(image_content)
    }


# Environment Variables for Testing
@pytest.fixture(autouse=True)
def setup_test_env(monkeypatch):
    """Setup test environment variables."""
    monkeypatch.setenv("ENVIRONMENT", "testing")
    monkeypatch.setenv("DATABASE_URL", SQLALCHEMY_DATABASE_URL)
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret_key_for_testing_only")
    monkeypatch.setenv("MINIO_ACCESS_KEY", "test_access_key")
    monkeypatch.setenv("MINIO_SECRET_KEY", "test_secret_key")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")