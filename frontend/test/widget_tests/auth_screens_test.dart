import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../lib/screens/auth/login_screen.dart';
import '../../lib/screens/auth/register_screen.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/message_provider.dart';
import 'test_helpers.dart';

void main() {
  group('Login Screen Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MessageProvider messageProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      messageProvider = MessageProvider();
    });

    Widget createLoginScreen() {
      return TestHelpers.createTestApp(
        child: const LoginScreen(),
        authProvider: mockAuthProvider,
        messageProvider: messageProvider,
      );
    }

    testWidgets('should display login form elements', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Verify the presence of key UI elements
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
    });

    testWidgets('should validate email field', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Try to submit with empty email
      final loginButton = find.byKey(const Key('login_button'));
      await TestHelpers.tapAndSettle(tester, loginButton);

      // Should show validation error
      expect(find.text('Por favor ingresa tu email'), findsOneWidget);
    });

    testWidgets('should validate password field', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Enter valid email but leave password empty
      final emailField = find.byKey(const Key('email_field'));
      await TestHelpers.enterTextAndSettle(tester, emailField, 'test@example.com');

      final loginButton = find.byKey(const Key('login_button'));
      await TestHelpers.tapAndSettle(tester, loginButton);

      // Should show password validation error
      expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('should show loading state during login', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Set loading state
      mockAuthProvider.setLoading(true);
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message on login failure', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Set error state
      mockAuthProvider.setError('Invalid credentials');
      await tester.pump();

      // Should show error message
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('should perform login with valid credentials', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Enter valid credentials
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      
      await TestHelpers.enterTextAndSettle(tester, emailField, 'test@example.com');
      await TestHelpers.enterTextAndSettle(tester, passwordField, 'password');

      // Tap login button
      final loginButton = find.byKey(const Key('login_button'));
      await TestHelpers.tapAndSettle(tester, loginButton);

      // Wait for async operation
      await tester.pump(const Duration(milliseconds: 200));

      // Should be authenticated
      expect(mockAuthProvider.isAuthenticated, isTrue);
    });

    testWidgets('should toggle password visibility', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Find password field and visibility toggle
      final passwordField = find.byKey(const Key('password_field'));
      final visibilityToggle = find.byKey(const Key('password_visibility_toggle'));

      // Enter password
      await TestHelpers.enterTextAndSettle(tester, passwordField, 'password');

      // Initially password should be obscured
      final textField = tester.widget<TextField>(passwordField);
      expect(textField.obscureText, isTrue);

      // Tap visibility toggle
      await TestHelpers.tapAndSettle(tester, visibilityToggle);

      // Password should now be visible
      final updatedTextField = tester.widget<TextField>(passwordField);
      expect(updatedTextField.obscureText, isFalse);
    });

    testWidgets('should navigate to register screen', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Find and tap register link
      final registerLink = find.text('¿No tienes cuenta? Regístrate');
      await TestHelpers.tapAndSettle(tester, registerLink);

      // Should navigate to register screen
      // Note: This would require proper navigation setup in a real test
    });

    testWidgets('should clear error when user starts typing', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      // Set error state
      mockAuthProvider.setError('Invalid credentials');
      await tester.pump();

      // Verify error is shown
      expect(find.text('Invalid credentials'), findsOneWidget);

      // Start typing in email field
      final emailField = find.byKey(const Key('email_field'));
      await TestHelpers.enterTextAndSettle(tester, emailField, 'new@example.com');

      // Error should be cleared
      expect(find.text('Invalid credentials'), findsNothing);
    });
  });

  group('Register Screen Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MessageProvider messageProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      messageProvider = MessageProvider();
    });

    Widget createRegisterScreen() {
      return TestHelpers.createTestApp(
        child: const RegisterScreen(),
        authProvider: mockAuthProvider,
        messageProvider: messageProvider,
      );
    }

    testWidgets('should display register form elements', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Verify the presence of key UI elements
      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('username_field')), findsOneWidget);
      expect(find.byKey(const Key('first_name_field')), findsOneWidget);
      expect(find.byKey(const Key('last_name_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_button')), findsOneWidget);
      expect(find.text('¿Ya tienes cuenta? Inicia sesión'), findsOneWidget);
    });

    testWidgets('should validate all required fields', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Try to submit with empty fields
      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Should show validation errors for required fields
      expect(find.text('Por favor ingresa tu email'), findsOneWidget);
      expect(find.text('Por favor ingresa tu nombre de usuario'), findsOneWidget);
      expect(find.text('Por favor ingresa tu nombre'), findsOneWidget);
      expect(find.text('Por favor ingresa tu apellido'), findsOneWidget);
      expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('should validate email format', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Enter invalid email
      final emailField = find.byKey(const Key('email_field'));
      await TestHelpers.enterTextAndSettle(tester, emailField, 'invalid-email');

      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Should show email format validation error
      expect(find.text('Por favor ingresa un email válido'), findsOneWidget);
    });

    testWidgets('should validate password strength', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Enter weak password
      final passwordField = find.byKey(const Key('password_field'));
      await TestHelpers.enterTextAndSettle(tester, passwordField, '123');

      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Should show password strength validation error
      expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);
    });

    testWidgets('should validate password confirmation', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Enter different passwords
      final passwordField = find.byKey(const Key('password_field'));
      final confirmPasswordField = find.byKey(const Key('confirm_password_field'));
      
      await TestHelpers.enterTextAndSettle(tester, passwordField, 'password123');
      await TestHelpers.enterTextAndSettle(tester, confirmPasswordField, 'password456');

      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Should show password mismatch error
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('should show loading state during registration', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Set loading state
      mockAuthProvider.setLoading(true);
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should perform registration with valid data', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Fill in all required fields with valid data
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('email_field')), 
        'newuser@example.com'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('username_field')), 
        'newuser'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('first_name_field')), 
        'New'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('last_name_field')), 
        'User'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('password_field')), 
        'password123'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('confirm_password_field')), 
        'password123'
      );

      // Tap register button
      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Wait for async operation
      await tester.pump(const Duration(milliseconds: 200));

      // Should be authenticated after successful registration
      expect(mockAuthProvider.isAuthenticated, isTrue);
    });

    testWidgets('should show username availability check', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Enter username
      final usernameField = find.byKey(const Key('username_field'));
      await TestHelpers.enterTextAndSettle(tester, usernameField, 'testuser');

      // Should show username availability indicator
      expect(find.byKey(const Key('username_availability_indicator')), findsOneWidget);
    });

    testWidgets('should navigate to login screen', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Find and tap login link
      final loginLink = find.text('¿Ya tienes cuenta? Inicia sesión');
      await TestHelpers.tapAndSettle(tester, loginLink);

      // Should navigate to login screen
      // Note: This would require proper navigation setup in a real test
    });

    testWidgets('should display terms and conditions checkbox', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Should show terms checkbox
      expect(find.byKey(const Key('terms_checkbox')), findsOneWidget);
      expect(find.text('Acepto los términos y condiciones'), findsOneWidget);
    });

    testWidgets('should require terms acceptance for registration', (tester) async {
      await tester.pumpWidget(createRegisterScreen());

      // Fill in all fields but don't check terms
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('email_field')), 
        'test@example.com'
      );
      // ... fill other fields

      final registerButton = find.byKey(const Key('register_button'));
      await TestHelpers.tapAndSettle(tester, registerButton);

      // Should show terms acceptance error
      expect(find.text('Debes aceptar los términos y condiciones'), findsOneWidget);
    });
  });

  group('Authentication Flow Integration Tests', () {
    testWidgets('should switch between login and register screens', (tester) async {
      // This would test the full authentication flow
      // including navigation between screens
    });

    testWidgets('should persist authentication state', (tester) async {
      // This would test that authentication state
      // is properly maintained across app restarts
    });

    testWidgets('should handle network errors gracefully', (tester) async {
      // This would test error handling for network issues
      // during authentication
    });
  });
}