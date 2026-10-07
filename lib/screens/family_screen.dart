import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage.dart';
import '../services/notification_service.dart';

class FamilyScreen extends StatefulWidget {
  final String familyCode;

  const FamilyScreen({
    super.key,
    required this.familyCode,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool pushRegistered = false;

  @override
  void initState() {
    super.initState();

    registerFamilyDevice(widget.familyCode).then((_) {
      if (mounted) {
        setState(() {
          pushRegistered = true;
        });
      }
    });
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();

    final memberId = prefs.getString(
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

    await prefs.remove(familyCodeKey);
    await prefs.remove(familyMemberIdKey);
    await prefs.remove(selectedRoleKey);

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
          (route) => false,
    );
  }

  Future<void> claimHelpRequest(
      String requestId,
      ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Morate biti prijavljeni kako biste preuzeli provjeru.',
          ),
        ),
      );
      return;
    }

    final memberName = user.displayName?.trim();

    final displayName =
    memberName != null && memberName.isNotEmpty
        ? memberName
        : (user.email ?? 'Član obitelji');

    final requestRef = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyCode)
        .collection('help_requests')
        .doc(requestId);

    try {
      await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final snapshot =
          await transaction.get(requestRef);

          if (!snapshot.exists) {
            throw StateError('request_not_found');
          }

          final data = snapshot.data()!;

          final lifecycleStatus =
              data['lifecycleStatus']?.toString() ??
                  'open';

          if (lifecycleStatus == 'claimed') {
            final claimedBy =
                data['claimedByName']?.toString() ??
                    'drugi član obitelji';

            throw StateError(
              'already_claimed:$claimedBy',
            );
          }

          if (lifecycleStatus != 'open') {
            throw StateError('not_open');
          }

          transaction.update(
            requestRef,
            {
              'lifecycleStatus': 'claimed',
              'claimedByUid': user.uid,
              'claimedByName': displayName,
              'claimedAt':
              FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preuzeli ste provjeru.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains('already_claimed:')) {
        final claimedBy = message
            .split('already_claimed:')
            .last
            .replaceAll("'", '')
            .replaceAll(')', '')
            .trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Provjeru je već preuzeo/la $claimedBy.',
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri preuzimanju provjere: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    time.hour.toString().padLeft(2, '0');

    final minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget buildStatusCard({
    required String seniorName,
    required bool needsHelp,
    required bool isOkay,
  }) {
    final Color statusColor;

    final IconData statusIcon;

    final String statusText;

    if (needsHelp) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
      statusText = 'TREBA POMOĆ';
    } else if (isOkay) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'DOBRO JE';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = 'NEMA STATUSA';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 52,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            seniorName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReactionSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyCode)
          .collection('help_requests')
          .orderBy(
        'timestamp',
        descending: true,
      )
          .limit(1)
          .snapshots(),
      builder: (
          context,
          snapshot,
          ) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(
                alpha: 0.08,
              ),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Text(
              'Nije moguće učitati stanje reakcije.',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final requestDoc =
            snapshot.data!.docs.first;

        final requestData =
        requestDoc.data()
        as Map<String, dynamic>;

        final lifecycleStatus =
            requestData['lifecycleStatus']
                ?.toString() ??
                'open';

        final claimedBy =
        requestData['claimedByName']
            ?.toString();

        if (lifecycleStatus == 'claimed') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(
                alpha: 0.12,
              ),
              borderRadius:
              BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user,
                  color: Colors.green,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provjera je preuzeta',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        claimedBy ??
                            'Član obitelji',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            onPressed: () {
              claimHelpRequest(
                requestDoc.id,
              );
            },
            icon: const Icon(
              Icons.pan_tool_alt,
            ),
            label: const Text(
              'PREUZIMAM PROVJERU',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text(
          'Član obitelji',
        ),
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
        child:
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('families')
              .doc(widget.familyCode)
              .snapshots(),
          builder: (
              context,
              snapshot,
              ) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Greška pri povezivanju s Firebaseom.',
                    textAlign: TextAlign.center,
                  ),
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

            String seniorName =
                'Starija osoba';

            Timestamp? timestamp;

            if (snapshot.hasData &&
                snapshot.data!.exists) {
              final data =
              snapshot.data!.data()
              as Map<String, dynamic>;

              status =
                  data['status']?.toString() ??
                      'NEMA STATUSA';

              final storedSeniorName =
              data['seniorName']
                  ?.toString()
                  .trim();

              if (storedSeniorName != null &&
                  storedSeniorName.isNotEmpty) {
                seniorName =
                    storedSeniorName;
              }

              timestamp =
              data['timestamp']
              as Timestamp?;
            }

            final needsHelp =
                status == 'TREBA MI POMOĆ';

            final isOkay =
                status == 'DOBRO SAM';

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                28,
              ),
              children: [
                Text(
                  'Povezano • ${widget.familyCode}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 20),

                const Icon(
                  Icons.family_restroom,
                  size: 58,
                  color: Color(0xFF006D77),
                ),

                const SizedBox(height: 12),

                Text(
                  seniorName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                buildStatusCard(
                  seniorName: seniorName,
                  needsHelp: needsHelp,
                  isOkay: isOkay,
                ),

                if (needsHelp) ...[
                  const SizedBox(height: 18),
                  buildReactionSection(),
                ],

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF006D77,
                          ).withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color:
                          Color(0xFF006D77),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            const Text(
                              'Zadnja potvrđena aktivnost',
                              style: TextStyle(
                                color:
                                Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timestamp == null
                                  ? 'Još nema aktivnosti'
                                  : 'Danas u ${formatTime(timestamp)}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      pushRegistered
                          ? Icons
                          .notifications_active
                          : Icons.sync,
                      size: 20,
                      color: pushRegistered
                          ? Colors.green
                          : const Color(
                        0xFF006D77,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Flexible(
                      child: Text(
                        pushRegistered
                            ? 'Push obavijesti su aktivne'
                            : 'Registracija za push...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}