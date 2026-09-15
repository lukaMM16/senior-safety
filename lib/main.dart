import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel emergencyChannel =
    AndroidNotificationChannel(
  'senior_safety_emergency',
  'Hitne obavijesti',
  description: 'Hitne Senior Safety obavijesti za pomoć.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const String seniorCodeKey = 'senior_family_code';
const String familyCodeKey = 'family_member_code';
const String familyMemberIdKey = 'family_member_id';
const String selectedRoleKey = 'selected_role';
const String seniorRole = 'senior';
const String familyRole = 'family';

bool notificationsInitialized = false;

StreamSubscription<String>? tokenRefreshSubscription;
StreamSubscription<RemoteMessage>? foregroundMessageSubscription;

Future<void> initializeNotifications() async {
  if (notificationsInitialized) {
    return;
  }

  const androidSettings =
      AndroidInitializationSettings('mipmap/ic_launcher');

  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: initializationSettings,
  );

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    emergencyChannel,
  );

  notificationsInitialized = true;
}

Future<void> showEmergencyNotification(
  RemoteMessage message,
) async {
  await initializeNotifications();

  const androidDetails = AndroidNotificationDetails(
    'senior_safety_emergency',
    'Hitne obavijesti',
    channelDescription:
        'Hitne Senior Safety obavijesti za pomoć.',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
  );

  const notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  final requestId =
      message.data['requestId']?.toString() ?? '';

  final notificationId = requestId.isNotEmpty
      ? requestId.hashCode & 0x7fffffff
      : DateTime.now()
          .millisecondsSinceEpoch
          .remainder(2147483647);

  final title = message.data['title']?.toString() ??
      message.notification?.title ??
      '🚨 Senior Safety';

  final body = message.data['body']?.toString() ??
      message.notification?.body ??
      'Starija osoba treba pomoć!';

  await localNotifications.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: requestId.isNotEmpty
        ? requestId
        : 'help_request',
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();

  try {
    await showEmergencyNotification(message);
  } catch (e) {
    debugPrint(
      'Greška kod background obavijesti: $e',
    );
  }
}

Future<void> startForegroundMessageListener() async {
  await foregroundMessageSubscription?.cancel();

  foregroundMessageSubscription =
      FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) async {
      debugPrint(
        'Primljena push poruka: ${message.data}',
      );

      try {
        await showEmergencyNotification(message);
      } catch (e) {
        debugPrint(
          'Greška kod prikaza obavijesti: $e',
        );
      }
    },
  );
}

Future<String?> getSavedFamilyCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(familyCodeKey);
}

Future<String?> getSavedRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(selectedRoleKey);
}

Future<void> saveRole(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(selectedRoleKey, role);
}

Future<void> clearSavedRole() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(selectedRoleKey);
}

Future<void> registerFamilyDevice(
  String familyCode,
) async {
  try {
    await initializeNotifications();

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission: '
      '${settings.authorizationStatus}',
    );

    final token = await messaging.getToken();

    if (token == null) {
      debugPrint('FCM token nije dobiven.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    String? memberId = prefs.getString(
      familyMemberIdKey,
    );

    if (memberId == null) {
      memberId = FirebaseFirestore.instance
          .collection('families')
          .doc(familyCode)
          .collection('members')
          .doc()
          .id;

      await prefs.setString(
        familyMemberIdKey,
        memberId,
      );
    }

    await prefs.setString(
      familyCodeKey,
      familyCode,
    );

    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyCode)
        .collection('members')
        .doc(memberId)
        .set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await tokenRefreshSubscription?.cancel();

    tokenRefreshSubscription =
        messaging.onTokenRefresh.listen(
      (newToken) async {
        final currentPrefs =
            await SharedPreferences.getInstance();

        final currentFamilyCode =
            currentPrefs.getString(familyCodeKey);

        final currentMemberId =
            currentPrefs.getString(familyMemberIdKey);

        if (currentFamilyCode == null ||
            currentMemberId == null) {
          return;
        }

        await FirebaseFirestore.instance
            .collection('families')
            .doc(currentFamilyCode)
            .collection('members')
            .doc(currentMemberId)
            .set({
          'fcmToken': newToken,
          'updatedAt':
              FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
    );

    debugPrint(
      'Uređaj registriran za obitelj $familyCode',
    );
  } catch (e) {
    debugPrint(
      'Greška kod registracije uređaja: $e',
    );
  }
}

Future<String> getOrCreateSeniorFamilyCode() async {
  final prefs = await SharedPreferences.getInstance();

  final savedCode =
      prefs.getString(seniorCodeKey);

  if (savedCode != null) {
    return savedCode;
  }

  final random = Random.secure();

  for (int attempt = 0; attempt < 20; attempt++) {
    final code =
        (100000 + random.nextInt(900000))
            .toString();

    final familyRef = FirebaseFirestore.instance
        .collection('families')
        .doc(code);

    final existing = await familyRef.get();

    if (!existing.exists) {
      await familyRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'NEMA STATUSA',
      });

      await prefs.setString(
        seniorCodeKey,
        code,
      );

      return code;
    }
  }

  throw Exception(
    'Nije moguće generirati kod za povezivanje.',
  );
}

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

