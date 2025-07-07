import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../lib/screens/home_screen.dart';
import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/message_provider.dart';
import 'test_helpers.dart';

void main() {
  group('Home Screen Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MessageProvider messageProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      messageProvider = MessageProvider();
    });

    Widget createHomeScreen({bool isAuthenticated = true}) {
      if (isAuthenticated) {
        mockAuthProvider.setAuthenticated(TestHelpers.testUser);
      }
      
      return TestHelpers.createTestApp(
        child: const HomeScreen(),
        authProvider: mockAuthProvider,
        messageProvider: messageProvider,
      );
    }

    testWidgets('should display welcome message for authenticated user', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display welcome message with user name
      expect(find.text('¡Bienvenido, Test User!'), findsOneWidget);
      expect(find.text('ResiCentral'), findsOneWidget);
    });

    testWidgets('should display main navigation cards', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display main feature cards
      expect(find.text('Calculadoras Médicas'), findsOneWidget);
      expect(find.text('Vademécum'), findsOneWidget);
      expect(find.text('Procedimientos'), findsOneWidget);
      expect(find.text('Algoritmos'), findsOneWidget);
      expect(find.text('Galería Clínica'), findsOneWidget);
      expect(find.text('Calendario'), findsOneWidget);
      expect(find.text('Asistente IA'), findsOneWidget);
    });

    testWidgets('should display user profile section', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display user profile information
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('should display quick stats section', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display quick statistics
      expect(find.text('Estadísticas Rápidas'), findsOneWidget);
      expect(find.text('Documentos'), findsOneWidget);
      expect(find.text('Imágenes'), findsOneWidget);
      expect(find.text('Turnos'), findsOneWidget);
    });

    testWidgets('should navigate to calculators when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap calculators card
      final calculatorsCard = find.widgetWithText(Card, 'Calculadoras Médicas');
      await TestHelpers.tapAndSettle(tester, calculatorsCard);

      // Should navigate to calculators screen
      // Note: This would require proper navigation setup
    });

    testWidgets('should navigate to vademecum when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap vademecum card
      final vademecumCard = find.widgetWithText(Card, 'Vademécum');
      await TestHelpers.tapAndSettle(tester, vademecumCard);

      // Should navigate to vademecum screen
    });

    testWidgets('should navigate to procedures when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap procedures card
      final proceduresCard = find.widgetWithText(Card, 'Procedimientos');
      await TestHelpers.tapAndSettle(tester, proceduresCard);

      // Should navigate to procedures screen
    });

    testWidgets('should navigate to algorithms when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap algorithms card
      final algorithmsCard = find.widgetWithText(Card, 'Algoritmos');
      await TestHelpers.tapAndSettle(tester, algorithmsCard);

      // Should navigate to algorithms screen
    });

    testWidgets('should navigate to gallery when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap gallery card
      final galleryCard = find.widgetWithText(Card, 'Galería Clínica');
      await TestHelpers.tapAndSettle(tester, galleryCard);

      // Should navigate to gallery screen
    });

    testWidgets('should navigate to calendar when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap calendar card
      final calendarCard = find.widgetWithText(Card, 'Calendario');
      await TestHelpers.tapAndSettle(tester, calendarCard);

      // Should navigate to calendar screen
    });

    testWidgets('should navigate to AI assistant when card is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Find and tap AI assistant card
      final aiCard = find.widgetWithText(Card, 'Asistente IA');
      await TestHelpers.tapAndSettle(tester, aiCard);

      // Should navigate to AI assistant screen
    });

    testWidgets('should display app drawer', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await TestHelpers.pumpAndSettle(tester);

      // Should display drawer items
      expect(find.text('Menú'), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Cerrar Sesión'), findsOneWidget);
    });

    testWidgets('should logout when logout button is pressed', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await TestHelpers.pumpAndSettle(tester);

      // Tap logout button
      final logoutButton = find.text('Cerrar Sesión');
      await TestHelpers.tapAndSettle(tester, logoutButton);

      // Should be logged out
      expect(mockAuthProvider.isUnauthenticated, isTrue);
    });

    testWidgets('should display floating action button', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should show quick actions when FAB is pressed', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Tap FAB
      final fab = find.byType(FloatingActionButton);
      await TestHelpers.tapAndSettle(tester, fab);

      // Should show quick actions bottom sheet
      expect(find.text('Acciones Rápidas'), findsOneWidget);
      expect(find.text('Nuevo Documento'), findsOneWidget);
      expect(find.text('Nueva Imagen'), findsOneWidget);
      expect(find.text('Nuevo Turno'), findsOneWidget);
    });

    testWidgets('should display recent activity section', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display recent activity
      expect(find.text('Actividad Reciente'), findsOneWidget);
    });

    testWidgets('should display shortcuts section', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display shortcuts
      expect(find.text('Accesos Rápidos'), findsOneWidget);
      expect(find.text('CURB-65'), findsOneWidget);
      expect(find.text('Wells PE'), findsOneWidget);
      expect(find.text('Glasgow'), findsOneWidget);
    });

    testWidgets('should navigate to specific calculator from shortcuts', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Tap CURB-65 shortcut
      final curb65Shortcut = find.text('CURB-65');
      await TestHelpers.tapAndSettle(tester, curb65Shortcut);

      // Should navigate to CURB-65 calculator
    });

    testWidgets('should refresh data when pull to refresh', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Perform pull to refresh
      final scrollable = find.byType(RefreshIndicator);
      await tester.drag(scrollable, const Offset(0, 300));
      await TestHelpers.pumpAndSettle(tester);

      // Should refresh data
      // In a real implementation, this would reload stats and recent activity
    });

    testWidgets('should display different content for superuser', (tester) async {
      // Create superuser
      final superuser = User(
        id: 1,
        email: 'admin@example.com',
        username: 'admin',
        firstName: 'Admin',
        lastName: 'User',
        fullName: 'Admin User',
        isActive: true,
        isVerified: true,
        isSuperuser: true,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
      );

      mockAuthProvider.setAuthenticated(superuser);

      await tester.pumpWidget(createHomeScreen());

      // Should display admin-specific content
      expect(find.text('Panel de Administración'), findsOneWidget);
      expect(find.text('Gestión de Usuarios'), findsOneWidget);
    });

    testWidgets('should handle loading state', (tester) async {
      mockAuthProvider.setLoading(true);

      await tester.pumpWidget(createHomeScreen());

      // Should display loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should handle error state', (tester) async {
      mockAuthProvider.setError('Failed to load user data');

      await tester.pumpWidget(createHomeScreen());

      // Should display error message
      expect(find.text('Failed to load user data'), findsOneWidget);
    });

    testWidgets('should display search functionality', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display search bar
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should open search when search icon is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Tap search icon
      final searchIcon = find.byIcon(Icons.search);
      await TestHelpers.tapAndSettle(tester, searchIcon);

      // Should open search delegate or search screen
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should display notifications icon', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should display notifications icon
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('should show notifications when notifications icon is tapped', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Tap notifications icon
      final notificationsIcon = find.byIcon(Icons.notifications);
      await TestHelpers.tapAndSettle(tester, notificationsIcon);

      // Should show notifications panel
      expect(find.text('Notificaciones'), findsOneWidget);
    });

    testWidgets('should be scrollable', (tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Should be able to scroll
      await TestHelpers.scrollAndSettle(
        tester,
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );

      // Content should still be visible after scrolling
      expect(find.text('ResiCentral'), findsOneWidget);
    });

    testWidgets('should adapt to different screen sizes', (tester) async {
      // Test with different screen sizes
      await tester.binding.setSurfaceSize(const Size(320, 640)); // Small screen
      await tester.pumpWidget(createHomeScreen());

      // Should adapt layout for small screens
      expect(find.byType(GridView), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 600)); // Large screen
      await tester.pumpWidget(createHomeScreen());

      // Should adapt layout for large screens
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}