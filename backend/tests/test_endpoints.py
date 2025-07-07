"""
Integration tests for API endpoints.
"""
import pytest
import json
import io
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

from app.main import app
from .fixtures import *


# Create test client
@pytest.fixture
def client(override_get_db):
    """Create test client with database override."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.mark.integration
@pytest.mark.auth
class TestAuthEndpoints:
    """Test authentication endpoints."""

    def test_root_endpoint(self, client):
        """Test root endpoint."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "version" in data
        assert "status" in data

    def test_health_check(self, client):
        """Test health check endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "service" in data
        assert "version" in data

    def test_login_success(self, client, test_user, test_user_data):
        """Test successful login."""
        login_data = {
            "email": test_user_data["email"],
            "password": test_user_data["password"]
        }
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"
        assert "user" in data

    def test_login_invalid_credentials(self, client):
        """Test login with invalid credentials."""
        login_data = {
            "email": "invalid@example.com",
            "password": "wrongpassword"
        }
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 401
        data = response.json()
        assert "detail" in data

    def test_login_inactive_user(self, client, test_inactive_user):
        """Test login with inactive user."""
        login_data = {
            "email": test_inactive_user.email,
            "password": "password123"
        }
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 400
        data = response.json()
        assert "Cuenta desactivada" in data["detail"]

    def test_register_success(self, client):
        """Test successful user registration."""
        user_data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "first_name": "New",
            "last_name": "User",
            "password": "NewPassword123"
        }
        response = client.post("/auth/register", json=user_data)
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == user_data["email"]
        assert data["username"] == user_data["username"]
        assert "id" in data

    def test_register_duplicate_email(self, client, test_user, test_user_data):
        """Test registration with duplicate email."""
        user_data = {
            "email": test_user_data["email"],  # Duplicate email
            "username": "newuser",
            "first_name": "New",
            "last_name": "User",
            "password": "NewPassword123"
        }
        response = client.post("/auth/register", json=user_data)
        assert response.status_code == 400
        data = response.json()
        assert "ya está registrado" in data["detail"]

    def test_register_duplicate_username(self, client, test_user, test_user_data):
        """Test registration with duplicate username."""
        user_data = {
            "email": "newuser@example.com",
            "username": test_user_data["username"],  # Duplicate username
            "first_name": "New",
            "last_name": "User",
            "password": "NewPassword123"
        }
        response = client.post("/auth/register", json=user_data)
        assert response.status_code == 400
        data = response.json()
        assert "ya está en uso" in data["detail"]

    def test_get_current_user(self, client, authenticated_headers):
        """Test getting current user profile."""
        response = client.get("/auth/me", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert "email" in data
        assert "username" in data

    def test_get_current_user_unauthenticated(self, client):
        """Test getting current user without authentication."""
        response = client.get("/auth/me")
        assert response.status_code == 401


@pytest.mark.integration
@pytest.mark.users
class TestUserEndpoints:
    """Test user management endpoints."""

    def test_get_users_as_superuser(self, client, superuser_headers, test_user):
        """Test getting users as superuser."""
        response = client.get("/users/", headers=superuser_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_get_users_as_regular_user(self, client, authenticated_headers):
        """Test getting users as regular user (should fail)."""
        response = client.get("/users/", headers=authenticated_headers)
        assert response.status_code == 403

    def test_get_user_by_id_own_profile(self, client, authenticated_headers, test_user):
        """Test getting own user profile."""
        response = client.get(f"/users/{test_user.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_user.id

    def test_get_user_by_id_forbidden(self, client, authenticated_headers, test_superuser):
        """Test getting other user's profile (should fail)."""
        response = client.get(f"/users/{test_superuser.id}", headers=authenticated_headers)
        assert response.status_code == 403

    def test_get_user_not_found(self, client, authenticated_headers):
        """Test getting non-existent user."""
        response = client.get("/users/99999", headers=authenticated_headers)
        assert response.status_code == 404

    def test_update_user_own_profile(self, client, authenticated_headers, test_user):
        """Test updating own user profile."""
        update_data = {
            "first_name": "Updated",
            "last_name": "Name",
            "bio": "Updated bio"
        }
        response = client.put(f"/users/{test_user.id}", headers=authenticated_headers, json=update_data)
        assert response.status_code == 200
        data = response.json()
        assert data["first_name"] == "Updated"
        assert data["last_name"] == "Name"
        assert data["bio"] == "Updated bio"

    def test_update_user_forbidden(self, client, authenticated_headers, test_superuser):
        """Test updating other user's profile (should fail)."""
        update_data = {"first_name": "Hacked"}
        response = client.put(f"/users/{test_superuser.id}", headers=authenticated_headers, json=update_data)
        assert response.status_code == 403

    def test_change_password_success(self, client, authenticated_headers, test_user, test_user_data):
        """Test successful password change."""
        password_data = {
            "current_password": test_user_data["password"],
            "new_password": "NewPassword456"
        }
        response = client.put(f"/users/{test_user.id}/change-password", 
                            headers=authenticated_headers, json=password_data)
        assert response.status_code == 200
        data = response.json()
        assert "exitosamente" in data["message"]

    def test_change_password_wrong_current(self, client, authenticated_headers, test_user):
        """Test password change with wrong current password."""
        password_data = {
            "current_password": "wrongpassword",
            "new_password": "NewPassword456"
        }
        response = client.put(f"/users/{test_user.id}/change-password", 
                            headers=authenticated_headers, json=password_data)
        assert response.status_code == 400
        data = response.json()
        assert "incorrecta" in data["detail"]

    def test_delete_user_as_superuser(self, client, superuser_headers, test_user):
        """Test deleting user as superuser."""
        response = client.delete(f"/users/{test_user.id}", headers=superuser_headers)
        assert response.status_code == 200
        data = response.json()
        assert "eliminado" in data["message"]

    def test_delete_user_as_regular_user(self, client, authenticated_headers, test_user):
        """Test deleting user as regular user (should fail)."""
        response = client.delete(f"/users/{test_user.id}", headers=authenticated_headers)
        assert response.status_code == 403


