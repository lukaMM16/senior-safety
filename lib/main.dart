import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/storage.dart';
import 'screens/app_start_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await initializeNotifications();

  runApp(const SeniorSafetyApp());
}

class SeniorSafetyApp extends StatefulWidget {
  const SeniorSafetyApp({super.key});

  @override
  State<SeniorSafetyApp> createState() =>
      _SeniorSafetyAppState();
}

class _SeniorSafetyAppState extends State<SeniorSafetyApp> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      try {
        await initializeNotifications();
        await startForegroundMessageListener();

        final familyCode = await getSavedFamilyCode();

        if (familyCode != null) {
          await registerFamilyDevice(familyCode);
        }
      } catch (e) {
        debugPrint('Greška pri početnoj registraciji: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Senior Safety',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D77),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AppStartScreen(),
      },
    );
  }
}
