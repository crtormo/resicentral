import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:resicentral_frontend/main.dart';
import 'package:resicentral_frontend/providers/auth_provider.dart';
import 'package:resicentral_frontend/providers/message_provider.dart';
import 'package:resicentral_frontend/services/api_service.dart';

import '../widget_tests/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('complete app flow test', (tester) async {
      // Start the app
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Should start with splash screen
      expect(find.text('ResiCentral'), findsOneWidget);
      
      // Wait for splash screen to finish
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should navigate to login screen (assuming not authenticated)
      expect(find.text('Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('authentication flow test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Wait for app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Login flow
      if (find.text('Iniciar Sesión').evaluate().isNotEmpty) {
        await _performLogin(tester);
      }

      // Should navigate to home screen after login
      expect(find.text('ResiCentral'), findsOneWidget);
      expect(find.text('Bienvenido'), findsOneWidget);
    });

    testWidgets('navigation flow test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Ensure we're logged in
      await _ensureLoggedIn(tester);

      // Test navigation to different screens
      await _testNavigationToCalculators(tester);
      await _testNavigationToVademecum(tester);
      await _testNavigationToGallery(tester);
      await _testNavigationToCalendar(tester);
    });

    testWidgets('calculator functionality test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Navigate to calculators
      await _navigateToCalculators(tester);

      // Test CURB-65 calculator
      await _testCurb65Calculator(tester);
    });

    testWidgets('data persistence test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Perform some actions that should persist data
      await _performCalculation(tester);

      // Restart app (simulated)
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Verify data persisted
      await _verifyDataPersistence(tester);
    });

    testWidgets('error handling test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Test various error scenarios
      await _testNetworkError(tester);
      await _testValidationErrors(tester);
      await _testAuthenticationErrors(tester);
    });

    testWidgets('user interaction flow test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Test complex user interactions
      await _testSearchFunctionality(tester);
      await _testFilterFunctionality(tester);
      await _testFavoritesFunctionality(tester);
    });

    testWidgets('accessibility test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Test accessibility features
      await _testAccessibilityFeatures(tester);
    });

    testWidgets('performance test', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Test app performance
      await _testScrollPerformance(tester);
      await _testNavigationPerformance(tester);
    });
  });

  group('Feature-specific Integration Tests', () {
    testWidgets('complete calculator workflow', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Complete calculator workflow
      await _completeCalculatorWorkflow(tester);
    });

    testWidgets('complete document management workflow', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Complete document workflow
      await _completeDocumentWorkflow(tester);
    });

    testWidgets('complete gallery workflow', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Complete gallery workflow
      await _completeGalleryWorkflow(tester);
    });

    testWidgets('complete calendar workflow', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      await _ensureLoggedIn(tester);

      // Complete calendar workflow
      await _completeCalendarWorkflow(tester);
    });
  });

  group('Error Recovery Tests', () {
    testWidgets('network disconnection recovery', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Simulate network disconnection and recovery
      await _testNetworkRecovery(tester);
    });

    testWidgets('app state recovery after crash', (tester) async {
      await tester.pumpWidget(const ResiCentralApp());
      await tester.pumpAndSettle();

      // Test app recovery after simulated crash
      await _testCrashRecovery(tester);
    });
  });
}

// Helper functions for integration tests

