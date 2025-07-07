import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static const String _tokenKey = AppConfig.tokenKey;
  
  String? _token;
  
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  /// Inicializar el servicio cargando el token guardado
  Future<void> init() async {
    await _loadToken();
  }
  
  /// Cargar token desde almacenamiento local
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }
  
  /// Guardar token en almacenamiento local
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _token = token;
  }
  
  /// Eliminar token del almacenamiento local
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
  }
  
  /// Obtener headers por defecto
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  /// Manejar errores de respuesta HTTP
  ApiResponse _handleResponse(http.Response response) {
    try {
      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(data);
      } else {
        String errorMessage = 'Error desconocido';
        if (data is Map && data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data is Map && data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data is Map && data.containsKey('errors')) {
          // Handle validation errors
          final errors = data['errors'];
          if (errors is List && errors.isNotEmpty) {
            errorMessage = errors.join(', ');
          }
        }
        
        // Handle specific HTTP status codes
        switch (response.statusCode) {
          case 401:
            errorMessage = 'Sesión expirada. Por favor, inicia sesión nuevamente.';
            _removeToken(); // Auto logout on 401
            break;
          case 403:
            errorMessage = 'No tienes permisos para realizar esta acción.';
            break;
          case 404:
            errorMessage = 'Recurso no encontrado.';
            break;
          case 422:
            errorMessage = 'Datos inválidos: $errorMessage';
            break;
          case 429:
            errorMessage = 'Demasiadas solicitudes. Intenta más tarde.';
            break;
          case 500:
            errorMessage = 'Error interno del servidor. Intenta más tarde.';
            break;
          case 503:
            errorMessage = 'Servicio temporalmente no disponible.';
            break;
        }
        
        return ApiResponse.error(errorMessage, response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Error procesando respuesta: $e', response.statusCode);
    }
  }
  
  /// Realizar petición GET
  Future<ApiResponse> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(AppConfig.defaultTimeout);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Error de conexión. Verifica tu internet.', 0);
    } on HttpException {
      return ApiResponse.error('Error de servidor.', 0);
    } catch (e) {
      return ApiResponse.error('Error inesperado: $e', 0);
    }
  }
  
  /// Realizar petición POST
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> data, {bool includeAuth = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: includeAuth),
        body: json.encode(data),
      ).timeout(AppConfig.defaultTimeout);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Error de conexión. Verifica tu internet.', 0);
    } on HttpException {
      return ApiResponse.error('Error de servidor.', 0);
    } catch (e) {
      return ApiResponse.error('Error inesperado: $e', 0);
    }
  }
  
  /// Realizar petición PUT
  Future<ApiResponse> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Error de conexión. Verifica tu internet.', 0);
    } on HttpException {
      return ApiResponse.error('Error de servidor.', 0);
    } catch (e) {
      return ApiResponse.error('Error inesperado: $e', 0);
    }
  }
  
  /// Realizar petición DELETE
  Future<ApiResponse> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Error de conexión. Verifica tu internet.', 0);
    } on HttpException {
      return ApiResponse.error('Error de servidor.', 0);
    } catch (e) {
      return ApiResponse.error('Error inesperado: $e', 0);
    }
  }
  
  // === MÉTODOS DE AUTENTICACIÓN ===
  
  /// Iniciar sesión
  Future<ApiResponse> login(String email, String password) async {
    final response = await post('/auth/login', {
      'email': email,
      'password': password,
    }, includeAuth: false);
    
    if (response.isSuccess && response.data != null) {
      final token = response.data!['access_token'];
      if (token != null) {
        await _saveToken(token);
      }
    }
    
    return response;
  }
  
  /// Registrar usuario
  Future<ApiResponse> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
    String? phone,
    String? bio,
  }) async {
    return await post('/auth/register', {
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
    }, includeAuth: false);
  }
  
  /// Obtener perfil del usuario actual
  Future<ApiResponse> getCurrentUser() async {
    return await get('/auth/me');
  }
  
  /// Cerrar sesión
  Future<void> logout() async {
    await _removeToken();
  }
  
  /// Verificar si el usuario está autenticado
  bool get isAuthenticated => _token != null;
  
  /// Obtener el token actual
  String? get token => _token;
  
  // === MÉTODOS DE USUARIOS ===
  
  /// Obtener lista de usuarios
  Future<ApiResponse> getUsers({int skip = 0, int limit = 100}) async {
    return await get('/users/', queryParams: {
      'skip': skip.toString(),
      'limit': limit.toString(),
    });
  }
  
  /// Obtener usuario por ID
  Future<ApiResponse> getUserById(int userId) async {
    return await get('/users/$userId');
  }
  
  /// Actualizar usuario
  Future<ApiResponse> updateUser(int userId, Map<String, dynamic> userData) async {
    return await put('/users/$userId', userData);
  }
  
  /// Cambiar contraseña
  Future<ApiResponse> changePassword(int userId, String currentPassword, String newPassword) async {
    return await put('/users/$userId/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
  
  /// Eliminar usuario
  Future<ApiResponse> deleteUser(int userId) async {
    return await delete('/users/$userId');
  }
  
  // === MÉTODOS DE DOCUMENTOS ===
  
  /// Obtener lista de documentos
  Future<ApiResponse> getDocuments({
    int skip = 0,
    int limit = 20,
    String? category,
    bool? isPublic,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (isPublic != null) queryParams['is_public'] = isPublic.toString();
    
    return await get('/documents/', queryParams: queryParams);
  }
  
  /// Obtener mis documentos
  Future<ApiResponse> getMyDocuments({
    int skip = 0,
    int limit = 20,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    
    return await get('/documents/my', queryParams: queryParams);
  }
  
  /// Obtener documentos públicos
  Future<ApiResponse> getPublicDocuments({
    int skip = 0,
    int limit = 20,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    
    return await get('/documents/public', queryParams: queryParams);
  }
  
  /// Obtener documento por ID
  Future<ApiResponse> getDocumentById(int documentId) async {
    return await get('/documents/$documentId');
  }
  
  /// Actualizar documento
  Future<ApiResponse> updateDocument(int documentId, Map<String, dynamic> documentData) async {
    return await put('/documents/$documentId', documentData);
  }
  
  /// Eliminar documento
  Future<ApiResponse> deleteDocument(int documentId) async {
    return await delete('/documents/$documentId');
  }
  
  /// Obtener URL de descarga de documento
  Future<ApiResponse> getDocumentDownloadUrl(int documentId, {int expiresHours = 1}) async {
    return await get('/documents/$documentId/download-url', queryParams: {
      'expires_hours': expiresHours.toString(),
    });
  }
  
  /// Buscar documentos
  Future<ApiResponse> searchDocuments({
    required String query,
    int skip = 0,
    int limit = 20,
    String? category,
    String? fileType,
    bool myDocumentsOnly = false,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      'my_documents_only': myDocumentsOnly.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (fileType != null) queryParams['file_type'] = fileType;
    
    return await get('/documents/search', queryParams: queryParams);
  }
  
  /// Obtener estadísticas de documentos
  Future<ApiResponse> getDocumentsStats({bool myStatsOnly = false}) async {
    return await get('/documents/stats', queryParams: {
      'my_stats_only': myStatsOnly.toString(),
    });
  }
  
  // === MÉTODOS PARA IMÁGENES CLÍNICAS ===
  
  /// Subir una imagen clínica
  Future<ApiResponse> uploadClinicalImage({
    required File imageFile,
    String? description,
    String? tags,
    bool isPublic = false,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/clinical-images/upload'));
      
      // Agregar headers
      request.headers.addAll(_getHeaders());
      
      // Agregar archivo
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      // Agregar campos
      if (description != null) request.fields['description'] = description;
      if (tags != null) request.fields['tags'] = tags;
      request.fields['is_public'] = isPublic.toString();
      
      var streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      var response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Error de conexión. Verifica tu internet.', 0);
    } on HttpException {
      return ApiResponse.error('Error de servidor.', 0);
    } catch (e) {
      return ApiResponse.error('Error inesperado: $e', 0);
    }
  }
  
  /// Obtener lista de imágenes clínicas
  Future<ApiResponse> getClinicalImages({
    int skip = 0,
    int limit = 20,
    String? tags,
    bool? isPublic,
  }) async {
    final queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (tags != null) queryParams['tags'] = tags;
    if (isPublic != null) queryParams['is_public'] = isPublic.toString();
    
    return await get('/clinical-images/', queryParams: queryParams);
  }
  
  /// Obtener mis imágenes clínicas
  Future<ApiResponse> getMyClinicalImages({
    int skip = 0,
    int limit = 20,
    String? tags,
  }) async {
    final queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (tags != null) queryParams['tags'] = tags;
    
    return await get('/clinical-images/my', queryParams: queryParams);
  }
  
  /// Obtener imágenes clínicas públicas
  Future<ApiResponse> getPublicClinicalImages({
    int skip = 0,
    int limit = 20,
    String? tags,
  }) async {
    final queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (tags != null) queryParams['tags'] = tags;
    
    return await get('/clinical-images/public', queryParams: queryParams);
  }
  
  /// Obtener una imagen clínica específica
  Future<ApiResponse> getClinicalImage(int imageId) async {
    return await get('/clinical-images/$imageId');
  }
  
  /// Actualizar una imagen clínica
  Future<ApiResponse> updateClinicalImage(int imageId, {
    String? description,
    String? tags,
    bool? isPublic,
  }) async {
    final data = <String, dynamic>{};
    
    if (description != null) data['description'] = description;
    if (tags != null) data['tags'] = tags;
    if (isPublic != null) data['is_public'] = isPublic;
    
    return await put('/clinical-images/$imageId', data);
  }
  
  /// Eliminar una imagen clínica
  Future<ApiResponse> deleteClinicalImage(int imageId) async {
    return await delete('/clinical-images/$imageId');
  }
  
  /// Obtener URL de una imagen clínica
  Future<ApiResponse> getClinicalImageUrl(int imageId, {int expiresHours = 1}) async {
    return await get('/clinical-images/$imageId/url', queryParams: {
      'expires_hours': expiresHours.toString(),
    });
  }
  
  /// Ver una imagen clínica (retorna la URL para mostrar inline)
  String getClinicalImageViewUrl(int imageId) {
    return '$baseUrl/clinical-images/$imageId/view';
  }
  
  /// Descargar una imagen clínica (retorna la URL para descarga)
  String getClinicalImageDownloadUrl(int imageId) {
    return '$baseUrl/clinical-images/$imageId/download';
  }
  
  /// Buscar imágenes clínicas
  Future<ApiResponse> searchClinicalImages({
    required String query,
    int skip = 0,
    int limit = 20,
    String? tags,
    bool myImagesOnly = false,
  }) async {
    final queryParams = {
      'q': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      'my_images_only': myImagesOnly.toString(),
    };
    
    if (tags != null) queryParams['tags'] = tags;
    
    return await get('/clinical-images/search', queryParams: queryParams);
  }
  
  /// Obtener estadísticas de imágenes clínicas
  Future<ApiResponse> getClinicalImagesStats({bool myStatsOnly = false}) async {
    return await get('/clinical-images/stats', queryParams: {
      'my_stats_only': myStatsOnly.toString(),
    });
  }
  
  /// Verificar estado del servidor
  Future<ApiResponse> healthCheck() async {
    return await get('/health');
  }

  // === MÉTODOS PARA FÁRMACOS (VADEMÉCUM) ===

  /// Obtener lista de fármacos
  Future<List<Map<String, dynamic>>> getDrugs({
    int skip = 0,
    int limit = 20,
    String? therapeuticClass,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (therapeuticClass != null) queryParams['therapeutic_class'] = therapeuticClass;
    
    final response = await get('/drugs/', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármacos');
    }
  }

  /// Obtener un fármaco específico por ID
  Future<Map<String, dynamic>> getDrugById(int drugId) async {
    final response = await get('/drugs/$drugId');
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármaco');
    }
  }

  /// Buscar fármacos
  Future<Map<String, dynamic>> searchDrugs({
    required String query,
    int skip = 0,
    int limit = 20,
    String? therapeuticClass,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    if (therapeuticClass != null) queryParams['therapeutic_class'] = therapeuticClass;
    
    final response = await get('/drugs/search', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error buscando fármacos');
    }
  }

  /// Obtener fármacos por clase terapéutica
  Future<List<Map<String, dynamic>>> getDrugsByTherapeuticClass(
    String therapeuticClass, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/drugs/therapeutic-class/$therapeuticClass', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármacos por clase terapéutica');
    }
  }

  /// Obtener fármacos que requieren receta
  Future<List<Map<String, dynamic>>> getPrescriptionDrugs({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/drugs/prescription-only', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármacos con receta');
    }
  }

  /// Obtener sustancias controladas
  Future<List<Map<String, dynamic>>> getControlledSubstances({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/drugs/controlled-substances', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo sustancias controladas');
    }
  }

  /// Obtener fármacos para uso pediátrico
  Future<List<Map<String, dynamic>>> getPediatricDrugs({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/drugs/pediatric', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármacos pediátricos');
    }
  }

  /// Obtener fármacos para uso geriátrico
  Future<List<Map<String, dynamic>>> getGeriatricDrugs({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/drugs/geriatric', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo fármacos geriátricos');
    }
  }

  /// Poblar la tabla de fármacos (solo superusuarios)
  Future<String> seedDrugs() async {
    final response = await post('/drugs/seed', {});
    
    if (response.isSuccess && response.data != null) {
      return response.data!['message'];
    } else {
      throw Exception(response.error ?? 'Error poblando fármacos');
    }
  }

  // === MÉTODOS PARA CALCULADORAS CLÍNICAS ===

  /// Obtener lista de calculadoras disponibles
  Future<Map<String, dynamic>> getCalculators() async {
    final response = await get('/calculators/');
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error obteniendo calculadoras');
    }
  }

  /// Calcular CURB-65
  Future<Map<String, dynamic>> calculateCURB65({
    required bool confusion,
    required double urea,
    required int respiratoryRate,
    required int bloodPressureSystolic,
    required int bloodPressureDiastolic,
    required int age,
  }) async {
    final data = {
      'confusion': confusion,
      'urea': urea,
      'respiratory_rate': respiratoryRate,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      'age': age,
    };
    
    final response = await post('/calculators/curb65', data);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error calculando CURB-65');
    }
  }

  /// Calcular Wells PE
  Future<Map<String, dynamic>> calculateWellsPE({
    required bool clinicalSignsDvt,
    required bool peLikely,
    required bool heartRateOver100,
    required bool immobilizationSurgery,
    required bool previousPeDvt,
    required bool hemoptysis,
    required bool malignancy,
  }) async {
    final data = {
      'clinical_signs_dvt': clinicalSignsDvt,
      'pe_likely': peLikely,
      'heart_rate_over_100': heartRateOver100,
      'immobilization_surgery': immobilizationSurgery,
      'previous_pe_dvt': previousPeDvt,
      'hemoptysis': hemoptysis,
      'malignancy': malignancy,
    };
    
    final response = await post('/calculators/wells-pe', data);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error calculando Wells PE');
    }
  }

  /// Calcular Escala de Coma de Glasgow
  Future<Map<String, dynamic>> calculateGlasgowComa({
    required int eyeOpening,
    required int verbalResponse,
    required int motorResponse,
  }) async {
    final data = {
      'eye_opening': eyeOpening,
      'verbal_response': verbalResponse,
      'motor_response': motorResponse,
    };
    
    final response = await post('/calculators/glasgow-coma', data);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error calculando Glasgow Coma Scale');
    }
  }

  /// Calcular CHA2DS2-VASc
  Future<Map<String, dynamic>> calculateCHADS2VASc({
    required bool congestiveHeartFailure,
    required bool hypertension,
    required int age,
    required bool diabetes,
    required bool strokeTiaHistory,
    required bool vascularDisease,
    required bool sexFemale,
  }) async {
    final data = {
      'congestive_heart_failure': congestiveHeartFailure,
      'hypertension': hypertension,
      'age': age,
      'diabetes': diabetes,
      'stroke_tia_history': strokeTiaHistory,
      'vascular_disease': vascularDisease,
      'sex_female': sexFemale,
    };
    
    final response = await post('/calculators/chads2-vasc', data);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error calculando CHA2DS2-VASc');
    }
  }

  // === MÉTODOS PARA PROCEDIMIENTOS ===

  /// Obtener lista de procedimientos
  Future<List<Map<String, dynamic>>> getProcedures({
    int skip = 0,
    int limit = 20,
    String? category,
    String? specialty,
    String? difficultyLevel,
    bool publishedOnly = true,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      'published_only': publishedOnly.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (specialty != null) queryParams['specialty'] = specialty;
    if (difficultyLevel != null) queryParams['difficulty_level'] = difficultyLevel;
    
    final response = await get('/procedures/', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimientos');
    }
  }

  /// Obtener un procedimiento específico por ID
  Future<Map<String, dynamic>> getProcedureById(int procedureId) async {
    final response = await get('/procedures/$procedureId');
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimiento');
    }
  }

  /// Buscar procedimientos
  Future<Map<String, dynamic>> searchProcedures({
    required String query,
    int skip = 0,
    int limit = 20,
    String? category,
    String? specialty,
    String? difficultyLevel,
    bool publishedOnly = true,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      'published_only': publishedOnly.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (specialty != null) queryParams['specialty'] = specialty;
    if (difficultyLevel != null) queryParams['difficulty_level'] = difficultyLevel;
    
    final response = await get('/procedures/search', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error buscando procedimientos');
    }
  }

  /// Obtener procedimientos destacados
  Future<List<Map<String, dynamic>>> getFeaturedProcedures({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/procedures/featured', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimientos destacados');
    }
  }

  /// Obtener procedimientos por categoría
  Future<List<Map<String, dynamic>>> getProceduresByCategory(
    String category, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/procedures/category/$category', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimientos por categoría');
    }
  }

  /// Obtener procedimientos por especialidad
  Future<List<Map<String, dynamic>>> getProceduresBySpecialty(
    String specialty, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/procedures/specialty/$specialty', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimientos por especialidad');
    }
  }

  /// Obtener procedimientos por nivel de dificultad
  Future<List<Map<String, dynamic>>> getProceduresByDifficulty(
    String difficultyLevel, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/procedures/difficulty/$difficultyLevel', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo procedimientos por dificultad');
    }
  }

  /// Incrementar contador de visualizaciones de un procedimiento
  Future<void> incrementProcedureViews(int procedureId) async {
    final response = await post('/procedures/$procedureId/view', {});
    
    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Error incrementando visualizaciones');
    }
  }

  /// Poblar procedimientos de ejemplo
  Future<String> seedProcedures() async {
    final response = await post('/procedures/seed', {});
    
    if (response.isSuccess && response.data != null) {
      return response.data!['message'];
    } else {
      throw Exception(response.error ?? 'Error poblando procedimientos');
    }
  }

  // === MÉTODOS PARA ALGORITMOS ===

  /// Obtener lista de algoritmos
  Future<List<Map<String, dynamic>>> getAlgorithms({
    int skip = 0,
    int limit = 20,
    String? category,
    String? specialty,
    String? algorithmType,
    bool publishedOnly = true,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      'published_only': publishedOnly.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (specialty != null) queryParams['specialty'] = specialty;
    if (algorithmType != null) queryParams['algorithm_type'] = algorithmType;
    
    final response = await get('/algorithms/', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmos');
    }
  }

  /// Obtener un algoritmo específico por ID
  Future<Map<String, dynamic>> getAlgorithmById(int algorithmId) async {
    final response = await get('/algorithms/$algorithmId');
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmo');
    }
  }

  /// Obtener algoritmo completo con nodos y conexiones
  Future<Map<String, dynamic>> getAlgorithmComplete(int algorithmId) async {
    final response = await get('/algorithms/$algorithmId/complete');
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmo completo');
    }
  }

  /// Buscar algoritmos
  Future<Map<String, dynamic>> searchAlgorithms({
    required String query,
    int skip = 0,
    int limit = 20,
    String? category,
    String? specialty,
    String? algorithmType,
    bool publishedOnly = true,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'skip': skip.toString(),
      'limit': limit.toString(),
      'published_only': publishedOnly.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (specialty != null) queryParams['specialty'] = specialty;
    if (algorithmType != null) queryParams['algorithm_type'] = algorithmType;
    
    final response = await get('/algorithms/search', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.error ?? 'Error buscando algoritmos');
    }
  }

  /// Obtener algoritmos destacados
  Future<List<Map<String, dynamic>>> getFeaturedAlgorithms({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/algorithms/featured', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmos destacados');
    }
  }

  /// Obtener algoritmos por categoría
  Future<List<Map<String, dynamic>>> getAlgorithmsByCategory(
    String category, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/algorithms/category/$category', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmos por categoría');
    }
  }

  /// Obtener algoritmos por especialidad
  Future<List<Map<String, dynamic>>> getAlgorithmsBySpecialty(
    String specialty, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/algorithms/specialty/$specialty', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmos por especialidad');
    }
  }

  /// Obtener algoritmos por tipo
  Future<List<Map<String, dynamic>>> getAlgorithmsByType(
    String algorithmType, {
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    
    final response = await get('/algorithms/type/$algorithmType', queryParams: queryParams);
    
    if (response.isSuccess && response.data != null) {
      return List<Map<String, dynamic>>.from(response.data!);
    } else {
      throw Exception(response.error ?? 'Error obteniendo algoritmos por tipo');
    }
  }

  /// Incrementar contador de visualizaciones de un algoritmo
  Future<void> incrementAlgorithmViews(int algorithmId) async {
    final response = await post('/algorithms/$algorithmId/view', {});
    
    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Error incrementando visualizaciones');
    }
  }

  /// Incrementar contador de uso de un algoritmo
  Future<void> incrementAlgorithmUsage(int algorithmId) async {
    final response = await post('/algorithms/$algorithmId/use', {});
    
    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Error incrementando uso');
    }
  }

  /// Poblar algoritmos de ejemplo
  Future<String> seedAlgorithms() async {
    final response = await post('/algorithms/seed', {});
    
    if (response.isSuccess && response.data != null) {
      return response.data!['message'];
    } else {
      throw Exception(response.error ?? 'Error poblando algoritmos');
    }
  }
}

