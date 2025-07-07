# ResiCentral Backend Tests

This directory contains comprehensive tests for the ResiCentral backend API.

## Test Structure

### Test Types

1. **Unit Tests** (`test_models.py`, `test_crud.py`)
   - Test individual components in isolation
   - Fast execution, no external dependencies
   - Mock external services and database interactions

2. **Integration Tests** (`test_endpoints.py`)
   - Test complete API endpoints
   - Include authentication, authorization, and business logic
   - Use test database with real data fixtures

### Test Organization

```
tests/
├── README.md                 # This file
├── fixtures.py              # Test fixtures and mock data
├── test_models.py           # Unit tests for database models
├── test_crud.py             # Unit tests for CRUD operations
└── test_endpoints.py        # Integration tests for API endpoints
```

## Test Categories

Tests are organized using pytest markers:

- `@pytest.mark.unit` - Unit tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.auth` - Authentication tests
- `@pytest.mark.users` - User management tests
- `@pytest.mark.documents` - Document management tests
- `@pytest.mark.clinical_images` - Clinical image tests
- `@pytest.mark.drugs` - Drug/pharmacy tests
- `@pytest.mark.calculators` - Clinical calculator tests
- `@pytest.mark.shifts` - Shift management tests
- `@pytest.mark.procedures` - Medical procedure tests
- `@pytest.mark.algorithms` - Medical algorithm tests
- `@pytest.mark.ai` - AI assistant tests
- `@pytest.mark.error_handling` - Error handling tests

## Running Tests

### Prerequisites

Install test dependencies:
```bash
pip install -r requirements.txt
```

### Basic Test Execution

Run all tests:
```bash
pytest
```

Run with coverage:
```bash
pytest --cov=app --cov-report=html --cov-report=term-missing
```

### Using the Test Runner Script

The `run_tests.py` script provides convenient test execution options:

```bash
# Run all tests
python run_tests.py

# Run only unit tests
python run_tests.py --unit

# Run only integration tests
python run_tests.py --integration

# Run specific test categories
python run_tests.py --auth
python run_tests.py --crud
python run_tests.py --models

# Run with coverage report
python run_tests.py --coverage

# Run specific test file
python run_tests.py --file test_endpoints.py

# Run specific test function
python run_tests.py --test test_login_success

# Run with verbose output
python run_tests.py --verbose

# Stop on first failure
python run_tests.py --fail-fast
```

### Advanced Options

Run tests in parallel:
```bash
pytest -n auto
```

Run tests with specific markers:
```bash
pytest -m "unit and not slow"
pytest -m "integration and auth"
```

Run tests with custom output:
```bash
pytest -v --tb=short --color=yes
```

## Test Environment

### Environment Variables

Tests use environment variables for configuration:
- `ENVIRONMENT=testing`
- `DATABASE_URL=sqlite:///./test.db`
- `JWT_SECRET_KEY=test_secret_key_for_testing_only`
- `MINIO_ACCESS_KEY=test_access_key`
- `MINIO_SECRET_KEY=test_secret_key`
- `LOG_LEVEL=DEBUG`

These are automatically set in the `setup_test_env` fixture.

### Test Database

Tests use an in-memory SQLite database that is:
- Created fresh for each test session
- Isolated per test function using transactions
- Automatically cleaned up after tests

### Mocking

External services are mocked in tests:
- MinIO file storage operations
- OpenAI API calls
- Email services
- External HTTP requests

## Test Data and Fixtures

### Core Fixtures

- `test_user` - Standard test user
- `test_superuser` - Superuser for admin tests
- `test_inactive_user` - Inactive user for testing access controls
- `authenticated_headers` - Headers with valid JWT token
- `superuser_headers` - Headers with superuser JWT token

### Model Fixtures

- `test_document` - Sample document
- `test_clinical_image` - Sample clinical image
- `test_drug` - Sample drug data
- `test_procedure` - Sample medical procedure
- `test_algorithm` - Sample medical algorithm
- `test_shift` - Sample work shift

### Calculator Test Data

- `curb65_test_data` - CURB-65 calculator test cases
- `wells_pe_test_data` - Wells PE calculator test cases
- `glasgow_test_data` - Glasgow Coma Scale test cases
- `chads2_vasc_test_data` - CHA2DS2-VASc calculator test cases

## Writing New Tests

### Test Naming Convention

- Test files: `test_*.py`
- Test classes: `Test*`
- Test functions: `test_*`

### Example Unit Test

```python
@pytest.mark.unit
@pytest.mark.models
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
    assert user.email == "test@example.com"
    assert user.is_active is True
```

### Example Integration Test

```python
@pytest.mark.integration
@pytest.mark.auth
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
    assert "user" in data
```

### Best Practices

1. **Test Isolation**: Each test should be independent
2. **Clear Assertions**: Use descriptive assertions
3. **Meaningful Names**: Test names should describe what they test
4. **Documentation**: Add docstrings to explain complex tests
5. **Mocking**: Mock external dependencies appropriately
6. **Data Cleanup**: Use fixtures for consistent test data

## Coverage Goals

Target coverage levels:
- **Overall**: 85%+
- **Models**: 90%+
- **CRUD Operations**: 95%+
- **API Endpoints**: 85%+
- **Business Logic**: 90%+

## Continuous Integration

Tests are designed to run in CI/CD environments:
- No external service dependencies
- Deterministic execution
- Fast execution time
- Clear failure reporting

## Troubleshooting

### Common Issues

1. **Database Locked**: Ensure proper cleanup in fixtures
2. **Import Errors**: Check PYTHONPATH and module structure
3. **Authentication Failures**: Verify JWT secret key configuration
4. **Async Issues**: Use `pytest-asyncio` for async tests

### Debug Tips

```bash
# Run with maximum verbosity
pytest -vvv --tb=long

# Run single test with print statements
pytest -s tests/test_models.py::TestUserModel::test_user_creation

# Use pdb debugger
pytest --pdb tests/test_endpoints.py::TestAuthEndpoints::test_login_success
```

## Performance

Test execution times (approximate):
- Unit tests: ~30 seconds
- Integration tests: ~2-3 minutes
- Full test suite: ~3-4 minutes

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure all tests pass
3. Maintain or improve coverage
4. Add appropriate markers
5. Update documentation

## Resources

- [pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)
- [SQLAlchemy Testing](https://docs.sqlalchemy.org/en/14/orm/session_transaction.html#joining-a-session-into-an-external-transaction-such-as-for-test-suites)