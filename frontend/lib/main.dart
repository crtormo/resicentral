import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/message_provider.dart';
import 'navigation/app_router.dart';
import 'services/api_service.dart';

void main() async {
  // Asegurar que los widgets estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar el servicio API
  await ApiService().init();
  
  runApp(const ResiCentralApp());
}

class ResiCentralApp extends StatelessWidget {
  const ResiCentralApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (context) => MessageProvider(),
        ),
      ],
      child: const AppRouterWidget(),
    );
  }
}