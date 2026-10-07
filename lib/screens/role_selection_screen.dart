import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/storage.dart';
import '../services/senior_service.dart';
import 'family_auth_screen.dart';
import 'family_pairing_screen.dart';
import 'family_screen.dart';
import 'senior_name_screen.dart';
import 'senior_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> openSenior(
      BuildContext context,
      ) async {
    try {
      final code =
      await getOrCreateSeniorFamilyCode();
      final seniorName = await getSavedSeniorName();

      await saveRole(seniorRole);

      if (!context.mounted) return;

      if (seniorName == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SeniorNameScreen(familyCode: code),
          ),
        );
        return;
      }

      await syncSeniorName(code, seniorName);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeniorScreen(
            familyCode: code,
            seniorName: seniorName,
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
    if (FirebaseAuth.instance.currentUser == null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const FamilyAuthScreen(),
        ),
      );

      if (!context.mounted || result != true) return;
    }

    await saveRole(familyRole);

    if (!context.mounted) return;

    final savedCode = await getSavedFamilyCode();

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => savedCode != null
            ? FamilyScreen(familyCode: savedCode)
            : const FamilyPairingScreen(),
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

