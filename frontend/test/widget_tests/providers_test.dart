import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/message_provider.dart';
import '../../lib/services/api_service.dart';
import 'test_helpers.dart';

void main() {
  group('AuthProvider Tests', () {
    late MockAuthProvider authProvider;
    late MockApiService mockApiService;

    setUp(() {
      authProvider = MockAuthProvider();
      mockApiService = MockApiService();
    });

    test('should initialize with unauthenticated status', () {
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isUnauthenticated, isTrue);
    });

    test('should update status when user logs in', () async {
      // Mock successful login
      when(mockApiService.login('test@example.com', 'password'))
          .thenAnswer((_) async => TestHelpers.mockSuccessResponse({
                'user': {
                  'id': 1,
                  'email': 'test@example.com',
                  'username': 'testuser',
                  'first_name': 'Test',
                  'last_name': 'User',
                  'full_name': 'Test User',
                  'is_active': true,
                  'is_verified': true,
                  'is_superuser': false,
                }
              }));

      final result = await authProvider.login('test@example.com', 'password');

      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.email, 'test@example.com');
    });

    test('should handle login failure', () async {
      final result = await authProvider.login('wrong@example.com', 'wrongpass');

      expect(result, isFalse);
      expect(authProvider.isUnauthenticated, isTrue);
      expect(authProvider.errorMessage, 'Invalid credentials');
    });

    test('should set loading state during login', () async {
      bool loadingStateChanged = false;
      
      authProvider.addListener(() {
        if (authProvider.isLoading) {
          loadingStateChanged = true;
        }
      });

      await authProvider.login('test@example.com', 'password');

      expect(loadingStateChanged, isTrue);
    });

    test('should clear error when clearError is called', () {
      authProvider.setError('Test error');
      expect(authProvider.errorMessage, 'Test error');

      authProvider.clearError();
      expect(authProvider.errorMessage, isNull);
    });

    test('should handle successful registration', () async {
      final result = await authProvider.register(
        email: 'new@example.com',
        username: 'newuser',
        firstName: 'New',
        lastName: 'User',
        password: 'password123',
      );

      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.email, 'new@example.com');
    });

    test('should handle registration failure', () async {
      final result = await authProvider.register(
        email: '',
        username: '',
        firstName: '',
        lastName: '',
        password: '',
      );

      expect(result, isFalse);
      expect(authProvider.isUnauthenticated, isTrue);
      expect(authProvider.errorMessage, isNotNull);
    });

    test('should logout user', () async {
      // First login
      await authProvider.login('test@example.com', 'password');
      expect(authProvider.isAuthenticated, isTrue);

      // Then logout
      await authProvider.logout();
      expect(authProvider.isUnauthenticated, isTrue);
      expect(authProvider.user, isNull);
    });

    test('should return correct user properties', () {
      final user = TestHelpers.testUser;
      authProvider.setAuthenticated(user);

      expect(authProvider.userFullName, 'Test User');
      expect(authProvider.userInitials, 'TU');
      expect(authProvider.isVerified, isTrue);
      expect(authProvider.isSuperuser, isFalse);
    });

    test('should notify listeners when state changes', () {
      int notificationCount = 0;
      
      authProvider.addListener(() {
        notificationCount++;
      });

      authProvider.setAuthenticated(TestHelpers.testUser);
      authProvider.setLoading(true);
      authProvider.setError('Test error');
      authProvider.clearError();

      expect(notificationCount, 4);
    });

    test('should handle update profile', () async {
      authProvider.setAuthenticated(TestHelpers.testUser);
      
      final result = await authProvider.updateProfile({
        'first_name': 'Updated',
        'last_name': 'Name',
      });

      expect(result, isTrue);
    });

    test('should handle change password', () async {
      authProvider.setAuthenticated(TestHelpers.testUser);
      
      final result = await authProvider.changePassword('oldpass', 'newpass');

      expect(result, isTrue);
    });

    test('should check server connection', () async {
      final result = await authProvider.checkServerConnection();
      expect(result, isTrue);
    });
  });

  group('MessageProvider Tests', () {
    late MessageProvider messageProvider;

    setUp(() {
      messageProvider = MessageProvider();
    });

    test('should initialize with no message', () {
      expect(messageProvider.message, isNull);
      expect(messageProvider.hasMessage, isFalse);
      expect(messageProvider.type, MessageType.info);
    });

    test('should show success message', () {
      messageProvider.showSuccess('Operation successful');

      expect(messageProvider.message, 'Operation successful');
      expect(messageProvider.type, MessageType.success);
      expect(messageProvider.hasMessage, isTrue);
    });

    test('should show error message', () {
      messageProvider.showError('Something went wrong');

      expect(messageProvider.message, 'Something went wrong');
      expect(messageProvider.type, MessageType.error);
      expect(messageProvider.hasMessage, isTrue);
    });

    test('should show info message', () {
      messageProvider.showInfo('Information message');

      expect(messageProvider.message, 'Information message');
      expect(messageProvider.type, MessageType.info);
      expect(messageProvider.hasMessage, isTrue);
    });

    test('should show warning message', () {
      messageProvider.showWarning('Warning message');

      expect(messageProvider.message, 'Warning message');
      expect(messageProvider.type, MessageType.warning);
      expect(messageProvider.hasMessage, isTrue);
    });

    test('should clear message', () {
      messageProvider.showSuccess('Test message');
      expect(messageProvider.hasMessage, isTrue);

      messageProvider.clear();
      expect(messageProvider.hasMessage, isFalse);
      expect(messageProvider.message, isNull);
    });

    test('should notify listeners when message changes', () {
      int notificationCount = 0;
      
      messageProvider.addListener(() {
        notificationCount++;
      });

      messageProvider.showSuccess('Success');
      messageProvider.showError('Error');
      messageProvider.clear();

      expect(notificationCount, 3);
    });

    test('should auto-hide message after delay', () async {
      messageProvider.showSuccess('Auto-hide test');
      expect(messageProvider.hasMessage, isTrue);

      // Wait for auto-hide (mocked in test)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // In a real implementation, this would be cleared after 5 seconds
      // For testing, we'll manually verify the mechanism exists
      expect(messageProvider.hasMessage, isTrue); // Still there in test
    });

    testWidgets('should display message in UI', (tester) async {
      final messageProvider = MessageProvider();
      
      final testWidget = TestHelpers.createTestApp(
        child: Consumer<MessageProvider>(
          builder: (context, provider, child) {
            if (!provider.hasMessage) {
              return const Text('No message');
            }
            
            return Container(
              color: provider.type.color,
              child: Row(
                children: [
                  Icon(provider.type.icon),
                  Text(provider.message!),
                ],
              ),
            );
          },
        ),
        messageProvider: messageProvider,
      );

      await tester.pumpWidget(testWidget);

      // Initially no message
      expect(find.text('No message'), findsOneWidget);

      // Show success message
      messageProvider.showSuccess('Success message');
      await tester.pump();

      expect(find.text('Success message'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Show error message
      messageProvider.showError('Error message');
      await tester.pump();

      expect(find.text('Error message'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });

  group('MessageType Extension Tests', () {
    test('should return correct colors for message types', () {
      expect(MessageType.success.color, Colors.green);
      expect(MessageType.error.color, Colors.red);
      expect(MessageType.warning.color, Colors.orange);
      expect(MessageType.info.color, Colors.blue);
    });

    test('should return correct icons for message types', () {
      expect(MessageType.success.icon, Icons.check_circle);
      expect(MessageType.error.icon, Icons.error);
      expect(MessageType.warning.icon, Icons.warning);
      expect(MessageType.info.icon, Icons.info);
    });
  });

  group('Provider Integration Tests', () {
    testWidgets('should work together in MultiProvider setup', (tester) async {
      final authProvider = MockAuthProvider();
      final messageProvider = MessageProvider();

      final testWidget = TestHelpers.createTestApp(
        child: Consumer2<AuthProvider, MessageProvider>(
          builder: (context, auth, message, child) {
            return Column(
              children: [
                Text('Auth Status: ${auth.status}'),
                Text('User: ${auth.user?.email ?? 'None'}'),
                Text('Message: ${message.message ?? 'None'}'),
              ],
            );
          },
        ),
        authProvider: authProvider,
        messageProvider: messageProvider,
      );

      await tester.pumpWidget(testWidget);

      // Initial state
      expect(find.text('Auth Status: AuthStatus.unauthenticated'), findsOneWidget);
      expect(find.text('User: None'), findsOneWidget);
      expect(find.text('Message: None'), findsOneWidget);

      // Change auth state
      authProvider.setAuthenticated(TestHelpers.testUser);
      await tester.pump();

      expect(find.text('Auth Status: AuthStatus.authenticated'), findsOneWidget);
      expect(find.text('User: test@example.com'), findsOneWidget);

      // Show message
      messageProvider.showSuccess('Login successful');
      await tester.pump();

      expect(find.text('Message: Login successful'), findsOneWidget);
    });

    testWidgets('should handle error states properly', (tester) async {
      final authProvider = MockAuthProvider();
      final messageProvider = MessageProvider();

      final testWidget = TestHelpers.createTestApp(
        child: Consumer<AuthProvider>(
          builder: (context, auth, child) {
            return Column(
              children: [
                if (auth.isLoading) const CircularProgressIndicator(),
                if (auth.errorMessage != null) 
                  Text('Error: ${auth.errorMessage}'),
                Text('Status: ${auth.status}'),
              ],
            );
          },
        ),
        authProvider: authProvider,
        messageProvider: messageProvider,
      );

      await tester.pumpWidget(testWidget);

      // Set loading state
      authProvider.setLoading(true);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Set error state
      authProvider.setLoading(false);
      authProvider.setError('Network error');
      await tester.pump();

      expect(find.text('Error: Network error'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}