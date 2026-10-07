import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/storage.dart';
import '../services/notification_service.dart';
import 'family_screen.dart';

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