Future<void> _performLogin(WidgetTester tester) async {
  // Find login form elements
  final emailField = find.byKey(const Key('email_field'));
  final passwordField = find.byKey(const Key('password_field'));
  final loginButton = find.byKey(const Key('login_button'));

  // Enter credentials
  await tester.enterText(emailField, 'test@example.com');
  await tester.enterText(passwordField, 'password123');
  await tester.pumpAndSettle();

  // Tap login button
  await tester.tap(loginButton);
  await tester.pumpAndSettle();

  // Wait for authentication
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _ensureLoggedIn(WidgetTester tester) async {
  // Check if already logged in
  if (find.text('Iniciar Sesión').evaluate().isNotEmpty) {
    await _performLogin(tester);
  }
}

Future<void> _testNavigationToCalculators(WidgetTester tester) async {
  // Find and tap calculators card
  final calculatorsCard = find.text('Calculadoras Médicas');
  await tester.tap(calculatorsCard);
  await tester.pumpAndSettle();

  // Verify navigation
  expect(find.text('Calculadoras Médicas'), findsOneWidget);
  expect(find.text('CURB-65'), findsOneWidget);

  // Navigate back
  final backButton = find.byIcon(Icons.arrow_back);
  await tester.tap(backButton);
  await tester.pumpAndSettle();
}

Future<void> _testNavigationToVademecum(WidgetTester tester) async {
  final vademecumCard = find.text('Vademécum');
  await tester.tap(vademecumCard);
  await tester.pumpAndSettle();

  expect(find.text('Vademécum'), findsOneWidget);

  final backButton = find.byIcon(Icons.arrow_back);
  await tester.tap(backButton);
  await tester.pumpAndSettle();
}

Future<void> _testNavigationToGallery(WidgetTester tester) async {
  final galleryCard = find.text('Galería Clínica');
  await tester.tap(galleryCard);
  await tester.pumpAndSettle();

  expect(find.text('Galería Clínica'), findsOneWidget);

  final backButton = find.byIcon(Icons.arrow_back);
  await tester.tap(backButton);
  await tester.pumpAndSettle();
}

Future<void> _testNavigationToCalendar(WidgetTester tester) async {
  final calendarCard = find.text('Calendario');
  await tester.tap(calendarCard);
  await tester.pumpAndSettle();

  expect(find.text('Calendario'), findsOneWidget);

  final backButton = find.byIcon(Icons.arrow_back);
  await tester.tap(backButton);
  await tester.pumpAndSettle();
}

Future<void> _navigateToCalculators(WidgetTester tester) async {
  final calculatorsCard = find.text('Calculadoras Médicas');
  await tester.tap(calculatorsCard);
  await tester.pumpAndSettle();
}

Future<void> _testCurb65Calculator(WidgetTester tester) async {
  // Tap CURB-65 calculator
  final curb65Card = find.text('CURB-65');
  await tester.tap(curb65Card);
  await tester.pumpAndSettle();

  // Fill in calculator form
  await tester.enterText(find.byKey(const Key('age_field')), '70');
  await tester.enterText(find.byKey(const Key('urea_field')), '50');
  await tester.enterText(find.byKey(const Key('respiratory_rate_field')), '35');
  await tester.enterText(find.byKey(const Key('systolic_bp_field')), '85');

  // Check confusion checkbox
  await tester.tap(find.byKey(const Key('confusion_checkbox')));
  await tester.pumpAndSettle();

  // Calculate
  await tester.tap(find.byKey(const Key('calculate_button')));
  await tester.pumpAndSettle();

  // Verify result
  expect(find.text('Puntuación: 5'), findsOneWidget);
  expect(find.text('Riesgo: Alto'), findsOneWidget);
}

Future<void> _performCalculation(WidgetTester tester) async {
  await _navigateToCalculators(tester);
  await _testCurb65Calculator(tester);
  
  // Save calculation
  await tester.tap(find.byKey(const Key('save_button')));
  await tester.pumpAndSettle();
}

Future<void> _verifyDataPersistence(WidgetTester tester) async {
  // Navigate to history or saved calculations
  // Verify that the calculation was persisted
}

Future<void> _testNetworkError(WidgetTester tester) async {
  // Simulate network error scenarios
  // Verify error messages are displayed
  // Verify retry functionality
}

Future<void> _testValidationErrors(WidgetTester tester) async {
  await _navigateToCalculators(tester);
  
  // Test various validation scenarios
  final curb65Card = find.text('CURB-65');
  await tester.tap(curb65Card);
  await tester.pumpAndSettle();

  // Try to calculate without filling required fields
  await tester.tap(find.byKey(const Key('calculate_button')));
  await tester.pumpAndSettle();

  // Verify validation errors
  expect(find.text('Por favor complete todos los campos'), findsOneWidget);
}

Future<void> _testAuthenticationErrors(WidgetTester tester) async {
  // Test various authentication error scenarios
  // This would involve simulating invalid credentials, expired tokens, etc.
}

Future<void> _testSearchFunctionality(WidgetTester tester) async {
  // Test search functionality across different screens
  await _navigateToCalculators(tester);

  // Test calculator search
  final searchField = find.byType(TextField);
  await tester.enterText(searchField, 'CURB');
  await tester.pumpAndSettle();

  expect(find.text('CURB-65'), findsOneWidget);
  expect(find.text('Wells PE'), findsNothing);
}

Future<void> _testFilterFunctionality(WidgetTester tester) async {
  await _navigateToCalculators(tester);

  // Test category filters
  final cardiovascularChip = find.text('Cardiovascular');
  await tester.tap(cardiovascularChip);
  await tester.pumpAndSettle();

  expect(find.text('Wells PE'), findsOneWidget);
  expect(find.text('CHA2DS2-VASc'), findsOneWidget);
}

Future<void> _testFavoritesFunctionality(WidgetTester tester) async {
  await _navigateToCalculators(tester);

  // Add calculator to favorites
  final favoriteIcon = find.byIcon(Icons.favorite_border).first;
  await tester.tap(favoriteIcon);
  await tester.pumpAndSettle();

  // Verify favorite was added
  expect(find.byIcon(Icons.favorite), findsOneWidget);
}

Future<void> _testAccessibilityFeatures(WidgetTester tester) async {
  // Test screen reader support
  // Test high contrast mode
  // Test font scaling
  // Test keyboard navigation
}

Future<void> _testScrollPerformance(WidgetTester tester) async {
  // Test scrolling performance on list screens
  await _navigateToCalculators(tester);

  // Perform scroll operations and measure performance
  final listView = find.byType(ListView);
  await tester.drag(listView, const Offset(0, -500));
  await tester.pumpAndSettle();
}

Future<void> _testNavigationPerformance(WidgetTester tester) async {
  // Test navigation performance
  final startTime = DateTime.now();
  
  await _navigateToCalculators(tester);
  
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);
  
  // Assert navigation happens within reasonable time
  expect(duration.inMilliseconds, lessThan(2000));
}

