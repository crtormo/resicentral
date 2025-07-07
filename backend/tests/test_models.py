"""
Unit tests for database models.
"""
import pytest
from datetime import datetime, timedelta
from sqlalchemy.exc import IntegrityError

from app.models import User, Drug, Document, ClinicalImage, Procedure, Algorithm, AlgorithmNode, AlgorithmEdge, Shift
from app.security import get_password_hash, verify_password
from .fixtures import *


@pytest.mark.unit
@pytest.mark.models
class TestUserModel:
    """Test User model functionality."""

    def test_user_creation(self, db_session):
        """Test user creation with required fields."""
        user = User(
            email="test@example.com",
            username="testuser",
            first_name="Test",
            last_name="User",
            hashed_password=get_password_hash("password123")
        )
        
        db_session.add(user)
        db_session.commit()
        db_session.refresh(user)
        
        assert user.id is not None
        assert user.uuid is not None
        assert user.email == "test@example.com"
        assert user.username == "testuser"
        assert user.full_name == "Test User"
        assert user.is_active is True
        assert user.is_verified is False
        assert user.is_superuser is False
        assert user.created_at is not None
        assert user.updated_at is not None

    def test_user_email_unique_constraint(self, db_session):
        """Test that email must be unique."""
        user1 = User(
            email="test@example.com",
            username="user1",
            first_name="Test",
            last_name="User1",
            hashed_password=get_password_hash("password123")
        )
        
        user2 = User(
            email="test@example.com",  # Same email
            username="user2",
            first_name="Test",
            last_name="User2",
            hashed_password=get_password_hash("password456")
        )
        
        db_session.add(user1)
        db_session.commit()
        
        db_session.add(user2)
        with pytest.raises(IntegrityError):
            db_session.commit()

    def test_user_username_unique_constraint(self, db_session):
        """Test that username must be unique."""
        user1 = User(
            email="test1@example.com",
            username="testuser",
            first_name="Test",
            last_name="User1",
            hashed_password=get_password_hash("password123")
        )
        
        user2 = User(
            email="test2@example.com",
            username="testuser",  # Same username
            first_name="Test",
            last_name="User2",
            hashed_password=get_password_hash("password456")
        )
        
        db_session.add(user1)
        db_session.commit()
        
        db_session.add(user2)
        with pytest.raises(IntegrityError):
            db_session.commit()

    def test_user_password_hashing(self):
        """Test password hashing and verification."""
        password = "mySecurePassword123"
        hashed = get_password_hash(password)
        
        assert hashed != password
        assert verify_password(password, hashed) is True
        assert verify_password("wrongPassword", hashed) is False

    def test_user_to_dict(self, test_user):
        """Test user to_dict method."""
        user_dict = test_user.to_dict()
        
        expected_keys = {
            'id', 'uuid', 'email', 'username', 'first_name', 'last_name',
            'full_name', 'is_active', 'is_verified', 'is_superuser',
            'phone', 'avatar_url', 'bio', 'created_at', 'updated_at', 'last_login'
        }
        
        assert set(user_dict.keys()) == expected_keys
        assert user_dict['full_name'] == f"{test_user.first_name} {test_user.last_name}"


@pytest.mark.unit
@pytest.mark.models
class TestDrugModel:
    """Test Drug model functionality."""

    def test_drug_creation(self, db_session, test_drug_data):
        """Test drug creation with all fields."""
        drug = Drug(**test_drug_data)
        
        db_session.add(drug)
        db_session.commit()
        db_session.refresh(drug)
        
        assert drug.id is not None
        assert drug.uuid is not None
        assert drug.name == test_drug_data["name"]
        assert drug.therapeutic_class == test_drug_data["therapeutic_class"]
        assert drug.is_active is True
        assert drug.created_at is not None

    def test_drug_to_dict(self, test_drug):
        """Test drug to_dict method."""
        drug_dict = test_drug.to_dict()
        
        assert 'id' in drug_dict
        assert 'uuid' in drug_dict
        assert 'name' in drug_dict
        assert drug_dict['name'] == test_drug.name
        assert drug_dict['therapeutic_class'] == test_drug.therapeutic_class


