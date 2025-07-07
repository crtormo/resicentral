import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isAuthenticating = authProvider.status == AuthStatus.authenticating;
        final isUninitialized = authProvider.status == AuthStatus.uninitialized;
        
        // Si está inicializando, mostrar splash
        if (isUninitialized) {
          return '/splash';
        }
        
        // Rutas que no requieren autenticación
        final publicRoutes = ['/login', '/register', '/splash'];
        final isOnPublicRoute = publicRoutes.contains(state.location);
        
        // Si no está autenticado y no está en una ruta pública, redirigir a login
        if (!isAuthenticated && !isAuthenticating && !isOnPublicRoute) {
          return '/login';
        }
        
        // Si está autenticado y está en una ruta pública, redirigir a home
        if (isAuthenticated && isOnPublicRoute && state.location != '/splash') {
          return '/home';
        }
        
        // Si está en la raíz y está autenticado, ir a home
        if (isAuthenticated && state.location == '/') {
          return '/home';
        }
        
        // Si está en la raíz y no está autenticado, ir a login
        if (!isAuthenticated && state.location == '/') {
          return '/login';
        }
        
        return null; // No redirigir
      },
      routes: [
        // Splash Screen
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        
        // Rutas de autenticación
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        
        // Rutas principales (requieren autenticación)
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        
        // Ruta raíz
        GoRoute(
          path: '/',
          name: 'root',
          builder: (context, state) => const SplashScreen(),
        ),
      ],
      
      // Manejador de errores
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Página no encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'La página "${state.location}" no existe.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que envuelve la aplicación con el router
class AppRouterWidget extends StatelessWidget {
  const AppRouterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final router = AppRouter.createRouter(authProvider);
        
        return MaterialApp.router(
          title: 'ResiCentral',
          debugShowCheckedModeBanner: false,
          
          // Configuración del router
          routerConfig: router,
          
          // Tema de la aplicación
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            
            // AppBar Theme
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            // Button Themes
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
            
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            // Input Decoration Theme
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            
            // Card Theme
            cardTheme: CardTheme(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            
            // FloatingActionButton Theme
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            
            // BottomNavigationBar Theme
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: Color(0xFF2E7D32),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              elevation: 8,
            ),
          ),
          
          // Configuración de localización
          locale: const Locale('es', 'ES'),
          
          // Builder para interceptar y mostrar mensajes globales
          builder: (context, child) {
            return Consumer<MessageProvider>(
              builder: (context, messageProvider, _) {
                // Mostrar SnackBar si hay un mensaje
                if (messageProvider.hasMessage) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              messageProvider.type.icon,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                messageProvider.message!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: messageProvider.type.color,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        action: SnackBarAction(
                          label: 'Cerrar',
                          textColor: Colors.white,
                          onPressed: () {
                            messageProvider.clear();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                        ),
                      ),
                    );
                    messageProvider.clear();
                  });
                }
                
                return child ?? const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}

/// Extensiones útiles para navegación
extension AppRouterExtension on BuildContext {
  /// Navegar a login
  void goToLogin() => go('/login');
  
  /// Navegar a registro
  void goToRegister() => go('/register');
  
  /// Navegar a home
  void goToHome() => go('/home');
  
  /// Volver atrás
  void goBack() => pop();
  
  /// Reemplazar ruta actual
  void replaceTo(String location) => pushReplacement(location);
}

/// Función para obtener el nombre de la ruta actual
String getCurrentRouteName(BuildContext context) {
  final routerState = GoRouter.of(context).routerDelegate.currentConfiguration;
  return routerState.location;
}

/// Widget de carga global
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  
  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          message!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}