/// Clase para manejar respuestas de la API
class ApiResponse {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? error;
  final int statusCode;
  
  ApiResponse.success(this.data) 
      : isSuccess = true, 
        error = null, 
        statusCode = 200;
  
  ApiResponse.error(this.error, this.statusCode) 
      : isSuccess = false, 
        data = null;
  
  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data)';
    } else {
      return 'ApiResponse.error(error: $error, statusCode: $statusCode)';
    }
  }
}

/// Modelos de datos
class User {
  final int id;
  final String uuid;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final bool isActive;
  final bool isVerified;
  final bool isSuperuser;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  
  User({
    required this.id,
    required this.uuid,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    required this.isVerified,
    required this.isSuperuser,
    this.phone,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      uuid: json['uuid'],
      email: json['email'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      isActive: json['is_active'],
      isVerified: json['is_verified'],
      isSuperuser: json['is_superuser'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
    );
  }
  
  String get fullName => '$firstName $lastName';
  
  String get initials {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
  }
}

class Document {
  final int id;
  final String uuid;
  final String title;
  final String? description;
  final String filename;
  final String originalFilename;
  final double fileSize;
  final double fileSizeMb;
  final String fileSizeHuman;
  final String fileType;
  final String fileExtension;
  final String? category;
  final String? tags;
  final bool isPublic;
  final bool isActive;
  final int downloadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int ownerId;
  final User? owner;
  
  Document({
    required this.id,
    required this.uuid,
    required this.title,
    this.description,
    required this.filename,
    required this.originalFilename,
    required this.fileSize,
    required this.fileSizeMb,
    required this.fileSizeHuman,
    required this.fileType,
    required this.fileExtension,
    this.category,
    this.tags,
    required this.isPublic,
    required this.isActive,
    required this.downloadCount,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.owner,
  });
  
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      uuid: json['uuid'],
      title: json['title'],
      description: json['description'],
      filename: json['filename'],
      originalFilename: json['original_filename'],
      fileSize: json['file_size'].toDouble(),
      fileSizeMb: json['file_size_mb'].toDouble(),
      fileSizeHuman: json['file_size_human'],
      fileType: json['file_type'],
      fileExtension: json['file_extension'],
      category: json['category'],
      tags: json['tags'],
      isPublic: json['is_public'],
      isActive: json['is_active'],
      downloadCount: json['download_count'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      ownerId: json['owner_id'],
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
    );
  }
  
  String get displayCategory => category ?? 'Sin categoría';
  
  String get fileIcon {
    switch (fileExtension.toLowerCase()) {
      case '.pdf':
        return '📄';
      case '.ppt':
      case '.pptx':
        return '📊';
      case '.doc':
      case '.docx':
        return '📝';
      case '.txt':
        return '📃';
      default:
        return '📁';
    }
  }
}

class ClinicalImage {
  final int id;
  final String uuid;
  final String? description;
  final String? tags;
  final String imageKey;
  final String originalFilename;
  final double fileSize;
  final double fileSizeMb;
  final String fileSizeHuman;
  final String fileType;
  final int? imageWidth;
  final int? imageHeight;
  final String imageDimensions;
  final double? aspectRatio;
  final bool isPublic;
  final bool isActive;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int ownerId;
  final User? owner;
  
