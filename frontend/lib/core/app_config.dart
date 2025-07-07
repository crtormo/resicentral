class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  static const String apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: 'v1',
  );
  
  // Timeout Configuration
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
  static const Duration downloadTimeout = Duration(minutes: 10);
  
  // File Upload Configuration
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxImageSize = 20 * 1024 * 1024; // 20MB
  
  static const List<String> allowedDocumentTypes = [
    'application/pdf',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ];
  
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/tiff',
  ];
  
  // Cache Configuration
  static const Duration cacheTimeout = Duration(hours: 1);
  static const int maxCacheSize = 100; // Maximum number of cached items
  
  // Security Configuration
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);
  
  // App Configuration
  static const String appName = 'ResiCentral';
  static const String appVersion = '1.0.0';
  static const bool debugMode = bool.fromEnvironment('DEBUG_MODE', defaultValue: false);
  
  // Error Handling Configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Environment Detection
  static bool get isProduction => const String.fromEnvironment('ENVIRONMENT') == 'production';
  static bool get isDevelopment => const String.fromEnvironment('ENVIRONMENT') == 'development';
  static bool get isStaging => const String.fromEnvironment('ENVIRONMENT') == 'staging';
  
  // Feature Flags
  static const bool enableOfflineMode = bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: false);
  static const bool enableAnalytics = bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: false);
  static const bool enableCrashReporting = bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: false);
  
  // API Endpoints
  static String get authEndpoint => '$apiBaseUrl/auth';
  static String get usersEndpoint => '$apiBaseUrl/users';
  static String get documentsEndpoint => '$apiBaseUrl/documents';
  static String get clinicalImagesEndpoint => '$apiBaseUrl/clinical-images';
  static String get drugsEndpoint => '$apiBaseUrl/drugs';
  static String get calculatorsEndpoint => '$apiBaseUrl/calculators';
  static String get proceduresEndpoint => '$apiBaseUrl/procedures';
  static String get algorithmsEndpoint => '$apiBaseUrl/algorithms';
  static String get shiftsEndpoint => '$apiBaseUrl/shifts';
  static String get aiEndpoint => '$apiBaseUrl/ai';
  static String get healthEndpoint => '$apiBaseUrl/health';
  
  // Validation Methods
  static bool isValidFileSize(int fileSize, {bool isImage = false}) {
    final maxSize = isImage ? maxImageSize : maxFileSize;
    return fileSize <= maxSize;
  }
  
  static bool isValidFileType(String mimeType, {bool isImage = false}) {
    final allowedTypes = isImage ? allowedImageTypes : allowedDocumentTypes;
    return allowedTypes.contains(mimeType.toLowerCase());
  }
  
  // Helper Methods
  static String getFileTypeDescription(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'Documento PDF';
      case '.doc':
      case '.docx':
        return 'Documento de Word';
      case '.ppt':
      case '.pptx':
        return 'Presentación de PowerPoint';
      case '.xls':
      case '.xlsx':
        return 'Hoja de cálculo de Excel';
      case '.txt':
        return 'Archivo de texto';
      case '.jpg':
      case '.jpeg':
        return 'Imagen JPEG';
      case '.png':
        return 'Imagen PNG';
      case '.gif':
        return 'Imagen GIF';
      case '.webp':
        return 'Imagen WebP';
      case '.bmp':
        return 'Imagen BMP';
      case '.tiff':
        return 'Imagen TIFF';
      default:
        return 'Archivo';
    }
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}