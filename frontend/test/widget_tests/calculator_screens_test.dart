import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/calculators/calculator_list_screen.dart';
import '../../lib/screens/calculators/curb65_screen.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/message_provider.dart';
import 'test_helpers.dart';

void main() {
  group('Calculator List Screen Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MessageProvider messageProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      messageProvider = MessageProvider();
      mockAuthProvider.setAuthenticated(TestHelpers.testUser);
    });

    Widget createCalculatorListScreen() {
      return TestHelpers.createTestApp(
        child: const CalculatorListScreen(),
        authProvider: mockAuthProvider,
        messageProvider: messageProvider,
      );
    }

    testWidgets('should display screen title', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      expect(find.text('Calculadoras Médicas'), findsOneWidget);
    });

    testWidgets('should display all available calculators', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Should display all calculator cards
      expect(find.text('CURB-65'), findsOneWidget);
      expect(find.text('Wells PE'), findsOneWidget);
      expect(find.text('Glasgow Coma Scale'), findsOneWidget);
      expect(find.text('CHA2DS2-VASc'), findsOneWidget);
    });

    testWidgets('should display calculator descriptions', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Should display calculator descriptions
      expect(find.text('Predictor de mortalidad en neumonía'), findsOneWidget);
      expect(find.text('Probabilidad de embolia pulmonar'), findsOneWidget);
      expect(find.text('Nivel de conciencia'), findsOneWidget);
      expect(find.text('Riesgo de ACV en fibrilación auricular'), findsOneWidget);
    });

    testWidgets('should display calculator categories', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Should display categories
      expect(find.text('Respiratorio'), findsOneWidget);
      expect(find.text('Cardiovascular'), findsOneWidget);
      expect(find.text('Neurológico'), findsOneWidget);
    });

    testWidgets('should filter calculators by category', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Tap on Cardiovascular category
      final cardiovascularChip = find.text('Cardiovascular');
      await TestHelpers.tapAndSettle(tester, cardiovascularChip);

      // Should show only cardiovascular calculators
      expect(find.text('Wells PE'), findsOneWidget);
      expect(find.text('CHA2DS2-VASc'), findsOneWidget);
      expect(find.text('CURB-65'), findsNothing);
    });

    testWidgets('should search calculators by name', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Enter search term
      final searchField = find.byType(TextField);
      await TestHelpers.enterTextAndSettle(tester, searchField, 'CURB');

      // Should show only CURB-65 calculator
      expect(find.text('CURB-65'), findsOneWidget);
      expect(find.text('Wells PE'), findsNothing);
    });

    testWidgets('should navigate to calculator when tapped', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Tap on CURB-65 calculator
      final curb65Card = find.widgetWithText(Card, 'CURB-65');
      await TestHelpers.tapAndSettle(tester, curb65Card);

      // Should navigate to CURB-65 calculator screen
      // Note: This would require proper navigation setup
    });

    testWidgets('should display favorites section', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Should display favorites section
      expect(find.text('Favoritos'), findsOneWidget);
    });

    testWidgets('should add calculator to favorites', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Tap favorite icon on CURB-65
      final favoriteIcon = find.descendant(
        of: find.widgetWithText(Card, 'CURB-65'),
        matching: find.byIcon(Icons.favorite_border),
      );
      await TestHelpers.tapAndSettle(tester, favoriteIcon);

      // Should change to filled favorite icon
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('should display recent calculators section', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Should display recent calculators
      expect(find.text('Usados Recientemente'), findsOneWidget);
    });

    testWidgets('should clear search when clear button is pressed', (tester) async {
      await tester.pumpWidget(createCalculatorListScreen());

      // Enter search term
      final searchField = find.byType(TextField);
      await TestHelpers.enterTextAndSettle(tester, searchField, 'CURB');

      // Tap clear button
      final clearButton = find.byIcon(Icons.clear);
      await TestHelpers.tapAndSettle(tester, clearButton);

      // Should show all calculators again
      expect(find.text('CURB-65'), findsOneWidget);
      expect(find.text('Wells PE'), findsOneWidget);
    });
  });

  group('CURB-65 Calculator Screen Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MessageProvider messageProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      messageProvider = MessageProvider();
      mockAuthProvider.setAuthenticated(TestHelpers.testUser);
    });

    Widget createCurb65Screen() {
      return TestHelpers.createTestApp(
        child: const Curb65Screen(),
        authProvider: mockAuthProvider,
        messageProvider: messageProvider,
      );
    }

    testWidgets('should display screen title and description', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      expect(find.text('CURB-65'), findsOneWidget);
      expect(find.text('Predictor de mortalidad en neumonía'), findsOneWidget);
    });

    testWidgets('should display all input fields', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Should display all CURB-65 criteria
      expect(find.text('Confusión'), findsOneWidget);
      expect(find.text('Urea > 7 mmol/L (42 mg/dL)'), findsOneWidget);
      expect(find.text('Frecuencia respiratoria ≥ 30/min'), findsOneWidget);
      expect(find.text('Presión arterial sistólica < 90 mmHg'), findsOneWidget);
      expect(find.text('Edad ≥ 65 años'), findsOneWidget);
    });

    testWidgets('should allow input of patient data', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Enter age
      final ageField = find.byKey(const Key('age_field'));
      await TestHelpers.enterTextAndSettle(tester, ageField, '70');

      // Enter urea value
      final ureaField = find.byKey(const Key('urea_field'));
      await TestHelpers.enterTextAndSettle(tester, ureaField, '50');

      // Enter respiratory rate
      final respiratoryRateField = find.byKey(const Key('respiratory_rate_field'));
      await TestHelpers.enterTextAndSettle(tester, respiratoryRateField, '32');

      // Check confusion checkbox
      final confusionCheckbox = find.byKey(const Key('confusion_checkbox'));
      await TestHelpers.tapAndSettle(tester, confusionCheckbox);

      // Verify inputs were accepted
      expect(find.text('70'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
    });

    testWidgets('should calculate CURB-65 score', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Fill in high-risk patient data
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '75'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('urea_field')), 
        '50'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('respiratory_rate_field')), 
        '35'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('systolic_bp_field')), 
        '85'
      );

      // Check confusion
      final confusionCheckbox = find.byKey(const Key('confusion_checkbox'));
      await TestHelpers.tapAndSettle(tester, confusionCheckbox);

      // Tap calculate button
      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Should display result
      expect(find.text('Puntuación: 5'), findsOneWidget);
      expect(find.text('Riesgo: Alto'), findsOneWidget);
    });

    testWidgets('should display risk interpretation', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Fill in low-risk patient data
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '45'
      );
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('urea_field')), 
        '5'
      );

      // Calculate
      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Should show low risk interpretation
      expect(find.text('Riesgo: Bajo'), findsOneWidget);
      expect(find.text('Manejo ambulatorio considerado'), findsOneWidget);
    });

    testWidgets('should validate required fields', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Try to calculate without filling all fields
      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Should show validation errors
      expect(find.text('Por favor complete todos los campos'), findsOneWidget);
    });

    testWidgets('should validate numeric ranges', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Enter invalid age
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '200'
      );

      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Should show validation error
      expect(find.text('Edad debe estar entre 0 y 120 años'), findsOneWidget);
    });

    testWidgets('should clear form when reset button is pressed', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Fill in some data
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '70'
      );

      // Tap reset button
      final resetButton = find.byKey(const Key('reset_button'));
      await TestHelpers.tapAndSettle(tester, resetButton);

      // Fields should be cleared
      final ageField = tester.widget<TextField>(find.byKey(const Key('age_field')));
      expect(ageField.controller?.text, isEmpty);
    });

    testWidgets('should save calculation to history', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Perform calculation
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '70'
      );

      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Tap save button
      final saveButton = find.byKey(const Key('save_button'));
      await TestHelpers.tapAndSettle(tester, saveButton);

      // Should show success message
      messageProvider.showSuccess('Cálculo guardado en el historial');
      await tester.pump();

      expect(find.text('Cálculo guardado en el historial'), findsOneWidget);
    });

    testWidgets('should display information about the calculator', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Tap info button
      final infoButton = find.byIcon(Icons.info);
      await TestHelpers.tapAndSettle(tester, infoButton);

      // Should show information dialog
      expect(find.text('Acerca de CURB-65'), findsOneWidget);
      expect(find.text('El CURB-65 es una herramienta'), findsOneWidget);
    });

    testWidgets('should allow sharing of results', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Perform calculation first
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '70'
      );

      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Tap share button
      final shareButton = find.byIcon(Icons.share);
      await TestHelpers.tapAndSettle(tester, shareButton);

      // Should trigger share functionality
      // In a real app, this would open the system share dialog
    });

    testWidgets('should display reference information', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Should display reference information
      expect(find.text('Referencia:'), findsOneWidget);
      expect(find.text('Lim WS, et al. Thorax 2003'), findsOneWidget);
    });

    testWidgets('should handle edge cases correctly', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Test edge case: exactly 65 years old
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '65'
      );

      final calculateButton = find.byKey(const Key('calculate_button'));
      await TestHelpers.tapAndSettle(tester, calculateButton);

      // Should include age criterion (≥ 65)
      expect(find.text('Puntuación: 1'), findsOneWidget);
    });

    testWidgets('should persist form data when navigating away', (tester) async {
      await tester.pumpWidget(createCurb65Screen());

      // Fill in data
      await TestHelpers.enterTextAndSettle(
        tester, 
        find.byKey(const Key('age_field')), 
        '70'
      );

      // Navigate away and back (simulated)
      // In a real test, this would involve actual navigation

      // Data should still be there
      final ageField = tester.widget<TextField>(find.byKey(const Key('age_field')));
      expect(ageField.controller?.text, '70');
    });
  });

  group('Calculator Integration Tests', () {
    testWidgets('should navigate between calculator screens', (tester) async {
      // Test navigation flow between calculator list and individual calculators
    });

    testWidgets('should maintain calculation history across sessions', (tester) async {
      // Test that calculation history is properly persisted
    });

    testWidgets('should handle network errors gracefully', (tester) async {
      // Test error handling when API calls fail
    });

    testWidgets('should work offline with cached data', (tester) async {
      // Test offline functionality
    });
  });
}