@pytest.mark.unit
@pytest.mark.models
class TestShiftModel:
    """Test Shift model functionality."""

    def test_shift_creation(self, db_session, test_user, test_shift_data):
        """Test shift creation."""
        shift = Shift(**test_shift_data, user_id=test_user.id)
        
        db_session.add(shift)
        db_session.commit()
        db_session.refresh(shift)
        
        assert shift.id is not None
        assert shift.uuid is not None
        assert shift.user_id == test_user.id
        assert shift.title == test_shift_data["title"]
        assert shift.shift_type == test_shift_data["shift_type"]
        assert shift.status == test_shift_data["status"]

    def test_shift_duration_calculation(self, test_shift):
        """Test duration calculation property."""
        expected_duration = (test_shift.end_date - test_shift.start_date).total_seconds() / 3600
        assert test_shift.duration_hours == expected_duration

    def test_shift_time_properties(self, db_session, test_user):
        """Test time-related properties."""
        now = datetime.utcnow()
        
        # Future shift
        future_shift = Shift(
            title="Future Shift",
            shift_type="mañana",
            start_date=now + timedelta(hours=2),
            end_date=now + timedelta(hours=10),
            user_id=test_user.id,
            status="programado"
        )
        
        # Current shift
        current_shift = Shift(
            title="Current Shift",
            shift_type="mañana",
            start_date=now - timedelta(hours=1),
            end_date=now + timedelta(hours=7),
            user_id=test_user.id,
            status="programado"
        )
        
        # Today's shift
        today_shift = Shift(
            title="Today Shift",
            shift_type="mañana",
            start_date=now.replace(hour=8, minute=0, second=0, microsecond=0),
            end_date=now.replace(hour=16, minute=0, second=0, microsecond=0),
            user_id=test_user.id,
            status="programado"
        )
        
        db_session.add_all([future_shift, current_shift, today_shift])
        db_session.commit()
        
        assert future_shift.is_upcoming is True
        assert future_shift.is_active is False
        
        assert current_shift.is_active is True
        assert current_shift.is_upcoming is False
        
        assert today_shift.is_today is True

    def test_shift_to_dict(self, test_shift):
        """Test shift to_dict method."""
        shift_dict = test_shift.to_dict()
        
        expected_keys = {
            'id', 'uuid', 'title', 'description', 'shift_type', 'start_date',
            'end_date', 'location', 'department', 'status', 'is_recurring',
            'recurrence_pattern', 'recurrence_end_date', 'notes', 'color',
            'priority', 'reminder_enabled', 'reminder_minutes_before',
            'duration_hours', 'is_today', 'is_upcoming', 'is_active',
            'created_at', 'updated_at', 'user_id', 'user'
        }
        
        assert set(shift_dict.keys()) == expected_keys
        assert shift_dict['duration_hours'] == test_shift.duration_hours


@pytest.mark.unit
@pytest.mark.models
class TestProcedureModel:
    """Test Procedure model functionality."""

    def test_procedure_creation(self, db_session, test_user, test_procedure_data):
        """Test procedure creation."""
        procedure = Procedure(**test_procedure_data, created_by_id=test_user.id)
        
        db_session.add(procedure)
        db_session.commit()
        db_session.refresh(procedure)
        
        assert procedure.id is not None
        assert procedure.uuid is not None
        assert procedure.created_by_id == test_user.id
        assert procedure.title == test_procedure_data["title"]
        assert procedure.category == test_procedure_data["category"]
        assert procedure.difficulty_level == test_procedure_data["difficulty_level"]

    def test_procedure_to_dict(self, test_procedure):
        """Test procedure to_dict method."""
        procedure_dict = test_procedure.to_dict()
        
        assert 'id' in procedure_dict
        assert 'uuid' in procedure_dict
        assert 'title' in procedure_dict
        assert 'created_by' in procedure_dict
        assert procedure_dict['title'] == test_procedure.title


