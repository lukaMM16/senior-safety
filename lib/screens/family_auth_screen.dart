import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({super.key});

  @override
  State<FamilyAuthScreen> createState() => _FamilyAuthScreenState();
}

class _FamilyAuthScreenState extends State<FamilyAuthScreen> {
  final AuthService authService = AuthService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  bool isRegisterMode = false;
  bool loading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (isRegisterMode && name.isEmpty) {
      showMessage('Upišite ime.');
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      showMessage('Upišite email i lozinku.');
      return;
    }

    if (isRegisterMode && password != confirmPassword) {
      showMessage('Lozinke se ne podudaraju.');
      return;
    }

    if (password.length < 6) {
      showMessage('Lozinka mora imati najmanje 6 znakova.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      if (isRegisterMode) {
        await authService.registerFamilyMember(
          name: name,
          email: email,
          password: password,
        );
      } else {
        await authService.signInFamilyMember(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      showMessage('Dogodila se greška. Pokušajte ponovno.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Korisnik s ovim emailom već postoji.';
      case 'invalid-email':
        return 'Email adresa nije ispravna.';
      case 'weak-password':
        return 'Lozinka je preslaba.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ili lozinka nisu ispravni.';
      case 'too-many-requests':
        return 'Previše pokušaja. Pokušajte ponovno kasnije.';
      case 'network-request-failed':
        return 'Provjerite internetsku vezu.';
      default:
        return 'Greška pri prijavi: ${error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: Text(
          isRegisterMode ? 'Registracija' : 'Prijava',
        ),
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              const Icon(
                Icons.family_restroom,
                size: 85,
                color: Color(0xFF006D77),
              ),

              const SizedBox(height: 20),

              Text(
                isRegisterMode
                    ? 'Napravite račun člana obitelji'
                    : 'Prijava člana obitelji',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 35),

              if (isRegisterMode) ...[
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ime',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
              ],

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Lozinka',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),

              if (isRegisterMode) ...[
                const SizedBox(height: 18),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: hidePassword,
                  decoration: const InputDecoration(
                    labelText: 'Ponovite lozinku',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(
                    isRegisterMode
                        ? 'REGISTRIRAJ SE'
                        : 'PRIJAVI SE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: loading
                    ? null
                    : () {
                  setState(() {
                    isRegisterMode = !isRegisterMode;
                    nameController.clear();
                    confirmPasswordController.clear();
                  });
                },
                child: Text(
                  isRegisterMode
                      ? 'Već imate račun? Prijavite se'
                      : 'Nemate račun? Registrirajte se',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
