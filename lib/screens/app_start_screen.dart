import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/storage.dart';
import '../services/senior_service.dart';
import 'family_pairing_screen.dart';
import 'family_screen.dart';
import 'role_selection_screen.dart';
import 'senior_name_screen.dart';
import 'senior_screen.dart';

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
        final seniorName = await getSavedSeniorName();

        if (seniorName == null) {
          return SeniorNameScreen(familyCode: code);
        }

        await syncSeniorName(code, seniorName);

        return SeniorScreen(
          familyCode: code,
          seniorName: seniorName,
        );
      } catch (e) {
        debugPrint('Greška pri otvaranju senior ekrana: $e');
        await clearSavedRole();
        return const RoleSelectionScreen();
      }
    }

    if (savedRole == familyRole) {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        await clearSavedRole();
        return const RoleSelectionScreen();
      }

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

