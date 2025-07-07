"""
Integration tests for API endpoints.
"""
import pytest
import json
from datetime import datetime, timedelta
from fastapi.testclient import TestClient

from app.models import User, Drug, Shift, Procedure


@pytest.mark.integration
@pytest.mark.api
class TestHealthEndpoints:
    """Test health and status endpoints."""

    def test_root_endpoint(self, client):
        """Test root endpoint."""
        response = client.get("/")
        assert response.status_code == 200
        
        data = response.json()
        assert "message" in data
        assert "version" in data
        assert "status" in data
        assert data["status"] == "active"

    def test_health_check(self, client):
        """Test health check endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert "service" in data
        assert "version" in data
        assert "database" in data


@pytest.mark.integration
@pytest.mark.api
@pytest.mark.auth
class TestAuthenticationEndpoints:
    """Test authentication endpoints."""

    def test_register_user_success(self, client, test_user_data):
        """Test successful user registration."""
        response = client.post("/auth/register", json=test_user_data)
        assert response.status_code == 200
        
        data = response.json()
        assert data["email"] == test_user_data["email"]
        assert data["username"] == test_user_data["username"]
        assert data["is_active"] is True
        assert data["is_verified"] is False
        assert "hashed_password" not in data  # Should not expose password

    def test_register_duplicate_email(self, client, test_user_data, test_user):
        """Test registration with duplicate email."""
        response = client.post("/auth/register", json=test_user_data)
        assert response.status_code == 400
        
        data = response.json()
        assert "email ya está registrado" in data["detail"]

    def test_register_duplicate_username(self, client, test_user_data, test_user):
        """Test registration with duplicate username."""
        user_data = test_user_data.copy()
        user_data["email"] = "different@example.com"
        
        response = client.post("/auth/register", json=user_data)
        assert response.status_code == 400
        
        data = response.json()
        assert "nombre de usuario ya está en uso" in data["detail"]

    def test_login_success(self, client, test_user_data, test_user):
        """Test successful login."""
        login_data = {
            "email": test_user_data["email"],
            "password": test_user_data["password"]
        }
        
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 200
        
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert "user" in data
        assert data["user"]["email"] == test_user_data["email"]

    def test_login_invalid_credentials(self, client, test_user_data):
        """Test login with invalid credentials."""
        login_data = {
            "email": test_user_data["email"],
            "password": "wrongpassword"
        }
        
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 401
        
        data = response.json()
        assert "Email o contraseña incorrectos" in data["detail"]

    def test_get_current_user(self, client, auth_headers, test_user):
        """Test getting current user profile."""
        response = client.get("/auth/me", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["id"] == test_user.id
        assert data["email"] == test_user.email
        assert data["username"] == test_user.username

    def test_get_current_user_unauthorized(self, client):
        """Test getting current user without authentication."""
        response = client.get("/auth/me")
        assert response.status_code == 401


@pytest.mark.integration
@pytest.mark.api
class TestUserEndpoints:
    """Test user management endpoints."""

    def test_get_users_superuser(self, client, superuser_headers, test_user):
        """Test getting users list as superuser."""
        response = client.get("/users/", headers=superuser_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1  # At least the test user

    def test_get_users_regular_user(self, client, auth_headers):
        """Test getting users list as regular user (should fail)."""
        response = client.get("/users/", headers=auth_headers)
        assert response.status_code == 403

    def test_get_user_by_id(self, client, auth_headers, test_user):
        """Test getting specific user by ID."""
        response = client.get(f"/users/{test_user.id}", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["id"] == test_user.id
        assert data["email"] == test_user.email

    def test_get_other_user_forbidden(self, client, auth_headers, test_superuser):
        """Test getting other user's profile (should fail)."""
        response = client.get(f"/users/{test_superuser.id}", headers=auth_headers)
        assert response.status_code == 403

    def test_update_user_profile(self, client, auth_headers, test_user):
        """Test updating user profile."""
        update_data = {
            "first_name": "Updated",
            "last_name": "Name",
            "bio": "Updated bio"
        }
        
        response = client.put(f"/users/{test_user.id}", 
                            json=update_data, 
                            headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["first_name"] == "Updated"
        assert data["last_name"] == "Name"
        assert data["bio"] == "Updated bio"

    def test_change_password(self, client, auth_headers, test_user, test_user_data):
        """Test changing user password."""
        password_data = {
            "current_password": test_user_data["password"],
            "new_password": "newSecurePassword123"
        }
        
        response = client.put(f"/users/{test_user.id}/change-password",
                            json=password_data,
                            headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "exitosamente" in data["message"]

    def test_change_password_wrong_current(self, client, auth_headers, test_user):
        """Test changing password with wrong current password."""
        password_data = {
            "current_password": "wrongCurrentPassword",
            "new_password": "newSecurePassword123"
        }
        
        response = client.put(f"/users/{test_user.id}/change-password",
                            json=password_data,
                            headers=auth_headers)
        assert response.status_code == 400
        
        data = response.json()
        assert "Contraseña actual incorrecta" in data["detail"]


@pytest.mark.integration
@pytest.mark.api
class TestDrugEndpoints:
    """Test drug/vademecum endpoints."""

    def test_get_drugs(self, client, auth_headers, test_drug):
        """Test getting drugs list."""
        response = client.get("/drugs/", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_get_drug_by_id(self, client, auth_headers, test_drug):
        """Test getting specific drug by ID."""
        response = client.get(f"/drugs/{test_drug.id}", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["id"] == test_drug.id
        assert data["name"] == test_drug.name
        assert data["therapeutic_class"] == test_drug.therapeutic_class

    def test_get_drug_not_found(self, client, auth_headers):
        """Test getting non-existent drug."""
        response = client.get("/drugs/99999", headers=auth_headers)
        assert response.status_code == 404

    def test_search_drugs(self, client, auth_headers, test_drug):
        """Test searching drugs."""
        response = client.get("/drugs/search?q=Paracetamol", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "drugs" in data
        assert "total" in data
        assert len(data["drugs"]) >= 1

    def test_get_drugs_by_therapeutic_class(self, client, auth_headers, test_drug):
        """Test getting drugs by therapeutic class."""
        response = client.get("/drugs/therapeutic-class/Analgesic", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_get_prescription_drugs(self, client, auth_headers):
        """Test getting prescription-only drugs."""
        response = client.get("/drugs/prescription-only", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_seed_drugs_superuser(self, client, superuser_headers):
        """Test seeding drugs database as superuser."""
        response = client.post("/drugs/seed", headers=superuser_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "exitosamente" in data["message"]

    def test_seed_drugs_regular_user(self, client, auth_headers):
        """Test seeding drugs as regular user (should fail)."""
        response = client.post("/drugs/seed", headers=auth_headers)
        assert response.status_code == 403


@pytest.mark.integration
@pytest.mark.api
class TestShiftEndpoints:
    """Test shift management endpoints."""

    def test_get_user_shifts(self, client, auth_headers, test_shift):
        """Test getting user's shifts."""
        response = client.get("/shifts/", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        assert data[0]["id"] == test_shift.id

    def test_get_today_shifts(self, client, auth_headers):
        """Test getting today's shifts."""
        response = client.get("/shifts/today", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_get_upcoming_shifts(self, client, auth_headers):
        """Test getting upcoming shifts."""
        response = client.get("/shifts/upcoming?days=7", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_get_shifts_by_month(self, client, auth_headers):
        """Test getting shifts by month."""
        now = datetime.now()
        response = client.get(f"/shifts/month/{now.year}/{now.month}", 
                            headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_get_shift_by_id(self, client, auth_headers, test_shift):
        """Test getting specific shift by ID."""
        response = client.get(f"/shifts/{test_shift.id}", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["id"] == test_shift.id
        assert data["title"] == test_shift.title

    def test_create_shift(self, client, auth_headers):
        """Test creating a new shift."""
        start_time = datetime.utcnow() + timedelta(days=1)
        end_time = start_time + timedelta(hours=8)
        
        shift_data = {
            "title": "New Test Shift",
            "shift_type": "tarde",
            "start_date": start_time.isoformat(),
            "end_date": end_time.isoformat(),
            "location": "Test Hospital",
            "department": "Test Department",
            "status": "programado"
        }
        
        response = client.post("/shifts/", json=shift_data, headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["title"] == "New Test Shift"
        assert data["shift_type"] == "tarde"

    def test_create_shift_missing_fields(self, client, auth_headers):
        """Test creating shift with missing required fields."""
        shift_data = {
            "title": "Incomplete Shift"
            # Missing required fields
        }
        
        response = client.post("/shifts/", json=shift_data, headers=auth_headers)
        assert response.status_code == 400

    def test_update_shift(self, client, auth_headers, test_shift):
        """Test updating a shift."""
        update_data = {
            "title": "Updated Shift Title",
            "description": "Updated description"
        }
        
        response = client.put(f"/shifts/{test_shift.id}",
                            json=update_data,
                            headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["title"] == "Updated Shift Title"
        assert data["description"] == "Updated description"

    def test_delete_shift(self, client, auth_headers, db_session, test_user):
        """Test deleting a shift."""
        # Create a shift to delete
        shift = Shift(
            title="Shift to Delete",
            shift_type="noche",
            start_date=datetime.utcnow() + timedelta(days=2),
            end_date=datetime.utcnow() + timedelta(days=2, hours=8),
            user_id=test_user.id,
            status="programado"
        )
        db_session.add(shift)
        db_session.commit()
        db_session.refresh(shift)
        
        response = client.delete(f"/shifts/{shift.id}", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "eliminado exitosamente" in data["message"]

    def test_search_shifts(self, client, auth_headers, test_shift):
        """Test searching shifts."""
        response = client.get("/shifts/search/Mañana", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_get_shift_statistics(self, client, auth_headers):
        """Test getting shift statistics."""
        response = client.get("/shifts/statistics/user", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, dict)


@pytest.mark.integration
@pytest.mark.api
class TestCalculatorEndpoints:
    """Test medical calculator endpoints."""

    def test_get_calculators(self, client, auth_headers):
        """Test getting available calculators."""
        response = client.get("/calculators/", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "calculators" in data
        assert isinstance(data["calculators"], list)

    def test_curb65_calculation(self, client, auth_headers, sample_medical_data):
        """Test CURB-65 calculation endpoint."""
        response = client.post("/calculators/curb65",
                             json=sample_medical_data["curb65"],
                             headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "score" in data
        assert "risk_level" in data
        assert "interpretation" in data
        assert "recommendations" in data

    def test_wells_pe_calculation(self, client, auth_headers, sample_medical_data):
        """Test Wells PE calculation endpoint."""
        response = client.post("/calculators/wells-pe",
                             json=sample_medical_data["wells_pe"],
                             headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "score" in data
        assert "risk_level" in data

    def test_glasgow_calculation(self, client, auth_headers, sample_medical_data):
        """Test Glasgow Coma Scale calculation endpoint."""
        response = client.post("/calculators/glasgow-coma",
                             json=sample_medical_data["glasgow_coma"],
                             headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "score" in data
        assert data["score"] == 15  # Perfect score

    def test_chads2vasc_calculation(self, client, auth_headers, sample_medical_data):
        """Test CHA2DS2-VASc calculation endpoint."""
        response = client.post("/calculators/chads2-vasc",
                             json=sample_medical_data["chads2_vasc"],
                             headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "score" in data
        assert "risk_level" in data

    def test_calculator_invalid_input(self, client, auth_headers):
        """Test calculator with invalid input."""
        invalid_data = {
            "confusion": "maybe",  # Should be boolean
            "urea": "high",        # Should be number
            "respiratory_rate": -1, # Should be positive
            "blood_pressure_systolic": 300,  # Unrealistic
            "blood_pressure_diastolic": 200, # Unrealistic
            "age": -5              # Should be positive
        }
        
        response = client.post("/calculators/curb65",
                             json=invalid_data,
                             headers=auth_headers)
        assert response.status_code == 400


@pytest.mark.integration
@pytest.mark.api
class TestProcedureEndpoints:
    """Test procedure endpoints."""

    def test_get_procedures(self, client, auth_headers, test_procedure):
        """Test getting procedures list."""
        response = client.get("/procedures/", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    def test_get_procedure_by_id(self, client, auth_headers, test_procedure):
        """Test getting specific procedure by ID."""
        response = client.get(f"/procedures/{test_procedure.id}", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["id"] == test_procedure.id
        assert data["title"] == test_procedure.title

    def test_get_featured_procedures(self, client, auth_headers):
        """Test getting featured procedures."""
        response = client.get("/procedures/featured", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)

    def test_search_procedures(self, client, auth_headers, test_procedure):
        """Test searching procedures."""
        response = client.get("/procedures/search?q=Intubación", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "procedures" in data
        assert "total" in data

    def test_rate_procedure(self, client, auth_headers, test_procedure):
        """Test rating a procedure."""
        response = client.post(f"/procedures/{test_procedure.id}/rate?rating=4.5",
                             headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "exitosamente" in data["message"]

    def test_rate_procedure_invalid_rating(self, client, auth_headers, test_procedure):
        """Test rating procedure with invalid rating."""
        response = client.post(f"/procedures/{test_procedure.id}/rate?rating=6.0",
                             headers=auth_headers)
        assert response.status_code == 400


@pytest.mark.integration
@pytest.mark.api
class TestAIAssistantEndpoints:
    """Test AI assistant endpoints."""

    def test_ai_chat_success(self, client, auth_headers):
        """Test AI chat endpoint with valid message."""
        message_data = {"message": "¿Cuáles son los signos vitales normales?"}
        
        response = client.post("/ai/chat", json=message_data, headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "message" in data
        assert "response" in data
        assert "timestamp" in data
        assert "user_id" in data

    def test_ai_chat_empty_message(self, client, auth_headers):
        """Test AI chat with empty message."""
        message_data = {"message": ""}
        
        response = client.post("/ai/chat", json=message_data, headers=auth_headers)
        assert response.status_code == 400

    def test_ai_suggestions(self, client, auth_headers):
        """Test getting AI suggestions."""
        response = client.get("/ai/suggestions?context=emergencia", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "suggestions" in data
        assert isinstance(data["suggestions"], list)

    def test_ai_medical_info(self, client, auth_headers):
        """Test getting medical information."""
        response = client.get("/ai/medical-info/hipertension", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert "topic" in data
        assert "information" in data

    def test_ai_medical_info_unknown_topic(self, client, auth_headers):
        """Test getting medical info for unknown topic."""
        response = client.get("/ai/medical-info/unknown_condition", headers=auth_headers)
        assert response.status_code == 200
        
        data = response.json()
        assert data["information"] is None
        assert "No se encontró información" in data["message"]


@pytest.mark.integration
@pytest.mark.api
class TestErrorHandling:
    """Test API error handling."""

    def test_404_endpoint(self, client):
        """Test non-existent endpoint returns 404."""
        response = client.get("/nonexistent-endpoint")
        assert response.status_code == 404

    def test_unauthorized_access(self, client):
        """Test accessing protected endpoint without auth."""
        response = client.get("/users/")
        assert response.status_code == 401

    def test_malformed_json(self, client, auth_headers):
        """Test sending malformed JSON."""
        response = client.post("/shifts/",
                             data="invalid json",
                             headers=auth_headers)
        assert response.status_code == 422

    def test_invalid_content_type(self, client, auth_headers):
        """Test sending invalid content type."""
        response = client.post("/shifts/",
                             data="<xml></xml>",
                             headers={**auth_headers, "Content-Type": "application/xml"})
        assert response.status_code == 422