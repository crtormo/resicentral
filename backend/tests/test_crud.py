"""
Unit tests for CRUD operations.
"""
import pytest
from datetime import datetime, timedelta

from app import crud
from app.schemas import UserCreate, UserUpdate, DocumentCreate, DocumentUpdate, ClinicalImageCreate, ClinicalImageUpdate
from app.models import User, Document, ClinicalImage, Drug, Shift
from .fixtures import *


@pytest.mark.unit
@pytest.mark.crud
class TestUserCRUD:
    """Test CRUD operations for User model."""

    def test_get_user_by_id(self, db_session, test_user):
        """Test getting user by ID."""
        user = crud.get_user_by_id(db_session, test_user.id)
        
        assert user is not None
        assert user.id == test_user.id
        assert user.email == test_user.email

    def test_get_user_by_id_not_found(self, db_session):
        """Test getting user by non-existent ID."""
        user = crud.get_user_by_id(db_session, 99999)
        
        assert user is None

    def test_get_user_by_email(self, db_session, test_user):
        """Test getting user by email."""
        user = crud.get_user_by_email(db_session, test_user.email)
        
        assert user is not None
        assert user.email == test_user.email

    def test_get_user_by_username(self, db_session, test_user):
        """Test getting user by username."""
        user = crud.get_user_by_username(db_session, test_user.username)
        
        assert user is not None
        assert user.username == test_user.username

    def test_get_users_with_pagination(self, db_session, test_user, test_superuser):
        """Test getting users with pagination."""
        users = crud.get_users(db_session, skip=0, limit=10)
        
        assert len(users) == 2
        assert any(u.id == test_user.id for u in users)
        assert any(u.id == test_superuser.id for u in users)

    def test_get_users_count(self, db_session, test_user, test_superuser):
        """Test getting users count."""
        count = crud.get_users_count(db_session)
        
        assert count == 2

    def test_create_user(self, db_session, test_user_data):
        """Test creating a new user."""
        user_create = UserCreate(**test_user_data)
        user = crud.create_user(db_session, user_create)
        
        assert user.id is not None
        assert user.email == test_user_data["email"]
        assert user.username == test_user_data["username"]
        assert user.is_active is True
        assert user.is_verified is False

    def test_update_user(self, db_session, test_user):
        """Test updating user information."""
        update_data = UserUpdate(
            first_name="Updated",
            last_name="Name",
            bio="Updated bio"
        )
        
        updated_user = crud.update_user(db_session, test_user.id, update_data)
        
        assert updated_user is not None
        assert updated_user.first_name == "Updated"
        assert updated_user.last_name == "Name"
        assert updated_user.bio == "Updated bio"

    def test_update_user_password(self, db_session, test_user):
        """Test updating user password."""
        new_password = "NewPassword123"
        
        updated_user = crud.update_user_password(db_session, test_user.id, new_password)
        
        assert updated_user is not None
        from app.security import verify_password
        assert verify_password(new_password, updated_user.hashed_password)

    def test_update_user_last_login(self, db_session, test_user):
        """Test updating user last login."""
        original_last_login = test_user.last_login
        
        updated_user = crud.update_user_last_login(db_session, test_user.id)
        
        assert updated_user is not None
        assert updated_user.last_login is not None
        assert updated_user.last_login != original_last_login

    def test_activate_user(self, db_session, test_inactive_user):
        """Test activating a user."""
        activated_user = crud.activate_user(db_session, test_inactive_user.id)
        
        assert activated_user is not None
        assert activated_user.is_active is True

    def test_deactivate_user(self, db_session, test_user):
        """Test deactivating a user."""
        deactivated_user = crud.deactivate_user(db_session, test_user.id)
        
        assert deactivated_user is not None
        assert deactivated_user.is_active is False

    def test_verify_user(self, db_session, test_user):
        """Test verifying a user."""
        verified_user = crud.verify_user(db_session, test_user.id)
        
        assert verified_user is not None
        assert verified_user.is_verified is True

    def test_make_superuser(self, db_session, test_user):
        """Test making user a superuser."""
        superuser = crud.make_superuser(db_session, test_user.id)
        
        assert superuser is not None
        assert superuser.is_superuser is True

    def test_delete_user(self, db_session, test_user):
        """Test soft deleting a user."""
        result = crud.delete_user(db_session, test_user.id)
        
        assert result is True
        
        # User should be deactivated, not deleted
        user = crud.get_user_by_id(db_session, test_user.id)
        assert user is not None
        assert user.is_active is False

    def test_email_exists(self, db_session, test_user):
        """Test checking if email exists."""
        assert crud.email_exists(db_session, test_user.email) is True
        assert crud.email_exists(db_session, "nonexistent@example.com") is False

    def test_username_exists(self, db_session, test_user):
        """Test checking if username exists."""
        assert crud.username_exists(db_session, test_user.username) is True
        assert crud.username_exists(db_session, "nonexistent") is False