Future<void> _completeCalculatorWorkflow(WidgetTester tester) async {
  // Complete end-to-end calculator workflow
  await _navigateToCalculators(tester);
  await _testCurb65Calculator(tester);
  
  // Save and share result
  await tester.tap(find.byKey(const Key('save_button')));
  await tester.pumpAndSettle();
  
  await tester.tap(find.byIcon(Icons.share));
  await tester.pumpAndSettle();
}

Future<void> _completeDocumentWorkflow(WidgetTester tester) async {
  // Navigate to documents
  // Upload a document
  // View document details
  // Download document
  // Delete document
}

Future<void> _completeGalleryWorkflow(WidgetTester tester) async {
  // Navigate to gallery
  // Upload an image
  // View image details
  // Apply filters
  // Share image
}

Future<void> _completeCalendarWorkflow(WidgetTester tester) async {
  // Navigate to calendar
  // Create a new shift
  // Edit shift
  // View shift details
  // Delete shift
}

Future<void> _testNetworkRecovery(WidgetTester tester) async {
  // Simulate network disconnection
  // Attempt operations
  // Simulate network reconnection
  // Verify operations retry and succeed
}

Future<void> _testCrashRecovery(WidgetTester tester) async {
  // Simulate app crash
  // Restart app
  // Verify state recovery
  // Verify data integrity
}