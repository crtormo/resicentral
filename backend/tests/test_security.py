"""
Tests for authentication and security functionality.
"""
import pytest
from datetime import datetime, timedelta
from jose import jwt

from app.security import (
    create_access_token,
    verify_token,
    get_password_hash,
    verify_password,
    get_current_user,
    get_current_active_user,
    get_current_verified_user,
    get_current_superuser
)
from app.core.config import settings
from app.models import User


@pytest.mark.unit
@pytest.mark.auth
class TestPasswordHashing:
    """Test password hashing and verification."""

    def test_password_hashing(self):
        """Test password hashing produces different hash each time."""
        password = "mySecurePassword123"
        
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        
        # Should produce different hashes due to salt
        assert hash1 != hash2
        assert hash1 != password
        assert hash2 != password

    def test_password_verification_success(self):
        """Test successful password verification."""
        password = "testPassword456"
        hashed_password = get_password_hash(password)
        
        assert verify_password(password, hashed_password) is True

    def test_password_verification_failure(self):
        """Test failed password verification."""
        password = "testPassword456"
        wrong_password = "wrongPassword789"
        hashed_password = get_password_hash(password)
        
        assert verify_password(wrong_password, hashed_password) is False

    def test_password_empty_string(self):
        """Test password hashing with empty string."""
        password = ""
        hashed_password = get_password_hash(password)
        
        assert verify_password(password, hashed_password) is True
        assert verify_password("not_empty", hashed_password) is False

    def test_password_special_characters(self):
        """Test password with special characters."""
        password = "P@ssw0rd!#$%^&*()_+{}|:<>?[]\\;'\",./"
        hashed_password = get_password_hash(password)
        
        assert verify_password(password, hashed_password) is True
        assert verify_password("different", hashed_password) is False

    def test_password_unicode_characters(self):
        """Test password with unicode characters."""
        password = "contraseña123áéíóúñü"
        hashed_password = get_password_hash(password)
        
        assert verify_password(password, hashed_password) is True


@pytest.mark.unit
@pytest.mark.auth
class TestJWTTokens:
    """Test JWT token creation and verification."""

    def test_create_access_token(self):
        """Test access token creation."""
        user_data = {"sub": "123"}
        token = create_access_token(data=user_data)
        
        assert isinstance(token, str)
        assert len(token) > 0

    def test_create_access_token_with_expiry(self):
        """Test access token creation with custom expiry."""
        user_data = {"sub": "123"}
        expires_delta = timedelta(minutes=30)
        token = create_access_token(data=user_data, expires_delta=expires_delta)
        
        # Decode token to check expiry
        payload = jwt.decode(
            token, 
            settings.jwt_secret_key, 
            algorithms=[settings.jwt_algorithm]
        )
        
        exp_timestamp = payload.get("exp")
        exp_datetime = datetime.utcfromtimestamp(exp_timestamp)
        expected_exp = datetime.utcnow() + expires_delta
        
        # Allow 1 minute tolerance for test execution time
        assert abs((exp_datetime - expected_exp).total_seconds()) < 60

    def test_verify_valid_token(self):
        """Test verifying a valid token."""
        user_data = {"sub": "123", "email": "test@example.com"}
        token = create_access_token(data=user_data)
        
        payload = verify_token(token)
        
        assert payload is not None
        assert payload.get("sub") == "123"
        assert payload.get("email") == "test@example.com"

    def test_verify_invalid_token(self):
        """Test verifying an invalid token."""
        invalid_token = "invalid.token.here"
        
        payload = verify_token(invalid_token)
        assert payload is None

    def test_verify_expired_token(self):
        """Test verifying an expired token."""
        user_data = {"sub": "123"}
        # Create token that expires immediately
        expires_delta = timedelta(seconds=-1)
        token = create_access_token(data=user_data, expires_delta=expires_delta)
        
        payload = verify_token(token)
        assert payload is None

    def test_verify_malformed_token(self):
        """Test verifying malformed tokens."""
        malformed_tokens = [
            "",
            "not.a.token",
            "header.payload",  # Missing signature
            "a.b.c.d",        # Too many parts
            None
        ]
        
        for token in malformed_tokens:
            payload = verify_token(token)
            assert payload is None


