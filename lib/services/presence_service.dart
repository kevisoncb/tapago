import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/firestore_schema.dart';

/// Sinal leve de uso para o painel do administrador ("online" e ativos).
class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final instance = PresenceService._();

  static const interval = Duration(minutes: 5);

  String? _uid;
  Timer? _timer;
  DateTime? _lastPing;

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    WidgetsBinding.instance.addObserver(this);
    _ping(force: true);
    _timer = Timer.periodic(interval, (_) => _ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_uid != null) WidgetsBinding.instance.removeObserver(this);
    _uid = null;
    _lastPing = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ping();
      _timer ??= Timer.periodic(interval, (_) => _ping());
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _ping({bool force = false}) async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    final last = _lastPing;
    if (!force && last != null && now.difference(last) < const Duration(minutes: 4)) {
      return;
    }
    _lastPing = now;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreSchema.presence)
          .doc(uid)
          .set({
        'last_seen_at': FieldValue.serverTimestamp(),
        'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
    } catch (error) {
      debugPrint('presence: $error');
    }
  }
}