@pytest.mark.unit
@pytest.mark.crud
class TestDocumentCRUD:
    """Test CRUD operations for Document model."""

    def test_get_document_by_id(self, db_session, test_document):
        """Test getting document by ID."""
        document = crud.get_document_by_id(db_session, test_document.id)
        
        assert document is not None
        assert document.id == test_document.id
        assert document.title == test_document.title

    def test_get_documents(self, db_session, test_document, test_public_document):
        """Test getting documents with filters."""
        # Get all documents
        documents = crud.get_documents(db_session)
        assert len(documents) == 2
        
        # Get public documents only
        public_docs = crud.get_documents(db_session, is_public=True)
        assert len(public_docs) == 1
        assert public_docs[0].is_public is True
        
        # Get documents by category
        medical_docs = crud.get_documents(db_session, category="medical")
        assert len(medical_docs) == 1

    def test_get_user_documents(self, db_session, test_user, test_document):
        """Test getting documents for a specific user."""
        documents = crud.get_user_documents(db_session, test_user.id)
        
        assert len(documents) >= 1
        assert all(doc.owner_id == test_user.id for doc in documents)

    def test_create_document(self, db_session, test_user, test_document_data):
        """Test creating a new document."""
        document_create = DocumentCreate(**test_document_data)
        upload_result = {
            "filename": "test_file.pdf",
            "original_filename": "test_file.pdf",
            "file_path": "documents/test_file.pdf",
            "file_size": 1024.0,
            "file_type": "application/pdf",
            "file_extension": ".pdf"
        }
        
        document = crud.create_document(db_session, document_create, test_user.id, upload_result)
        
        assert document.id is not None
        assert document.title == test_document_data["title"]
        assert document.owner_id == test_user.id
        assert document.filename == upload_result["filename"]

    def test_update_document(self, db_session, test_document):
        """Test updating document information."""
        update_data = DocumentUpdate(
            title="Updated Title",
            description="Updated description",
            is_public=True
        )
        
        updated_document = crud.update_document(db_session, test_document.id, update_data)
        
        assert updated_document is not None
        assert updated_document.title == "Updated Title"
        assert updated_document.description == "Updated description"
        assert updated_document.is_public is True

    def test_delete_document(self, db_session, test_document):
        """Test deleting a document."""
        result = crud.delete_document(db_session, test_document.id)
        
        assert result is True
        
        # Document should be deleted
        document = crud.get_document_by_id(db_session, test_document.id)
        assert document is None

    def test_increment_download_count(self, db_session, test_document):
        """Test incrementing document download count."""
        original_count = test_document.download_count
        
        updated_document = crud.increment_download_count(db_session, test_document.id)
        
        assert updated_document is not None
        assert updated_document.download_count == original_count + 1

    def test_search_documents(self, db_session, test_document, test_public_document):
        """Test searching documents."""
        # Search by title
        results = crud.search_documents(db_session, "Test")
        assert len(results) >= 1
        
        # Search by category
        results = crud.search_documents(db_session, "medical", category="medical")
        assert len(results) >= 1

    def test_get_documents_stats(self, db_session, test_user, test_document, test_public_document):
        """Test getting document statistics."""
        # All documents stats
        stats = crud.get_documents_stats(db_session)
        
        assert stats["total_documents"] == 2
        assert stats["total_size_mb"] > 0
        assert "documents_by_category" in stats
        
        # User-specific stats
        user_stats = crud.get_documents_stats(db_session, owner_id=test_user.id)
        assert user_stats["total_documents"] == 2  # Both test documents belong to test_user


