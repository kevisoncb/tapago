import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (error) {
        debugPrint('Fuso horário indisponível: $error');
        return;
      }
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  Future<void> sync({
    required bool enabled,
    required List<Debt> debts,
  }) async {
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;

    final now = DateTime.now();
    var slot = 0;
    for (var offset = 0; offset < 14; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      final atNine = DateTime(day.year, day.month, day.day, 9);
      if (!atNine.isAfter(now)) continue;
      final due = debts.where((debt) => _shouldRemind(debt, day)).toList();
      if (due.isEmpty) continue;
      final when = tz.TZDateTime(
        tz.local,
        atNine.year,
        atNine.month,
        atNine.day,
        9,
      );
      await _plugin.zonedSchedule(
        slot,
        due.length == 1
            ? '1 débito para cobrar'
            : '${due.length} débitos para cobrar',
        _body(due),
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'cobrancas',
            'Lembretes de cobrança',
            channelDescription: 'Avisos diários de débitos a receber',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'cobranca',
      );
      slot++;
    }
  }

  bool _shouldRemind(Debt debt, DateTime day) {
    if (debt.statusPago) return false;
    final due = DateTime(
      debt.dataVencimento.year,
      debt.dataVencimento.month,
      debt.dataVencimento.day,
    );
    final start = DateTime(day.year, day.month, day.day);
    return !due.isAfter(start);
  }

  String _body(List<Debt> debts) {
    final names = debts.take(3).map((debt) => debt.nome).join(', ');
    if (debts.length <= 3) return names;
    return '$names e mais ${debts.length - 3}';
  }
}
