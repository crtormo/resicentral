import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../../lib/providers/auth_provider.dart';
import '../../lib/providers/message_provider.dart';
import '../../lib/services/api_service.dart';

// Generate mocks
@GenerateMocks([ApiService])
class MockApiService extends Mock implements ApiService {}

/// Test utilities and helpers for widget tests
class TestHelpers {
  /// Create a MaterialApp wrapper with providers for testing widgets
  static Widget createTestApp({
    required Widget child,
    AuthProvider? authProvider,
    MessageProvider? messageProvider,
    NavigatorObserver? navigatorObserver,
    ThemeData? theme,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => authProvider ?? MockAuthProvider(),
        ),
        ChangeNotifierProvider<MessageProvider>(
          create: (_) => messageProvider ?? MessageProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'ResiCentral Test',
        theme: theme ?? ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
        home: Scaffold(body: child),
      ),
    );
  }

  /// Create a test app with navigation support
  static Widget createTestAppWithRouter({
    required Widget child,
    AuthProvider? authProvider,
    MessageProvider? messageProvider,
    String initialRoute = '/',
    Map<String, WidgetBuilder>? routes,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => authProvider ?? MockAuthProvider(),
        ),
        ChangeNotifierProvider<MessageProvider>(
          create: (_) => messageProvider ?? MessageProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'ResiCentral Test',
        initialRoute: initialRoute,
        routes: routes ?? {
          '/': (context) => Scaffold(body: child),
        },
      ),
    );
  }

  /// Common test data
  static const testUser = User(
    id: 1,
    email: 'test@example.com',
    username: 'testuser',
    firstName: 'Test',
    lastName: 'User',
    fullName: 'Test User',
    isActive: true,
    isVerified: true,
    isSuperuser: false,
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
  );

  /// Wait for animations to complete
  static Future<void> pumpAndSettle(WidgetTester tester, [Duration? duration]) async {
    await tester.pumpAndSettle(duration ?? const Duration(milliseconds: 100));
  }

  /// Tap a widget and wait for animations
  static Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await pumpAndSettle(tester);
  }

  /// Enter text and wait for animations
  static Future<void> enterTextAndSettle(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await pumpAndSettle(tester);
  }

  /// Scroll and wait for animations
  static Future<void> scrollAndSettle(
    WidgetTester tester,
    Finder finder,
    Offset offset,
  ) async {
    await tester.drag(finder, offset);
    await pumpAndSettle(tester);
  }

  /// Find text widget with specific text
  static Finder findTextWidget(String text) => find.text(text);

  /// Find widget by key
  static Finder findByKey(String key) => find.byKey(Key(key));

  /// Find widget by type
  static Finder findByType<T>() => find.byType(T);

  /// Find button by text
  static Finder findButtonByText(String text) {
    return find.widgetWithText(ElevatedButton, text);
  }

  /// Find text field by hint
  static Finder findTextFieldByHint(String hint) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );
  }

  /// Verify widget exists
  static void expectWidgetExists(Finder finder) {
    expect(finder, findsOneWidget);
  }

  /// Verify widget doesn't exist
  static void expectWidgetNotExists(Finder finder) {
    expect(finder, findsNothing);
  }

  /// Verify text exists
  static void expectTextExists(String text) {
    expectWidgetExists(findTextWidget(text));
  }

  /// Verify text doesn't exist
  static void expectTextNotExists(String text) {
    expectWidgetNotExists(findTextWidget(text));
  }

  /// Create a mock API response
  static ApiResponse mockSuccessResponse(Map<String, dynamic> data) {
    return ApiResponse.success(data);
  }

  /// Create a mock API error response
  static ApiResponse mockErrorResponse(String error, [int statusCode = 400]) {
    return ApiResponse.error(error, statusCode);
  }
}

/// Mock AuthProvider for testing
class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  AuthStatus _status = AuthStatus.unauthenticated;
  User? _user;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  AuthStatus get status => _status;

  @override
  User? get user => _user;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  @override
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  @override
  bool get isSuperuser => _user?.isSuperuser ?? false;

  @override
  bool get isVerified => _user?.isVerified ?? false;

  @override
  String get userFullName => _user?.fullName ?? '';

  @override
  String get userInitials => _user?.initials ?? '';

  void setAuthenticated(User user) {
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  Future<void> init() async {
    // Mock implementation
  }

  @override
  Future<bool> login(String email, String password) async {
    setLoading(true);
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (email == 'test@example.com' && password == 'password') {
      setAuthenticated(TestHelpers.testUser);
      setLoading(false);
      return true;
    } else {
      setError('Invalid credentials');
      setLoading(false);
      return false;
    }
  }

  @override
  Future<bool> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
    String? phone,
    String? bio,
  }) async {
    setLoading(true);
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (email.isNotEmpty && password.isNotEmpty) {
      final user = User(
        id: 1,
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        fullName: '$firstName $lastName',
        isActive: true,
        isVerified: false,
        isSuperuser: false,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      setAuthenticated(user);
      setLoading(false);
      return true;
    } else {
      setError('Invalid registration data');
      setLoading(false);
      return false;
    }
  }

  @override
  Future<void> logout() async {
    setLoading(true);
    await Future.delayed(const Duration(milliseconds: 100));
    setUnauthenticated();
    setLoading(false);
  }

  @override
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    // Mock implementation
    return true;
  }

  @override
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    // Mock implementation
    return true;
  }

  @override
  Future<void> refreshUser() async {
    // Mock implementation
  }

  @override
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  Future<bool> checkServerConnection() async {
    return true;
  }
}

/// Simplified User model for testing
class User {
  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final bool isActive;
  final bool isVerified;
  final bool isSuperuser;
  final String createdAt;
  final String updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.isActive,
    required this.isVerified,
    required this.isSuperuser,
    required this.createdAt,
    required this.updatedAt,
  });

  String get initials {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '',
      isActive: json['is_active'] ?? true,
      isVerified: json['is_verified'] ?? false,
      isSuperuser: json['is_superuser'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

/// Simplified ApiResponse model for testing
class ApiResponse {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? error;
  final int? statusCode;

  ApiResponse.success(this.data)
      : isSuccess = true,
        error = null,
        statusCode = 200;

  ApiResponse.error(this.error, this.statusCode)
      : isSuccess = false,
        data = null;
}

/// Custom matchers for testing
class CustomMatchers {
  static Matcher hasText(String text) {
    return findsOneWidget;
  }

  static Matcher isEnabled() {
    return predicate<Widget>((widget) {
      if (widget is ElevatedButton) {
        return widget.onPressed != null;
      }
      if (widget is TextButton) {
        return widget.onPressed != null;
      }
      if (widget is OutlinedButton) {
        return widget.onPressed != null;
      }
      return true;
    }, 'is enabled');
  }

  static Matcher isDisabled() {
    return predicate<Widget>((widget) {
      if (widget is ElevatedButton) {
        return widget.onPressed == null;
      }
      if (widget is TextButton) {
        return widget.onPressed == null;
      }
      if (widget is OutlinedButton) {
        return widget.onPressed == null;
      }
      return false;
    }, 'is disabled');
  }
}