@pytest.mark.unit
@pytest.mark.crud
class TestClinicalImageCRUD:
    """Test CRUD operations for ClinicalImage model."""

    def test_get_clinical_image_by_id(self, db_session, test_clinical_image):
        """Test getting clinical image by ID."""
        image = crud.get_clinical_image_by_id(db_session, test_clinical_image.id)
        
        assert image is not None
        assert image.id == test_clinical_image.id
        assert image.image_key == test_clinical_image.image_key

    def test_create_clinical_image(self, db_session, test_user, test_clinical_image_data):
        """Test creating a new clinical image."""
        image_create = ClinicalImageCreate(**test_clinical_image_data)
        upload_result = {
            "filename": "test_image.jpg",
            "original_filename": "test_image.jpg",
            "file_path": "clinical-images/test_image.jpg",
            "file_size": 2048.0,
            "file_type": "image/jpeg",
            "image_width": 800,
            "image_height": 600,
            "image_key": "test_image_key"
        }
        
        image = crud.create_clinical_image(db_session, image_create, test_user.id, upload_result)
        
        assert image.id is not None
        assert image.description == test_clinical_image_data["description"]
        assert image.owner_id == test_user.id
        assert image.image_key == upload_result["image_key"]

    def test_update_clinical_image(self, db_session, test_clinical_image):
        """Test updating clinical image information."""
        update_data = ClinicalImageUpdate(
            description="Updated description",
            tags="updated,tags",
            is_public=True
        )
        
        updated_image = crud.update_clinical_image(db_session, test_clinical_image.id, update_data)
        
        assert updated_image is not None
        assert updated_image.description == "Updated description"
        assert updated_image.tags == "updated,tags"
        assert updated_image.is_public is True

    def test_increment_image_view_count(self, db_session, test_clinical_image):
        """Test incrementing image view count."""
        original_count = test_clinical_image.view_count
        
        updated_image = crud.increment_image_view_count(db_session, test_clinical_image.id)
        
        assert updated_image is not None
        assert updated_image.view_count == original_count + 1


@pytest.mark.unit
@pytest.mark.crud
class TestDrugCRUD:
    """Test CRUD operations for Drug model."""

    def test_get_drug_by_id(self, db_session, test_drug):
        """Test getting drug by ID."""
        drug = crud.get_drug_by_id(db_session, test_drug.id)
        
        assert drug is not None
        assert drug.id == test_drug.id
        assert drug.name == test_drug.name

    def test_get_drugs(self, db_session, test_drug):
        """Test getting drugs with filters."""
        drugs = crud.get_drugs(db_session)
        assert len(drugs) >= 1
        
        # Filter by therapeutic class
        analgesics = crud.get_drugs(db_session, therapeutic_class="Analgesics")
        assert len(analgesics) >= 1

    def test_search_drugs(self, db_session, test_drug):
        """Test searching drugs."""
        results = crud.search_drugs(db_session, "Acetaminophen")
        assert len(results) >= 1
        assert any(drug.name == "Acetaminophen" for drug in results)

    def test_get_drugs_by_therapeutic_class(self, db_session, test_drug):
        """Test getting drugs by therapeutic class."""
        drugs = crud.get_drugs_by_therapeutic_class(db_session, "Analgesics")
        assert len(drugs) >= 1

    def test_get_prescription_drugs(self, db_session, test_drug_data, db_session):
        """Test getting prescription-only drugs."""
        # Create a prescription drug
        prescription_drug_data = test_drug_data.copy()
        prescription_drug_data["name"] = "Morphine"
        prescription_drug_data["is_prescription_only"] = True
        
        prescription_drug = Drug(**prescription_drug_data)
        db_session.add(prescription_drug)
        db_session.commit()
        
        prescription_drugs = crud.get_prescription_drugs(db_session)
        assert len(prescription_drugs) >= 1
        assert all(drug.is_prescription_only for drug in prescription_drugs)