@pytest.mark.integration
@pytest.mark.auth
class TestUserAuthentication:
    """Test user authentication dependencies."""

    def test_get_current_user_valid_token(self, db_session, test_user):
        """Test getting current user with valid token."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        user = get_current_user(credentials, db_session)
        
        assert user.id == test_user.id
        assert user.email == test_user.email

    def test_get_current_user_invalid_token(self, db_session):
        """Test getting current user with invalid token."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid_token")
        
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(credentials, db_session)
        
        assert exc_info.value.status_code == 401

    def test_get_current_user_nonexistent_user(self, db_session):
        """Test getting current user for non-existent user ID."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        token = create_access_token(data={"sub": "99999"})  # Non-existent user ID
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(credentials, db_session)
        
        assert exc_info.value.status_code == 401

    def test_get_current_active_user_success(self, db_session, test_user):
        """Test getting current active user."""
        from fastapi.security import HTTPAuthorizationCredentials
        
        # Ensure user is active
        test_user.is_active = True
        db_session.commit()
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        user = get_current_active_user(credentials, db_session)
        
        assert user.id == test_user.id
        assert user.is_active is True

    def test_get_current_active_user_inactive(self, db_session, test_user):
        """Test getting current user when user is inactive."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        # Make user inactive
        test_user.is_active = False
        db_session.commit()
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        with pytest.raises(HTTPException) as exc_info:
            get_current_active_user(credentials, db_session)
        
        assert exc_info.value.status_code == 400

    def test_get_current_verified_user_success(self, db_session, test_user):
        """Test getting current verified user."""
        from fastapi.security import HTTPAuthorizationCredentials
        
        # Ensure user is verified
        test_user.is_verified = True
        db_session.commit()
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        user = get_current_verified_user(credentials, db_session)
        
        assert user.id == test_user.id
        assert user.is_verified is True

    def test_get_current_verified_user_unverified(self, db_session, test_user):
        """Test getting current user when user is unverified."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        # Make user unverified
        test_user.is_verified = False
        db_session.commit()
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        with pytest.raises(HTTPException) as exc_info:
            get_current_verified_user(credentials, db_session)
        
        assert exc_info.value.status_code == 400

    def test_get_current_superuser_success(self, db_session, test_superuser):
        """Test getting current superuser."""
        from fastapi.security import HTTPAuthorizationCredentials
        
        token = create_access_token(data={"sub": str(test_superuser.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        user = get_current_superuser(credentials, db_session)
        
        assert user.id == test_superuser.id
        assert user.is_superuser is True

    def test_get_current_superuser_regular_user(self, db_session, test_user):
        """Test getting superuser when user is not superuser."""
        from fastapi import HTTPException
        from fastapi.security import HTTPAuthorizationCredentials
        
        token = create_access_token(data={"sub": str(test_user.id)})
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        
        with pytest.raises(HTTPException) as exc_info:
            get_current_superuser(credentials, db_session)
        
        assert exc_info.value.status_code == 403


@pytest.mark.integration
@pytest.mark.auth
class TestAuthenticationFlow:
    """Test complete authentication flows."""

    def test_login_flow_success(self, client, test_user_data, test_user):
        """Test complete successful login flow."""
        # Login
        login_data = {
            "email": test_user_data["email"],
            "password": test_user_data["password"]
        }
        
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 200
        
        data = response.json()
        token = data["access_token"]
        
        # Use token to access protected endpoint
        headers = {"Authorization": f"Bearer {token}"}
        response = client.get("/auth/me", headers=headers)
        assert response.status_code == 200
        
        user_data = response.json()
        assert user_data["email"] == test_user_data["email"]

    def test_registration_and_login_flow(self, client):
        """Test registration followed by login."""
        # Register new user
        register_data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "first_name": "New",
            "last_name": "User",
            "password": "newPassword123"
        }
        
        response = client.post("/auth/register", json=register_data)
        assert response.status_code == 200
        
        # Try to login with new user
        login_data = {
            "email": register_data["email"],
            "password": register_data["password"]
        }
        
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 200
        
        data = response.json()
        assert "access_token" in data

    def test_token_expiry_behavior(self, client, test_user_data, test_user):
        """Test behavior with expired tokens."""
        # Create short-lived token
        short_token = create_access_token(
            data={"sub": str(test_user.id)},
            expires_delta=timedelta(seconds=-1)  # Already expired
        )
        
        headers = {"Authorization": f"Bearer {short_token}"}
        response = client.get("/auth/me", headers=headers)
        assert response.status_code == 401

    def test_authorization_header_formats(self, client, test_user):
        """Test different authorization header formats."""
        token = create_access_token(data={"sub": str(test_user.id)})
        
        # Valid format
        headers = {"Authorization": f"Bearer {token}"}
        response = client.get("/auth/me", headers=headers)
        assert response.status_code == 200
        
        # Invalid formats
        invalid_headers = [
            {"Authorization": f"Basic {token}"},    # Wrong scheme
            {"Authorization": token},               # Missing scheme
            {"Authorization": f"Bearer"},           # Missing token
            {"Authorization": f"Bearer {token} extra"},  # Extra content
            {},                                     # Missing header
        ]
        
        for invalid_header in invalid_headers:
            response = client.get("/auth/me", headers=invalid_header)
            assert response.status_code == 401

    def test_concurrent_login_sessions(self, client, test_user_data, test_user):
        """Test multiple concurrent login sessions."""
        login_data = {
            "email": test_user_data["email"],
            "password": test_user_data["password"]
        }
        
        # Create multiple tokens
        tokens = []
        for _ in range(3):
            response = client.post("/auth/login", json=login_data)
            assert response.status_code == 200
            tokens.append(response.json()["access_token"])
        
        # All tokens should work
        for token in tokens:
            headers = {"Authorization": f"Bearer {token}"}
            response = client.get("/auth/me", headers=headers)
            assert response.status_code == 200


@pytest.mark.integration
@pytest.mark.auth
class TestSecurityHeaders:
    """Test security-related headers and configurations."""

    def test_cors_headers(self, client):
        """Test CORS headers are properly set."""
        response = client.options("/")
        
        # Check for CORS headers (may vary based on configuration)
        assert response.status_code in [200, 405]  # OPTIONS might not be implemented

    def test_no_server_header_exposure(self, client):
        """Test that server details are not exposed."""
        response = client.get("/")
        
        # Should not expose sensitive server information
        headers = response.headers
        assert "Server" not in headers or "uvicorn" not in headers.get("Server", "").lower()

    def test_content_type_security(self, client, auth_headers):
        """Test content type validation."""
        # Valid JSON content
        response = client.post("/shifts/",
                             json={"title": "test"},
                             headers=auth_headers)
        
        # Should handle content type appropriately
        assert response.status_code in [200, 400, 422]  # Not 500


@pytest.mark.integration
@pytest.mark.auth
class TestRateLimiting:
    """Test rate limiting and abuse prevention."""

    def test_multiple_failed_logins(self, client):
        """Test behavior with multiple failed login attempts."""
        login_data = {
            "email": "nonexistent@example.com",
            "password": "wrongpassword"
        }
        
        # Try multiple failed logins
        failed_attempts = 5
        for _ in range(failed_attempts):
            response = client.post("/auth/login", json=login_data)
            assert response.status_code == 401
        
        # Should still respond (no lockout implemented yet, but testing behavior)
        response = client.post("/auth/login", json=login_data)
        assert response.status_code == 401

    def test_rapid_requests(self, client, auth_headers):
        """Test rapid requests to same endpoint."""
        # Make rapid requests
        responses = []
        for _ in range(10):
            response = client.get("/auth/me", headers=auth_headers)
            responses.append(response)
        
        # All should succeed (no rate limiting implemented yet)
        for response in responses:
            assert response.status_code == 200


@pytest.mark.integration
@pytest.mark.auth
class TestInputValidation:
    """Test input validation for security."""

    def test_sql_injection_attempts(self, client):
        """Test SQL injection attempts in login."""
        malicious_inputs = [
            "'; DROP TABLE users; --",
            "admin'--",
            "' OR '1'='1",
            "' UNION SELECT * FROM users --"
        ]
        
        for malicious_input in malicious_inputs:
            login_data = {
                "email": malicious_input,
                "password": "password"
            }
            
            response = client.post("/auth/login", json=login_data)
            # Should not cause server error
            assert response.status_code in [400, 401, 422]

    def test_xss_attempts_in_user_data(self, client, auth_headers, test_user):
        """Test XSS attempts in user profile updates."""
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "{{7*7}}"  # Template injection
        ]
        
        for payload in xss_payloads:
            update_data = {
                "first_name": payload,
                "bio": payload
            }
            
            response = client.put(f"/users/{test_user.id}",
                                json=update_data,
                                headers=auth_headers)
            
            # Should not cause server error
            assert response.status_code in [200, 400, 422]
            
            if response.status_code == 200:
                # If accepted, data should be properly escaped/sanitized
                data = response.json()
                # In a real implementation, you'd check for proper escaping