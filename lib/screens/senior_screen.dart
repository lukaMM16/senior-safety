import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SeniorScreen extends StatefulWidget {
  final String familyCode;
  final String? seniorName;

  const SeniorScreen({
    super.key,
    required this.familyCode,
    this.seniorName,
  });

  @override
  State<SeniorScreen> createState() => _SeniorScreenState();
}

class _SeniorScreenState extends State<SeniorScreen> {
  bool sendingOkay = false;
  bool sendingHelp = false;

  Future<void> sendStatus(
      String status,
      String seniorName,
      ) async {
    final isHelp = status == 'TREBA MI POMOĆ';

    if (isHelp) {
      if (sendingHelp) return;

      setState(() {
        sendingHelp = true;
      });
    } else {
      if (sendingOkay) return;

      setState(() {
        sendingOkay = true;
      });
    }

    try {
      final familyRef = FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyCode);

      await familyRef.set({
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'seniorName': seniorName,
      }, SetOptions(merge: true));

      if (isHelp) {
        await familyRef
            .collection('help_requests')
            .add({
          'status': status,
          'seniorName': seniorName,
          'timestamp': FieldValue.serverTimestamp(),

          // Potrebno za funkciju
          // "PREUZIMAM PROVJERU".
          'lifecycleStatus': 'open',
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHelp
                ? 'Zahtjev za pomoć je poslan.'
                : 'Potvrda je uspješno poslana.',
          ),
          backgroundColor:
          isHelp ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri slanju statusa: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isHelp) {
            sendingHelp = false;
          } else {
            sendingOkay = false;
          }
        });
      }
    }
  }

  Widget buildConnectionSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyCode)
          .collection('members')
          .limit(1)
          .snapshots(),
      builder: (
          context,
          snapshot,
          ) {
        final hasConnectedMember =
            snapshot.hasData &&
                snapshot.data!.docs.isNotEmpty;

        if (hasConnectedMember) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Obitelj je povezana',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black12,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Kod za povezivanje',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 6),

              SelectableText(
                widget.familyCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                  color: Color(0xFF006D77),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Član obitelji treba upisati ovaj kod.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyRef = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyCode);

    return Scaffold(
      backgroundColor:
      const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text(
          'Senior Safety',
        ),
        backgroundColor:
        const Color(0xFF006D77),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: familyRef.snapshots(),
          builder: (
              context,
              snapshot,
              ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nije moguće učitati podatke.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            String seniorName =
            widget.seniorName?.trim().isNotEmpty == true
                ? widget.seniorName!.trim()
                : 'Starija osoba';

            if (snapshot.hasData &&
                snapshot.data!.exists) {
              final data =
              snapshot.data!.data()
              as Map<String, dynamic>;

              final storedName =
              data['seniorName']
                  ?.toString()
                  .trim();

              if (storedName != null &&
                  storedName.isNotEmpty) {
                seniorName = storedName;
              }
            }

            return LayoutBuilder(
              builder: (
                  context,
                  constraints,
                  ) {
                return SingleChildScrollView(
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                      constraints.maxHeight -
                          44,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          buildConnectionSection(),

                          const SizedBox(height: 26),

                          Text(
                            'Pozdrav, $seniorName',
                            textAlign:
                            TextAlign.center,
                            style:
                            const TextStyle(
                              fontSize: 27,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              Color(0xFF006D77),
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Kako ste danas?',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            width:
                            double.infinity,
                            height: 125,
                            child:
                            ElevatedButton.icon(
                              onPressed:
                              sendingOkay
                                  ? null
                                  : () {
                                sendStatus(
                                  'DOBRO SAM',
                                  seniorName,
                                );
                              },
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                Colors.green,
                                foregroundColor:
                                Colors.white,
                                disabledBackgroundColor:
                                Colors.green
                                    .withValues(
                                  alpha: 0.55,
                                ),
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    22,
                                  ),
                                ),
                              ),
                              icon: sendingOkay
                                  ? const SizedBox(
                                width: 28,
                                height: 28,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color:
                                  Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons
                                    .check_circle,
                                size: 38,
                              ),
                              label: Text(
                                sendingOkay
                                    ? 'ŠALJEM...'
                                    : 'DOBRO SAM',
                                style:
                                const TextStyle(
                                  fontSize: 26,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width:
                            double.infinity,
                            height: 125,
                            child:
                            ElevatedButton.icon(
                              onPressed:
                              sendingHelp
                                  ? null
                                  : () {
                                sendStatus(
                                  'TREBA MI POMOĆ',
                                  seniorName,
                                );
                              },
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                Colors.red,
                                foregroundColor:
                                Colors.white,
                                disabledBackgroundColor:
                                Colors.red
                                    .withValues(
                                  alpha: 0.55,
                                ),
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    22,
                                  ),
                                ),
                              ),
                              icon: sendingHelp
                                  ? const SizedBox(
                                width: 28,
                                height: 28,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color:
                                  Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons
                                    .warning_rounded,
                                size: 40,
                              ),
                              label: Text(
                                sendingHelp
                                    ? 'ŠALJEM...'
                                    : 'TREBA MI POMOĆ',
                                textAlign:
                                TextAlign.center,
                                style:
                                const TextStyle(
                                  fontSize: 25,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          const SizedBox(height: 24),

                          const Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: Color(
                                  0xFF006D77,
                                ),
                                size: 19,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Senior Safety je aktivan',
                                style: TextStyle(
                                  color:
                                  Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}