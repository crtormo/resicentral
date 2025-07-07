# ResiCentral Frontend Tests

This directory contains comprehensive tests for the ResiCentral Flutter application.

## Test Structure

### Test Types

1. **Unit Tests** (`unit_tests/`)
   - Test individual functions and classes in isolation
   - Mock external dependencies
   - Fast execution, no UI components

2. **Widget Tests** (`widget_tests/`)
   - Test individual widgets and their interactions
   - Test UI components and user interactions
   - Use Flutter's widget testing framework

3. **Integration Tests** (`integration_test/`)
   - Test complete user workflows
   - Test app behavior on real devices/emulators
   - End-to-end testing scenarios

### Test Organization

```
test/
├── README.md                    # This file
├── unit_tests/                  # Unit tests (currently empty, to be implemented)
├── widget_tests/                # Widget tests
│   ├── test_helpers.dart        # Test utilities and mock classes
│   ├── auth_screens_test.dart   # Authentication screen tests
│   ├── providers_test.dart      # Provider class tests
│   ├── home_screen_test.dart    # Home screen tests
│   └── calculator_screens_test.dart # Calculator screen tests
└── integration_test/            # Integration tests
    └── app_test.dart           # Full app integration tests
```

## Dependencies

The tests use these packages:

- `flutter_test` - Flutter's testing framework
- `integration_test` - Integration testing support
- `mockito` - Mocking framework
- `provider` - State management testing
- `build_runner` - Code generation for mocks

## Running Tests

### Prerequisites

1. **Flutter SDK**: Ensure Flutter is installed and in your PATH
2. **Dependencies**: Run `flutter pub get` to install dependencies
3. **Device/Emulator**: For integration tests, ensure a device or emulator is available

### Quick Start

```bash
# Run all unit and widget tests
flutter test

# Run specific test files
flutter test test/widget_tests/auth_screens_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests (requires device/emulator)
flutter test integration_test/
```

### Using the Test Runner Script

```bash
# Make script executable
chmod +x test_runner.dart

# Run all tests
dart test_runner.dart --all

# Run specific test types
dart test_runner.dart --unit
dart test_runner.dart --widget
dart test_runner.dart --integration

# Run with coverage
dart test_runner.dart --coverage

# Get help
dart test_runner.dart --help
```

### Test Categories

Run tests by category using test markers:

```bash
# Run authentication tests
flutter test --plain-name "auth"

# Run provider tests
flutter test --plain-name "provider"

# Run calculator tests
flutter test --plain-name "calculator"
```

## Test Helpers and Utilities

### TestHelpers Class

The `TestHelpers` class provides utilities for widget testing:

```dart
// Create test app with providers
Widget testApp = TestHelpers.createTestApp(
  child: MyWidget(),
  authProvider: mockAuthProvider,
);

// Common test actions
await TestHelpers.tapAndSettle(tester, finder);
await TestHelpers.enterTextAndSettle(tester, finder, "text");

// Verification helpers
TestHelpers.expectWidgetExists(find.text("Hello"));
TestHelpers.expectTextExists("Welcome");
```

### Mock Classes

Pre-built mock classes for testing:

- `MockAuthProvider` - Mock authentication provider
- `MockApiService` - Mock API service
- `MockMessageProvider` - Mock message provider

### Test Data

Common test data available:

```dart
// Test user
final user = TestHelpers.testUser;

// Mock API responses
final response = TestHelpers.mockSuccessResponse(data);
final error = TestHelpers.mockErrorResponse("Error message");
```

## Widget Test Examples

### Testing Authentication Screens

```dart
testWidgets('should display login form', (tester) async {
  await tester.pumpWidget(TestHelpers.createTestApp(
    child: LoginScreen(),
  ));

  expect(find.text('Email'), findsOneWidget);
  expect(find.text('Password'), findsOneWidget);
  expect(find.text('Login'), findsOneWidget);
});
```

### Testing Provider State

```dart
testWidgets('should update UI when provider state changes', (tester) async {
  final authProvider = MockAuthProvider();
  
  await tester.pumpWidget(TestHelpers.createTestApp(
    child: Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Text(auth.isAuthenticated ? 'Logged In' : 'Logged Out');
      },
    ),
    authProvider: authProvider,
  ));

  expect(find.text('Logged Out'), findsOneWidget);

  authProvider.setAuthenticated(TestHelpers.testUser);
  await tester.pump();

  expect(find.text('Logged In'), findsOneWidget);
});
```

### Testing User Interactions

