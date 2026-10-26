import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FollowUpTiming { overdue, today, upcoming }

/// A user's private note about a conversation. It never records a payment.
class CollectionFollowUp {
  const CollectionFollowUp({
    required this.userId,
    required this.contactKey,
    required this.clientName,
    this.note = '',
    this.lastContactedAt,
    this.nextContactAt,
    this.promisedAmount,
  });

  final String userId;
  final String contactKey;
  final String clientName;
  final String note;
  final DateTime? lastContactedAt;
  final DateTime? nextContactAt;
  final double? promisedAmount;

  String get id =>
      sha256.convert(utf8.encode('$userId|$contactKey')).toString();

  FollowUpTiming? timingAt(DateTime now) {
    final next = nextContactAt;
    if (next == null) return null;
    final day = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(next.year, next.month, next.day);
    if (scheduled.isBefore(day)) return FollowUpTiming.overdue;
    if (scheduled == day) return FollowUpTiming.today;
    return FollowUpTiming.upcoming;
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'contact_key': contactKey,
    'client_name': clientName,
    'note': note,
    'last_contacted_at': lastContactedAt?.toIso8601String(),
    'next_contact_at': nextContactAt?.toIso8601String(),
    'promised_amount': promisedAmount,
  };

  Map<String, dynamic> toFirestore() => {
    ...toMap(),
    'last_contacted_at': lastContactedAt,
    'next_contact_at': nextContactAt,
    'updated_at': FieldValue.serverTimestamp(),
  };

  factory CollectionFollowUp.fromMap(Map<String, dynamic> data) {
    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return value is String ? DateTime.tryParse(value) : null;
    }

    return CollectionFollowUp(
      userId: data['user_id'] as String,
      contactKey: data['contact_key'] as String,
      clientName: data['client_name'] as String,
      note: data['note'] as String? ?? '',
      lastContactedAt: date(data['last_contacted_at']),
      nextContactAt: date(data['next_contact_at']),
      promisedAmount: (data['promised_amount'] as num?)?.toDouble(),
    );
  }
}

class CollectionFollowUpStore {
  CollectionFollowUpStore({required this.usesFirestore, required this.userId});

  final bool usesFirestore;
  final String userId;
  String get _key => 'pago_${userId}_follow_ups';

  Future<CollectionFollowUp?> get(String contactKey) async {
    final id = CollectionFollowUp(
      userId: userId,
      contactKey: contactKey,
      clientName: '',
    ).id;
    if (usesFirestore) {
      final snapshot = await FirebaseFirestore.instance
          .collection('CollectionFollowUps')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      return snapshot.exists
          ? CollectionFollowUp.fromMap(snapshot.data()!)
          : null;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    final records = jsonDecode(raw) as Map<String, dynamic>;
    final data = records[id];
    return data == null
        ? null
        : CollectionFollowUp.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<List<CollectionFollowUp>> list() async {
    final List<CollectionFollowUp> values;
    if (usesFirestore) {
      final snapshot = await FirebaseFirestore.instance
          .collection('CollectionFollowUps')
          .where('user_id', isEqualTo: userId)
          .get(const GetOptions(source: Source.server));
      values = [
        for (final document in snapshot.docs)
          CollectionFollowUp.fromMap(document.data()),
      ];
    } else {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null) return const [];
      final records = jsonDecode(raw) as Map<String, dynamic>;
      values = [
        for (final data in records.values)
          CollectionFollowUp.fromMap(Map<String, dynamic>.from(data as Map)),
      ];
    }
    return values.where((item) => item.userId == userId).toList()..sort((a, b) {
      final left = a.nextContactAt;
      final right = b.nextContactAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
  }

  Future<void> save(CollectionFollowUp followUp) async {
    if (followUp.userId != userId ||
        followUp.note.length > 1000 ||
        followUp.clientName.length > 80 ||
        followUp.contactKey.length > 160 ||
        (followUp.promisedAmount != null &&
            (!followUp.promisedAmount!.isFinite ||
                followUp.promisedAmount! <= 0 ||
                followUp.promisedAmount! > 100000000))) {
      throw ArgumentError('Acompanhamento inválido.');
    }
    if (usesFirestore) {
      await FirebaseFirestore.instance
          .collection('CollectionFollowUps')
          .doc(followUp.id)
          .set(followUp.toFirestore());
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    final records = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    records[followUp.id] = followUp.toMap();
    await preferences.setString(_key, jsonEncode(records));
  }
}
