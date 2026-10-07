import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage.dart';

Future<String?> getSavedSeniorName() async {
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString(seniorNameKey)?.trim();
  return (name == null || name.isEmpty) ? null : name;
}

Future<void> saveSeniorName(String name) async {
  final cleanName = name.trim();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(seniorNameKey, cleanName);
}

Future<void> syncSeniorName(
    String familyCode,
    String seniorName,
    ) async {
  await FirebaseFirestore.instance
      .collection('families')
      .doc(familyCode)
      .set({
    'seniorName': seniorName.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
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
