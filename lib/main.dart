import 'package:anri/providers/settings_provider.dart';
import 'package:anri/providers/theme_provider.dart';
import 'package:anri/providers/ticket_provider.dart';
import 'package:flutter/material.dart';
import 'package:anri/pages/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()), // BARU
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Helpdesk Mobile',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
          surface: Colors.white,
          background: const Color(0xFFF0F4F8),
          surfaceVariant: Colors.blue.shade50,
          surfaceContainerHighest: const Color(0xFFE3E3E3),
          onPrimaryContainer: Colors.black,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.lightBlue.shade300,
          surface: const Color.fromARGB(255, 25, 34, 44),
          background: const Color(0xFF1C2833),
          surfaceContainerLowest: const Color(0xFF1C2833),
          surfaceContainerHighest: const Color.fromARGB(255, 29, 40, 52),
          onPrimaryContainer: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false, //mengilangkan banner debug
    );
  }
}