```dart
testWidgets('should calculate CURB-65 score', (tester) async {
  await tester.pumpWidget(TestHelpers.createTestApp(
    child: Curb65Screen(),
  ));

  // Fill form
  await TestHelpers.enterTextAndSettle(
    tester, 
    find.byKey(Key('age_field')), 
    '70'
  );

  // Submit
  await TestHelpers.tapAndSettle(
    tester, 
    find.byKey(Key('calculate_button'))
  );

  // Verify result
  expect(find.text('Score: 1'), findsOneWidget);
});
```

## Integration Test Examples

### Complete User Flow

```dart
testWidgets('complete authentication and navigation flow', (tester) async {
  await tester.pumpWidget(ResiCentralApp());
  await tester.pumpAndSettle();

  // Login
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password_field')), 'password');
  await tester.tap(find.byKey(Key('login_button')));
  await tester.pumpAndSettle();

  // Navigate to calculators
  await tester.tap(find.text('Calculators'));
  await tester.pumpAndSettle();

  // Use CURB-65 calculator
  await tester.tap(find.text('CURB-65'));
  await tester.pumpAndSettle();

  // Verify navigation worked
  expect(find.text('CURB-65 Calculator'), findsOneWidget);
});
```

## Best Practices

### Test Organization

1. **Group related tests** using `group()` descriptions
2. **Use descriptive test names** that explain what is being tested
3. **Keep tests focused** - one concept per test
4. **Use setup and teardown** for common test initialization

### Widget Testing

1. **Use keys** for important widgets to make them findable
2. **Test user interactions** not just widget presence
3. **Verify state changes** after user actions
4. **Test error states** and edge cases

### Mocking

1. **Mock external dependencies** like API calls
2. **Use dependency injection** to make components testable
3. **Verify mock interactions** when testing business logic
4. **Reset mocks** between tests

### Performance

1. **Use pumpAndSettle()** sparingly - prefer pump() when possible
2. **Avoid unnecessary delays** in tests
3. **Group similar tests** to share setup costs
4. **Use testWidgets** instead of test for UI tests

## Test Coverage

### Coverage Goals

- **Overall Coverage**: 80%+
- **Widget Tests**: 85%+
- **Unit Tests**: 90%+
- **Critical Paths**: 95%+

### Generating Coverage Reports

```bash
# Generate coverage data
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# View report
open coverage/html/index.html
```

### Excluding Files from Coverage

Add to `test/coverage_helper_test.dart`:

```dart
// Helper file to import all files for coverage
// This ensures all files are included in coverage reports

// Import all lib files here
import 'package:resicentral_frontend/main.dart';
import 'package:resicentral_frontend/providers/auth_provider.dart';
// ... other imports

void main() {
  // This file helps with coverage collection
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test --coverage
      - run: flutter test integration_test/
```

### Pre-commit Hooks

```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running Flutter tests..."
flutter test

if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi

echo "All tests passed!"
```

## Troubleshooting

### Common Issues

1. **"No MaterialLocalizations found"**
   - Wrap test widgets in MaterialApp
   - Use TestHelpers.createTestApp()

2. **"Provider not found"**
   - Ensure providers are properly configured in test setup
   - Use MultiProvider in test app wrapper

3. **"Timeout waiting for widget"**
   - Use pumpAndSettle() to wait for animations
   - Increase timeout for slow operations

4. **Integration tests fail**
   - Ensure device/emulator is running
   - Check that app builds successfully
   - Verify test device has sufficient resources

### Debugging Tests

```dart
// Add debug output
testWidgets('debug test', (tester) async {
  await tester.pumpWidget(myWidget);
  
  // Print widget tree
  debugDumpApp();
  
  // Print specific widget
  print(tester.widget(find.byType(MyWidget)));
  
  // Add breakpoint
  debugger();
});
```

### Performance Issues

```dart
// Skip expensive animations in tests
testWidgets('fast test', (tester) async {
  tester.binding.setSurfaceSize(Size(800, 600));
  
  await tester.pumpWidget(myWidget);
  
  // Skip settling for performance
  await tester.pump();
  
  // Verify immediately
  expect(find.text('Hello'), findsOneWidget);
});
```

## Contributing

When adding new features:

1. **Write tests first** (TDD approach)
2. **Test both happy path and error cases**
3. **Add integration tests** for complete workflows
4. **Update this documentation** if needed
5. **Ensure all tests pass** before submitting

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Widget Testing Guide](https://docs.flutter.dev/cookbook/testing/widget)
- [Integration Testing Guide](https://docs.flutter.dev/testing/integration-tests)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Provider Testing](https://pub.dev/packages/provider#testing)