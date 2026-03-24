import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/pet_repository.dart';
import 'data/repositories/booking_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepository(prefs)),
        ChangeNotifierProvider(create: (_) => PetRepository(prefs)),
        ChangeNotifierProvider(create: (_) => BookingRepository(prefs)),
      ],
      child: const PetSaathiApp(),
    ),
  );
}

class PetSaathiApp extends StatelessWidget {
  const PetSaathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = context.read<AuthRepository>();
    final router = AppRouter.createRouter(authRepo);

    return MaterialApp.router(
      title: 'PetSaathi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