class _SeniorSafetyAppState
    extends State<SeniorSafetyApp> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      try {
        await initializeNotifications();
        await startForegroundMessageListener();

        final familyCode =
            await getSavedFamilyCode();

        if (familyCode != null) {
          await registerFamilyDevice(
            familyCode,
          );
        }
      } catch (e) {
        debugPrint(
          'Greška pri početnoj registraciji: $e',
        );
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
      home: const AppStartScreen(),
    );
  }
}

class AppStartScreen extends StatefulWidget {
  const AppStartScreen({super.key});

  @override
  State<AppStartScreen> createState() =>
      _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  late final Future<Widget> startScreenFuture;

  @override
  void initState() {
    super.initState();
    startScreenFuture = determineStartScreen();
  }

  Future<Widget> determineStartScreen() async {
    final savedRole = await getSavedRole();

    if (savedRole == seniorRole) {
      try {
        final code = await getOrCreateSeniorFamilyCode();
        return SeniorScreen(familyCode: code);
      } catch (e) {
        debugPrint('Greška pri otvaranju senior ekrana: $e');
        await clearSavedRole();
        return const RoleSelectionScreen();
      }
    }

    if (savedRole == familyRole) {
      final code = await getSavedFamilyCode();

      if (code != null) {
        return FamilyScreen(familyCode: code);
      }

      return const FamilyPairingScreen();
    }

    return const RoleSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: startScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F6F1),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const RoleSelectionScreen();
        }

        return snapshot.data!;
      },
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> openSenior(
    BuildContext context,
  ) async {
    try {
      final code =
          await getOrCreateSeniorFamilyCode();

      await saveRole(seniorRole);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SeniorScreen(
            familyCode: code,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška: $e',
          ),
        ),
      );
    }
  }

  Future<void> openFamily(
    BuildContext context,
  ) async {
    final savedCode =
        await getSavedFamilyCode();

    if (!context.mounted) return;

    if (savedCode != null) {
      await saveRole(familyRole);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FamilyScreen(
            familyCode: savedCode,
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const FamilyPairingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F6F1),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              const Icon(
                Icons.health_and_safety,
                size: 90,
                color: Color(0xFF006D77),
              ),

              const SizedBox(height: 20),

              const Text(
                'SENIOR SAFETY',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight:
                      FontWeight.bold,
                  color: Color(0xFF006D77),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Sigurnost i povezanost s obitelji',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),

              const Spacer(),

              const Text(
                'Odaberite način korištenja',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 90,
                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    openSenior(context);
                  },
                  icon: const Icon(
                    Icons.person,
                    size: 38,
                  ),
                  label: const Text(
                    'STARIJA OSOBA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 90,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    openFamily(context);
                  },
                  icon: const Icon(
                    Icons.family_restroom,
                    size: 38,
                  ),
                  label: const Text(
                    'ČLAN OBITELJI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Text(
                'Senior Safety • Firebase',
                style: TextStyle(
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeniorScreen extends StatelessWidget {
  final String familyCode;

  const SeniorScreen({
    super.key,
    required this.familyCode,
  });

  Future<void> sendStatus(
    BuildContext context,
    String status,
  ) async {
    try {
      final familyRef =
          FirebaseFirestore.instance
              .collection('families')
              .doc(familyCode);

      await familyRef.set({
        'status': status,
        'timestamp':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (status ==
          'TREBA MI POMOĆ') {
        await familyRef
            .collection('help_requests')
            .add({
          'status': status,
          'timestamp':
              FieldValue.serverTimestamp(),
        });
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Status poslan: $status',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri slanju statusa: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> changeRole(BuildContext context) async {
    await clearSavedRole();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) =>
            const RoleSelectionScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F6F1),
      appBar: AppBar(
        title:
            const Text('Senior Safety'),
        backgroundColor:
            const Color(0xFF006D77),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              changeRole(context);
            },
            tooltip: 'Promijeni ulogu',
            icon: const Icon(
              Icons.swap_horiz,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 15),

              const Text(
                'Kod za povezivanje',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 6),

              SelectableText(
                familyCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight:
                      FontWeight.bold,
                  letterSpacing: 5,
                  color: Color(0xFF006D77),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Član obitelji treba upisati ovaj kod.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Kako ste danas?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 140,
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.green,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                  onPressed: () {
                    sendStatus(
                      context,
                      'DOBRO SAM',
                    );
                  },
                  child: const Text(
                    'DOBRO SAM',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 140,
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.red,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                  onPressed: () {
                    sendStatus(
                      context,
                      'TREBA MI POMOĆ',
                    );
                  },
                  child: const Text(
                    'TREBA MI POMOĆ',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done,
                    color: Colors.green,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Firebase veza aktivna',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyPairingScreen
    extends StatefulWidget {
  const FamilyPairingScreen({
    super.key,
  });

  @override
  State<FamilyPairingScreen>
      createState() =>
          _FamilyPairingScreenState();
}

class _FamilyPairingScreenState
    extends State<FamilyPairingScreen> {
  final TextEditingController
      codeController =
      TextEditingController();

  bool loading = false;

  Future<void> connect() async {
    final code =
        codeController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Upišite 6-znamenkasti kod.',
          ),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final familyDocument =
          await FirebaseFirestore.instance
              .collection('families')
              .doc(code)
              .get();

      if (!familyDocument.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Kod ne postoji.',
            ),
          ),
        );

        return;
      }

      await registerFamilyDevice(
        code,
      );

      await saveRole(familyRole);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FamilyScreen(
            familyCode: code,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri povezivanju: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F6F1),
      appBar: AppBar(
        title:
            const Text('Povezivanje'),
        backgroundColor:
            const Color(0xFF006D77),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.link,
              size: 80,
              color: Color(0xFF006D77),
            ),

            const SizedBox(height: 25),

            const Text(
              'Povežite se sa starijom osobom',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Upišite 6-znamenkasti kod prikazan na mobitelu starije osobe.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 35),

            TextField(
              controller:
                  codeController,
              keyboardType:
                  TextInputType.number,
              textAlign:
                  TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter
                    .digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 30,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 6,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Kod za povezivanje',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed:
                    loading ? null : connect,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'POVEŽI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FamilyScreen
    extends StatefulWidget {
  final String familyCode;

  const FamilyScreen({
    super.key,
    required this.familyCode,
  });

  @override
  State<FamilyScreen> createState() =>
      _FamilyScreenState();
}

class _FamilyScreenState
    extends State<FamilyScreen> {
  bool pushRegistered = false;

  @override
  void initState() {
    super.initState();

    registerFamilyDevice(
      widget.familyCode,
    ).then((_) {
      if (mounted) {
        setState(() {
          pushRegistered = true;
        });
      }
    });
  }

  Future<void> disconnect() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final memberId =
        prefs.getString(
      familyMemberIdKey,
    );

    if (memberId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyCode)
            .collection('members')
            .doc(memberId)
            .delete();
      } catch (e) {
        debugPrint(
          'Greška kod brisanja uređaja: $e',
        );
      }
    }

    await prefs.remove(
      familyCodeKey,
    );

    await prefs.remove(
      familyMemberIdKey,
    );

    await prefs.remove(
      selectedRoleKey,
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) =>
            const RoleSelectionScreen(),
      ),
      (route) => false,
    );
  }

  String formatTime(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return '--:--';
    }

    final time =
        timestamp.toDate().toLocal();

    final hour =
        time.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        time.minute
            .toString()
            .padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F6F1),
      appBar: AppBar(
        title:
            const Text('Član obitelji'),
        backgroundColor:
            const Color(0xFF006D77),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: disconnect,
            tooltip: 'Odspoji uređaj',
            icon: const Icon(
              Icons.link_off,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child:
              StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('families')
                    .doc(widget.familyCode)
                    .snapshots(),
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Greška pri povezivanju s Firebaseom.',
                  ),
                );
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              String status =
                  'NEMA STATUSA';

              Timestamp? timestamp;

              if (snapshot.hasData &&
                  snapshot.data!.exists) {
                final data =
                    snapshot.data!.data()
                        as Map<String, dynamic>;

                status =
                    data['status'] ??
                        'NEMA STATUSA';

                timestamp =
                    data['timestamp']
                        as Timestamp?;
              }

              final needsHelp =
                  status ==
                      'TREBA MI POMOĆ';

              final isOkay =
                  status == 'DOBRO SAM';

              final statusColor =
                  needsHelp
                      ? Colors.red
                      : isOkay
                          ? Colors.green
                          : Colors.grey;

              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Povezano: ${widget.familyCode}',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Icon(
                    Icons.family_restroom,
                    size: 70,
                    color:
                        Color(0xFF006D77),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Status starije osobe',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withValues(
                        alpha: 0.15,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color: statusColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          needsHelp
                              ? Icons.warning
                              : isOkay
                                  ? Icons
                                      .check_circle
                                  : Icons
                                      .help_outline,
                          size: 65,
                          color:
                              statusColor,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Text(
                          status,
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            fontSize: 30,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Zadnji status:',
                          style: TextStyle(
                            color:
                                Colors.black54,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          status,
                          style:
                              const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        const Text(
                          'Vrijeme slanja:',
                          style: TextStyle(
                            color:
                                Colors.black54,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          formatTime(
                            timestamp,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        pushRegistered
                            ? Icons
                                .notifications_active
                            : Icons.sync,
                        color:
                            pushRegistered
                                ? Colors.green
                                : const Color(
                                    0xFF006D77,
                                  ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Text(
                        pushRegistered
                            ? 'Push obavijesti su aktivne'
                            : 'Registracija za push...',
                        style:
                            const TextStyle(
                          color:
                              Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