  ClinicalImage({
    required this.id,
    required this.uuid,
    this.description,
    this.tags,
    required this.imageKey,
    required this.originalFilename,
    required this.fileSize,
    required this.fileSizeMb,
    required this.fileSizeHuman,
    required this.fileType,
    this.imageWidth,
    this.imageHeight,
    required this.imageDimensions,
    this.aspectRatio,
    required this.isPublic,
    required this.isActive,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.owner,
  });
  
  factory ClinicalImage.fromJson(Map<String, dynamic> json) {
    return ClinicalImage(
      id: json['id'],
      uuid: json['uuid'],
      description: json['description'],
      tags: json['tags'],
      imageKey: json['image_key'],
      originalFilename: json['original_filename'],
      fileSize: json['file_size'].toDouble(),
      fileSizeMb: json['file_size_mb'].toDouble(),
      fileSizeHuman: json['file_size_human'],
      fileType: json['file_type'],
      imageWidth: json['image_width'],
      imageHeight: json['image_height'],
      imageDimensions: json['image_dimensions'],
      aspectRatio: json['aspect_ratio']?.toDouble(),
      isPublic: json['is_public'],
      isActive: json['is_active'],
      viewCount: json['view_count'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      ownerId: json['owner_id'],
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
    );
  }
  
  String get displayDescription => description ?? 'Sin descripción';
  
  String get imageTypeIcon {
    switch (fileType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return '🖼️';
      case 'image/png':
        return '🖼️';
      case 'image/gif':
        return '🎞️';
      case 'image/webp':
        return '🖼️';
      case 'image/bmp':
        return '🖼️';
      case 'image/tiff':
        return '🖼️';
      default:
        return '📷';
    }
  }
  
  bool get hasValidDimensions => imageWidth != null && imageHeight != null;
}

/// Clase para manejo de estadísticas de imágenes clínicas
class ClinicalImageStats {
  final int totalImages;
  final double totalSizeMb;
  final Map<String, int> imagesByType;
  final int recentUploads;
  final int totalViews;
  
  ClinicalImageStats({
    required this.totalImages,
    required this.totalSizeMb,
    required this.imagesByType,
    required this.recentUploads,
    required this.totalViews,
  });
  
  factory ClinicalImageStats.fromJson(Map<String, dynamic> json) {
    return ClinicalImageStats(
      totalImages: json['total_images'],
      totalSizeMb: json['total_size_mb'].toDouble(),
      imagesByType: Map<String, int>.from(json['images_by_type']),
      recentUploads: json['recent_uploads'],
      totalViews: json['total_views'],
    );
  }
}