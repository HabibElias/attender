import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If the .env file is missing (e.g., in production builds), continue without crashing.
    debugPrint('Warning: Could not load .env file: $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Supabase Flutter Demo')),
        body: const Center(child: Text('Welcome to Supabase with Flutter!')),
      ),
    );
  }
}