@pytest.mark.integration
@pytest.mark.documents
class TestDocumentEndpoints:
    """Test document management endpoints."""

    @patch('app.minio_client.upload_document')
    def test_upload_document_success(self, mock_upload, client, authenticated_headers):
        """Test successful document upload."""
        mock_upload.return_value = {
            "success": True,
            "filename": "test.pdf",
            "original_filename": "test.pdf",
            "file_path": "documents/test.pdf",
            "file_size": 1024.0,
            "file_type": "application/pdf",
            "file_extension": ".pdf"
        }
        
        files = {"file": ("test.pdf", b"PDF content", "application/pdf")}
        data = {
            "title": "Test Document",
            "description": "Test description",
            "category": "medical",
            "is_public": "false"
        }
        
        response = client.post("/documents/upload", headers=authenticated_headers, 
                             files=files, data=data)
        assert response.status_code == 200
        response_data = response.json()
        assert response_data["title"] == "Test Document"

    def test_upload_document_invalid_type(self, client, authenticated_headers):
        """Test document upload with invalid file type."""
        files = {"file": ("test.exe", b"EXE content", "application/x-executable")}
        data = {"title": "Test Document"}
        
        response = client.post("/documents/upload", headers=authenticated_headers, 
                             files=files, data=data)
        assert response.status_code == 400
        data = response.json()
        assert "no permitido" in data["detail"]

    def test_get_documents(self, client, authenticated_headers, test_document):
        """Test getting documents."""
        response = client.get("/documents/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_my_documents(self, client, authenticated_headers, test_document):
        """Test getting user's own documents."""
        response = client.get("/documents/my", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_public_documents(self, client, test_public_document):
        """Test getting public documents (no auth required)."""
        response = client.get("/documents/public")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_document_by_id(self, client, authenticated_headers, test_document):
        """Test getting document by ID."""
        response = client.get(f"/documents/{test_document.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_document.id

    def test_get_document_forbidden(self, client, superuser_headers, test_document):
        """Test getting private document without permission."""
        response = client.get(f"/documents/{test_document.id}", headers=superuser_headers)
        # Should succeed for superuser
        assert response.status_code == 200

    def test_update_document(self, client, authenticated_headers, test_document):
        """Test updating document."""
        update_data = {
            "title": "Updated Title",
            "description": "Updated description"
        }
        response = client.put(f"/documents/{test_document.id}", 
                            headers=authenticated_headers, json=update_data)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Title"

    @patch('app.minio_client.delete_document')
    def test_delete_document(self, mock_delete, client, authenticated_headers, test_document):
        """Test deleting document."""
        mock_delete.return_value = True
        
        response = client.delete(f"/documents/{test_document.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "eliminado" in data["message"]

    def test_search_documents(self, client, authenticated_headers, test_document):
        """Test searching documents."""
        response = client.get("/documents/search?q=Test", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "documents" in data
        assert "total" in data

    def test_get_documents_stats(self, client, authenticated_headers, test_document):
        """Test getting document statistics."""
        response = client.get("/documents/stats", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total_documents" in data


@pytest.mark.integration
@pytest.mark.clinical_images
class TestClinicalImageEndpoints:
    """Test clinical image management endpoints."""

    @patch('app.minio_client.upload_clinical_image')
    def test_upload_clinical_image_success(self, mock_upload, client, authenticated_headers):
        """Test successful clinical image upload."""
        mock_upload.return_value = {
            "success": True,
            "filename": "test.jpg",
            "original_filename": "test.jpg",
            "file_path": "clinical-images/test.jpg",
            "file_size": 2048.0,
            "file_type": "image/jpeg",
            "image_width": 800,
            "image_height": 600
        }
        
        files = {"file": ("test.jpg", b"JPEG content", "image/jpeg")}
        data = {
            "description": "Test clinical image",
            "tags": "test,clinical",
            "is_public": "false"
        }
        
        response = client.post("/clinical-images/upload", headers=authenticated_headers, 
                             files=files, data=data)
        assert response.status_code == 200
        response_data = response.json()
        assert response_data["description"] == "Test clinical image"

    def test_upload_clinical_image_invalid_type(self, client, authenticated_headers):
        """Test clinical image upload with invalid file type."""
        files = {"file": ("test.txt", b"Text content", "text/plain")}
        data = {"description": "Test image"}
        
        response = client.post("/clinical-images/upload", headers=authenticated_headers, 
                             files=files, data=data)
        assert response.status_code == 400
        data = response.json()
        assert "no permitido" in data["detail"]

    def test_get_clinical_images(self, client, authenticated_headers, test_clinical_image):
        """Test getting clinical images."""
        response = client.get("/clinical-images/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_clinical_image_by_id(self, client, authenticated_headers, test_clinical_image):
        """Test getting clinical image by ID."""
        response = client.get(f"/clinical-images/{test_clinical_image.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_clinical_image.id

    def test_update_clinical_image(self, client, authenticated_headers, test_clinical_image):
        """Test updating clinical image."""
        update_data = {
            "description": "Updated description",
            "tags": "updated,tags"
        }
        response = client.put(f"/clinical-images/{test_clinical_image.id}", 
                            headers=authenticated_headers, json=update_data)
        assert response.status_code == 200
        data = response.json()
        assert data["description"] == "Updated description"

    @patch('app.minio_client.delete_clinical_image')
    def test_delete_clinical_image(self, mock_delete, client, authenticated_headers, test_clinical_image):
        """Test deleting clinical image."""
        mock_delete.return_value = True
        
        response = client.delete(f"/clinical-images/{test_clinical_image.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "eliminada" in data["message"]

    def test_search_clinical_images(self, client, authenticated_headers, test_clinical_image):
        """Test searching clinical images."""
        response = client.get("/clinical-images/search?q=Test", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "images" in data
        assert "total" in data


@pytest.mark.integration
@pytest.mark.drugs
class TestDrugEndpoints:
    """Test drug endpoints."""

    def test_get_drugs(self, client, authenticated_headers, test_drug):
        """Test getting drugs."""
        response = client.get("/drugs/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_drug_by_id(self, client, authenticated_headers, test_drug):
        """Test getting drug by ID."""
        response = client.get(f"/drugs/{test_drug.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_drug.id
        assert data["name"] == test_drug.name

    def test_get_drug_not_found(self, client, authenticated_headers):
        """Test getting non-existent drug."""
        response = client.get("/drugs/99999", headers=authenticated_headers)
        assert response.status_code == 404

    def test_search_drugs(self, client, authenticated_headers, test_drug):
        """Test searching drugs."""
        response = client.get("/drugs/search?q=Acetaminophen", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "drugs" in data
        assert "total" in data

    def test_get_drugs_by_therapeutic_class(self, client, authenticated_headers, test_drug):
        """Test getting drugs by therapeutic class."""
        response = client.get("/drugs/therapeutic-class/Analgesics", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_prescription_drugs(self, client, authenticated_headers):
        """Test getting prescription-only drugs."""
        response = client.get("/drugs/prescription-only", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_seed_drugs_as_superuser(self, client, superuser_headers):
        """Test seeding drugs as superuser."""
        with patch('app.crud.seed_drugs') as mock_seed:
            mock_seed.return_value = True
            response = client.post("/drugs/seed", headers=superuser_headers)
            assert response.status_code == 200
            data = response.json()
            assert "exitosamente" in data["message"]

    def test_seed_drugs_as_regular_user(self, client, authenticated_headers):
        """Test seeding drugs as regular user (should fail)."""
        response = client.post("/drugs/seed", headers=authenticated_headers)
        assert response.status_code == 403


@pytest.mark.integration
@pytest.mark.calculators
class TestCalculatorEndpoints:
    """Test clinical calculator endpoints."""

    def test_get_calculators(self, client, authenticated_headers):
        """Test getting available calculators."""
        response = client.get("/calculators/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "calculators" in data
        assert isinstance(data["calculators"], list)

    def test_calculate_curb65(self, client, authenticated_headers, curb65_test_data):
        """Test CURB-65 calculation."""
        request_data = curb65_test_data["low_risk"]
        response = client.post("/calculators/curb65", headers=authenticated_headers, json=request_data)
        assert response.status_code == 200
        data = response.json()
        assert data["score"] == request_data["expected_score"]
        assert data["risk_level"] == request_data["expected_risk"]

    def test_calculate_wells_pe(self, client, authenticated_headers, wells_pe_test_data):
        """Test Wells PE calculation."""
        request_data = wells_pe_test_data["low_risk"]
        response = client.post("/calculators/wells-pe", headers=authenticated_headers, json=request_data)
        assert response.status_code == 200
        data = response.json()
        assert data["score"] == request_data["expected_score"]
        assert data["risk_level"] == request_data["expected_risk"]

    def test_calculate_glasgow_coma(self, client, authenticated_headers, glasgow_test_data):
        """Test Glasgow Coma Scale calculation."""
        request_data = glasgow_test_data["mild"]
        response = client.post("/calculators/glasgow-coma", headers=authenticated_headers, json=request_data)
        assert response.status_code == 200
        data = response.json()
        assert data["score"] == request_data["expected_score"]
        assert data["risk_level"] == request_data["expected_risk"]

    def test_calculate_chads2_vasc(self, client, authenticated_headers, chads2_vasc_test_data):
        """Test CHA2DS2-VASc calculation."""
        request_data = chads2_vasc_test_data["low_risk"]
        response = client.post("/calculators/chads2-vasc", headers=authenticated_headers, json=request_data)
        assert response.status_code == 200
        data = response.json()
        assert data["score"] == request_data["expected_score"]
        assert data["risk_level"] == request_data["expected_risk"]


@pytest.mark.integration
@pytest.mark.shifts
class TestShiftEndpoints:
    """Test shift management endpoints."""

    def test_get_user_shifts(self, client, authenticated_headers, test_shift):
        """Test getting user shifts."""
        response = client.get("/shifts/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_today_shifts(self, client, authenticated_headers):
        """Test getting today's shifts."""
        response = client.get("/shifts/today", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_upcoming_shifts(self, client, authenticated_headers):
        """Test getting upcoming shifts."""
        response = client.get("/shifts/upcoming?days=7", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_active_shift(self, client, authenticated_headers):
        """Test getting active shift."""
        response = client.get("/shifts/active", headers=authenticated_headers)
        assert response.status_code == 200
        # Can return None if no active shift

    def test_get_shift_by_id(self, client, authenticated_headers, test_shift):
        """Test getting shift by ID."""
        response = client.get(f"/shifts/{test_shift.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_shift.id

    def test_create_shift(self, client, authenticated_headers):
        """Test creating a new shift."""
        shift_data = {
            "title": "New Shift",
            "shift_type": "mañana",
            "start_date": "2024-01-15T08:00:00",
            "end_date": "2024-01-15T16:00:00",
            "description": "Morning shift",
            "location": "Emergency Department",
            "status": "programado"
        }
        response = client.post("/shifts/", headers=authenticated_headers, json=shift_data)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "New Shift"

    def test_update_shift(self, client, authenticated_headers, test_shift):
        """Test updating a shift."""
        update_data = {
            "title": "Updated Shift",
            "description": "Updated description"
        }
        response = client.put(f"/shifts/{test_shift.id}", headers=authenticated_headers, json=update_data)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Shift"

    def test_delete_shift(self, client, authenticated_headers, test_shift):
        """Test deleting a shift."""
        response = client.delete(f"/shifts/{test_shift.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "eliminado" in data["message"]

    def test_search_shifts(self, client, authenticated_headers, test_shift):
        """Test searching shifts."""
        response = client.get("/shifts/search/Night", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_shift_statistics(self, client, authenticated_headers):
        """Test getting shift statistics."""
        response = client.get("/shifts/statistics/user", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total_shifts" in data

    def test_seed_shifts_as_superuser(self, client, superuser_headers):
        """Test seeding shifts as superuser."""
        with patch('app.crud.seed_sample_shifts') as mock_seed:
            mock_seed.return_value = True
            response = client.post("/shifts/seed", headers=superuser_headers)
            assert response.status_code == 200
            data = response.json()
            assert "exitosamente" in data["message"]


@pytest.mark.integration
@pytest.mark.procedures
class TestProcedureEndpoints:
    """Test procedure endpoints."""

    def test_get_procedures(self, client, authenticated_headers, test_procedure):
        """Test getting procedures."""
        response = client.get("/procedures/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_featured_procedures(self, client, authenticated_headers):
        """Test getting featured procedures."""
        response = client.get("/procedures/featured", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_procedure_by_id(self, client, authenticated_headers, test_procedure):
        """Test getting procedure by ID."""
        response = client.get(f"/procedures/{test_procedure.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_procedure.id

    def test_search_procedures(self, client, authenticated_headers, test_procedure):
        """Test searching procedures."""
        response = client.get("/procedures/search?q=Central", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "procedures" in data
        assert "total" in data

    def test_rate_procedure(self, client, authenticated_headers, test_procedure):
        """Test rating a procedure."""
        rating_data = {"rating": 4.5}
        response = client.post(f"/procedures/{test_procedure.id}/rate?rating=4.5", 
                             headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "exitosamente" in data["message"]

    def test_seed_procedures_as_superuser(self, client, superuser_headers):
        """Test seeding procedures as superuser."""
        with patch('app.crud.seed_sample_procedures') as mock_seed:
            mock_seed.return_value = True
            response = client.post("/procedures/seed", headers=superuser_headers)
            assert response.status_code == 200
            data = response.json()
            assert "exitosamente" in data["message"]


@pytest.mark.integration
@pytest.mark.algorithms
class TestAlgorithmEndpoints:
    """Test algorithm endpoints."""

    def test_get_algorithms(self, client, authenticated_headers, test_algorithm):
        """Test getting algorithms."""
        response = client.get("/algorithms/", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_featured_algorithms(self, client, authenticated_headers):
        """Test getting featured algorithms."""
        response = client.get("/algorithms/featured", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    def test_get_algorithm_by_id(self, client, authenticated_headers, test_algorithm):
        """Test getting algorithm by ID."""
        response = client.get(f"/algorithms/{test_algorithm.id}", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_algorithm.id

    def test_get_algorithm_full(self, client, authenticated_headers, test_algorithm):
        """Test getting full algorithm with nodes and edges."""
        response = client.get(f"/algorithms/{test_algorithm.id}/full", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_algorithm.id
        assert "nodes" in data
        assert "edges" in data

    def test_search_algorithms(self, client, authenticated_headers, test_algorithm):
        """Test searching algorithms."""
        response = client.get("/algorithms/search?q=ACLS", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "algorithms" in data
        assert "total" in data

    def test_seed_algorithms_as_superuser(self, client, superuser_headers):
        """Test seeding algorithms as superuser."""
        with patch('app.crud.seed_sample_algorithms') as mock_seed:
            mock_seed.return_value = True
            response = client.post("/algorithms/seed", headers=superuser_headers)
            assert response.status_code == 200
            data = response.json()
            assert "exitosamente" in data["message"]


@pytest.mark.integration
@pytest.mark.ai
class TestAIEndpoints:
    """Test AI assistant endpoints."""

    @patch('openai.ChatCompletion.create')
    def test_chat_with_ai(self, mock_openai, client, authenticated_headers):
        """Test chat with AI assistant."""
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = "AI response"
        mock_openai.return_value = mock_response
        
        message_data = {"message": "What is hypertension?"}
        response = client.post("/ai/chat", headers=authenticated_headers, json=message_data)
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "response" in data

    def test_chat_with_ai_no_api_key(self, client, authenticated_headers):
        """Test chat with AI when API key is not configured."""
        with patch.dict('os.environ', {}, clear=True):
            message_data = {"message": "What is hypertension?"}
            response = client.post("/ai/chat", headers=authenticated_headers, json=message_data)
            assert response.status_code == 500

    def test_get_ai_suggestions(self, client, authenticated_headers):
        """Test getting AI suggestions."""
        response = client.get("/ai/suggestions?context=turno", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "suggestions" in data
        assert isinstance(data["suggestions"], list)

    def test_get_medical_info(self, client, authenticated_headers):
        """Test getting medical information."""
        response = client.get("/ai/medical-info/hipertension", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert "topic" in data
        assert "information" in data

    def test_get_medical_info_not_found(self, client, authenticated_headers):
        """Test getting medical information for unknown topic."""
        response = client.get("/ai/medical-info/unknown_condition", headers=authenticated_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["information"] is None
        assert "No se encontró" in data["message"]


@pytest.mark.integration
@pytest.mark.error_handling
class TestErrorHandling:
    """Test error handling and edge cases."""

    def test_unauthenticated_access(self, client):
        """Test accessing protected endpoints without authentication."""
        protected_endpoints = [
            "/users/",
            "/documents/",
            "/clinical-images/",
            "/drugs/",
            "/shifts/",
            "/calculators/",
            "/ai/chat"
        ]
        
        for endpoint in protected_endpoints:
            response = client.get(endpoint)
            assert response.status_code == 401

    def test_invalid_json_request(self, client, authenticated_headers):
        """Test requests with invalid JSON."""
        response = client.post("/auth/login", 
                             headers=authenticated_headers,
                             data="invalid json")
        assert response.status_code == 422

    def test_missing_required_fields(self, client):
        """Test requests with missing required fields."""
        # Test login without password
        response = client.post("/auth/login", json={"email": "test@example.com"})
        assert response.status_code == 422

        # Test registration without required fields
        response = client.post("/auth/register", json={"email": "test@example.com"})
        assert response.status_code == 422

    def test_pagination_parameters(self, client, authenticated_headers, test_document):
        """Test pagination parameters."""
        # Test valid pagination
        response = client.get("/documents/?skip=0&limit=10", headers=authenticated_headers)
        assert response.status_code == 200

        # Test with large limit
        response = client.get("/documents/?skip=0&limit=1000", headers=authenticated_headers)
        assert response.status_code == 200

    def test_file_upload_size_limit(self, client, authenticated_headers):
        """Test file upload size limits."""
        # Create a large fake file (mock)
        large_content = b"x" * (51 * 1024 * 1024)  # 51MB (over limit)
        files = {"file": ("large.pdf", large_content, "application/pdf")}
        data = {"title": "Large Document"}
        
        response = client.post("/documents/upload", 
                             headers=authenticated_headers, 
                             files=files, data=data)
        assert response.status_code == 400
        assert "demasiado grande" in response.json()["detail"]

    def test_sql_injection_protection(self, client, authenticated_headers):
        """Test SQL injection protection."""
        # Try SQL injection in search queries
        malicious_queries = [
            "'; DROP TABLE users; --",
            "1' OR '1'='1",
            "UNION SELECT * FROM users"
        ]
        
        for query in malicious_queries:
            response = client.get(f"/documents/search?q={query}", headers=authenticated_headers)
            # Should not cause server error
            assert response.status_code in [200, 400, 422]

    def test_rate_limiting_simulation(self, client, authenticated_headers):
        """Simulate rate limiting by making multiple requests."""
        # Make multiple rapid requests (this tests that the server handles them gracefully)
        for _ in range(10):
            response = client.get("/health")
            assert response.status_code == 200

    def test_concurrent_requests(self, client, authenticated_headers):
        """Test handling of concurrent requests."""
        import concurrent.futures
        
        def make_request():
            return client.get("/health")
        
        # Make concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200