@pytest.mark.unit
@pytest.mark.models
class TestDocumentModel:
    """Test Document model functionality."""

    def test_document_file_size_properties(self, db_session, test_user):
        """Test file size calculation properties."""
        document = Document(
            title="Test Document",
            filename="test.pdf",
            original_filename="test.pdf",
            file_path="/documents/test.pdf",
            file_size=1048576,  # 1MB
            file_type="application/pdf",
            file_extension=".pdf",
            owner_id=test_user.id
        )
        
        db_session.add(document)
        db_session.commit()
        
        assert document.file_size_mb == 1.0
        assert document.file_size_human == "1.0 MB"

    def test_document_small_file_size(self, db_session, test_user):
        """Test file size for small files."""
        document = Document(
            title="Small Document",
            filename="small.txt",
            original_filename="small.txt",
            file_path="/documents/small.txt",
            file_size=512,  # 512 bytes
            file_type="text/plain",
            file_extension=".txt",
            owner_id=test_user.id
        )
        
        db_session.add(document)
        db_session.commit()
        
        assert document.file_size_human == "512 B"


@pytest.mark.unit
@pytest.mark.models
class TestClinicalImageModel:
    """Test ClinicalImage model functionality."""

    def test_clinical_image_properties(self, db_session, test_user):
        """Test clinical image properties."""
        image = ClinicalImage(
            description="Test X-ray",
            image_key="test-xray-123.jpg",
            original_filename="xray.jpg",
            file_size=2097152,  # 2MB
            file_type="image/jpeg",
            image_width=800,
            image_height=600,
            owner_id=test_user.id
        )
        
        db_session.add(image)
        db_session.commit()
        
        assert image.file_size_mb == 2.0
        assert image.file_size_human == "2.0 MB"
        assert image.image_dimensions == "800 x 600"
        assert image.aspect_ratio == 1.33  # 800/600 rounded to 2 decimals

    def test_clinical_image_unknown_dimensions(self, db_session, test_user):
        """Test clinical image with unknown dimensions."""
        image = ClinicalImage(
            description="Test Image",
            image_key="test-image-456.png",
            original_filename="image.png",
            file_size=1048576,
            file_type="image/png",
            owner_id=test_user.id
        )
        
        db_session.add(image)
        db_session.commit()
        
        assert image.image_dimensions == "Desconocido"
        assert image.aspect_ratio is None


@pytest.mark.unit
@pytest.mark.models
class TestModelRelationships:
    """Test model relationships."""

    def test_user_document_relationship(self, db_session, test_user):
        """Test User-Document relationship."""
        document = Document(
            title="User Document",
            filename="doc.pdf",
            original_filename="doc.pdf",
            file_path="/documents/doc.pdf",
            file_size=1024,
            file_type="application/pdf",
            file_extension=".pdf",
            owner_id=test_user.id
        )
        
        db_session.add(document)
        db_session.commit()
        db_session.refresh(test_user)
        
        assert len(test_user.documents) == 1
        assert test_user.documents[0].title == "User Document"
        assert document.owner.id == test_user.id

    def test_user_shift_relationship(self, db_session, test_user):
        """Test User-Shift relationship."""
        shift = Shift(
            title="Test Shift",
            shift_type="mañana",
            start_date=datetime.utcnow(),
            end_date=datetime.utcnow() + timedelta(hours=8),
            user_id=test_user.id,
            status="programado"
        )
        
        db_session.add(shift)
        db_session.commit()
        db_session.refresh(test_user)
        
        assert len(test_user.shifts) == 1
        assert test_user.shifts[0].title == "Test Shift"
        assert shift.user.id == test_user.id

    def test_cascade_delete_user_documents(self, db_session, test_user):
        """Test cascade delete for user documents."""
        document = Document(
            title="Document to Delete",
            filename="delete.pdf",
            original_filename="delete.pdf",
            file_path="/documents/delete.pdf",
            file_size=1024,
            file_type="application/pdf",
            file_extension=".pdf",
            owner_id=test_user.id
        )
        
        db_session.add(document)
        db_session.commit()
        
        # Delete user should cascade to documents
        db_session.delete(test_user)
        db_session.commit()
        
        # Check that document was also deleted
        remaining_documents = db_session.query(Document).filter_by(id=document.id).first()
        assert remaining_documents is None