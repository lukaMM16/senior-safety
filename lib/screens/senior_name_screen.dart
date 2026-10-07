import 'package:flutter/material.dart';

import '../services/senior_service.dart';
import 'senior_screen.dart';

class SeniorNameScreen extends StatefulWidget {
  final String familyCode;

  const SeniorNameScreen({
    super.key,
    required this.familyCode,
  });

  @override
  State<SeniorNameScreen> createState() =>
      _SeniorNameScreenState();
}

class _SeniorNameScreenState extends State<SeniorNameScreen> {
  final TextEditingController nameController =
  TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> saveAndContinue() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upišite ime starije osobe.'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await saveSeniorName(name);
      await syncSeniorName(widget.familyCode, name);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SeniorScreen(
            familyCode: widget.familyCode,
            seniorName: name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri spremanju imena: $e'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text('Starija osoba'),
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person,
                size: 85,
                color: Color(0xFF006D77),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kako se zove starija osoba?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ime će članovima obitelji biti prikazano uz status i upozorenja.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!loading) saveAndContinue();
                },
                decoration: const InputDecoration(
                  labelText: 'Ime',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: loading ? null : saveAndContinue,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                    'NASTAVI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

