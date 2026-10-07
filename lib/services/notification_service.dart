import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage.dart';

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

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = currentUser?.displayName;
    final currentUserEmail = currentUser?.email;

    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyCode)
        .collection('members')
        .doc(memberId)
        .set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
      if (currentUser != null) 'uid': currentUser.uid,
      if (currentUserName != null &&
          currentUserName.isNotEmpty)
        'name': currentUserName,
      if (currentUserEmail != null &&
          currentUserEmail.isNotEmpty)
        'email': currentUserEmail,
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