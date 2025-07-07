import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AuthStatus {
  uninitialized,
  unauthenticated,
  authenticated,
  authenticating,
}

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  String? _errorMessage;
  bool _isLoading = false;
  
  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  
  /// Inicializar el provider verificando si hay un token guardado
  Future<void> init() async {
    _setLoading(true);
    
    try {
      await _apiService.init();
      
      if (_apiService.isAuthenticated) {
        await _loadCurrentUser();
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _setError('Error inicializando autenticación: $e');
      _setStatus(AuthStatus.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }
  
  /// Cargar información del usuario actual
  Future<void> _loadCurrentUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      
      if (response.isSuccess && response.data != null) {
        _user = User.fromJson(response.data!);
        _setStatus(AuthStatus.authenticated);
        _clearError();
      } else {
        // Token inválido o expirado
        await logout();
      }
    } catch (e) {
      _setError('Error cargando usuario: $e');
      await logout();
    }
  }
  
  /// Iniciar sesión
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setStatus(AuthStatus.authenticating);
    _clearError();
    
    try {
      final response = await _apiService.login(email, password);
      
      if (response.isSuccess && response.data != null) {
        // Extraer información del usuario de la respuesta
        final userData = response.data!['user'];
        if (userData != null) {
          _user = User.fromJson(userData);
          _setStatus(AuthStatus.authenticated);
          _setLoading(false);
          return true;
        } else {
          _setError('Error: Datos de usuario no encontrados');
        }
      } else {
        _setError(response.error ?? 'Error de autenticación');
      }
    } catch (e) {
      _setError('Error de conexión: $e');
    }
    
    _setStatus(AuthStatus.unauthenticated);
    _setLoading(false);
    return false;
  }
  
  /// Registrar nuevo usuario
  Future<bool> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
    String? phone,
    String? bio,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.register(
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        password: password,
        phone: phone,
        bio: bio,
      );
      
      if (response.isSuccess) {
        // Registro exitoso, ahora hacer login automático
        _setLoading(false);
        return await login(email, password);
      } else {
        _setError(response.error ?? 'Error en el registro');
      }
    } catch (e) {
      _setError('Error de conexión: $e');
    }
    
    _setLoading(false);
    return false;
  }
  
  /// Cerrar sesión
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await _apiService.logout();
    } catch (e) {
      // Ignorar errores al cerrar sesión
      debugPrint('Error cerrando sesión: $e');
    }
    
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
    _clearError();
    _setLoading(false);
  }
  
  /// Actualizar perfil del usuario
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.updateUser(_user!.id, profileData);
      
      if (response.isSuccess && response.data != null) {
        _user = User.fromJson(response.data!);
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(response.error ?? 'Error actualizando perfil');
      }
    } catch (e) {
      _setError('Error de conexión: $e');
    }
    
    _setLoading(false);
    return false;
  }
  
  /// Cambiar contraseña
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_user == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _apiService.changePassword(
        _user!.id, 
        currentPassword, 
        newPassword
      );
      
      if (response.isSuccess) {
        _setLoading(false);
        return true;
      } else {
        _setError(response.error ?? 'Error cambiando contraseña');
      }
    } catch (e) {
      _setError('Error de conexión: $e');
    }
    
    _setLoading(false);
    return false;
  }
  
  /// Refrescar información del usuario
  Future<void> refreshUser() async {
    if (_status == AuthStatus.authenticated) {
      await _loadCurrentUser();
    }
  }
  
  /// Verificar si el usuario es superusuario
  bool get isSuperuser => _user?.isSuperuser ?? false;
  
  /// Verificar si el usuario está verificado
  bool get isVerified => _user?.isVerified ?? false;
  
  /// Obtener nombre completo del usuario
  String get userFullName => _user?.fullName ?? '';
  
  /// Obtener iniciales del usuario
  String get userInitials => _user?.initials ?? '';
  
  // Métodos privados para manejo de estado
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Limpiar error manualmente
  void clearError() {
    _clearError();
  }
  
  /// Verificar estado de conexión con el servidor
  Future<bool> checkServerConnection() async {
    try {
      final response = await _apiService.healthCheck();
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

/// Provider para manejar mensajes de la aplicación
class MessageProvider extends ChangeNotifier {
  String? _message;
  MessageType _type = MessageType.info;
  
  String? get message => _message;
  MessageType get type => _type;
  bool get hasMessage => _message != null;
  
  void showSuccess(String message) {
    _message = message;
    _type = MessageType.success;
    notifyListeners();
    _autoHide();
  }
  
  void showError(String message) {
    _message = message;
    _type = MessageType.error;
    notifyListeners();
    _autoHide();
  }
  
  void showInfo(String message) {
    _message = message;
    _type = MessageType.info;
    notifyListeners();
    _autoHide();
  }
  
  void showWarning(String message) {
    _message = message;
    _type = MessageType.warning;
    notifyListeners();
    _autoHide();
  }
  
  void clear() {
    _message = null;
    notifyListeners();
  }
  
  void _autoHide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_message != null) {
        clear();
      }
    });
  }
}

enum MessageType {
  success,
  error,
  warning,
  info,
}

/// Extensión para obtener colores según el tipo de mensaje
extension MessageTypeExtension on MessageType {
  Color get color {
    switch (this) {
      case MessageType.success:
        return Colors.green;
      case MessageType.error:
        return Colors.red;
      case MessageType.warning:
        return Colors.orange;
      case MessageType.info:
        return Colors.blue;
    }
  }
  
  IconData get icon {
    switch (this) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.error:
        return Icons.error;
      case MessageType.warning:
        return Icons.warning;
      case MessageType.info:
        return Icons.info;
    }
  }
}