@pytest.mark.unit
@pytest.mark.crud
class TestShiftCRUD:
    """Test CRUD operations for Shift model."""

    def test_get_shift_by_id(self, db_session, test_shift):
        """Test getting shift by ID."""
        shift = crud.get_shift_by_id(db_session, test_shift.id)
        
        assert shift is not None
        assert shift.id == test_shift.id
        assert shift.title == test_shift.title

    def test_get_user_shifts(self, db_session, test_user, test_shift):
        """Test getting shifts for a user."""
        shifts = crud.get_user_shifts(db_session, test_user.id)
        
        assert len(shifts) >= 1
        assert all(shift.user_id == test_user.id for shift in shifts)

    def test_get_today_shifts(self, db_session, test_user):
        """Test getting today's shifts."""
        from datetime import datetime, timezone
        
        today = datetime.now(timezone.utc)
        
        # Create a shift for today
        today_shift = Shift(
            title="Today's Shift",
            shift_type="día",
            start_date=today.replace(hour=8, minute=0, second=0, microsecond=0),
            end_date=today.replace(hour=16, minute=0, second=0, microsecond=0),
            user_id=test_user.id,
            status="programado"
        )
        
        db_session.add(today_shift)
        db_session.commit()
        
        today_shifts = crud.get_today_shifts(db_session, test_user.id)
        assert len(today_shifts) >= 1
        assert all(shift.is_today for shift in today_shifts)

    def test_get_upcoming_shifts(self, db_session, test_user, test_shift):
        """Test getting upcoming shifts."""
        upcoming_shifts = crud.get_upcoming_shifts(db_session, test_user.id, days=7)
        
        assert len(upcoming_shifts) >= 1
        assert all(shift.is_upcoming for shift in upcoming_shifts)

    def test_get_active_shift(self, db_session, test_user):
        """Test getting active shift."""
        from datetime import datetime, timezone
        
        now = datetime.now(timezone.utc)
        
        # Create an active shift
        active_shift = Shift(
            title="Active Shift",
            shift_type="día",
            start_date=now - timedelta(hours=1),
            end_date=now + timedelta(hours=7),
            user_id=test_user.id,
            status="programado"
        )
        
        db_session.add(active_shift)
        db_session.commit()
        
        current_shift = crud.get_active_shift(db_session, test_user.id)
        assert current_shift is not None
        assert current_shift.is_active is True

    def test_create_shift(self, db_session, test_user, test_shift_data):
        """Test creating a new shift."""
        shift = crud.create_shift(db_session, test_shift_data, test_user.id)
        
        assert shift.id is not None
        assert shift.title == test_shift_data["title"]
        assert shift.user_id == test_user.id

    def test_update_shift(self, db_session, test_shift):
        """Test updating shift information."""
        update_data = {
            "title": "Updated Shift Title",
            "description": "Updated description",
            "status": "confirmado"
        }
        
        updated_shift = crud.update_shift(db_session, test_shift.id, update_data)
        
        assert updated_shift is not None
        assert updated_shift.title == "Updated Shift Title"
        assert updated_shift.description == "Updated description"
        assert updated_shift.status == "confirmado"

    def test_delete_shift(self, db_session, test_shift):
        """Test deleting a shift."""
        result = crud.delete_shift(db_session, test_shift.id)
        
        assert result is True
        
        # Shift should be deleted
        shift = crud.get_shift_by_id(db_session, test_shift.id)
        assert shift is None

    def test_search_shifts(self, db_session, test_user, test_shift):
        """Test searching shifts."""
        results = crud.search_shifts(db_session, test_user.id, "Night")
        
        assert len(results) >= 1
        assert any("Night" in shift.title for shift in results)

    def test_get_shift_statistics(self, db_session, test_user, test_shift):
        """Test getting shift statistics."""
        stats = crud.get_shift_statistics(db_session, test_user.id)
        
        assert "total_shifts" in stats
        assert "upcoming_shifts" in stats
        assert "total_hours" in stats
        assert stats["total_shifts"] >= 1